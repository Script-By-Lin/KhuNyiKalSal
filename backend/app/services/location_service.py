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
    Prioritizes matching categories (e.g., Medical -> Hospitals, Fire -> Fire Station).
    Always returns organizations if any active ones exist in the system.
    """
    result = await db.execute(
        select(Organization).where(
            Organization.is_active == True,  # noqa: E712
            Organization.geo_lat.between(lat - 5.0, lat + 5.0),
            Organization.geo_lng.between(lng - 5.0, lng + 5.0)
        )
    )
    orgs = list(result.scalars().all())

    # Fallback to all active organizations if none within ±5 degrees bounding box
    if not orgs:
        fallback_res = await db.execute(
            select(Organization).where(Organization.is_active == True)  # noqa: E712
        )
        orgs = list(fallback_res.scalars().all())

    def _type_score(org: Organization) -> int:
        if not emergency_type:
            return 0
        
        cat = (org.category or "").lower().strip()
        etype = emergency_type.lower().strip().replace(" ", "_")

        is_voluntary = "voluntary" in cat or "volunteer" in cat or "local" in cat
        is_fire = "fire" in cat
        is_medical = "medical" in cat or "hospital" in cat or "health" in cat

        if etype in ["natural_disaster", "disaster"]:
            # For natural disasters: Both Fire and Local Voluntary organizations are tier 0
            if is_fire or is_voluntary:
                return 0
            if is_medical:
                return 1
            return 2

        if etype == "fire":
            # Primary: Fire (0), Secondary: Local Voluntary (1), Others: (2)
            if is_fire:
                return 0
            if is_voluntary:
                return 1
            return 2

        if etype in ["medical", "accident"]:
            # Primary: Medical (0), Secondary: Local Voluntary (1), Others: (2)
            if is_medical:
                return 0
            if is_voluntary:
                return 1
            if is_fire:
                return 2
            return 3

        if is_voluntary:
            return 0
        return 1

    all_sorted: List[Tuple[Organization, float]] = []
    fallback_sorted: List[Tuple[Organization, float]] = []

    for org in orgs:
        haversine_km = haversine(lat, lng, org.geo_lat, org.geo_lng)
        fallback_sorted.append((org, haversine_km))

        # Check coverage radius if defined
        radius = org.coverage_radius_km if org.coverage_radius_km and org.coverage_radius_km > 0 else 50.0
        if haversine_km <= radius:
            all_sorted.append((org, haversine_km))

    # If no organizations within strict coverage radius, fallback to all nearest active orgs
    candidates = all_sorted if all_sorted else fallback_sorted
    candidates.sort(key=lambda item: (_type_score(item[0]), item[1]))

    return candidates
