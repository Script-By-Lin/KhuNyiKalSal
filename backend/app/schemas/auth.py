from datetime import datetime
import re
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional

PHONE_REGEX = re.compile(r"^(?:\+959|09)\d{9,10}$")


def validate_myanmar_phone(v: str) -> str:
    cleaned = v.strip().replace(" ", "").replace("-", "")
    if not PHONE_REGEX.match(cleaned):
        raise ValueError(
            "Phone number must start with +959 or 09 followed by 9 or 10 digits (e.g. 09123456789 or +959123456789)"
        )
    return cleaned


def validate_password(v: str) -> str:
    if len(v) < 6:
        raise ValueError("Password must be at least 6 characters long")
    if not re.search(r"[A-Z]", v):
        raise ValueError("Password must contain at least one uppercase letter (A-Z)")
    if not re.search(r"[a-z]", v):
        raise ValueError("Password must contain at least one lowercase letter (a-z)")
    if not re.search(r"\d", v):
        raise ValueError("Password must contain at least one number (0-9)")
    return v


class RegisterUserRequest(BaseModel):
    """Registration payload for regular users."""
    email: EmailStr
    password: str
    full_name: str
    phone_number: str
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[list[dict]] = None
    device_id: Optional[str] = None
    device_name: Optional[str] = None

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v: str) -> str:
        return validate_myanmar_phone(v)

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password(v)

    @field_validator("full_name")
    @classmethod
    def check_full_name(cls, v: str) -> str:
        if not v or len(v.strip()) < 2:
            raise ValueError("Full name must be at least 2 characters long")
        return v.strip()


class RegisterOrgRequest(BaseModel):
    """Registration payload for rescue organizations."""
    email: EmailStr
    password: str
    org_name: str
    phone_number: str
    geo_lat: float
    geo_lng: float
    coverage_radius_km: float = 50.0
    device_id: Optional[str] = None
    device_name: Optional[str] = None

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v: str) -> str:
        return validate_myanmar_phone(v)

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password(v)


class LoginRequest(BaseModel):
    email: str
    password: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    user_id: str
    session_id: str


class AccountResponse(BaseModel):
    id: str
    email: str
    role: str
    is_active: bool

    model_config = {"from_attributes": True}


class SessionItemResponse(BaseModel):
    session_id: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    is_active: bool
    created_at: datetime
    last_used_at: datetime
    is_current: bool = False


class AdminSessionResponse(BaseModel):
    session_id: str
    user_id: str
    email: str
    role: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    is_active: bool
    created_at: datetime
    last_used_at: datetime

