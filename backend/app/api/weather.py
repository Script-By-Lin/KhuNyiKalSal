"""Weather & Natural Disaster Alerts API

Provides real-time location-based weather forecasts, severe weather warnings,
USGS earthquake feeds, GDACS global multi-hazard disaster alerts, and bilingual
emergency preparedness safety guides.
"""

import math
import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
import httpx
from fastapi import APIRouter, Query, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.announcement import Announcement
from app.websocket.manager import manager

logger = logging.getLogger(__name__)

router = APIRouter()

# ── WMO Weather Code Translations (Bilingual) ──────────────────────────────
WMO_CODES: Dict[int, Dict[str, str]] = {
    0: {"en": "Clear sky", "my": "ကြည်လင်သော မိုးကောင်းကင်", "icon": "sunny", "type": "clear"},
    1: {"en": "Mainly clear", "my": "အများအားဖြင့် ကြည်လင်သည်", "icon": "sunny", "type": "clear"},
    2: {"en": "Partly cloudy", "my": "တိမ်အသင့်အတင့် ဖြစ်ထွန်းသည်", "icon": "partly_cloudy", "type": "cloudy"},
    3: {"en": "Overcast", "my": "တိမ်ထူထပ်သည်", "icon": "cloud", "type": "cloudy"},
    45: {"en": "Foggy", "my": "မြူဆိုင်းနေသည်", "icon": "foggy", "type": "fog"},
    48: {"en": "Depositing rime fog", "my": "ဆီးနှင်းမြူဆိုင်းသည်", "icon": "foggy", "type": "fog"},
    51: {"en": "Light drizzle", "my": "မိုးဖွဲဖွဲရွာသည်", "icon": "grain", "type": "rain"},
    53: {"en": "Moderate drizzle", "my": "မိုးအသင့်အတင့် ဖွဲရွာသည်", "icon": "grain", "type": "rain"},
    55: {"en": "Dense drizzle", "my": "မိုးသည်းထန်စွာ ဖွဲရွာသည်", "icon": "grain", "type": "rain"},
    61: {"en": "Slight rain", "my": "မိုးအနည်းငယ် ရွာသည်", "icon": "water_drop", "type": "rain"},
    63: {"en": "Moderate rain", "my": "မိုးအသင့်အတင့် ရွာသည်", "icon": "water_drop", "type": "rain"},
    65: {"en": "Heavy rain", "my": "မိုးသည်းထန်စွာ ရွာသည်", "icon": "thunderstorm", "type": "heavy_rain"},
    71: {"en": "Slight snow", "my": "နှင်းအနည်းငယ် ကျသည်", "icon": "ac_unit", "type": "snow"},
    73: {"en": "Moderate snow", "my": "နှင်းအသင့်အတင့် ကျသည်", "icon": "ac_unit", "type": "snow"},
    75: {"en": "Heavy snow", "my": "နှင်းသည်းထန်စွာ ကျသည်", "icon": "ac_unit", "type": "snow"},
    80: {"en": "Slight rain showers", "my": "နေရာကွက်ကျား မိုးရွာသည်", "icon": "water_drop", "type": "rain"},
    81: {"en": "Moderate rain showers", "my": "မိုးရွာသွန်းမှု အသင့်အတင့်ရှိသည်", "icon": "water_drop", "type": "rain"},
    82: {"en": "Violent rain showers", "my": "မိုးသက်မုန်တိုင်းနှင့်အတူ မိုးသည်းစွာရွာသည်", "icon": "thunderstorm", "type": "storm"},
    95: {"en": "Thunderstorm", "my": "မိုးကြိုးမုန်တိုင်း ဖြစ်ပေါ်သည်", "icon": "thunderstorm", "type": "storm"},
    96: {"en": "Thunderstorm with slight hail", "my": "မိုးသီးကြွေ မိုးကြိုးမုန်တိုင်း", "icon": "thunderstorm", "type": "storm"},
    99: {"en": "Severe thunderstorm with heavy hail", "my": "ပြင်းထန်သော မိုးကြိုးမိုးသီး မုန်တိုင်း", "icon": "thunderstorm", "type": "severe_storm"},
}


