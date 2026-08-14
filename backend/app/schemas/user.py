from pydantic import BaseModel, field_validator
from typing import Optional
from app.schemas.auth import validate_myanmar_phone


class UserProfileResponse(BaseModel):
    account_id: str
    full_name: str
    phone_number: str
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[list[dict]] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None

    model_config = {"from_attributes": True}


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[list[dict]] = None

    @field_validator("phone_number")
    @classmethod
    def check_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            return validate_myanmar_phone(v)
        return v


class UpdateLocationRequest(BaseModel):
    lat: float
    lng: float


class DeviceTokenRequest(BaseModel):
    fcm_token: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None
