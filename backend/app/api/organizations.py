"""Organization endpoints — list all, nearby search, detail, update."""

import uuid as uuid_module
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.organization import Organization
from app.core.security import get_current_user
from app.core.permissions import require_role
from app.schemas.organization import OrganizationResponse, UpdateOrgRequest
from app.services.location_service import find_nearest_organizations, haversine

router = APIRouter()


@router.get("/all", response_model=list[OrganizationResponse])
@router.get("/", response_model=list[OrganizationResponse])
async def list_all_organizations(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all active rescue organizations."""
    result = await db.execute(
        select(Organization).where(Organization.is_active == True)  # noqa: E712
    )
    orgs = result.scalars().all()

    res = []
    for org in orgs:
        dist = None
        if lat is not None and lng is not None:
            dist = round(haversine(lat, lng, org.geo_lat, org.geo_lng), 2)
        res.append(
            OrganizationResponse(
                account_id=str(org.account_id),
                org_name=org.org_name,
                phone_number=org.phone_number,
                geo_lat=org.geo_lat,
                geo_lng=org.geo_lng,
                coverage_radius_km=org.coverage_radius_km,
                category=org.category,
                is_active=org.is_active,
                distance_km=dist,
            )
        )

    if lat is not None and lng is not None:
        res.sort(key=lambda x: x.distance_km if x.distance_km is not None else 99999)

    return res


@router.get("/nearby", response_model=list[OrganizationResponse])
async def get_nearby_organizations(
    lat: float,
    lng: float,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return organisations sorted by distance from the given coordinates."""
    org_distances = await find_nearest_organizations(lat, lng, db)
    return [
        OrganizationResponse(
            account_id=str(org.account_id),
            org_name=org.org_name,
            phone_number=org.phone_number,
            geo_lat=org.geo_lat,
            geo_lng=org.geo_lng,
            coverage_radius_km=org.coverage_radius_km,
            category=org.category,
            is_active=org.is_active,
            distance_km=round(dist, 2),
        )
        for org, dist in org_distances
    ]


@router.get("/{org_id}", response_model=OrganizationResponse)
async def get_organization(
    org_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Organization).where(
            Organization.account_id == uuid_module.UUID(org_id)
        )
    )
    org = result.scalar_one_or_none()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
    return OrganizationResponse(
        account_id=str(org.account_id),
        org_name=org.org_name,
        phone_number=org.phone_number,
        geo_lat=org.geo_lat,
        geo_lng=org.geo_lng,
        coverage_radius_km=org.coverage_radius_km,
        category=org.category,
        is_active=org.is_active,
    )


@router.put("/{org_id}", response_model=OrganizationResponse)
async def update_organization(
    org_id: str,
    data: UpdateOrgRequest,
    current_user: Account = Depends(require_role("organization")),
    db: AsyncSession = Depends(get_db),
):
    if str(current_user.id) != org_id:
        raise HTTPException(
            status_code=403, detail="You can only update your own organization"
        )

    result = await db.execute(
        select(Organization).where(
            Organization.account_id == uuid_module.UUID(org_id)
        )
    )
    org = result.scalar_one_or_none()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(org, field, value)
    await db.commit()
    await db.refresh(org)

    return OrganizationResponse(
        account_id=str(org.account_id),
        org_name=org.org_name,
        phone_number=org.phone_number,
        geo_lat=org.geo_lat,
        geo_lng=org.geo_lng,
        coverage_radius_km=org.coverage_radius_km,
        category=org.category,
        is_active=org.is_active,
    )
