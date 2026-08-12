Build a full-stack **Mobile Emergency Response Application** named **“Khu Nyi Kal Sal”** using **Flutter (frontend)** and **FastAPI (backend)** with PostgreSQL and Redis.

---

# 🎯 OBJECTIVE

Create a **real-time emergency system** that allows users to send SOS alerts and connects them to the nearest rescue organizations and volunteers with rerouting logic if no one responds.

---

# 🔐 RBAC SYSTEM

Implement Role-Based Access Control with 3 roles:

1. User
2. Organization
3. Volunteer (created and managed by Organization)

---

# 🎨 UI/UX DESIGN

Design a **simple, user-friendly, professional interface** using:

* Primary Color: Red (#E53935) → SOS / Emergency
* Secondary: Green (#2E7D32) → Accepted / Safe
* Background: White (#FFFFFF)
* Text/Dark: Black (#121212)

### UI Rules:

* Minimal design (no clutter)
* Large buttons (especially SOS)
* High contrast
* Smooth animations (SOS hold interaction)

---

# 📱 APP FLOW

## Authentication

* Login / Register screen
* Before registration → show legal agreement (Myanmar text)
* Require checkbox “I Agree” before proceeding

---

## Home Screen

* Banner explaining app
* Buttons:

  * “How to Use”
  * “Rules & Laws”
* Bottom floating navigation bar

---

## Map Screen (Main Feature)

* Show real-time user location
* Display nearby organizations on map
* Floating **center SOS button**

---

# 🔴 SOS FUNCTIONALITY

## Behavior:

* User must press and hold SOS button for 3 seconds
* Then choose emergency type:

  * Fire
  * Medical
  * Crime

---

# 🚨 BACKEND SOS FLOW

## Step 1: Create Emergency Event

Send:
{
"user_id": "...",
"type": "medical",
"location": "lat,long",
"timestamp": "..."
}

---

## Step 2: Attach Full User Data

Include:

* Full name
* Phone number
* Blood type
* Medical conditions
* Emergency contacts

---

## Step 3: Find Nearest Organization

Use:

* Linear Search
* Haversine Formula

Return sorted nearest organizations.

---

## Step 4: Send Alert

Send emergency request to:

* Nearest organization
* All active volunteers under that organization

---

# 🧑‍🚒 VOLUNTEER RESPONSE SYSTEM

Each volunteer receives:

* User location
* Emergency type
* Full medical profile

---

## Volunteer Actions

### ACCEPT:

* Assign volunteer to emergency
* Update status → accepted
* Notify user: “Help is on the way”

### REJECT:

* Mark volunteer unavailable
* Try next volunteer

---

# 🔁 REROUTE LOGIC

If:

* No volunteer accepts within 10 seconds
  OR
* All volunteers reject

Then:

1. Move to next nearest organization
2. Repeat alert process

---

## Pseudocode:

for org in nearest_orgs:
volunteers = get_active_volunteers(org)

```
for v in volunteers:
    send_alert(v)

wait 10 seconds

if any volunteer accepts:
    assign and stop loop
```

---

# 👨‍👩‍👧 FAMILY ALERT SYSTEM

When SOS is triggered:

* Notify all linked family members
* Include:

  * Emergency type
  * Location

---

# 📡 OFFLINE MODE

If no internet:

* Send SMS to:

  * Organizations
  * Family contacts

Message format:
SOS EMERGENCY!
Type: Medical
Location: lat,long
Name: User Name
Blood: A

---

# 🗄️ DATABASE SCHEMA

## User

{
"user_id": "uuid",
"role": "user",
"full_name": "...",
"blood_type": "...",
"phone_number": "...",
"medical_profile": "...",
"location": "lat,long"
}

---

## Organization

{
"org_id": "uuid",
"org_name": "...",
"geo_location": "lat,long",
"coverage_radius_km": 50
}

---

## Volunteer

{
"volunteer_id": "uuid",
"org_id": "...",
"full_name": "...",
"is_active": true,
"current_location": "lat,long"
}

---

## Emergency

{
"emergency_id": "uuid",
"user_id": "...",
"type": "medical",
"status": "pending | accepted | completed",
"assigned_org": "...",
"assigned_volunteer": "...",
"created_at": "timestamp"
}

---

# ⚙️ REAL-TIME SYSTEM

Use WebSockets in FastAPI.

Events:

* SOS_CREATED
* VOLUNTEER_ACCEPTED
* VOLUNTEER_REJECTED
* REROUTE_TRIGGERED

---

# 🔔 NOTIFICATIONS

* Firebase Cloud Messaging (push notifications)
* In-app alerts
* SMS fallback

---

# ⚠️ ABUSE PREVENTION

* Limit SOS requests per day
* Track fake alerts
* Block users if abuse detected

---

# 🚀 DEVELOPMENT PHASES

Phase 1:

* Authentication
* SOS system
* Map + nearest organization

Phase 2:

* Volunteer accept/reject system
* Rerouting logic

Phase 3:

* Smartwatch integration
* AI emergency detection

---

# 🔥 REQUIREMENTS

* Clean, scalable code
* Modular architecture
* Async FastAPI
* Secure authentication (JWT)
* Optimized API responses
* Real-time performance priority

---

Build this as a production-ready system with clear separation of frontend, backend, and real-time services and use the best architecture 
