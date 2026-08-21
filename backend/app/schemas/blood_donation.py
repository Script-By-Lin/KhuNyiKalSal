from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, field_validator, model_validator


VALID_BLOOD_TYPES = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}
VALID_GENDERS = {"MALE", "FEMALE", "OTHER"}


class BloodDonationCreate(BaseModel):
    request_type: str = "donate"  # "donate" (blood pledge) or "request" (patient blood requisition)
    patient_name: Optional[str] = None
    hospital_name: Optional[str] = None
    urgency_level: Optional[str] = "Normal"  # "Emergency / Immediate", "Within 24 Hours", "Scheduled Surgery", "Normal"

    donor_name: str
    donor_phone: str
    blood_type: str
    age: int
    gender: str
    medical_notes: Optional[str] = None

    target_org_id: Optional[str] = None
    target_location_name: str
    target_lat: Optional[float] = None
    target_lng: Optional[float] = None

    preferred_date: Optional[str] = None
    units: int = 1
    notes: Optional[str] = None

    @field_validator("blood_type")
    @classmethod
    def validate_blood_type(cls, v: str) -> str:
        bt = (v or "").strip().upper()
        if bt not in VALID_BLOOD_TYPES:
            raise ValueError(f"Invalid blood group '{v}'. Must be one of {sorted(VALID_BLOOD_TYPES)}")
        return bt

    @field_validator("gender")
    @classmethod
    def validate_gender(cls, v: str) -> str:
        g = (v or "").strip().upper()
        if g not in VALID_GENDERS:
            raise ValueError("Gender is required and must be Male, Female, or Other.")
        return g.capitalize()

    @field_validator("units")
    @classmethod
    def validate_units(cls, v: int) -> int:
        if v < 1 or v > 10:
            raise ValueError("Blood units must be between 1 and 10.")
        return v

    @field_validator("donor_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Name is required.")
        return v.strip()

    @field_validator("donor_phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not v or len(v.strip()) < 5:
            raise ValueError("A valid contact phone number is required.")
        return v.strip()

    @model_validator(mode="after")
    def validate_age_and_context(self):
        req_type = (self.request_type or "donate").lower()
        if req_type == "donate":
            if self.age < 18 or self.age > 65:
                raise ValueError("Blood donors must be between 18 and 65 years old to donate safely.")
        else:
            if self.age < 1 or self.age > 120:
                raise ValueError("Patient age must be between 1 and 120 years.")
            if not self.hospital_name or not self.hospital_name.strip():
                if not self.target_location_name or not self.target_location_name.strip():
                    raise ValueError("Hospital or target medical facility name is required for blood requests.")
        return self


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
