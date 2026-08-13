import uuid
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Float, Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base
from app.core.privacy import encrypt_field, decrypt_field

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.organization import Organization


class Volunteer(Base):
    """Volunteer managed by an organization. Receives and responds to SOS alerts."""

    __tablename__ = "volunteers"

    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"),
        primary_key=True,
    )
    org_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("organizations.account_id", ondelete="CASCADE"),
        nullable=False,
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(500), nullable=False)
    phone_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)

    nrc_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    date_of_birth: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    emergency_contact: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    assigned_region: Mapped[Optional[str]] = mapped_column(String(100), default="Yangon")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    current_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    current_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    account: Mapped["Account"] = relationship(back_populates="volunteer")
    organization: Mapped["Organization"] = relationship(back_populates="volunteers")

    def get_decrypted_phone(self) -> str:
        """Return decrypted phone number using stored salt."""
        return decrypt_field(self.phone_number, self.phone_salt) or self.phone_number

    def set_salted_phone(self, raw_phone: str):
        """Encrypt and set phone number with a cryptographic salt."""
        enc, salt = encrypt_field(raw_phone, self.phone_salt)
        if enc:
            self.phone_number = enc
            self.phone_salt = salt
