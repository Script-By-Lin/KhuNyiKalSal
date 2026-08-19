import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship as sa_relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base

if TYPE_CHECKING:
    from app.models.account import Account


class FamilyGroup(Base):
    """Family group managed by a creator."""

    __tablename__ = "family_groups"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    group_name: Mapped[str] = mapped_column(String(255), nullable=False)
    creator_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    creator: Mapped["Account"] = sa_relationship(foreign_keys=[creator_id], lazy="selectin")
    members: Mapped[list["FamilyMember"]] = sa_relationship(
        back_populates="family_group", cascade="all, delete-orphan", lazy="selectin"
    )
    alerts: Mapped[list["FamilyAlert"]] = sa_relationship(
        back_populates="family_group", cascade="all, delete-orphan", lazy="selectin"
    )


class FamilyMember(Base):
    """Member belonging to a family group with a relationship title."""

    __tablename__ = "family_members"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    family_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("family_groups.id", ondelete="CASCADE"), nullable=False
    )
    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False
    )
    relationship: Mapped[str] = mapped_column(
        String(50), nullable=False, default="Other"
    )  # Father, Mother, Son, Daughter, Spouse, Sibling, Other
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="accepted", server_default="accepted"
    )  # pending, accepted, denied
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    family_group: Mapped["FamilyGroup"] = sa_relationship(back_populates="members")
    account: Mapped["Account"] = sa_relationship(foreign_keys=[account_id], lazy="selectin")


class FamilyAlert(Base):
    """Emergency alert message pushed to all family group members when an SOS is triggered."""

    __tablename__ = "family_alerts"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    family_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("family_groups.id", ondelete="CASCADE"), nullable=False
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False
    )
    emergency_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("emergencies.id", ondelete="SET NULL"), nullable=True
    )
    emergency_type: Mapped[str] = mapped_column(String(50), nullable=False)
    location_lat: Mapped[float] = mapped_column(Float, nullable=False)
    location_lng: Mapped[float] = mapped_column(Float, nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    is_resolved: Mapped[bool] = mapped_column(default=False, server_default="false", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    family_group: Mapped["FamilyGroup"] = sa_relationship(back_populates="alerts")
    sender: Mapped["Account"] = sa_relationship(foreign_keys=[sender_id], lazy="selectin")
