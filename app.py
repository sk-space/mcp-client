import streamlit as st
from logger import get_logger, setup_file_logging
import requests
import pandas as pd

st.set_page_config(layout="wide")
setup_file_logging("server.log")
logger = get_logger(__name__)

base_url = "http://localhost:8001/api"

st.title("Welcome, NL2SQL")


@st.cache_data(ttl=60, show_spinner=False)
def fetch_schema_json(url: str) -> dict:
    endpoint = f"{url}/schema"
    resp = requests.get(endpoint, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    return data if isinstance(data, dict) else {"tables": {}}


def run_nl_query(url: str, nl_query: str) -> str | None:
    endpoint = f"{url}/query"
    payload = {"query": nl_query}
    resp = requests.post(endpoint, json=payload, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    return data.get("sql")


def execute_sql(url: str, sql: str) -> dict:
    endpoint = f"{url}/execute-sql"
    resp = requests.post(endpoint, json={"query": sql}, timeout=60)
    resp.raise_for_status()
    return resp.json()


def results_to_df(result_json: dict) -> pd.DataFrame:
    rows = result_json.get("data") or []
    cols = result_json.get("columns") or []

    if not isinstance(rows, list):
        rows = [rows]

    df = pd.DataFrame(rows)

    if cols and not df.empty:
        ordered = [c for c in cols if c in df.columns]
        if ordered:
            df = df.reindex(columns=ordered)

    return df


def schema_tables_to_rows(schema_json: dict) -> dict[str, pd.DataFrame]:
    """Convert schema JSON into per-table DataFrames.

    Expected shape (from /api/schema):
        {"tables": {"table": {"columns": {"col": {"type": str, "primary_key": bool, "nullable": bool}}}}}
    """
    tables = schema_json.get("tables") if isinstance(schema_json, dict) else None
    if not isinstance(tables, dict):
        return {}

    out: dict[str, pd.DataFrame] = {}
    for table_name, table_info in tables.items():
        if not isinstance(table_info, dict):
            continue

        cols = table_info.get("columns")
        if not isinstance(cols, dict):
            cols = {}

        rows = []
        for col_name, meta in cols.items():
            meta = meta if isinstance(meta, dict) else {}
            rows.append(
                {
                    "column": col_name,
                    "type": meta.get("type", ""),
                    "pk": bool(meta.get("primary_key", False)),
                    "nullable": bool(meta.get("nullable", True)),
                }
            )

        df = pd.DataFrame(rows)
        if not df.empty:
            df = df.sort_values(by=["pk", "column"], ascending=[False, True], kind="mergesort")

        out[str(table_name)] = df

    return out


# ---------- Layout ----------
left, right = st.columns([2, 3], gap="large")

# ---------- Schema (left) ----------
with left:
    header_cols = st.columns([12, 1], vertical_alignment="center")
    with header_cols[0]:
        st.subheader("Database Schema")
    with header_cols[1]:
        refresh_schema = st.button("⟳", help="Refresh schema")

    st.caption("Cached for 60s")

    if refresh_schema:
        fetch_schema_json.clear()

    # A fixed-height scroll area for the schema content only (scrollbar only on the left).
    schema_scroll = st.container(height=650, border=True)

    with schema_scroll:
        try:
            with st.spinner("Loading schema..."):
                schema_json = fetch_schema_json(base_url)
        except requests.RequestException as e:
            logger.exception("Schema request failed")
            st.error(f"Schema request failed: {e}")
            schema_json = None
        except ValueError:
            logger.exception("Schema returned non-JSON")
            st.error("Schema response was not valid JSON.")
            schema_json = None

        if schema_json:
            tables_map = schema_json.get("tables", {}) if isinstance(schema_json, dict) else {}
            if not isinstance(tables_map, dict) or not tables_map:
                st.info("No tables found in schema response.")
            else:
                table_names = sorted(tables_map.keys(), key=lambda s: str(s).lower())
                st.caption(f"Tables: {len(table_names)}")

                per_table = schema_tables_to_rows(schema_json)

                for t in table_names:
                    df_cols = per_table.get(str(t), pd.DataFrame(columns=["column", "type", "pk", "nullable"]))
                    col_count = int(len(df_cols)) if isinstance(df_cols, pd.DataFrame) else 0

                    with st.expander(f"{t} ({col_count} columns)", expanded=False):
                        if isinstance(df_cols, pd.DataFrame) and not df_cols.empty:
                            st.dataframe(
                                df_cols,
                                use_container_width=True,
                                hide_index=True,
                                height=min(360, 34 * (len(df_cols) + 1)),
                            )
                        else:
                            st.caption("No column details available.")


# ---------- Query + results (right) ----------
with right:
    st.subheader("Ask a question")

    with st.form("nl2sql_form", clear_on_submit=False, border=True):
        query = st.text_area(
            "Your question",
            key="query",
            height=120,
            placeholder="e.g. Show top 10 customers by total revenue in the last 30 days",
        )

        form_cols = st.columns([1, 1, 2])
        with form_cols[0]:
            submit = st.form_submit_button("Run", type="primary", use_container_width=True)
        with form_cols[1]:
            clear = st.form_submit_button("Clear", use_container_width=True)
        with form_cols[2]:
            st.caption("We’ll generate SQL, execute it, and show results below.")

    if clear:
        st.session_state["query"] = ""

    # Stable placeholders so the layout doesn’t jump around
    status_ph = st.empty()
    tabs = st.tabs(["Results", "Generated SQL", "Raw response"])

    if submit:
        if not query.strip():
            status_ph.error("Please enter a query.")
        else:
            status_ph.info("Generating SQL…")

            sql = None
            result_json: dict | None = None

            try:
                sql = run_nl_query(base_url, query.strip())
                logger.info("SQL: %s", sql)
            except requests.RequestException as e:
                logger.exception("/query request failed")
                status_ph.error(f"Query request failed: {e}")
            except ValueError:
                logger.exception("/query returned non-JSON")
                status_ph.error("Query response was not valid JSON.")

            if sql:
                status_ph.success("SQL generated. Executing…")
                try:
                    result_json = execute_sql(base_url, sql)
                    logger.info("execute-sql success=%s", result_json.get("success"))
                except requests.RequestException as e:
                    logger.exception("execute-sql request failed")
                    status_ph.error(f"SQL execution request failed: {e}")
                except ValueError:
                    logger.exception("execute-sql returned non-JSON")
                    status_ph.error("SQL execution response was not valid JSON.")

            with tabs[1]:
                st.markdown("#### Generated SQL")
                st.code(sql or "No SQL generated.", language="sql")

            with tabs[2]:
                st.markdown("#### Raw response")
                # Show both, useful for debugging
                st.json({"query": query.strip(), "sql": sql, "result": result_json})

            with tabs[0]:
                st.markdown("#### Query Result")

                if not sql:
                    st.info("No SQL to execute yet.")
                elif not result_json:
                    st.info("No execution result yet.")
                elif not result_json.get("success", False):
                    st.error("SQL execution failed.")
                    st.json(result_json)
                else:
                    df = results_to_df(result_json)

                    metrics = st.columns(3)
                    with metrics[0]:
                        st.metric("Rows", int(len(df)))
                    with metrics[1]:
                        st.metric("Columns", int(len(df.columns)))
                    with metrics[2]:
                        st.metric("Status", "OK")

                    st.dataframe(df, use_container_width=True, hide_index=True)

            if sql and result_json and result_json.get("success", False):
                status_ph.success("Done.")
