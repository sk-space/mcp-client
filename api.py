import json
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from client import MCPClient
from core.config import config
from core.schema import schema_manager
from logger import get_logger, setup_file_logging

setup_file_logging("server.log")
logger = get_logger(__name__)



@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting MCP Client API with MCP server at {config.MCP_SERVER_URL}")
    client = MCPClient(config.MCP_SERVER_URL)
    try:
        connected = await client.connect_to_server()
        if not connected:
            raise HTTPException(
                status_code=500, detail="Failed to connect to MCP server"
            )
        app.state.client = client
        yield
    except Exception as e:
        logger.info(f"Error during lifespan: {e}")
        raise HTTPException(status_code=500, detail="Error during lifespan") from e
    finally:
        # shutdown
        await client.cleanup()


app = FastAPI(title="MCP Client API", lifespan=lifespan)


# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)


class QueryRequest(BaseModel):
    query: str


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}


@app.get("/api/tools")
async def get_tools():
    """Get the list of available tools"""
    try:
        tools = await app.state.client.get_mcp_tools()
        return {
            "tools": [
                {
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.inputSchema,
                }
                for tool in tools
            ]
        }
    except Exception as e:
        logger.info(f"Failed to get available tools: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/schema")
async def get_schema():
    """Get the database schema"""
    try:
        schema = await schema_manager.get_schema_info(config.DB_NAME)
        return {"schema": schema}
    except Exception as e:
        logger.info(f"Failed to get database schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/query")
async def process_query(request: QueryRequest):
    """Process a query and return the response"""
    try:
        schema_string = schema_manager.get_schema_string(config.DB_NAME)
        schema = schema_manager.parse_schema_string(schema_string)
        response = await app.state.client.process_query(request.query, schema)
        return json.loads(response)
    except Exception as e:
        logger.info(f"Failed to generate sql: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))





if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=f"{config.API_HOST}", port=config.API_PORT)