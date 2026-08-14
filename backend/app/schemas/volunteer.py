from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from app.schemas.auth import validate_myanmar_phone, validate_password


class CreateVolunteerRequest(BaseModel):
    """Organization creates a volunteer account."""
    email: EmailStr
    password: str
    full_name: str
    phone_number: str

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password(v)

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v: str) -> str:
        return validate_myanmar_phone(v)


class VolunteerResponse(BaseModel):
    account_id: str
    org_id: str
    full_name: str
    phone_number: str
    is_active: bool
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None

    model_config = {"from_attributes": True}


class VolunteerRespondRequest(BaseModel):
    """Volunteer accepts or rejects an emergency."""
    emergency_id: str
    action: str  # "accept" or "reject"


class AssignVolunteerRequest(BaseModel):
    """Organization assigns emergency to a specific volunteer."""
    emergency_id: str
    volunteer_id: str


class UpdateVolunteerLocationRequest(BaseModel):
    lat: float
    lng: float

