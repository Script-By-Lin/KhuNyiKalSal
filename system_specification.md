# KhuNyiKalSal - Digital Marketing Poster Prompt Specification

This document outlines the core algorithms, workflows, and privacy/security features of the **KhuNyiKalSal** (Help & Rescue) system. It is specifically designed to be used as a prompt for generating high-conversion digital marketing posters or social media assets.

---

## 🚀 Target Audience & Vibe
- **Target Audience:** General public, families wanting peace of mind, rescue volunteers, and local rescue organizations.
- **Vibe:** Urgent yet reassuring, modern, secure, and community-driven. (Keywords: "Life-Saving", "Instant", "Secure", "Family").

---

## 🧠 Core Algorithms & Technology (The "Smart" Features)
Highlight these in the marketing materials to show technical superiority:

1. **Spatial Geo-Search & Nearest-Neighbor Algorithm:**
   - Instantly scans the radius around a victim using advanced geospatial indexing to calculate and pinpoint the closest available rescue organizations.
   - Drastically reduces dispatch times by mathematically identifying the shortest geographic path to help.
2. **Real-Time Pub/Sub Alerting System:**
   - Powered by an ultra-low-latency, event-driven WebSocket architecture.
   - When an SOS is triggered, the algorithm instantly broadcasts the alert to linked Family Members and nearby Responders in milliseconds.
3. **Dynamic Anti-False-Alarm Algorithm:**
   - Uses a time-gated interaction threshold (3-second hold) to filter out accidental pocket triggers, ensuring 100% SOS signal accuracy.
4. **Intelligent Dispatch & Pathfinding:**
   - Responders receive exact GPS coordinates for precision routing.
   - Continuous real-time coordinate synchronization tracks the responder's movement on the live map, keeping the victim informed of their exact distance.

---

## 🔄 User Flows (The "How It Works" Story)
Use this flow to create a 3-step visual graphic on the poster:

1. **Trigger (The SOS):** User holds the central SOS button for 3 seconds. 
2. **Broadcast (The Network):** 
   - **Family:** Loved ones receive a high-priority push notification.
   - **Responders:** Local rescue organizations see a flashing red pin drop on their command center map.
3. **Rescue (The Resolution):** A volunteer accepts the mission. Both the family and the victim can see the rescue vehicle moving live on the map until help arrives.

---

## 🔒 Privacy & Security Features (The "Trust" Factors)
Crucial for marketing to users concerned about tracking. Emphasize these points:

- **Zero-Idle Tracking (Privacy First):** Your location is **never** tracked or stored while the app is idle. GPS is strictly activated *only* when the SOS button is triggered.
- **Secure Encrypted Vault:** Uses military-grade secure storage (`flutter_secure_storage`) to keep authentication tokens completely isolated from malicious apps.
- **Granular Data Access:** 
   - Only your verified Family Group and authenticated Rescue Organizations can see your emergency location.
   - Once the emergency is resolved, live location sharing instantly cuts off.
- **Local Caching for Offline Resilience:** Critical emergency contacts and family data are cached locally, ensuring the app remains functional and fast even in low-connectivity zones.

---

## 🎨 Suggested Visual Elements for Poster
- **Centerpiece:** A glowing, pulsing red SOS button with a "3...2...1" dynamic countdown.
- **Background:** A sleek, dark-mode map with a pulsing signal connecting a victim's pin to a rescue vehicle and family avatars.
- **Badges:** "100% Privacy Focused", "Real-Time Tracking", "Zero Accidental Triggers".
- **Call to Action:** "Protect Your Loved Ones Today. Download KhuNyiKalSal."
