from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """App settings read from environment variables (see .env.example)."""

    database_url: str  # DATABASE_URL
    jwt_secret: str  # JWT_SECRET


settings = Settings()
