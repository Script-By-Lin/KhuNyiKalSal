from pydantic import BaseModel
from typing import Optional


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


class UpdateLocationRequest(BaseModel):
    lat: float
    lng: float
