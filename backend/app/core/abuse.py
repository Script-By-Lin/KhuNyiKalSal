"""SOS abuse prevention — daily rate limiting, cancellation tracking, and progressive 3-tier user suspension."""

from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.emergency import Emergency, EmergencyStatus
from app.models.account import Account


async def check_sos_limit(user_id, db: AsyncSession, account: Optional[Account] = None):
    """
    Check if user is currently suspended or has exceeded allowable daily SOS trigger limit within 24 hours.
    """
    if account and account.is_currently_suspended:
        rem = account.remaining_suspension_seconds
        tier = account.suspension_tier
        tier_label = "1 Day (24 Hours)" if tier == 1 else ("10 Days" if tier == 2 else "100 Years Ban")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Your account is currently suspended ({tier_label}) due to repeated SOS cancellations. "
                f"Remaining time: {rem} seconds. Please wait for the timer to expire or contact administrator."
            ),
        )

    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    result = await db.execute(
        select(func.count(Emergency.id)).where(
            Emergency.user_id == user_id,
            Emergency.created_at >= cutoff,
        )
    )
    count = result.scalar() or 0
    max_allowed = getattr(settings, "MAX_SOS_PER_DAY", 100)

    if count >= max_allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Daily SOS limit reached ({max_allowed} alerts per 24 hours). Please contact emergency services directly.",
        )


async def evaluate_cancellation_abuse(account: Account, db: AsyncSession) -> Optional[dict]:
    """
    Evaluates whether the user has cancelled 5 or more SOS calls within the past 24 hours.
    Applies the progressive 3-tier escalating suspension:
    - Tier 1 (1st offense): 1 Day (24 hours) suspension with live countdown timer.
    - Tier 2 (2nd offense): 10 Days suspension with live countdown timer.
    - Tier 3 (3rd offense): 100 Years Permanent Ban (contact administrator to lift).
    """
    now_utc = datetime.now(timezone.utc)
    cutoff = now_utc - timedelta(hours=24)

    res = await db.execute(
        select(func.count(Emergency.id)).where(
            Emergency.user_id == account.id,
            Emergency.created_at >= cutoff,
            Emergency.status == EmergencyStatus.CANCELLED,
        )
    )
    cancel_count = res.scalar() or 0

    # Trigger suspension at 5 or more cancellations in 24 hours
    if cancel_count >= 5:
        # If user is already in active suspension, do not duplicate
        if account.is_currently_suspended:
            return {
                "is_suspended": True,
                "suspended_until": account.suspended_until.isoformat() if account.suspended_until else None,
                "remaining_seconds": account.remaining_suspension_seconds,
                "suspension_tier": account.suspension_tier,
                "suspension_reason": account.suspension_reason,
            }

        # Escalate tier level
        current_tier = (account.suspension_count or 0) + 1
        account.suspension_count = current_tier

        if current_tier == 1:
            duration = timedelta(days=1)
            reason = "1st Offense: 5 SOS calls cancelled within 24 hours. Account suspended for 1 day."
        elif current_tier == 2:
            duration = timedelta(days=10)
            reason = "2nd Offense: 5 SOS calls cancelled within 24 hours. Account suspended for 10 days."
        else:
            duration = timedelta(days=36500)  # 100 years
            reason = "3rd Offense: Permanent Ban (100 Years) due to repeated emergency abuse. Please contact administrator support."

        account.is_suspended = True
        account.suspended_until = now_utc + duration
        account.suspension_reason = reason

        await db.commit()
        await db.refresh(account)

        # Broadcast real-time suspension event over WebSocket
        try:
            from app.websocket.manager import manager
            payload = {
                "event": "ACCOUNT_SUSPENDED",
                "is_suspended": True,
                "suspended_until": account.suspended_until.isoformat(),
                "remaining_seconds": account.remaining_suspension_seconds,
                "suspension_tier": account.suspension_tier,
                "suspension_reason": reason,
            }
            await manager.send_personal(str(account.id), payload)
        except Exception:
            pass

        return {
            "is_suspended": True,
            "suspended_until": account.suspended_until.isoformat(),
            "remaining_seconds": account.remaining_suspension_seconds,
            "suspension_tier": account.suspension_tier,
            "suspension_reason": reason,
        }

    return None
