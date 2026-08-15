import uuid
import enum
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING

from sqlalchemy import Float, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.organization import Organization


class EmergencyType(str, enum.Enum):
    FIRE = "fire"
    MEDICAL = "medical"
    ACCIDENT = "accident"
    NATURAL_DISASTER = "natural_disaster"
    CRIME = "crime"

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            val_clean = value.strip().lower()
            for member in cls:
                if member.value == val_clean or member.name.lower() == val_clean:
                    return member
        return None


class EmergencyStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            val_clean = value.strip().lower()
            for member in cls:
                if member.value == val_clean or member.name.lower() == val_clean:
                    return member
        return None


class Emergency(Base):
    """An SOS emergency event created by a user."""

    __tablename__ = "emergencies"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False
    )
    type: Mapped[EmergencyType] = mapped_column(
        SAEnum(EmergencyType, name="emergency_type_enum", values_callable=lambda x: [e.value for e in x]), nullable=False, index=True
    )
    status: Mapped[EmergencyStatus] = mapped_column(
        SAEnum(EmergencyStatus, name="emergency_status_enum"),
        default=EmergencyStatus.PENDING, index=True
    )
    assigned_org_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("organizations.account_id"), nullable=True, index=True
    )
    assigned_volunteer_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("volunteers.account_id"), nullable=True, index=True
    )
    location_lat: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    location_lng: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=True,
    )

    user: Mapped["Account"] = relationship(foreign_keys=[user_id], lazy="selectin")
    assigned_org: Mapped[Optional["Organization"]] = relationship(foreign_keys=[assigned_org_id], lazy="selectin")
    assigned_volunteer: Mapped[Optional["Volunteer"]] = relationship(foreign_keys=[assigned_volunteer_id], lazy="selectin")
