import traceback

from fastmcp import Client
from fastmcp.client.transports import StreamableHttpTransport

from logger import get_logger

logger = get_logger(__name__)


class MCPClient:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.tools = []
        self.transport = None
        self.session = None


    # connect to MCP server
    async def connect_to_server(self):
        if self.session:
            return True

        self.transport = StreamableHttpTransport(url=self.base_url)
        self.session = Client(self.transport)

        try:
            await self.session.__aenter__()
            await self.session.initialize()

            tools_response = await self.session.list_tools()
            logger.info(f"Tools found {tools_response} tools")

            self.tools = [
                {
                    "name": tool.name,
                    "description": tool.description.replace("\n", " ").strip(),
                    "input_schema": tool.inputSchema,
                }
                for tool in tools_response
            ]
            logger.info(f"Available tools: {self.tools}")

            return True

        except Exception:
            await self.session.__aexit__(None, None, None)
            self.session = None
            raise


    # get mcp tool list
    async def get_mcp_tools(self):
        try:
            response = await self.session.list_tools()
            return response

        except Exception as e:
            logger.error(f"Error getting to MCP tools: {e}")
            raise


    # process query
    async def process_query(self, natural_language_query: str, schema_context: str):
        try:
            tool_names = [tool.get("name") for tool in self.tools if "name" in tool]
            if not "tool_convert_to_sql" in tool_names:
                logger.info("Required tool not found for processing query.\n Exiting the process.")
                raise

            response = await self.session.call_tool("tool_convert_to_sql", arguments={"query": natural_language_query, "schema_context": schema_context})

            logger.info(f"Processed query response: {response}")

            return response.content[0].text

        except Exception as e:
            logger.error(f"Error processing query: {e}")
            raise



    # cleanup
    async def cleanup(self):
        try:
            await self.session.__aexit__(None, None, None)
            logger.info("Cleaned up MCP server")
        except Exception as e:
            logger.error(f"Error during cleanup: {e}")
            traceback.print_exc()
            raise