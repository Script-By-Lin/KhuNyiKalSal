from typing import Optional
from pydantic_settings import BaseSettings
import os

class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    DATABASE_URL: Optional[str] = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///khunyikalsal.db")
    SECRET_KEY: str = "your-super-secret-key-change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30  # Short-lived 30 mins
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    SESSION_INACTIVITY_HOURS: int = 24  # Expire sessions after 24h of inactivity
    MAX_USER_SESSIONS: int = 3  # Max 3 active devices for regular users
    MAX_VOLUNTEER_SESSIONS: int = 1  # Exactly 1 active device for volunteers
    MAX_SOS_PER_DAY: int = 100
    VOLUNTEER_TIMEOUT_SECONDS: int = 300  # 5 minutes per organization
    REDIS_URL: Optional[str] = os.getenv("REDIS_URL", "redis://localhost:6379")

    model_config = {"env_file": ".env", "extra": "ignore"}

    @property
    def async_database_url(self) -> str:
        """Fix Postgres URI schemes for SQLAlchemy asyncpg."""
        url = self.DATABASE_URL or "sqlite+aiosqlite:///khunyikalsal.db"
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif url.startswith("postgresql://") and not url.startswith("postgresql+asyncpg://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


settings = Settings()
