# Khu Nyi Kal Sal — SESSION CONTROL & DEVICE MANAGEMENT PROMPT

Build a **secure session management system** for a real-time emergency application using **FastAPI (backend)** and **Flutter (frontend)**.

---

# 🎯 OBJECTIVE

Implement a **multi-device session control system** with:

* Secure login
* Device tracking
* Session validation
* Role-based restrictions
* Emergency safety locking
* Refresh Token Middleware
* Session Expiration
* Device limit enforcement
* Authentication Middleware

---

# 🗄️ DATABASE DESIGN

Create a sessions table:

sessions:

* session_id (uuid, primary key)
* user_id (uuid, foreign key)
* device_id (string)
* device_name (string)
* refresh_token (hashed)
* ip_address (string)
* user_agent (string)
* is_active (boolean)
* created_at (timestamp)
* last_used_at (timestamp)

---

# 🔐 LOGIN FLOW

On login:

1. Validate user credentials
2. Generate:

   * access_token (JWT)
   * refresh_token
3. Create new session record
4. Attach session_id inside JWT

---

# 📱 DEVICE MANAGEMENT RULES

## USER

* Allow maximum 3 active devices

## ORGANIZATION

* Allow multiple devices (no strict limit)

## VOLUNTEER

* Only ONE active session allowed
* On login → logout all previous sessions

---

# 🔒 DEVICE LIMIT ENFORCEMENT

If user exceeds device limit:

* Reject login OR
* Optionally remove oldest session

---

# 🔁 TOKEN SYSTEM

## Access Token

* Short-lived (15–30 min)
* Contains:

  * user_id
  * session_id
  * role

## Refresh Token

* Stored hashed in DB
* Used to generate new access token

---

# 🔁 REFRESH FLOW

1. Client sends refresh_token
2. Backend verifies hashed token
3. If session is active:

   * issue new access_token
4. Else:

   * reject request

---

# 🚪 LOGOUT SYSTEM

## Single Device Logout

* Set is_active = false for session_id

## Logout All Devices

* Set is_active = false for all user sessions

---

# 🧠 SESSION VALIDATION MIDDLEWARE

On every request:

1. Decode JWT
2. Extract session_id
3. Check:

   * session exists
   * session is_active == true

If invalid → reject request

---

# 🦺 VOLUNTEER SPECIAL LOGIC

On volunteer login:

* Deactivate all previous sessions
* Create new session

This ensures:

* Only one active device
* Prevent double emergency acceptance

---

# 🚨 EMERGENCY SESSION LOCK

When user triggers SOS:

* Lock user to current session
* Deactivate other sessions

Purpose:

* Prevent duplicate SOS requests
* Ensure consistency

---

# ⏱ SESSION EXPIRATION

* Automatically expire inactive sessions (e.g., 24 hours)
* Update last_used_at on every request

---

# 📡 SECURITY FEATURES

Implement:

* Hash refresh tokens (never store plain)
* Track:

  * IP address
  * device info
* Detect:

  * suspicious login (new device)
* Optional:

  * notify user of new login

---

# ⚠️ ABUSE PREVENTION

* Limit login attempts
* Limit number of devices
* Detect unusual behavior

---

# 📊 ADMIN MONITORING

Allow admin to view:

* Active sessions
* Devices per user
* Last activity
* IP locations

---

# 🔧 BACKEND REQUIREMENTS

* Async FastAPI
* SQLAlchemy (async)
* JWT authentication
* Secure hashing (bcrypt + token hashing)

---

# 📱 FRONTEND REQUIREMENTS (FLUTTER)

* Store access_token securely
* Store refresh_token securely
* Attach token to API requests
* Auto refresh expired token
* Handle logout properly

---

# 🚀 FINAL GOAL

Build a **secure, scalable, real-time session control system** that supports:

* Multi-device users
* Single-session volunteers
* Emergency-safe operations
* High security and privacy compliance

---

Ensure the system is production-ready and integrates cleanly with SOS emergency workflows.
