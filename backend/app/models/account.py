import uuid
import enum
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Boolean, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base

if TYPE_CHECKING:
    from app.models.user_profile import UserProfile
    from app.models.organization import Organization
    from app.models.volunteer import Volunteer
    from app.models.session import UserSession


class RoleEnum(str, enum.Enum):
    USER = "USER"
    ORGANIZATION = "ORGANIZATION"
    VOLUNTEER = "VOLUNTEER"
    ADMIN = "ADMIN"


class Account(Base):
    """Unified authentication table for all roles."""

    __tablename__ = "accounts"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[RoleEnum] = mapped_column(
        SAEnum(RoleEnum, name="roleenum"),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # One-to-one relationships to role-specific profiles
    user_profile: Mapped[Optional["UserProfile"]] = relationship(
        back_populates="account", uselist=False, lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )
    organization: Mapped[Optional["Organization"]] = relationship(
        back_populates="account", uselist=False, lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )
    volunteer: Mapped[Optional["Volunteer"]] = relationship(
        back_populates="account", uselist=False, lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )
    sessions: Mapped[list["UserSession"]] = relationship(
        back_populates="account", lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )
