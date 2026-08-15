"""Support & Donation API — Bank accounts, KBZPay, WavePay, and MMQR details."""

from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.support_info import SupportInfo
from app.core.permissions import require_role

router = APIRouter()


class SupportInfoResponse(BaseModel):
    kbz_pay_name: str
    kbz_pay_phone: str
    wave_pay_name: str
    wave_pay_phone: str
    bank_name: str
    bank_account_number: str
    bank_account_name: str
    mmqr_payload: Optional[str] = None
    mmqr_image_url: Optional[str] = None
    note_message: Optional[str] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class UpdateSupportInfoRequest(BaseModel):
    kbz_pay_name: Optional[str] = None
    kbz_pay_phone: Optional[str] = None
    wave_pay_name: Optional[str] = None
    wave_pay_phone: Optional[str] = None
    bank_name: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_account_name: Optional[str] = None
    mmqr_payload: Optional[str] = None
    mmqr_image_url: Optional[str] = None
    note_message: Optional[str] = None


@router.get("", response_model=SupportInfoResponse)
@router.get("/", response_model=SupportInfoResponse)
async def get_support_info(db: AsyncSession = Depends(get_db)):
    """Public / user endpoint to fetch official donation channels."""
    res = await db.execute(select(SupportInfo).limit(1))
    info = res.scalar_one_or_none()
    if not info:
        # Create default initial record
        info = SupportInfo()
        db.add(info)
        await db.commit()
        await db.refresh(info)

    return SupportInfoResponse(
        kbz_pay_name=info.kbz_pay_name,
        kbz_pay_phone=info.kbz_pay_phone,
        wave_pay_name=info.wave_pay_name,
        wave_pay_phone=info.wave_pay_phone,
        bank_name=info.bank_name,
        bank_account_number=info.bank_account_number,
        bank_account_name=info.bank_account_name,
        mmqr_payload=info.mmqr_payload,
        mmqr_image_url=info.mmqr_image_url,
        note_message=info.note_message,
        updated_at=info.updated_at,
    )


@router.put("", response_model=SupportInfoResponse)
@router.put("/", response_model=SupportInfoResponse)
async def update_support_info(
    data: UpdateSupportInfoRequest,
    current_user: Account = Depends(require_role("admin", "superadmin")),
    db: AsyncSession = Depends(get_db),
):
    """Admin endpoint to update donation accounts and MMQR."""
    res = await db.execute(select(SupportInfo).limit(1))
    info = res.scalar_one_or_none()
    if not info:
        info = SupportInfo()
        db.add(info)

    update_dict = data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(info, field, value)

    await db.commit()
    await db.refresh(info)

    return SupportInfoResponse(
        kbz_pay_name=info.kbz_pay_name,
        kbz_pay_phone=info.kbz_pay_phone,
        wave_pay_name=info.wave_pay_name,
        wave_pay_phone=info.wave_pay_phone,
        bank_name=info.bank_name,
        bank_account_number=info.bank_account_number,
        bank_account_name=info.bank_account_name,
        mmqr_payload=info.mmqr_payload,
        mmqr_image_url=info.mmqr_image_url,
        note_message=info.note_message,
        updated_at=info.updated_at,
    )
