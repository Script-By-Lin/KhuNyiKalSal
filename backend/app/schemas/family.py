from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional, List
from datetime import datetime


VALID_RELATIONSHIPS = [
    "Father",
    "Mother",
    "Son",
    "Daughter",
    "Spouse",
    "Sibling",
    "Other",
]


class CreateFamilyGroupRequest(BaseModel):
    group_name: str

    @field_validator("group_name")
    @classmethod
    def check_name(cls, v: str) -> str:
        if not v or len(v.strip()) < 2:
            raise ValueError("Group name must be at least 2 characters")
        return v.strip()


class UpdateFamilyGroupRequest(BaseModel):
    group_name: str

    @field_validator("group_name")
    @classmethod
    def check_name(cls, v: str) -> str:
        if not v or len(v.strip()) < 2:
            raise ValueError("Group name must be at least 2 characters")
        return v.strip()


class AddFamilyMemberRequest(BaseModel):
    email: EmailStr
    relationship: str

    @field_validator("relationship")
    @classmethod
    def check_relationship(cls, v: str) -> str:
        formatted = v.strip().capitalize()
        if formatted not in VALID_RELATIONSHIPS:
            raise ValueError(
                f"Invalid relationship. Choose from: {', '.join(VALID_RELATIONSHIPS)}"
            )
        return formatted


class FamilyMemberResponse(BaseModel):
    account_id: str
    full_name: str
    email: str
    phone_number: str
    relationship: str
    is_creator: bool
    status: str = "accepted"  # "pending", "accepted", "denied"
    added_at: datetime


class FamilyInvitationResponse(BaseModel):
    invitation_id: str
    family_id: str
    group_name: str
    creator_name: str
    creator_email: str
    relationship: str
    status: str = "pending"
    created_at: datetime


class FamilyGroupResponse(BaseModel):
    family_id: str
    group_name: str
    creator_id: str
    is_creator: bool
    members: List[FamilyMemberResponse]
    pending_members: Optional[List[FamilyMemberResponse]] = []
    created_at: datetime


class FamilyAlertResponse(BaseModel):
    alert_id: str
    family_id: str
    sender_id: str
    sender_name: str
    relationship: str
    emergency_id: Optional[str] = None
    emergency_type: str
    location_lat: float
    location_lng: float
    message: str
    is_resolved: bool
    created_at: datetime
