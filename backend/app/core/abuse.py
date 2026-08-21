"""SOS abuse prevention — daily rate limiting and user blocking."""

from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.emergency import Emergency


async def check_sos_limit(user_id, db: AsyncSession):
    """
    Check if user has exceeded the allowable daily SOS trigger limit within 24 hours.
    Prevents distress button abuse and server spamming.
    """
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
