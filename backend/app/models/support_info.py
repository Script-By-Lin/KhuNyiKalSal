import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import String, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base


class SupportInfo(Base):
    """Organization donation channels (KBZPay, WavePay, Bank Accounts, MMQR) managed by Admin."""

    __tablename__ = "support_info"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    kbz_pay_name: Mapped[str] = mapped_column(String(100), default="Khu Nyi Kal Sal Relief Fund")
    kbz_pay_phone: Mapped[str] = mapped_column(String(50), default="09789123456")
    wave_pay_name: Mapped[str] = mapped_column(String(100), default="Khu Nyi Kal Sal Relief Fund")
    wave_pay_phone: Mapped[str] = mapped_column(String(50), default="09789123456")
    bank_name: Mapped[str] = mapped_column(String(100), default="KBZ Bank")
    bank_account_number: Mapped[str] = mapped_column(String(100), default="123-456-789012345")
    bank_account_name: Mapped[str] = mapped_column(String(100), default="Khu Nyi Kal Sal Emergency Response")
    mmqr_payload: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    note_message: Mapped[Optional[str]] = mapped_column(Text, default="All donations directly support emergency rescue operations, first aid kits, and blood drives.")

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
