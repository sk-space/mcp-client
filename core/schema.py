import re
from typing import Dict, Any, List

from core.database import db_manager
from logger import get_logger

logger = get_logger(__name__)


class SchemaManager:
    def __init__(self):
        self._connection = db_manager.connect()

    def get_database_list(self, exclude_system: bool = True) -> List[str]:
        try:
            with db_manager.get_cursor() as cursor:
                if exclude_system:
                    query = """
                    SELECT SCHEMA_NAME 
                    FROM information_schema.SCHEMATA 
                    WHERE SCHEMA_NAME NOT IN (
                        'information_schema', 
                        'mysql', 
                        'performance_schema', 
                        'sys'
                    )
                    ORDER BY SCHEMA_NAME
                    """
                else:
                    query = "SHOW DATABASES"

                cursor.execute(query)
                results = cursor.fetchall()

                if exclude_system:
                    return [row['SCHEMA_NAME'] for row in results]
                else:
                    return [row['Database'] for row in results]

        except Exception as e:
            raise Exception(f"Failed to get database list: {e}")


    def get_table_list(self, database_name: str = None) -> List[str]:
        try:
            with db_manager.get_cursor() as cursor:
                if database_name:
                    cursor.execute(f"SHOW TABLES FROM `{database_name}`")
                else:
                    cursor.execute("SHOW TABLES")

                results = cursor.fetchall()

                # Results format depends on how we connect
                key = f"Tables_in_{database_name}" if database_name else list(results[0].keys())[0]
                return [row[key] for row in results]

        except Exception as e:
            raise Exception(f"Failed to get table list: {e}")


    def _get_table_basic_info(self, table_name: str, database_name: str) -> Dict:
        """Get basic table information"""
        query = """
        SELECT 
            TABLE_NAME,
            TABLE_TYPE,
            ENGINE,
            ROW_FORMAT,
            TABLE_ROWS,
            AVG_ROW_LENGTH,
            ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_mb,
            ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_mb,
            ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as total_mb,
            DATA_FREE,
            AUTO_INCREMENT,
            TABLE_COLLATION,
            CREATE_TIME,
            UPDATE_TIME,
            CHECK_TIME,
            TABLE_COMMENT
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
        """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            result = cursor.fetchone()
            return result if result else {}


    def _get_table_columns(self, table_name: str, database_name: str) -> List[str]:
        """Return column names in ordinal position order."""
        query = """
        SELECT
            COLUMN_NAME
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
        ORDER BY ORDINAL_POSITION
        """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            rows = cursor.fetchall()
        return [row["COLUMN_NAME"] for row in rows]


    def _get_table_indexes(self, table_name: str, database_name: str) -> Dict[str, Dict]:
        """
        Return minimal, query-relevant index metadata grouped by index name.
        """
        query = """
                    SELECT
                        INDEX_NAME,
                        NON_UNIQUE,
                        SEQ_IN_INDEX,
                        COLUMN_NAME,
                        INDEX_TYPE,
                        CARDINALITY,
                        SUB_PART
                    FROM information_schema.STATISTICS
                    WHERE TABLE_SCHEMA = %s
                      AND TABLE_NAME = %s
                    ORDER BY INDEX_NAME, SEQ_IN_INDEX
                """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            rows = cursor.fetchall()

        indexes: Dict[str, Dict] = {}

        for row in rows:
            name = row["INDEX_NAME"]

            if name not in indexes:
                indexes[name] = {
                    "unique": row["NON_UNIQUE"] == 0,
                    "type": row["INDEX_TYPE"],
                    "cardinality": row["CARDINALITY"],
                    "columns": []
                }

            indexes[name]["columns"].append({
                "name": row["COLUMN_NAME"],
                "prefix_length": row["SUB_PART"]
            })

        return indexes

    def _get_foreign_keys(self, table_name: str, database_name: str) -> List[Dict[str, Any]]:
        """Return foreign key metadata grouped by constraint (supports composite FKs)."""
        query = """
                SELECT kcu.CONSTRAINT_NAME,
                       kcu.COLUMN_NAME,
                       kcu.REFERENCED_TABLE_NAME,
                       kcu.REFERENCED_COLUMN_NAME,
                       kcu.ORDINAL_POSITION
                FROM information_schema.KEY_COLUMN_USAGE kcu
                WHERE kcu.TABLE_SCHEMA = %s
                  AND kcu.TABLE_NAME = %s
                  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
                ORDER BY kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION
                """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            rows = cursor.fetchall()

        fks: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            name = row["CONSTRAINT_NAME"]
            if name not in fks:
                fks[name] = {
                    "name": name,
                    "referenced_table": row["REFERENCED_TABLE_NAME"],
                    "column_mapping": [],
                }
            fks[name]["column_mapping"].append(
                {"local": row["COLUMN_NAME"], "referenced": row["REFERENCED_COLUMN_NAME"]}
            )

        return list(fks.values())

    def _get_table_constraints(self, table_name: str, database_name: str) -> List[Dict]:
        """Get table constraints"""
        query = """
                SELECT 
                    CONSTRAINT_NAME,
                    CONSTRAINT_TYPE
                FROM information_schema.TABLE_CONSTRAINTS
                WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
                ORDER BY CONSTRAINT_TYPE
                """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            return cursor.fetchall()


    def _get_referential_constraints(self, table_name: str, database_name: str) -> List[Dict]:
        """Get detailed referential constraints"""
        query = """
        SELECT 
            CONSTRAINT_NAME,
            UNIQUE_CONSTRAINT_SCHEMA,
            UNIQUE_CONSTRAINT_NAME,
            MATCH_OPTION,
            UPDATE_RULE,
            DELETE_RULE
        FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = %s AND TABLE_NAME = %s
        """

        with db_manager.get_cursor() as cursor:
            cursor.execute(query, (database_name, table_name))
            return cursor.fetchall()

    def _get_create_statement(self, table_name: str, database_name: str) -> str:
        """Get CREATE TABLE statement as a single line"""
        with db_manager.get_cursor() as cursor:
            cursor.execute(f"SHOW CREATE TABLE `{database_name}`.`{table_name}`")
            result = cursor.fetchone()

        create_sql = result['Create Table'] if result else ""

        # Remove newlines and extra spaces
        create_sql_single_line = " ".join(create_sql.replace("\n", " ").replace("\r", " ").split())

        return create_sql_single_line



    def get_schema(self, database_name: str = None) -> Dict[str, Any]:
        """Return lean schema for LLM context: create_statement, columns (names only), foreign_keys."""
        schema_info: Dict[str, Any] = {"tables": {}}

        try:
            tables = self.get_table_list(database_name=database_name)

            for table in tables:
                schema_info["tables"][table] = {
                    "create_statement": self._get_create_statement(table, database_name),
                    "columns": self._get_table_columns(table, database_name),
                    "foreign_keys": self._get_foreign_keys(table, database_name),
                }

            return schema_info

        except Exception as e:
            logger.info(f"Error getting schema: {e}")
            raise

    def get_schema_string(self, database_name: str = None) -> str:
        """Convert schema to a compact string format for debugging."""
        schema_info = self.get_schema(database_name)
        schema_string = "Database Schema:\n\n"

        for table_name, table_info in schema_info["tables"].items():
            schema_string += f"Table: {table_name}\n"
            schema_string += f"Create Statement: {table_info['create_statement']}\n"
            schema_string += "Columns:\n"
            for col_name in table_info.get("columns", []):
                schema_string += f"  - {col_name}\n"

            fks = table_info.get("foreign_keys") or []
            if fks:
                schema_string += "Foreign Keys:\n"
                for fk in fks:
                    ref_table = fk.get("referenced_table", "")
                    mapping = fk.get("column_mapping", [])
                    pairs = ", ".join([f"{m.get('local')}->{ref_table}.{m.get('referenced')}" for m in mapping])
                    schema_string += f"  - {pairs}\n"

            schema_string += "\n"

        return schema_string

    def parse_schema_string(self, schema_string: str) -> Dict[str, Any]:
        """Parse the debug schema string back into the lean dict shape."""
        schema: Dict[str, Any] = {"tables": {}}
        current_table: Dict[str, Any] = {}

        for raw in schema_string.splitlines():
            line = raw.strip()
            if not line:
                continue

            if line.startswith("Table:"):
                table_name = line.replace("Table:", "").strip()
                current_table = {
                    "create_statement": "",
                    "columns": [],
                    "foreign_keys": [],
                }
                schema["tables"][table_name] = current_table
                continue

            if not current_table:
                continue

            if line.startswith("Create Statement:"):
                current_table["create_statement"] = line.replace("Create Statement:", "").strip()
                continue

            if line.startswith("-"):
                # Column line inside "Columns:" block
                m = re.match(r"-\s+(\w+)$", line)
                if m:
                    current_table["columns"].append(m.group(1))
                continue

        return schema


schema_manager = SchemaManager()
