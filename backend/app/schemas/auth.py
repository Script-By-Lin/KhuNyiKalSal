from pydantic import BaseModel
from typing import Optional


class RegisterUserRequest(BaseModel):
    """Registration payload for regular users."""
    email: str
    password: str
    full_name: str
    phone_number: str
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[list[dict]] = None


class RegisterOrgRequest(BaseModel):
    """Registration payload for rescue organizations."""
    email: str
    password: str
    org_name: str
    phone_number: str
    geo_lat: float
    geo_lng: float
    coverage_radius_km: float = 50.0


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: str


class AccountResponse(BaseModel):
    id: str
    email: str
    role: str
    is_active: bool

    model_config = {"from_attributes": True}
