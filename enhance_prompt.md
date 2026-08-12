# Khu Nyi Kal Sal — IMPLEMENTATION PROMPT V2 (Production-Level)

Build a **real-time emergency response system** using:

* Frontend: Flutter (Riverpod, GoRouter, FlutterMap)
* Backend: FastAPI (Async)
* Database: PostgreSQL (Async SQLAlchemy)
* Realtime: WebSockets
* Routing: OSRM API

---

# 🏗️ SYSTEM ARCHITECTURE

Follow a layered architecture:

1. Frontend Layer (Flutter apps)

   * User App
   * Organization Dashboard
   * Volunteer Console
   * Admin Panel

2. Backend Layer (FastAPI)

   * API Routers
   * WebSocket Manager (channel-based)
   * SOS Orchestrator Service
   * Location Service (Haversine + scoring)

3. Database Layer (PostgreSQL)

   * accounts (RoleEnum: USER, ORG, VOLUNTEER, ADMIN)
   * user_profiles
   * organizations
   * volunteers
   * emergencies

---

# 🔐 RBAC SYSTEM

Implement role-based access using middleware:

* USER → can trigger SOS
* ORGANIZATION → manage volunteers
* VOLUNTEER → accept/reject emergencies
* ADMIN → full control

---

# 🚨 SOS ORCHESTRATION (CORE ENGINE)

## Function:

process_sos(emergency_id, user_id, lat, lng, emergency_type)

---

## Step 1: Retrieve User Data

Include:

* name
* phone
* blood type
* medical conditions

---

## Step 2: Notify Family

Call notification_service

---

## Step 3: Find Nearest Organizations

Use:

* Haversine distance
* Priority scoring

### Scoring formula:

score = distance + (type_weight * 0.5)

Sort ascending

---

## Step 4: Filter Organizations

ONLY include:

* active organizations
* not rejected before
* within coverage radius

---

## Step 5: Dispatch Loop

for org in sorted_orgs:

```
send WebSocket event to org channel:
"org:{org_id}"

send to all active volunteers in org:
"volunteer:{volunteer_id}"

try:
    wait for response (10 sec timeout)

    if accepted:
        assign emergency
        break

except Timeout:
    continue to next org
```

---

# 🔁 RESPONSE TRACKER

Maintain in-memory:

* rejected_ids[emergency_id] = set()
* accepted_event = asyncio.Event()

Methods:

* add_rejection()
* is_rejected()
* respond()

---

# 📡 WEBSOCKET EVENTS

Implement channel-based messaging:

Events:

* SOS_CREATED
* VOLUNTEER_ACCEPTED
* VOLUNTEER_REJECTED
* RESPONDER_LOCATION_UPDATED
* EMERGENCY_COMPLETED

---

# 🚗 LIVE TRACKING SYSTEM

Use OSRM API:

* Fetch route coordinates
* Simulate movement using timer
* Update backend every 1–2 sec

Backend:

* update volunteer location
* broadcast to user

---

# 🔴 SOS BUTTON (Frontend)

* Center floating button
* Hold for 3 seconds
* Show emergency type selection

---

# 📱 UI DESIGN

Color System:

* Red → SOS / danger
* Green → accepted / success
* White → background
* Black → text

Design:

* minimal
* large buttons
* high contrast
* smooth animations

---

# 👨‍👩‍👧 FAMILY ALERT SYSTEM

Send:

* push notification
* SMS fallback

Include:

* type
* location

---

# 📡 OFFLINE MODE

If no internet:

* send SMS:
  "SOS! Type: Medical | Location: lat,long | Blood: A"

---

# ⚠️ ABUSE CONTROL

* limit SOS calls per day
* track misuse count
* block abusive users

---

# 🧠 PERFORMANCE REQUIREMENTS

* fully async backend
* non-blocking WebSocket
* optimized DB queries
* real-time response priority

---

# 🚀 DEVELOPMENT PRIORITY

1. Auth + RBAC
2. SOS + WebSocket
3. Nearest org algorithm
4. Volunteer response system
5. Live tracking

---

Build this system as **production-ready, modular, scalable, and real-time optimized**.
