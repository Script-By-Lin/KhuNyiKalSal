import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base
from app.core.privacy import encrypt_field, decrypt_field

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.organization import Organization


class BloodDonation(Base):
    """Blood donation pledge / appointment request submitted by a user."""

    __tablename__ = "blood_donations"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    donor_name: Mapped[str] = mapped_column(String(255), nullable=False)
    donor_phone: Mapped[str] = mapped_column(String(500), nullable=False)
    donor_phone_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    blood_type: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    age: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    medical_notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    target_org_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("organizations.account_id", ondelete="SET NULL"), nullable=True, index=True
    )
    target_location_name: Mapped[str] = mapped_column(String(255), nullable=False)
    target_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    target_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    preferred_date: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    units: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(50), default="Pending", index=True)  # Pending, Accepted, Completed, Cancelled
    
    # Details provided by the Organization when accepting the appointment
    appointment_date: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    appointment_location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    appointment_notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=True,
    )

    user: Mapped["Account"] = relationship(foreign_keys=[user_id], lazy="selectin")
    target_org: Mapped[Optional["Organization"]] = relationship(foreign_keys=[target_org_id], lazy="selectin")

    def get_decrypted_phone(self) -> str:
        """Return decrypted donor phone number using stored salt."""
        return decrypt_field(self.donor_phone, self.donor_phone_salt) or self.donor_phone

    def set_salted_phone(self, raw_phone: str):
        """Encrypt and set donor phone with a cryptographic salt."""
        enc, salt = encrypt_field(raw_phone, self.donor_phone_salt)
        if enc:
            self.donor_phone = enc
            self.donor_phone_salt = salt
