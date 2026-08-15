from pydantic import BaseModel, field_validator
from typing import Optional, List, Dict, Any
from app.schemas.auth import validate_myanmar_phone


class UserProfileResponse(BaseModel):
    account_id: str
    role: str = "USER"
    email: Optional[str] = None
    full_name: str
    phone_number: str
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[List[Dict[str, Any]]] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    # Organization specific
    org_name: Optional[str] = None
    category: Optional[str] = None
    operating_regions: Optional[str] = None
    headquarters_address: Optional[str] = None
    registration_number: Optional[str] = None
    coverage_radius_km: Optional[float] = None
    # Volunteer specific
    nrc_number: Optional[str] = None
    assigned_region: Optional[str] = None
    is_active: Optional[bool] = None

    model_config = {"from_attributes": True}


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    blood_type: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: Optional[List[Dict[str, Any]]] = None
    # Org specific
    org_name: Optional[str] = None
    category: Optional[str] = None
    operating_regions: Optional[str] = None
    headquarters_address: Optional[str] = None
    registration_number: Optional[str] = None
    coverage_radius_km: Optional[float] = None
    # Volunteer specific
    nrc_number: Optional[str] = None
    assigned_region: Optional[str] = None
    emergency_contact: Optional[str] = None

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