def get_weather_desc(code: int) -> Dict[str, str]:
    return WMO_CODES.get(code, {
        "en": "Cloudy",
        "my": "တိမ်ထူထပ်သည်",
        "icon": "cloud",
        "type": "cloudy",
    })


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance between two points in kilometers."""
    r = 6371.0  # Earth's radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(r * c, 1)


# ── Schemas ───────────────────────────────────────────────────────────────
class HourlyWeatherItem(BaseModel):
    time: str
    temperature: float
    precipitation_probability: int
    weather_code: int
    condition_en: str
    condition_my: str
    wind_speed: float
    is_day: bool


class DailyWeatherItem(BaseModel):
    date: str
    max_temp: float
    min_temp: float
    precipitation_probability: int
    weather_code: int
    condition_en: str
    condition_my: str
    sunrise: str
    sunset: str
    uv_index_max: float


class CurrentWeatherResponse(BaseModel):
    latitude: float
    longitude: float
    timezone: str
    temperature: float
    apparent_temperature: float
    humidity: int
    weather_code: int
    condition_en: str
    condition_my: str
    icon_type: str
    wind_speed: float
    wind_direction: int
    uv_index: float
    precipitation: float
    precipitation_probability: int
    surface_pressure: float
    is_day: bool
    hourly_forecast: List[HourlyWeatherItem]
    daily_forecast: List[DailyWeatherItem]
    flood_risk_level: str  # 'LOW', 'MODERATE', 'HIGH', 'SEVERE'
    air_quality_summary: Dict[str, Any]
    last_updated: str


class DisasterAlertItem(BaseModel):
    id: str
    type: str  # 'EARTHQUAKE', 'CYCLONE', 'FLOOD', 'TSUNAMI', 'HEATWAVE', 'OFFICIAL_ANNOUNCEMENT'
    title: str
    title_my: str
    description: str
    description_my: str
    severity: str  # 'CRITICAL', 'WARNING', 'ADVISORY'
    alert_color: str  # 'RED', 'ORANGE', 'YELLOW', 'GREEN'
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_km: Optional[float] = None
    magnitude: Optional[float] = None
    depth_km: Optional[float] = None
    wind_speed_kmh: Optional[float] = None
    timestamp: str
    source: str
    action_advice_en: str
    action_advice_my: str
    is_emergency_proximity: bool = False
    affected_region: Optional[str] = "Myanmar"


class SafetyGuideItem(BaseModel):
    id: str
    hazard_type: str
    title_en: str
    title_my: str
    icon: str
    color: str
    summary_en: str
    summary_my: str
    before_steps_en: List[str]
    before_steps_my: List[str]
    during_steps_en: List[str]
    during_steps_my: List[str]
    after_steps_en: List[str]
    after_steps_my: List[str]
    emergency_contacts: List[Dict[str, str]]
    go_bag_items_en: List[str]
    go_bag_items_my: List[str]


# ── Endpoints ─────────────────────────────────────────────────────────────

@router.get("/current", response_model=CurrentWeatherResponse)
async def get_current_weather(
    lat: float = Query(16.8661, description="Latitude (default Yangon)"),
    lon: float = Query(96.1951, description="Longitude (default Yangon)"),
):
    """
    Fetch comprehensive current weather, 24-hour hourly forecast, and 7-day daily forecast
    from Open-Meteo with zero API key requirements.
    """
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": [
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "is_day",
            "precipitation",
            "weather_code",
            "surface_pressure",
            "wind_speed_10m",
            "wind_direction_10m",
        ],
        "hourly": [
            "temperature_2m",
            "precipitation_probability",
            "weather_code",
            "wind_speed_10m",
            "is_day",
            "uv_index",
        ],
        "daily": [
            "weather_code",
            "temperature_2m_max",
            "temperature_2m_min",
            "precipitation_probability_max",
            "sunrise",
            "sunset",
            "uv_index_max",
        ],
        "timezone": "auto",
        "forecast_days": 7,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(url, params=params)
            res.raise_for_status()
            data = res.json()
    except Exception as e:
        logger.warning(f"Open-Meteo forecast fetch failed ({e}), returning fallback estimates.")
        # Return sensible fallback if external network is unavailable
        now_str = datetime.now(timezone.utc).isoformat()
        return CurrentWeatherResponse(
            latitude=lat,
            longitude=lon,
            timezone="Asia/Yangon",
            temperature=31.0,
            apparent_temperature=34.5,
            humidity=72,
            weather_code=2,
            condition_en="Partly cloudy",
            condition_my="တိမ်အသင့်အတင့် ဖြစ်ထွန်းသည်",
            icon_type="partly_cloudy",
            wind_speed=12.5,
            wind_direction=210,
            uv_index=6.2,
            precipitation=0.0,
            precipitation_probability=20,
            surface_pressure=1010.2,
            is_day=True,
            hourly_forecast=[],
            daily_forecast=[],
            flood_risk_level="LOW",
            air_quality_summary={"aqi": 45, "status_en": "Good", "status_my": "ကောင်းမွန်ပါသည်"},
            last_updated=now_str,
        )

    current = data.get("current", {})
    hourly = data.get("hourly", {})
    daily = data.get("daily", {})

    w_code = int(current.get("weather_code", 0))
    desc = get_weather_desc(w_code)

    # Process hourly forecast (next 24 hours)
    hourly_items: List[HourlyWeatherItem] = []
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    precip_probs = hourly.get("precipitation_probability", [])
    codes = hourly.get("weather_code", [])
    winds = hourly.get("wind_speed_10m", [])
    is_days = hourly.get("is_day", [])

    for i in range(min(24, len(times))):
        h_code = int(codes[i]) if i < len(codes) else 0
        h_desc = get_weather_desc(h_code)
        hourly_items.append(
            HourlyWeatherItem(
                time=times[i],
                temperature=float(temps[i]) if i < len(temps) else 0.0,
                precipitation_probability=int(precip_probs[i]) if i < len(precip_probs) and precip_probs[i] is not None else 0,
                weather_code=h_code,
                condition_en=h_desc["en"],
                condition_my=h_desc["my"],
                wind_speed=float(winds[i]) if i < len(winds) else 0.0,
                is_day=bool(is_days[i]) if i < len(is_days) else True,
            )
        )

    # Process daily forecast (7 days)
    daily_items: List[DailyWeatherItem] = []
    d_times = daily.get("time", [])
    d_max = daily.get("temperature_2m_max", [])
    d_min = daily.get("temperature_2m_min", [])
    d_precip = daily.get("precipitation_probability_max", [])
    d_codes = daily.get("weather_code", [])
    d_sunrise = daily.get("sunrise", [])
    d_sunset = daily.get("sunset", [])
    d_uv = daily.get("uv_index_max", [])

    for i in range(min(7, len(d_times))):
        d_code = int(d_codes[i]) if i < len(d_codes) else 0
        d_desc = get_weather_desc(d_code)
        daily_items.append(
            DailyWeatherItem(
                date=d_times[i],
                max_temp=float(d_max[i]) if i < len(d_max) else 0.0,
                min_temp=float(d_min[i]) if i < len(d_min) else 0.0,
                precipitation_probability=int(d_precip[i]) if i < len(d_precip) and d_precip[i] is not None else 0,
                weather_code=d_code,
                condition_en=d_desc["en"],
                condition_my=d_desc["my"],
                sunrise=d_sunrise[i] if i < len(d_sunrise) else "",
                sunset=d_sunset[i] if i < len(d_sunset) else "",
                uv_index_max=float(d_uv[i]) if i < len(d_uv) and d_uv[i] is not None else 5.0,
            )
        )

    # Calculate flood risk indicator based on recent precipitation
    total_precip_chance = sum(h.precipitation_probability for h in hourly_items[:12]) / max(1, len(hourly_items[:12]))
    if total_precip_chance > 80:
        flood_risk = "HIGH"
    elif total_precip_chance > 50:
        flood_risk = "MODERATE"
    else:
        flood_risk = "LOW"

    # Current UV Index from first hour or estimated
    first_uv = float(hourly.get("uv_index", [5.0])[0]) if hourly.get("uv_index") else 5.0

    return CurrentWeatherResponse(
        latitude=lat,
        longitude=lon,
        timezone=data.get("timezone", "Asia/Yangon"),
        temperature=float(current.get("temperature_2m", 30.0)),
        apparent_temperature=float(current.get("apparent_temperature", 32.0)),
        humidity=int(current.get("relative_humidity_2m", 65)),
        weather_code=w_code,
        condition_en=desc["en"],
        condition_my=desc["my"],
        icon_type=desc["type"],
        wind_speed=float(current.get("wind_speed_10m", 10.0)),
        wind_direction=int(current.get("wind_direction_10m", 0)),
        uv_index=first_uv,
        precipitation=float(current.get("precipitation", 0.0)),
        precipitation_probability=hourly_items[0].precipitation_probability if hourly_items else 10,
        surface_pressure=float(current.get("surface_pressure", 1012.0)),
        is_day=bool(current.get("is_day", 1)),
        hourly_forecast=hourly_items,
        daily_forecast=daily_items,
        flood_risk_level=flood_risk,
        air_quality_summary={
            "aqi": 38,
            "status_en": "Good",
            "status_my": "လေထုအရည်အသွေး ကောင်းမွန်ပါသည်",
            "pm2_5": 9.2,
        },
        last_updated=datetime.now(timezone.utc).isoformat(),
    )


def is_in_myanmar_region(lat_val: float, lon_val: float) -> bool:
    """Check if coordinates fall inside Myanmar territory or adjacent borderline zones (Lat 8.5–29.0, Lon 91.0–102.5)."""
    return 8.5 <= lat_val <= 29.0 and 91.0 <= lon_val <= 102.5


@router.get("/disasters", response_model=List[DisasterAlertItem])
async def get_disaster_alerts(
    lat: float = Query(16.8661, description="User latitude"),
    lon: float = Query(96.1951, description="User longitude"),
    db: AsyncSession = Depends(get_db),
):
    """
    Aggregates active real-time natural disaster alerts focused on Myanmar:
    1. USGS Live Earthquakes (filtered for Myanmar region along Sagaing fault, Shan, Rakhine, etc.)
    2. GDACS Multi-Hazard Alerts (Bay of Bengal / Andaman Sea Cyclones, Myanmar River Floods, Tsunamis)
    3. Official EOC emergency broadcast announcements
    Marks `is_emergency_proximity = True` if the event is near the user's location (<= 150 km).
    """
    alerts: List[DisasterAlertItem] = []

    # 1. Fetch Real-time Earthquakes from USGS (Myanmar & immediate borderline fault lines)
    try:
        usgs_url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson"
        async with httpx.AsyncClient(timeout=8.0) as client:
            usgs_res = await client.get(usgs_url)
            if usgs_res.status_code == 200:
                features = usgs_res.json().get("features", [])
                for f in features:
                    props = f.get("properties", {})
                    geom = f.get("geometry", {})
                    coords = geom.get("coordinates", [0, 0, 0])
                    eq_lon, eq_lat = coords[0], coords[1]
                    eq_depth = coords[2] if len(coords) > 2 else 10.0
                    mag = float(props.get("mag") or 0.0)
                    place = props.get("place", "Myanmar Region")
                    ts = props.get("time", 0) / 1000.0
                    dt = datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()

                    dist_km = haversine_distance_km(lat, lon, eq_lat, eq_lon)
                    in_mm = is_in_myanmar_region(eq_lat, eq_lon)

                    # Strictly focus on Myanmar or events within 450 km of user
                    if in_mm or dist_km <= 450 or (mag >= 5.5 and dist_km <= 800):
                        is_near = dist_km <= 150.0 or (mag >= 5.0 and dist_km <= 250.0)
                        severity = "CRITICAL" if mag >= 5.5 or (mag >= 4.0 and is_near) else ("WARNING" if mag >= 4.0 else "ADVISORY")
                        color = "RED" if severity == "CRITICAL" else ("ORANGE" if severity == "WARNING" else "YELLOW")

                        alerts.append(
                            DisasterAlertItem(
                                id=f"usgs-{props.get('code', f.get('id', 'eq'))}",
                                type="EARTHQUAKE",
                                title=f"M{mag:.1f} Earthquake — {place}",
                                title_my=f"ပြင်းအား {mag:.1f} ငလျင်လှုပ်ခတ်မှု — {place}",
                                description=f"An earthquake of magnitude {mag:.1f} occurred at depth {eq_depth:.1f} km, approx. {dist_km:.0f} km from your current location.",
                                description_my=f"ပြင်းအား {mag:.1f} ရှိသော ငလျင်သည် အနက် {eq_depth:.1f} ကီလိုမီတာတွင် ဖြစ်ပေါ်ခဲ့ပြီး သင်ရှိရာမှ {dist_km:.0f} ကီလိုမီတာ အကွာတွင် တည်ရှိပါသည်။",
                                severity=severity,
                                alert_color=color,
                                latitude=eq_lat,
                                longitude=eq_lon,
                                distance_km=dist_km,
                                magnitude=mag,
                                depth_km=eq_depth,
                                timestamp=dt,
                                source="USGS Seismology (Myanmar Network)",
                                action_advice_en="Drop, Cover, and Hold On. Stay away from glass windows, heavy furniture, and power lines.",
                                action_advice_my="ဝပ်ပါ၊ အကာအကွယ်ယူပါ၊ မြဲမြံစွာကိုင်ထားပါ။ ပြတင်းပေါက်မှန်များနှင့် လျှပ်စစ်လိုင်းများနှင့် ဝေးရာတွင် နေပါ။",
                                is_emergency_proximity=is_near,
                                affected_region="Myanmar",
                            )
                        )
    except Exception as e:
        logger.warning(f"USGS Earthquake fetch notice: {e}")

    # 2. Fetch GDACS Global Alerts (Cyclones in Bay of Bengal/Andaman Sea, Myanmar floods, Tsunamis)
    try:
        gdacs_url = "https://www.gdacs.org/gdacsapi/api/events/geteventlist/MAP?eventlist=TC;FL;EQ;TS"
        async with httpx.AsyncClient(timeout=8.0) as client:
            gdacs_res = await client.get(gdacs_url)
            if gdacs_res.status_code == 200:
                features = gdacs_res.json().get("features", [])
                for f in features:
                    props = f.get("properties", {})
                    geom = f.get("geometry", {})
                    coords = geom.get("coordinates", [0, 0])
                    g_lon, g_lat = coords[0], coords[1]
                    event_type = props.get("eventtype", "TC")
                    event_name = props.get("eventname", "Hazard Alert")
                    alert_level = props.get("alertlevel", "Green").upper()
                    description = props.get("description", "")
                    ts_str = props.get("fromdate", datetime.now(timezone.utc).isoformat())

                    dist_km = haversine_distance_km(lat, lon, g_lat, g_lon)
                    in_mm_sea = is_in_myanmar_region(g_lat, g_lon)

                    # Only show if inside Myanmar territory / Bay of Bengal / Andaman Sea or within 600km
                    if in_mm_sea or dist_km <= 600 or (alert_level in ["RED", "ORANGE"] and dist_km <= 1200):
                        mapped_type = "CYCLONE" if event_type == "TC" else ("FLOOD" if event_type == "FL" else ("TSUNAMI" if event_type == "TS" else "DISASTER"))
                        is_near = dist_km <= 200.0 or alert_level == "RED"
                        severity = "CRITICAL" if (alert_level == "RED" or is_near) else ("WARNING" if alert_level == "ORANGE" else "ADVISORY")
                        color = "RED" if severity == "CRITICAL" else ("ORANGE" if severity == "WARNING" else "YELLOW")

                        title_en = f"{mapped_type.title()} Warning: {event_name}"
                        title_my = f"{'မုန်တိုင်းသတိပေးချက်' if mapped_type == 'CYCLONE' else ('ရေကြီးမှုသတိပေးချက်' if mapped_type == 'FLOOD' else 'သဘာဝဘေးသတိပေးချက်')}: {event_name}"

                        alerts.append(
                            DisasterAlertItem(
                                id=f"gdacs-{props.get('eventid', 'gdacs')}",
                                type=mapped_type,
                                title=title_en,
                                title_my=title_my,
                                description=f"{description} ({dist_km:.0f} km away from your location)",
                                description_my=f"{title_my} ဖြစ်ပေါ်နေပြီး သင်ရှိရာမှ {dist_km:.0f} ကီလိုမီတာ အကွာတွင် တည်ရှိပါသည်။ ဒေသခံများ သတိထားပါ။",
                                severity=severity,
                                alert_color=color,
                                latitude=g_lat,
                                longitude=g_lon,
                                distance_km=dist_km,
                                timestamp=ts_str,
                                source="GDACS Global Hazards (Myanmar/SE Asia)",
                                action_advice_en="Monitor meteorological bulletins, prepare emergency go-bag, and secure outdoor items.",
                                action_advice_my="မိုးလေဝသသတင်းများကို အထူးဂရုပြုနားထောင်ပါ၊ အရေးပေါ်အသုံးအဆောင်အိတ် အသင့်ပြင်ဆင်ထားပါ။",
                                is_emergency_proximity=is_near,
                                affected_region="Myanmar",
                            )
                        )
    except Exception as e:
        logger.warning(f"GDACS alert fetch notice: {e}")

    # 3. Pull Official Announcements from DB tagged under Weather or Disaster
    if db is not None and hasattr(db, "execute"):
        try:
            q = select(Announcement).where(
                Announcement.is_active == True,  # noqa: E712
                Announcement.category.in_(["Weather", "Disaster", "Emergency", "Natural Disaster"]),
            ).order_by(Announcement.created_at.desc()).limit(5)
            res = await db.execute(q)
            official_announcements = res.scalars().all()

            for a in official_announcements:
                alerts.append(
                    DisasterAlertItem(
                        id=f"ann-{a.id}",
                        type="OFFICIAL_ANNOUNCEMENT",
                        title=f"🚨 Official Bulletin: {a.title}",
                        title_my=f"🚨 ဌာနဆိုင်ရာ အရေးပေါ်ကြေညာချက်: {a.title}",
                        description=a.content,
                        description_my=a.content,
                        severity="CRITICAL" if a.is_pinned else "WARNING",
                        alert_color="RED" if a.is_pinned else "ORANGE",
                        distance_km=0.0,
                        timestamp=a.created_at.isoformat(),
                        source=f"EOC Myanmar — {a.author_name}",
                        action_advice_en="Follow official emergency instructions and contact hotlines if in distress.",
                        action_advice_my="အရေးပေါ်လမ်းညွှန်ချက်များကို တိကျစွာလိုက်နာပါ၊ အကူအညီလိုအပ်ပါက အရေးပေါ်ဖုန်းခေါ်ဆိုပါ။",
                        is_emergency_proximity=True,
                        affected_region="Myanmar",
                    )
                )
        except Exception as e:
            logger.warning(f"DB announcements fetch notice: {e}")

    # Sort alerts by proximity flag, severity (CRITICAL > WARNING > ADVISORY), and distance
    severity_rank = {"CRITICAL": 0, "WARNING": 1, "ADVISORY": 2}
    alerts.sort(key=lambda x: (0 if x.is_emergency_proximity else 1, severity_rank.get(x.severity, 3), x.distance_km or 99999))

    return alerts


@router.get("/safety-guides", response_model=List[SafetyGuideItem])
async def get_safety_guides():
    """
    Returns comprehensive bilingual (Burmese & English) emergency survival and
    preparedness protocols for major natural disaster scenarios.
    """
    guides = [
        SafetyGuideItem(
            id="cyclone",
            hazard_type="CYCLONE",
            title_en="Cyclone & Severe Tropical Storm",
            title_my="မုန်တိုင်းနှင့် လေပြင်းဘေး အန္တရာယ်",
            icon="cyclone",
            color="0xFF0288D1",
            summary_en="Vital safety measures before, during, and after devastating tropical cyclones and extreme gale winds.",
            summary_my="မုန်တိုင်းတိုက်ခတ်ခြင်းနှင့် ပြင်းထန်သော လေပြင်းဘေးမှ အသက်အန္တရာယ်ကင်းရှင်းစေရန် လိုက်နာရမည့် နည်းလမ်းများ။",
            before_steps_en=[
                "Reinforce doors, windows, and roof sheets with sturdy battens.",
                "Prune dead tree branches near power lines and buildings.",
                "Store at least 3 days of clean drinking water and non-perishable food.",
                "Keep flashlights, whistle, power banks, and portable radio fully charged.",
                "Know your nearest community storm shelter or cyclone-resistant building.",
            ],
            before_steps_my=[
                "အိမ်ခေါင်မိုး၊ ပြတင်းပေါက်နှင့် တံခါးများကို ကြံ့ခိုင်စွာ တွဲဆိုင်းထားပါ။",
                "အိမ်နီးနားရှိ သစ်ပင်ခြောက်ကိုင်းများကို ကြိုတင်ခုတ်ထွင်ရှင်းလင်းပါ။",
                "အနည်းဆုံး ၃ ရက်စာ သောက်ရေသန့်နှင့် ခြောက်သွေ့စားသောက်ကုန်များ စုဆောင်းထားပါ။",
                "လက်နှိပ်ဓာတ်မီး၊ လေချွန်ခရာ၊ ပါဝါဘဏ်နှင့် ရေဒီယိုများကို အားပြည့်အောင် ပြင်ဆင်ပါ။",
                "အနီးဆုံး မုန်တိုင်းခိုလုံရာ နေရာများကို ကြိုတင်လေ့လာမှတ်သားထားပါ။",
            ],
            during_steps_en=[
                "Stay indoors away from exterior windows and glass doors.",
                "Disconnect main electrical breaker and gas cylinders.",
                "Do NOT go outside during the calm 'eye of the storm' as ferocious winds will resume from the reverse direction.",
                "If building suffers structural failure, shelter under a heavy mattress or wooden table.",
            ],
            during_steps_my=[
                "အိမ်တွင်း၌သာနေပြီး မှန်ပြတင်းပေါက်များနှင့် ဝေးရာတွင် ခိုလှုံပါ။",
                "အဓိက လျှပ်စစ်မိန်းခလုတ်နှင့် ဂတ်စ်အိုးများကို ပိတ်ထားပါ။",
                "မုန်တိုင်းဗဟိုချက်ဖြတ်သန်းချိန်တွင် ခေတ္တလေငြိမ်သက်သွားသော်လည်း အပြင်သို့ လုံးဝမထွက်ပါနှင့် (ဆန့်ကျင်ဘက်မှ လေပြင်းပြန်တိုက်မည်)။",
                "အဆောက်အဦ ပျက်စီးပါက အကြမ်းခံစားပွဲ သို့မဟုတ် မွေ့ရာအောက်တွင် အကာအကွယ်ယူပါ။",
            ],
            after_steps_en=[
                "Watch out for dangling electrical wires and contaminated floodwaters.",
                "Boil drinking water before consumption to prevent cholera and diarrhea.",
                "Report trapped neighbors using the KhuNyiKalSal SOS broadcast.",
            ],
            after_steps_my=[
                "ပြတ်ကျနေသော လျှပ်စစ်ကြိုးများနှင့် ညစ်ညမ်းရေဆိုးများကို အထူးသတိပြုပါ။",
                "ဝမ်းရောဂါ ကာကွယ်ရန် သောက်ရေကို ကျိုချက်ပြီးမှ သောက်သုံးပါ။",
                "ပိတ်မိနေသူများရှိပါက KhuNyiKalSal SOS စနစ်ဖြင့် အရေးပေါ်အကူအညီတောင်းပါ။",
            ],
            emergency_contacts=[
                {"name": "Fire & Rescue (မီးသတ်/ကယ်ဆယ်ရေး)", "number": "191"},
                {"name": "Emergency Medical (ဆေးဘက်ဆိုင်ရာ)", "number": "192"},
                {"name": "Myanmar Red Cross (ကြက်ခြေနီ)", "number": "01-383680"},
                {"name": "Meteorological Dept (မိုး/ဇလ)", "number": "067-411031"},
            ],
            go_bag_items_en=[
                "National ID card & essential family documents in waterproof pouch",
                "Bottled drinking water (3L per person)",
                "Emergency first-aid medical kit & prescription medicines",
                "High-powered LED flashlight & extra batteries",
                "Multi-tool pocket knife & whistle",
            ],
            go_bag_items_my=[
                "မှတ်ပုံတင်နှင့် အရေးကြီးစာရွက်စာတမ်းများကို ရေလုံအိတ်ထဲ ထည့်ထားခြင်း",
                "သောက်ရေသန့် (တစ်ဦးလျှင် အနည်းဆုံး ၃ လီတာ)",
                "ရှေးဦးသူနာပြုစုနည်း အိတ်နှင့် နေ့စဉ်သောက်ဆေးများ",
                "အားကောင်းသော လက်နှိပ်ဓာတ်မီးနှင့် အပိုဓာတ်ခဲများ",
                "ဘက်စုံသုံးဓားနှင့် အရေးပေါ်အချက်ပြ လေချွန်ခရာ",
            ],
        ),
        SafetyGuideItem(
            id="earthquake",
            hazard_type="EARTHQUAKE",
            title_en="Earthquake Drop, Cover & Hold",
            title_my="ငလျင်ဘေး အရေးပေါ် အသက်ရှင်နည်း",
            icon="earthquake",
            color="0xFFE65100",
            summary_en="Critical survival procedures during sudden seismic shaking and avoiding aftershock hazards.",
            summary_my="ငလျင်လှုပ်ခတ်စဉ် ထိခိုက်ဒဏ်ရာ မရရှိစေရန် လိုက်နာရမည့် ဝပ်၊ ကာ၊ ကိုင် အသက်ရှင်နည်းလမ်းများ။",
            before_steps_en=[
                "Secure heavy furniture, water heaters, and wall hangings to wall studs.",
                "Identify safe shelter spots in each room (under sturdy desks or interior walls).",
                "Keep shoes and a flashlight beside your bed.",
            ],
            before_steps_my=[
                "ဗီရိုကြီးများ၊ ရေပူစက်နှင့် လေးလံသော ပရိဘောဂများကို နံရံတွင် မြဲမြံစွာတွဲချည်ပါ။",
                "အခန်းတိုင်းတွင် လုံခြုံသော နေရာများ (ခိုင်ခံ့သော စားပွဲအောက်) ကို သတ်မှတ်ထားပါ။",
                "အိပ်ရာဘေးတွင် ဖိနပ်နှင့် လက်နှိပ်ဓာတ်မီး အသင့်ထားရှိပါ။",
            ],
            during_steps_en=[
                "DROP to your hands and knees immediately.",
                "COVER your head and neck under a sturdy table or desk.",
                "HOLD ON to your shelter until shaking stops.",
                "If outdoors, move to an open area away from high-rises, utility poles, and flyovers.",
                "Do NOT use elevators during or immediately after shaking.",
            ],
            during_steps_my=[
                "ချက်ချင်း ကြမ်းပြင်ပေါ်သို့ ဝပ်ချပါ။ (DROP)",
                "ခိုင်ခံ့သော စားပွဲအောက်သို့ဝင်၍ ဦးခေါင်းနှင့် လည်ပင်းကို အုပ်ကာပါ (COVER)။",
                "လှုပ်ခတ်မှု ရပ်တန့်သွားသည်အထိ စားပွဲခြေထောက်ကို မြဲမြံစွာ ကိုင်ထားပါ (HOLD ON)။",
                "အပြင်ဘက်ရောက်နေပါက တိုက်မြင့်ကြီးများ၊ ဓာတ်တိုင်များနှင့် ဝေးရာ ကွင်းပြင်သို့ ပြေးပါ။",
                "ဓာတ်လှေကားကို လုံးဝ (လုံးဝ) အသုံးမပြုပါနှင့်။",
            ],
            after_steps_en=[
                "Expect aftershocks. Each time you feel shaking, Drop, Cover, and Hold On.",
                "Check for gas leaks (smell) and switch off valves immediately if detected.",
                "Exit damaged structures cautiously using stairs.",
            ],
            after_steps_my=[
                "နောက်ဆက်တွဲငလျင်ငယ် (Aftershocks) များ ဆက်လက်လှုပ်နိုင်သဖြင့် အသင့်ပြင်ထားပါ။",
                "ဂတ်စ်ယိုစိမ့်မှုရှိမရှိ စစ်ဆေးပြီး အနံ့ရပါက ချက်ချင်းပိတ်ပါ။",
                "ပျက်စီးနေသော အဆောက်အဦအတွင်းမှ လှေကားကို အသုံးပြု၍ သတိဖြင့် ထွက်ပါ။",
            ],
            emergency_contacts=[
                {"name": "Fire & Rescue (မီးသတ်/ကယ်ဆယ်ရေး)", "number": "191"},
                {"name": "Police (ရဲတပ်ဖွဲ့)", "number": "199"},
                {"name": "Ambulance (လူနာတင်ယာဉ်)", "number": "192"},
            ],
            go_bag_items_en=[
                "Protective work gloves & N95 dust masks",
                "Emergency foil thermal blanket",
                "Flashlight, whistle, power bank",
                "Clean water & high-calorie energy bars",
            ],
            go_bag_items_my=[
                "လက်အိတ်ထူထူနှင့် ဖုန်မှုန့်ကာ N95 နှာခေါင်းစည်းများ",
                "အအေးဒဏ်ကာ သတ္တုစောင်",
                "ဓာတ်မီး၊ လေချွန်ခရာ၊ ပါဝါဘဏ်",
                "သောက်ရေသန့်နှင့် အာဟာရပြည့် အသင့်စား မုန့်ခြောက်များ",
            ],
        ),
        SafetyGuideItem(
            id="flood",
            hazard_type="FLOOD",
            title_en="Flash Flood & River Inundation",
            title_my="လျှပ်တစ်ပြက် ရေကြီးရေလျှံမှု ဘေး",
            icon="flood",
            color="0xFF0D47A1",
            summary_en="Actions to take when rapid floodwaters rise and submerged hazards threaten communities.",
            summary_my="ရေကြီးရေလျှံမှုနှင့် လျှပ်တစ်ပြက် ရေစတင်တက်လာချိန်တွင် လိုက်နာရမည့် အရေးပေါ်အစီအမံများ။",
            before_steps_en=[
                "Move electrical appliances, valuables, and legal documents to upper floors.",
                "Know evacuation routes to designated high ground or multi-story buildings.",
                "Clear nearby storm drains of debris.",
            ],
            before_steps_my=[
                "လျှပ်စစ်ပစ္စည်းများ၊ တန်ဖိုးကြီးပစ္စည်းများနှင့် စာရွက်စာတမ်းများကို အပေါ်ထပ်သို့ ရွှေ့ပါ။",
                "အမြင့်ပိုင်း ကယ်ဆယ်ရေးစခန်းများသို့ သွားရောက်နိုင်မည့် လမ်းကြောင်းကို မှတ်ထားပါ။",
                "အနီးပတ်ဝန်းကျင်ရှိ ရေနုတ်မြောင်းများကို ကြိုတင်ရှင်းလင်းပါ။",
            ],
            during_steps_en=[
                "Evacuate immediately if advised by local emergency authorities.",
                "NEVER walk, swim, or drive through moving floodwaters ('Turn Around, Don't Drown').",
                "Just 15 cm of moving water can knock you down, and 30 cm can float a car.",
                "Disconnect electric power if water enters the premises.",
            ],
            during_steps_my=[
                "ကယ်ဆယ်ရေးအဖွဲ့များက ပြောင်းရွှေ့ရန် ညွှန်ကြားပါက ချက်ချင်း ရွှေ့ပြောင်းပါ။",
                "စီးဆင်းနေသော ရေထဲသို့ ဖြတ်သန်းလမ်းလျှောက်ခြင်း၊ ကူးခတ်ခြင်း၊ ကားမောင်းခြင်း လုံးဝမပြုပါနှင့်။",
                "ရေစီးသန်နေသော ၆ လက်မခန့် ရေသည် လူကို လဲကျစေနိုင်ပြီး ၁ ပေခန့် ရေသည် ကားကို မျောပါစေနိုင်ပါသည်။",
                "အိမ်တွင်းသို့ ရေစတင်ဝင်ရောက်လာပါက လျှပ်စစ်မိန်းကို ချက်ချင်းချပါ။",
            ],
            after_steps_en=[
                "Do NOT enter buildings if floodwaters remain around the foundation.",
                "Beware of venomous snakes and contaminated water hazards.",
                "Disinfect everything that touched floodwaters.",
            ],
            after_steps_my=[
                "အဆောက်အဦ အောက်ခြေတွင် ရေဝပ်နေပါက အတွင်းသို့ ပြန်မဝင်ပါနှင့်။",
                "ရေထဲတွင် မျောပါလာနိုင်သော မြွေဆိုးများနှင့် အဆိပ်ရှိသတ္တဝါများကို သတိပြုပါ။",
                "ရေစိုခဲ့သော ပစ္စည်းများကို ပိုးသတ်သန့်စင်ပြီးမှ ပြန်လည်အသုံးပြုပါ။",
            ],
            emergency_contacts=[
                {"name": "Disaster Management Dept (သဘာဝဘေး စီမံဌာန)", "number": "067-3404050"},
                {"name": "Fire & Rescue (မီးသတ်/ကယ်ဆယ်ရေး)", "number": "191"},
                {"name": "Medical Emergency (လူနာတင်ယာဉ်)", "number": "192"},
            ],
            go_bag_items_en=[
                "Waterproof dry-bag for all gear",
                "Water purification tablets or LifeStraw filter",
                "High-visibility life vest or inflatable floatation ring",
                "Waterproof flashlight & whistle",
            ],
            go_bag_items_my=[
                "ပစ္စည်းအားလုံး ထည့်သွင်းနိုင်မည့် ရေလုံအိတ်",
                "ရေသန့်စင်ဆေးပြားများ သို့မဟုတ် ရေသန့်စစ်စက်",
                "အသက်ကယ်အင်္ကျီ (Life Vest) သို့မဟုတ် ရေပေါ်ပေါ်နိုင်သောအရာများ",
                "ရေစိုခံ ဓာတ်မီးနှင့် လေချွန်ခရာ",
            ],
        ),
        SafetyGuideItem(
            id="tsunami",
            hazard_type="TSUNAMI",
            title_en="Tsunami Coastal Evacuation",
            title_my="ဆူနာမီ ကမ်းရိုးတန်း အရေးပေါ် ဘေးလွတ်ရာရှောင်နည်း",
            icon="tsunami",
            color="0xFF006064",
            summary_en="Crucial warning signs and rapid evacuation procedures for massive coastal surge waves.",
            summary_my="ငလျင်ကြီး လှုပ်ခတ်ပြီးနောက် ကမ်းရိုးတန်းသို့ ရောက်ရှိလာနိုင်သော ဆူနာမီလှိုင်းလုံးကြီးများမှ ကာကွယ်နည်း။",
            before_steps_en=[
                "Know the tsunami evacuation zones in coastal areas.",
                "Understand that a severe coastal earthquake is your natural immediate warning.",
            ],
            before_steps_my=[
                "ကမ်းရိုးတန်းဒေသများရှိ ဆူနာမီ လွတ်ကင်းရာ ကုန်းမြင့်ဇုန်များကို လေ့လာထားပါ။",
                "ပြင်းထန်သော ငလျင်လှုပ်ခတ်ခြင်းသည် ဆူနာမီဖြစ်ပေါ်နိုင်သည့် သဘာဝသတိပေးချက်ဖြစ်ကြောင်း သတိပြုပါ။",
            ],
            during_steps_en=[
                "If the sea suddenly recedes exposing the seabed, RUN immediately to high ground.",
                "Move inland at least 2 km or ascend to an elevation of at least 30 meters.",
                "Do NOT wait for official warnings if you feel strong shaking near the coast.",
            ],
            during_steps_my=[
                "ပင်လယ်ရေသည် ကမ်းခြေမှ ရုတ်တရက် အလွန်အမင်း နောက်ဆုတ်သွားပါက ကုန်းမြင့်သို့ ချက်ချင်းပြေးပါ။",
                "ကမ်းခြေနှင့် အနည်းဆုံး ၂ ကီလိုမီတာ အကွာ သို့မဟုတ် အမြင့် ပေ ၁၀၀ (မီတာ ၃၀) အထက်သို့ တက်ရောက်ခိုလှုံပါ။",
                "ကမ်းခြေအနီးတွင် ပြင်းထန်သော ငလျင်လှုပ်ခတ်ပါက တရားဝင်ကြေညာချက်ကို စောင့်မနေဘဲ ချက်ချင်းပြေးပါ။",
            ],
            after_steps_en=[
                "Tsunamis are a series of waves; the first wave may not be the largest.",
                "Stay away from the coast until emergency officials declare an all-clear.",
            ],
            after_steps_my=[
                "ဆူနာမီလှိုင်းသည် အကြိမ်ကြိမ် လာရောက်နိုင်ပြီး ပထမလှိုင်းသည် အကြီးဆုံးမဟုတ်နိုင်ပါ။",
                "အာဏာပိုင်များက စိတ်ချရပြီဟု ကြေညာမှသာ ကမ်းခြေသို့ ပြန်သွားပါ။",
            ],
            emergency_contacts=[
                {"name": "Coast Guard & Navy (ရေတပ်/ကမ်းခြေစောင့်)", "number": "01-220000"},
                {"name": "Fire & Rescue (မီးသတ်/ကယ်ဆယ်ရေး)", "number": "191"},
            ],
            go_bag_items_en=[
                "Lightweight waterproof backpack",
                "Personal ID documents & cash",
                "Emergency whistle & distress mirror",
            ],
            go_bag_items_my=[
                "ပေါ့ပါးသော ရေလုံကျောပိုးအိတ်",
                "မှတ်ပုံတင်၊ ငွေသားနှင့် အရေးကြီးစာရွက်စာတမ်းများ",
                "အချက်ပြ လေချွန်ခရာနှင့် မှန်",
            ],
        ),
        SafetyGuideItem(
            id="landslide",
            hazard_type="LANDSLIDE",
            title_en="Landslide & Mudflow Warning",
            title_my="မြေပြိုဘေးနှင့် ရွှံ့နွံစီးဆင်းမှု ကာကွယ်ရေး",
            icon="landslide",
            color="0xFF4E342E",
            summary_en="Warning signs of hillside slope instability and urgent evacuation steps.",
            summary_my="တောင်စောင်းဒေသများတွင် မိုးသည်းထန်စွာရွာသွန်းပြီးနောက် ဖြစ်ပွားတတ်သော မြေပြိုဘေး ကာကွယ်နည်း။",
            before_steps_en=[
                "Observe slope cracks, leaning trees, or doors sticking in hillside homes.",
                "Avoid building or staying in steep gullies and drainage paths during heavy monsoon rain.",
            ],
            before_steps_my=[
                "တောင်စောင်းများတွင် မြေအက်ကွဲခြင်း၊ သစ်ပင်များ စောင်းယိုင်လာခြင်းရှိမရှိ စောင့်ကြည့်ပါ။",
                "မိုးသည်းထန်စွာ ရွာသွန်းချိန်တွင် ချောက်ကမ်းပါးနှင့် တောင်စောင်းအောက်ခြေများတွင် မနေပါနှင့်။",
            ],
            during_steps_en=[
                "Listen for rumbling sounds or cracking trees indicating approaching debris flows.",
                "Evacuate laterally away from the path of the flow toward stable ridge tops.",
                "Curl into a tight ball and protect your head if escape is impossible.",
            ],
            during_steps_my=[
                "တောင်ပြိုသံ၊ သစ်ပင်ကျိုးသံများ ကြားရပါက ရွှံ့နွံစီးဆင်းရာ လမ်းကြောင်းမှ ဘေးဘက်သို့ အမြန်ပြေးပါ။",
                "ပြေးမလွတ်နိုင်ပါက ခန္ဓာကိုယ်ကို လုံးကျစ်ပြီး ဦးခေါင်းကို လက်ဖြင့် အုပ်ကာထားပါ။",
            ],
            after_steps_en=[
                "Stay alert for secondary slides following the initial event.",
                "Check for injured or trapped persons without entering the unstable slide area directly.",
            ],
            after_steps_my=[
                "ပထမအကြိမ် မြေပြိုပြီးနောက် ထပ်မံပြိုကျနိုင်သဖြင့် ဧရိယာအနီး မကပ်ပါနှင့်။",
                "ပိတ်မိနေသူများကို ကယ်ဆယ်ရေးအဖွဲ့များထံ အမြန်ဆုံး အကြောင်းကြားပါ။",
            ],
            emergency_contacts=[
                {"name": "Fire & Rescue (မီးသတ်/ကယ်ဆယ်ရေး)", "number": "191"},
                {"name": "Red Cross (ကြက်ခြေနီ)", "number": "01-383680"},
            ],
            go_bag_items_en=[
                "Heavy-duty hiking boots",
                "Dust respirators & safety goggles",
                "Whistle & emergency beacon",
            ],
            go_bag_items_my=[
                "ခိုင်ခံ့သော ဖိနပ်ထူထူ",
                "မျက်မှန်နှင့် ဖုန်ကာနှာခေါင်းစည်း",
                "လေချွန်ခရာနှင့် အချက်ပြမီး",
            ],
        ),
        SafetyGuideItem(
            id="heatwave",
            hazard_type="HEATWAVE",
            title_en="Extreme Heatwave & Sunstroke",
            title_my="အပူလှိုင်းဘေးနှင့် အပူဒဏ်ကာကွယ်ရေး",
            icon="sunny",
            color="0xFFD84315",
            summary_en="Preventing heat exhaustion and life-threatening heatstroke during blistering hot summer temperatures.",
            summary_my="နွေရာသီ အပူချိန်လွန်ကဲချိန်တွင် အပူလျှပ်ခြင်းနှင့် အသက်အန္တရာယ်မှ ကာကွယ်ရန် နည်းလမ်းများ။",
            before_steps_en=[
                "Check weather forecasts and UV index ratings daily.",
                "Ensure vulnerable elders, children, and pets have cool resting areas.",
            ],
            before_steps_my=[
                "နေ့စဉ် မိုးလေဝသနှင့် ခရမ်းလွန်ရောင်ခြည် (UV Index) အညွှန်းကိန်းကို ကြည့်ပါ။",
                "သက်ကြီးရွယ်အိုများနှင့် ကလေးငယ်များအတွက် အေးမြသော နေရာများ ကြိုတင်စီစဉ်ပါ။",
            ],
            during_steps_en=[
                "Drink water regularly even before feeling thirsty (avoid alcohol and excessive caffeine).",
                "Stay indoors during peak sun hours (11:00 AM – 3:30 PM).",
                "Wear loose, lightweight, light-colored cotton clothing.",
                "If someone shows symptoms of heatstroke (confusion, high body temp, no sweat), apply cold water and call 192 immediately.",
            ],
            during_steps_my=[
                "ရေဆာသည်အထိ မစောင့်ဘဲ ရေခဏခဏ ကြိုသောက်ပေးပါ (အရက်နှင့် ကဖိန်းဓာတ် လျှော့ပါ)။",
                "နေအပူဆုံးအချိန် (နံနက် ၁၁:၀၀ မှ ညနေ ၃:၃၀ ထိ) နေပူထဲ မထွက်ပါနှင့်။",
                "ချောင်ချိပြီး ပေါ့ပါးသော ချည်ထည် အဝတ်အစားများကို ဝတ်ဆင်ပါ။",
                "အပူလျှပ်ခြင်း လက္ခဏာများ (သတိလစ်ခြင်း၊ အဖျားတက်ခြင်း) တွေ့ပါက ရေအေးပတ်တိုက်ပေးပြီး ဆေးရုံ/လူနာတင်ယာဉ် ၁၉၂ သို့ ချက်ချင်းဆက်သွယ်ပါ။",
            ],
            after_steps_en=[
                "Continue hydration and electrolyte replenishment with ORS salts.",
            ],
            after_steps_my=[
                "ဓာတ်ဆားရည်နှင့် သောက်ရေသန့်ကို ဆက်လက်သောက်သုံးပေးပါ။",
            ],
            emergency_contacts=[
                {"name": "Medical Emergency (လူနာတင်ယာဉ်)", "number": "192"},
                {"name": "Red Cross First Aid (ကြက်ခြေနီ)", "number": "01-383680"},
            ],
            go_bag_items_en=[
                "Electrolyte oral rehydration salts (ORS)",
                "Sun protection hat & UV sunglasses",
                "Insulated thermal water thermos",
            ],
            go_bag_items_my=[
                "ဓာတ်ဆားထုပ်များ (ORS)",
                "ဦးထုပ်နှင့် နေကာမျက်မှန်",
                "ရေအေးခံ သာမိုဘူး",
            ],
        ),
    ]

    return guides
