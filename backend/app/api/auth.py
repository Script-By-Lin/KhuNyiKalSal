"""Authentication endpoints — register (user / org) and login."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.auth import (
    RegisterUserRequest,
    RegisterOrgRequest,
    LoginRequest,
    TokenResponse,
    AccountResponse,
)
from app.services.auth_service import register_user, register_organization, login
from app.core.security import get_current_user
from app.models.account import Account

router = APIRouter()


@router.post("/register/user", response_model=TokenResponse)
async def register_user_endpoint(
    data: RegisterUserRequest, db: AsyncSession = Depends(get_db)
):
    return await register_user(data, db)


@router.post("/register/organization", response_model=TokenResponse)
async def register_org_endpoint(
    data: RegisterOrgRequest, db: AsyncSession = Depends(get_db)
):
    return await register_organization(data, db)


@router.post("/login", response_model=TokenResponse)
async def login_endpoint(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await login(data, db)


@router.get("/me", response_model=AccountResponse)
async def get_me(current_user: Account = Depends(get_current_user)):
    return AccountResponse(
        id=str(current_user.id),
        email=current_user.email,
        role=current_user.role.value,
        is_active=current_user.is_active,
    )
