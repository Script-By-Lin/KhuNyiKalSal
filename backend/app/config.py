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
    VOLUNTEER_TIMEOUT_SECONDS: int = 180  # 3 minutes per organization
    SOS_REROUTE_TIMEOUT_SECONDS: int = 180  # 3 minutes auto-reroute timeout
    REDIS_URL: Optional[str] = os.getenv("REDIS_URL", "redis://localhost:6379")
    FCM_SERVER_KEY: Optional[str] = os.getenv("FCM_SERVER_KEY", None)
    FIREBASE_CREDENTIALS_JSON: Optional[str] = os.getenv("FIREBASE_CREDENTIALS_JSON", None)

    # EmailJS Configuration
    EMAILJS_SERVICE_ID: Optional[str] = os.getenv("EMAILJS_SERVICE_ID", "service_7eznh8w")
    EMAILJS_TEMPLATE_ID: Optional[str] = os.getenv("EMAILJS_TEMPLATE_ID", "template_dfpnmo9")
    EMAILJS_PUBLIC_KEY: Optional[str] = os.getenv("EMAILJS_PUBLIC_KEY", "GnGSWrvd1vwRf9sie")
    EMAILJS_PRIVATE_KEY: Optional[str] = os.getenv("EMAILJS_PRIVATE_KEY", None)

    # OTP Configuration
    OTP_VALIDITY_SECONDS: int = int(os.getenv("OTP_VALIDITY_SECONDS", "30"))

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
