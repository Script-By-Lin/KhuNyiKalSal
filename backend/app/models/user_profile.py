import uuid
from datetime import date
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Float, Boolean, Integer, Text, Date, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base

if TYPE_CHECKING:
    from app.models.account import Account


class UserProfile(Base):
    """Extended profile for users with role='user'. Stores medical and emergency info."""

    __tablename__ = "user_profiles"

    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"),
        primary_key=True,
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(50), nullable=False)
    blood_type: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    medical_conditions: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    emergency_contacts: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    location_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    family_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    nrc_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    date_of_birth: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    medical_profile: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    address_info: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    last_synced_at: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    sos_count_today: Mapped[int] = mapped_column(Integer, default=0)
    last_sos_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    account: Mapped["Account"] = relationship(back_populates="user_profile")
