from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Settings come from environment variables (12-factor style)."""

    app_name: str = "Pragya Campus Library API"
    app_version: str = "1.0.0"
    database_url: str = "postgresql+psycopg://library:library@localhost:5432/library"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
