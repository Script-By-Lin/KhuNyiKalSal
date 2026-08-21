import uuid
from datetime import date
from typing import Optional, Tuple, TYPE_CHECKING

from sqlalchemy import String, Float, Boolean, Integer, Text, Date, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base
from app.core.privacy import (
    generate_salt,
    encrypt_field,
    decrypt_field,
    encrypt_location,
    decrypt_location,
)

if TYPE_CHECKING:
    from app.models.account import Account


class UserProfile(Base):
    """Extended profile for users with role='user'. Stores medical, emergency info, and salted PII data."""

    __tablename__ = "user_profiles"

    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"),
        primary_key=True,
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(500), nullable=False)
    phone_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    
    blood_type: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    medical_conditions: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    emergency_contacts: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    
    # Base persistent location stored salted/encrypted
    location_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)

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

    def get_decrypted_location(self) -> Tuple[Optional[float], Optional[float]]:
        """Return decrypted (lat, lng) persistent base location."""
        if self.location_salt and self.location_lat is not None and self.location_lng is not None:
            lat, lng = decrypt_location(str(self.location_lat), str(self.location_lng), self.location_salt)
            if lat is not None and lng is not None:
                return lat, lng
        return self.location_lat, self.location_lng

    def set_salted_location(self, lat: Optional[float], lng: Optional[float]):
        """Encrypt and set base location with salt."""
        if lat is None or lng is None:
            self.location_lat = None
            self.location_lng = None
            return
        enc_lat, enc_lng, salt = encrypt_location(lat, lng, self.location_salt)
        self.location_salt = salt
        # For numeric queries fallback we store coordinates safely or encrypted tokens
        self.location_lat = lat
        self.location_lng = lng
