from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class SOSRequest(BaseModel):
    """Payload to trigger an SOS emergency."""
    type: str  # "fire", "medical", "crime"
    location_lat: float
    location_lng: float


class EmergencyResponse(BaseModel):
    id: str
    user_id: str
    type: str
    status: str
    assigned_org_id: Optional[str] = None
    assigned_volunteer_id: Optional[str] = None
    location_lat: float
    location_lng: float
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class AdminEmergencyRecord(BaseModel):
    emergency_id: str
    user_name: str
    user_phone: str
    blood_type: str
    medical_conditions: str
    type: str
    status: str
    assigned_org_name: Optional[str] = None
    location_lat: float
    location_lng: float
    created_at: datetime


class SOSCreatedResponse(BaseModel):
    emergency_id: str
    status: str = "pending"
    message: str = "SOS alert sent. Looking for nearest responders..."
