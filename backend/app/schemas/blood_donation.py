from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class BloodDonationCreate(BaseModel):
    request_type: str = "donate"  # "donate" (blood pledge) or "request" (patient blood requisition)
    patient_name: Optional[str] = None
    hospital_name: Optional[str] = None
    urgency_level: Optional[str] = "Normal"  # "Emergency / Immediate", "Within 24 Hours", "Scheduled Surgery", "Normal"

    donor_name: str
    donor_phone: str
    blood_type: str
    age: Optional[int] = None
    gender: Optional[str] = None
    medical_notes: Optional[str] = None

    target_org_id: Optional[str] = None
    target_location_name: str
    target_lat: Optional[float] = None
    target_lng: Optional[float] = None

    preferred_date: Optional[str] = None
    units: int = 1
    notes: Optional[str] = None


class BloodDonationAccept(BaseModel):
    appointment_date: Optional[str] = None
    appointment_location: Optional[str] = None
    appointment_notes: Optional[str] = None
    pickup_location_message: Optional[str] = None  # Message stating where to get/pickup the blood supply


class BloodDonationStatusUpdate(BaseModel):
    status: str  # "Pending", "Accepted", "Completed", "Cancelled"


class BloodDonationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    request_type: str = "donate"
    patient_name: Optional[str] = None
    hospital_name: Optional[str] = None
    urgency_level: Optional[str] = None

    donor_name: str
    donor_phone: str
    blood_type: str
    age: Optional[int] = None
    gender: Optional[str] = None
    medical_notes: Optional[str] = None

    target_org_id: Optional[str] = None
    target_org_name: Optional[str] = None
    target_org_phone: Optional[str] = None

    accepted_org_id: Optional[str] = None
    accepted_org_name: Optional[str] = None
    accepted_org_phone: Optional[str] = None

    target_location_name: Optional[str] = None
    target_lat: Optional[float] = None
    target_lng: Optional[float] = None

    preferred_date: Optional[str] = None
    units: int
    status: str

    appointment_date: Optional[str] = None
    appointment_location: Optional[str] = None
    appointment_notes: Optional[str] = None
    pickup_location_message: Optional[str] = None

    notes: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
