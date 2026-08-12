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
        if org.category.lower() == emergency_type.lower():
            return 0
            
        # Optional fallback mapping if categories aren't strictly aligned, 
        # but for now we expect them to be identical (e.g., 'Fire' -> 'fire')
        return 1

    all_sorted: List[Tuple[Organization, float]] = []

    for org in orgs:
        # 1. Fast linear distance in degrees
        linear_deg = math.hypot(lat - org.geo_lat, lng - org.geo_lng)
        
        # 2. Fast filter: discard organizations outside an approximate 200km radius (~1.8 degrees)
        # Note: We can adjust this threshold, but for safety we'll use 5.0 degrees (~550km)
        if linear_deg > 5.0:
            continue
            
        # 3. Approximate linear distance in km (1 degree ~ 111km)
        linear_km = linear_deg * 111.0
        
        # 4. Precise Haversine distance
        haversine_km = haversine(lat, lng, org.geo_lat, org.geo_lng)
        
        # 5. Combined Score: Average of linear and haversine for "linear + haversine" metric
        combined_distance = (linear_km + haversine_km) / 2.0
        
        # 6. Coverage Check: Ensure the emergency is within the organization's coverage radius
        if combined_distance > org.coverage_radius_km:
            continue
        
        all_sorted.append((org, combined_distance))

    all_sorted.sort(key=lambda item: (_type_score(item[0]), item[1]))

    return all_sorted
