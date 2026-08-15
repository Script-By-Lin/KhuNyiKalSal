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

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            val_clean = value.strip().upper()
            for member in cls:
                if member.value == val_clean or member.name.upper() == val_clean:
                    return member
        return None


class RobustRoleEnum(SAEnum):
    """
    Native PostgreSQL Enum for roleenum that binds correctly to PostgreSQL
    while overriding result_processor to safely handle case-insensitive values without LookupError.
    """
    def result_processor(self, dialect, coltype):
        def process(value):
            if value is None:
                return None
            if isinstance(value, self.enum_class):
                return value
            val_clean = str(value).strip().upper()
            for member in self.enum_class:
                if str(member.value).upper() == val_clean or member.name.upper() == val_clean:
                    return member
            try:
                return self.enum_class(val_clean)
            except Exception:
                return RoleEnum.USER
        return process

    def bind_processor(self, dialect):
        def process(value):
            if value is None:
                return None
            if isinstance(value, self.enum_class):
                return value.value
            val_clean = str(value).strip().upper()
            for member in self.enum_class:
                if str(member.value).upper() == val_clean or member.name.upper() == val_clean:
                    return member.value
            return val_clean
        return process


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
        RobustRoleEnum(RoleEnum, name="roleenum"),
        nullable=False,
        default=RoleEnum.USER,
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
