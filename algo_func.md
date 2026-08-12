# Khu Nyi Kal Sal — Complete System Architecture, Algorithm & Functional Specification

## 1. 🏗️ High-Level System Architecture & Layers

The **Khu Nyi Kal Sal** platform is a real-time mobile emergency response system connecting emergency victims, rescue organizations, volunteers, and system administrators.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                                FRONTEND LAYER                                    │
│  [Flutter Web & Mobile] — Riverpod State Management | GoRouter | FlutterMap     │
│  • Victim App (ShellScreen, HomeScreen, MapScreen, ProfileScreen)                │
│  • Organization Command Center (OrgDashboard, ManageVolunteersScreen)            │
│  • Volunteer Console (VolunteerDashboard)                                       │
│  • Super Admin Control Panel (AdminDashboard)                                    │
└───────────────────────────────┬──────────────────────────────────────────────────┘
                                │ HTTP / REST & WebSockets (wss://)
┌───────────────────────────────▼──────────────────────────────────────────────────┐
│                                BACKEND LAYER                                     │
│  [FastAPI Python Engine] — Asynchronous ASGI Server                             │
│  ├── API Routers (/api/auth, /api/emergency, /api/volunteers, /api/admin)        │
│  ├── WebSocket Connection Manager (app/websocket/manager.py)                     │
│  ├── SOS Orchestrator & Background Tasks (app/services/sos_service.py)           │
│  └── Haversine & Geolocation Engine (app/services/location_service.py)           │
└───────────────────────────────┬──────────────────────────────────────────────────┘
                                │ Async SQLAlchemy ORM / Asyncpg
┌───────────────────────────────▼──────────────────────────────────────────────────┐
│                                DATABASE LAYER                                    │
│  [PostgreSQL Engine]                                                             │
│  ├── accounts (Unified Authentication & RoleEnum: USER, ORG, VOLUNTEER, ADMIN)  │
│  ├── user_profiles (Medical Info, NRC, Blood Type, Emergency Contacts)          │
│  ├── organizations (Geographic Base Coordinates, Headquarters, Coverage Radius) │
│  ├── volunteers (Affiliated Org ID, Duty Status, Live Location Coordinates)     │
│  └── emergencies (Type, Status, Location Coordinates, Timestamps)              │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 🧮 Core Algorithms & Function Specifications

### 2.1. Haversine Distance Algorithm (`haversine`)
- **File**: [location_service.py](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/backend/app/services/location_service.py)
- **Function**: `haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float`
- **Logic**:
  Computes the great-circle distance between two geographic coordinates on Earth using spherical trigonometry:
  $$\Delta \text{lat} = \text{radians}(\text{lat}_2 - \text{lat}_1)$$
  $$\Delta \text{lng} = \text{radians}(\text{lng}_2 - \text{lng}_1)$$
  $$a = \sin^2\left(\frac{\Delta \text{lat}}{2}\right) + \cos(\text{radians}(\text{lat}_1)) \cdot \cos(\text{radians}(\text{lat}_2)) \cdot \sin^2\left(\frac{\Delta \text{lng}}{2}\right)$$
  $$c = 2 \cdot \arcsin(\sqrt{a})$$
  $$\text{Distance} = R \cdot c \quad (R = 6371.0 \text{ km})$$

---

### 2.2. Nearest Organization Search & Priority Scoring Algorithm
- **File**: [location_service.py](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/backend/app/services/location_service.py)
- **Function**: `find_nearest_organizations(lat, lng, db, emergency_type) -> List[Tuple[Organization, float]]`
- **Logic**:
  1. Queries all active rescue organizations (`Organization.is_active == True`).
  2. Calculates the Haversine distance from the emergency location $(lat, lng)$ to each organization's base location $(geo\_lat, geo\_lng)$.
  3. Assigns an emergency-type priority score $\text{score}(\text{org})$:
     - **Fire Emergency**: Matches keyword `fire`, `station`, `brigade` (Score 0 vs 1).
     - **Medical Emergency**: Matches keyword `hospital`, `medical`, `health`, `rescue` (Score 0 vs 1).
     - **Crime Emergency**: Matches keyword `police`, `security`, `guard`, `crime` (Score 0 vs 1).
  4. Sorts organizations by tuple key: `(_type_score(org), distance)`.

---

### 2.3. SOS Dispatch Orchestration Algorithm
- **File**: [sos_service.py](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/backend/app/services/sos_service.py)
- **Function**: `process_sos(emergency_id, user_id, lat, lng, emergency_type)`
- **Logic**:
  1. **User Medical Retrieval**: Queries `UserProfile` to construct victim information (Name, Phone, Blood Type, Medical Conditions).
  2. **Family Notification**: Calls `notify_family` to alert user emergency contacts via SMS/push mock.
  3. **Nearest Org Calculation**: Calls `find_nearest_organizations` to determine the best matching rescue station.
  4. **WebSocket Broadcast**: Builds `SOS_CREATED` event payload and executes `manager.broadcast_all(alert_data)` to deliver real-time alerts instantly to all active rescue organization consoles.

---

### 2.4. In-Memory Response & Rejection Tracker
- **File**: [sos_service.py](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/backend/app/services/sos_service.py)
- **Class**: `EmergencyResponseTracker`
- **Methods**:
  - `add_rejection(emergency_id, account_id)`: Records persistent organization or volunteer rejections in `_rejected_ids: dict[str, set[str]]`.
  - `is_rejected_by(emergency_id, account_id) -> bool`: Checks if an organization previously rejected a specific case.
  - `respond(emergency_id, volunteer_id, accepted)`: Sets the `asyncio.Event` signal upon acceptance.

---

### 2.5. Live OSRM Road Route Interpolation & Dispatch Simulator
- **File**: [org_dashboard.dart](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/frontend/lib/screens/organization/org_dashboard.dart)
- **Method**: `_startLiveSimulation(Map<String, dynamic> e)`
- **Logic**:
  1. Extracts starting base coordinates of the responding organization $(startLat, startLng)$ and victim destination $(endLat, endLng)$.
  2. Issues HTTP GET to Open Source Routing Machine (OSRM):
     `https://router.project-osrm.org/route/v1/driving/startLng,startLat;endLng,endLat?overview=full&geometries=geojson`
  3. Extracts the list of road coordinates $[(lat_0, lng_0), (lat_1, lng_1), \dots, (lat_N, lng_N)]$.
  4. Runs a `Timer.periodic` every 1.2 seconds, stepping through index $0 \to N$.
  5. On each step, calls `ApiService().updateVolunteerLocation(lat, lng)`, which updates PostgreSQL and broadcasts `RESPONDER_LOCATION_UPDATED` over WebSockets to move the map vehicle marker along real streets.

---

### 2.6. Real-Time Location Stream Engine
- **File**: [location_service.dart](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/frontend/lib/services/location_service.dart)
- **Methods**:
  - `getCurrentLocation() -> Future<Position>`: Requests GPS permission checks (`checkPermission`, `requestPermission`) and fetches high-accuracy GPS coordinates.
  - `getLocationStream() -> Stream<Position>`: Provides continuous location updates using a 10-meter distance filter.

---

### 2.7. Super Admin Organization CRUD Engine
- **Backend File**: [admin.py](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/backend/app/api/admin.py)
- **Frontend File**: [admin_dashboard.dart](file:///c:/Users/Script-Kid/Desktop/KhuNyiKalSal/frontend/lib/screens/admin/admin_dashboard.dart)
- **Methods**:
  - `GET /api/admin/organizations`: Returns all registered organization accounts.
  - `POST /api/admin/organizations`: Creates unified `Account` (Role `ORGANIZATION`) and linked `Organization` record.
  - `PUT /api/admin/organizations/{id}`: Updates name, phone, location coordinates, regions, or active status.
  - `DELETE /api/admin/organizations/{id}`: Deletes organization and cascades deletion of affiliated volunteers.
  - `_pickLocationOnMap()`: Interactive map pin picker modal allowing administrators to tap anywhere on a map to visually set station coordinates.

---

## 3. 🔄 System Execution Workflows

### Workflow 1: Emergency SOS Call & Live Dispatch Lifecycle
```
[Victim User]                    [FastAPI Engine]                 [Org Dashboard]               [User Map Screen]
     │                                  │                                │                              │
     ├─── 1. Press SOS Button ─────────►│                                │                              │
     │    (POST /api/emergency/sos)     │                                │                              │
     │                                  ├── 2. Save Emergency (PENDING)  │                              │
     │                                  ├── 3. process_sos (Background)  │                              │
     │                                  │                                │                              │
     │                                  ├── 4. Broadcast SOS_CREATED ───►│                              │
     │                                  │    (WebSocket)                 ├── 5. Ring Alarm Sound 🔔      │
     │                                  │                                ├── 6. Show Card & ETA         │
     │                                  │                                │                              │
     │                                  │◄── 7. Accept & Dispatch ───────┤                              │
     │                                  │    (POST /volunteers/respond)  │                              │
     │                                  ├── 8. Update (ACCEPTED)         │                              │
     │                                  │                                │                              │
     │                                  ├── 9. Send VOLUNTEER_ACCEPTED ────────────────────────────────►│
     │                                  │                                │                              ├── 10. Draw Green Polyline
     │                                  │                                │                              └── 11. Show ETA Badge
     │                                  │                                │                              │
     │                                  │◄── 12. OSRM Step GPS Tick ─────┤                              │
     │                                  │    (PUT /volunteers/location)  │ (Vehicle moves along road)   │
     │                                  ├── 13. Send RESPONDER_LOCATION_UPDATED ───────────────────────►│
     │                                  │                                │                              └── 14. Animate Car Marker
     │                                  │                                │                              │
     │                                  │◄── 15. Complete Emergency ─────┤                              │
     │                                  │    (PUT /emergency/complete)   │                              │
     │                                  ├── 16. Send EMERGENCY_COMPLETED ──────────────────────────────►│
     │                                  │                                │                              └── 17. Success Screen
```

---

### Workflow 2: Super Admin Organization Management Lifecycle
```
[Admin]                              [AdminDashboard UI]                     [Backend REST API]
   │                                         │                                      │
   ├── 1. Log in (admin@khunyikalsal.com) ──►│                                      │
   │                                         ├── 2. GET /api/admin/organizations ──►│
   │                                         │◄── 3. Return JSON List ──────────────┤
   │                                         │                                      │
   ├── 4. Click "ADD ORG" ──────────────────►│                                      │
   ├── 5. Click "📍 PICK LOCATION ON MAP PIN" ┤                                      │
   │    (Tap map to set Lat/Lng)             │                                      │
   ├── 6. Click "CREATE ORGANIZATION" ──────►│                                      │
   │                                         ├── 7. POST /api/admin/organizations ─►│
   │                                         │    (Creates Account & Organization)  │
   │                                         │◄── 8. 201 Created Confirmation ──────┤
   │                                         │                                      │
   └── 9. Refresh Dashboard Table ──────────►│                                      │
```

---

## 4. 📁 Complete Directory Structure Reference

```
KhuNyiKalSal/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   │   ├── admin.py           # Super Admin Organization CRUD API
│   │   │   ├── auth.py            # JWT Login & Registration API
│   │   │   ├── emergency.py       # SOS Creation, Cancel, Complete API
│   │   │   ├── organizations.py   # Organization directory & profile API
│   │   │   ├── users.py           # User Profile & Location API
│   │   │   ├── volunteers.py      # Responder alerts, history & response API
│   │   │   └── websocket.py       # Real-time WebSocket connection endpoint
│   │   ├── core/
│   │   │   ├── permissions.py     # Role-based access control (require_role)
│   │   │   └── security.py        # Password hashing & JWT token encoding
│   │   ├── models/
│   │   │   ├── account.py         # Unified Account ORM model & RoleEnum
│   │   │   ├── emergency.py       # Emergency ORM model & EmergencyStatus
│   │   │   ├── organization.py    # Organization ORM model
│   │   │   ├── user_profile.py    # UserProfile ORM model
│   │   │   └── volunteer.py       # Volunteer ORM model
│   │   ├── services/
│   │   │   ├── location_service.py# Haversine distance & nearest org finder
│   │   │   ├── notification_service.py # SMS & family notification mock
│   │   │   └── sos_service.py     # SOS background orchestrator & response tracker
│   │   ├── websocket/
│   │   │   └── manager.py         # ConnectionManager singleton
│   │   ├── config.py              # Application settings & environment vars
│   │   ├── database.py            # Async SQLAlchemy engine & session maker
│   │   ├── main.py                # FastAPI application entrypoint
│   │   └── seed.py                # Database initialiser & sample dataset
│   └── requirements.txt           # Python backend dependencies
└── frontend/
    ├── lib/
    │   ├── config/
    │   │   ├── routes.dart        # GoRouter navigation configuration
    │   │   └── theme.dart         # Dark Command Center theme palette
    │   ├── models/                # Data models for User, Emergency, Org
    │   ├── providers/             # Riverpod state providers (auth, emergency)
    │   ├── screens/
    │   │   ├── admin/             # AdminDashboard screen
    │   │   ├── auth/              # LoginScreen, RegisterScreen, LegalAgreementScreen
    │   │   ├── home/              # HomeScreen, HowToUseScreen, RulesLawsScreen
    │   │   ├── map/               # MapScreen (OSRM polyline, live simulation tracking)
    │   │   ├── organization/      # OrgDashboard, ManageVolunteersScreen, OrgsListScreen
    │   │   ├── profile/           # ProfileScreen (NRC, Blood Type, Medical profile)
    │   │   ├── volunteer/         # VolunteerDashboard console
    │   │   └── shell_screen.dart  # Main navigation shell with active emergency banner
    │   ├── services/
    │   │   ├── api_service.dart   # Dio HTTP API client
    │   │   └── location_service.dart # Geolocator position stream service
    │   └── main.dart              # Flutter application entrypoint
    └── pubspec.yaml               # Flutter package configuration
```
