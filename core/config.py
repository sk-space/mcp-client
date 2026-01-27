import os
from dataclasses import dataclass
from pathlib import Path
from logger import get_logger


logger = get_logger(__name__)

@dataclass
class Config:
    # Database Configuration
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: int = int(os.getenv("DB_PORT", 3306))
    DB_USER: str = os.getenv("DB_USER", "root")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "toor")
    DB_NAME: str = os.getenv("DB_NAME", "test_db")

    # MCP Server Configuration
    MCP_SERVER_URL = os.getenv("MCP_SERVER_URL")

    # API Configuration
    API_HOST: str = os.getenv("API_HOST", "localhost")
    API_PORT: int = int(os.getenv("API_PORT", 8001))

    # Application Paths
    BASE_DIR: Path = Path(__file__).parent.parent

    def validate(self):
        """Validate configuration"""
        required_vars = {
            "DB_HOST": self.DB_HOST,
            "DB_USER": self.DB_USER,
            "DB_NAME": self.DB_NAME,
            "MCP_SERVER_URL": self.MCP_SERVER_URL,
        }

        missing = [var for var, value in required_vars.items() if not value]
        if missing:
            raise ValueError(f"Missing required configuration: {', '.join(missing)}")


# Create and validate config
config = Config()

try:
    config.validate()
    logger.info("Configuration validated")
except ValueError as e:
    logger.info("Configuration error: {e}")