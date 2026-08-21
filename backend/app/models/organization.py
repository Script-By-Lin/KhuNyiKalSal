import uuid
from typing import Optional, TYPE_CHECKING

from datetime import datetime, timezone
from sqlalchemy import String, Float, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base
from app.core.privacy import encrypt_field, decrypt_field

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.volunteer import Volunteer


class Organization(Base):
    """Rescue organization with geographic location and coverage radius."""

    __tablename__ = "organizations"

    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"),
        primary_key=True,
    )
    org_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(500), nullable=False)
    phone_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)

    geo_lat: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    geo_lng: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    registration_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    headquarters_address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    operating_regions: Mapped[Optional[str]] = mapped_column(String(255), default="Yangon")
    category: Mapped[str] = mapped_column(String(50), default="Medical", index=True)
    status: Mapped[str] = mapped_column(String(50), default="Active")
    coverage_radius_km: Mapped[float] = mapped_column(Float, default=50.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    account: Mapped["Account"] = relationship(back_populates="organization")
    volunteers: Mapped[list["Volunteer"]] = relationship(
        back_populates="organization", lazy="selectin"
    )

    def get_decrypted_phone(self) -> str:
        """Return decrypted phone number using stored salt."""
        dec = decrypt_field(self.phone_number, self.phone_salt)
        if dec:
            return dec
        if self.phone_number and not self.phone_number.startswith("gAAAAA"):
            return self.phone_number
        return ""

    def set_salted_phone(self, raw_phone: str):
        """Encrypt and set phone number with a cryptographic salt."""
        enc, salt = encrypt_field(raw_phone, self.phone_salt)
        if enc:
            self.phone_number = enc
            self.phone_salt = salt
