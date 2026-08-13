import socket
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    DATABASE_URL: str = "postgresql+asyncpg://postgres:KOkVhtgUPDVkBFjaPekgrdeJLVqLLxQw@postgres.railway.internal:5432/railway"
    SECRET_KEY: str = "your-super-secret-key-change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours
    MAX_SOS_PER_DAY: int = 100
    VOLUNTEER_TIMEOUT_SECONDS: int = 300  # 5 minutes per organization
    REDIS_URL: str = "redis://default:FjJkHWjFHbWJpeVGXNGttEMAZFXMkOwA@redis.railway.internal:6379"

    model_config = {"env_file": ".env", "extra": "ignore"}

    @property
    def async_database_url(self) -> str:
        """Fix Railway Postgres URI schemes for SQLAlchemy asyncpg & handle local DNS fallback."""
        url = self.DATABASE_URL
        if "railway.internal" in url:
            try:
                socket.gethostbyname("postgres.railway.internal")
            except socket.gaierror:
                # Running locally outside Railway internal network — fallback to SQLite
                return "sqlite+aiosqlite:///./khunyikalsal.db"

        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif url.startswith("postgresql://") and not url.startswith("postgresql+asyncpg://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


settings = Settings()
