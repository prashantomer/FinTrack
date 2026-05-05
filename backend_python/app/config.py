from zoneinfo import ZoneInfo

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60       # 1 hour
    refresh_token_expire_minutes: int = 180     # 3 hours
    environment: str = "development"
    log_level: str = "INFO"
    app_timezone: str = "Asia/Kolkata"
    redis_url: str | None = None
    dashboard_cache_refresh_minutes: int = 5  # allowed: 1, 5, 10, 60


settings = Settings()

TZ = ZoneInfo(settings.app_timezone)
