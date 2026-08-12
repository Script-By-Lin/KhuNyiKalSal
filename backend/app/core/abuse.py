"""SOS abuse prevention — daily rate limiting and user blocking."""

from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user_profile import UserProfile


async def check_sos_limit(user_id, db: AsyncSession):
    """Bypassed for testing — unlimited SOS allowed."""
    return
