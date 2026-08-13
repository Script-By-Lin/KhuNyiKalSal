"""Location service — Haversine distance and nearest-organization search."""

import math
from typing import List, Tuple

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.organization import Organization


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate the great-circle distance between two points (in km)."""
    R = 6371.0  # Earth's radius in kilometres
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.asin(math.sqrt(a))
    return R * c


from typing import List, Tuple, Optional


async def find_nearest_organizations(
    lat: float,
    lng: float,
    db: AsyncSession,
    emergency_type: Optional[str] = None,
) -> List[Tuple[Organization, float]]:
    """
    Return active organizations sorted by type relevance and distance from (lat, lng).
    Prioritizes fire stations for fire emergencies, hospitals for medical, etc.
    """
    result = await db.execute(
        select(Organization).where(
            Organization.is_active == True,  # noqa: E712
            Organization.geo_lat.between(lat - 5.0, lat + 5.0),
            Organization.geo_lng.between(lng - 5.0, lng + 5.0)
        )
    )
    orgs = result.scalars().all()

    def _type_score(org: Organization) -> int:
        if not emergency_type:
            return 0
        
        # Exact match of category gets top priority (score 0)
        # Others get lower priority (score 1)
        if org.category and org.category.lower() == emergency_type.lower():
            return 0
            
        # Optional fallback mapping if categories aren't strictly aligned, 
        # but for now we expect them to be identical (e.g., 'Fire' -> 'fire')
        return 1

    all_sorted: List[Tuple[Organization, float]] = []

    for org in orgs:
        # Precise Haversine distance is actually very fast to calculate for a pre-filtered list
        haversine_km = haversine(lat, lng, org.geo_lat, org.geo_lng)
        
        # Coverage Check: Ensure the emergency is within the organization's coverage radius
        if haversine_km > org.coverage_radius_km:
            continue
        
        all_sorted.append((org, haversine_km))

    all_sorted.sort(key=lambda item: (_type_score(item[0]), item[1]))

    return all_sorted
