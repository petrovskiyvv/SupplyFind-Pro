from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    TAVILY_API_KEY: str
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/food_supplier_db"
    DEEPSEEK_API_KEY: Optional[str] = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
