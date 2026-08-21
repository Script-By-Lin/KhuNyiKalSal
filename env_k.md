# 🚀 Railway Environment Variables (.env) for Khu Nyi Kal Sal

You can copy and paste the block below directly into Railway's **"Raw Editor"** in the **Variables** tab of your backend service.

---

### 📋 Copy & Paste (Raw Editor Format)

```env
DATABASE_URL=postgresql://postgres:bdVNJVoRQcWkycAohaOXBrfoFnWUNvMm@postgres.railway.internal:5432/railway
REDIS_URL=redis://default:FjJkHWjFHbWJpeVGXNGttEMAZFXMkOwA@redis.railway.internal:6379
SECRET_KEY=d7d5bf1ae69e3985b71db6d141e39b9c07c155@!$@e7ce44307736b396708c41a457@
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
MAX_SOS_PER_DAY=5
VOLUNTEER_TIMEOUT_SECONDS=180
SOS_REROUTE_TIMEOUT_SECONDS=180
EMAILJS_SERVICE_ID=service_7eznh8w
EMAILJS_TEMPLATE_ID=template_dfpnmo9
EMAILJS_PUBLIC_KEY=GnGSWrvd1vwRf9sie
EMAILJS_PRIVATE_KEY=ngwRK6yaJf5vZtkg8VuK2
OTP_VALIDITY_SECONDS=60
TZ=Asia/Yangon
```

---

### 🔑 Key & Value Reference Table

| Variable Key | Value | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres:bdVNJVoRQcWkycAohaOXBrfoFnWUNvMm@postgres.railway.internal:5432/railway` | Railway PostgreSQL internal database connection string |
| `REDIS_URL` | `redis://default:FjJkHWjFHbWJpeVGXNGttEMAZFXMkOwA@redis.railway.internal:6379` | Railway Redis in-memory cache & Pub/Sub broker |
| `SECRET_KEY` | `your-super-secret-key-change-me-in-production` | Secret key used for signing JWT access & refresh tokens |
| `ALGORITHM` | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | JWT token validity window (1440 minutes = 24 hours) |
| `MAX_SOS_PER_DAY` | `5` | Maximum SOS calls allowed per user per 24 hours |
| `VOLUNTEER_TIMEOUT_SECONDS` | `180` | Time window before escalating to next rescue responder (3 mins) |
| `SOS_REROUTE_TIMEOUT_SECONDS` | `180` | Auto-reroute timeout for unaccepted SOS emergency calls |
| `EMAILJS_SERVICE_ID` | `service_7eznh8w` | EmailJS Service ID for sending OTP password reset emails |
| `EMAILJS_TEMPLATE_ID` | `template_dfpnmo9` | EmailJS Template ID for OTP password reset template |
| `EMAILJS_PUBLIC_KEY` | `GnGSWrvd1vwRf9sie` | EmailJS User / Public Key |
| `EMAILJS_PRIVATE_KEY` | `ngwRK6yaJf5vZtkg8VuK2` | EmailJS Private Access Token / Secret Key |
| `OTP_VALIDITY_SECONDS` | `60` | OTP code expiration time (60 seconds) |
| `TZ` | `Asia/Yangon` | System & logging timezone (Myanmar Time, UTC+06:30) |

---

### 💡 Optional Push Notification Variables (If using Firebase Cloud Messaging)

```env
FCM_SERVER_KEY=
FIREBASE_CREDENTIALS_JSON=
```
