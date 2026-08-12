import uuid
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Float, Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.database import Base

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
    phone_number: Mapped[str] = mapped_column(String(50), nullable=False)
    geo_lat: Mapped[float] = mapped_column(Float, nullable=False)
    geo_lng: Mapped[float] = mapped_column(Float, nullable=False)
    registration_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    headquarters_address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    operating_regions: Mapped[Optional[str]] = mapped_column(String(255), default="Yangon")
    category: Mapped[str] = mapped_column(String(50), default="Medical")
    status: Mapped[str] = mapped_column(String(50), default="Active")
    coverage_radius_km: Mapped[float] = mapped_column(Float, default=50.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    account: Mapped["Account"] = relationship(back_populates="organization")
    volunteers: Mapped[list["Volunteer"]] = relationship(
        back_populates="organization", lazy="selectin"
    )
