from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """App settings read from environment variables (see .env.example)."""

    database_url: str  # DATABASE_URL
    jwt_secret: str = Field(min_length=32)  # JWT_SECRET: at least 32 random bytes
    jwt_expires_seconds: int = 24 * 60 * 60  # JWT_EXPIRES_SECONDS: 24 hours by default


settings = Settings()
