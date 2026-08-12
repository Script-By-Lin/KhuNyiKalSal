from pydantic import BaseModel
from typing import Optional


class OrganizationResponse(BaseModel):
    account_id: str
    org_name: str
    phone_number: str
    geo_lat: float
    geo_lng: float
    coverage_radius_km: float
    category: str
    is_active: bool
    distance_km: Optional[float] = None

    model_config = {"from_attributes": True}


class UpdateOrgRequest(BaseModel):
    org_name: Optional[str] = None
    phone_number: Optional[str] = None
    geo_lat: Optional[float] = None
    geo_lng: Optional[float] = None
    coverage_radius_km: Optional[float] = None
    category: Optional[str] = None
