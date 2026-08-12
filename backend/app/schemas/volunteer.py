from pydantic import BaseModel
from typing import Optional


class CreateVolunteerRequest(BaseModel):
    """Organization creates a volunteer account."""
    email: str
    password: str
    full_name: str
    phone_number: str


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


class UpdateVolunteerLocationRequest(BaseModel):
    lat: float
    lng: float
