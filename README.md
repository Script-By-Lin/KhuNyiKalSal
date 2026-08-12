# 🚨 Khu Nyi Kal Sal (ကူညီကယ်ဆယ်)

Khu Nyi Kal Sal is a comprehensive, real-time emergency dispatch and GPS radar application designed to rapidly connect individuals in distress with nearby rescue organizations and volunteers. Built with speed, reliability, and accessibility in mind, it provides live tracking, instant SOS dispatching, and full bilingual support (English & Myanmar).

---

## ✨ Key Features

- **🔴 Instant SOS Dispatch**: One-tap emergency alerts broadcasted instantly to nearby active rescue organizations and on-duty volunteers.
- **🗺️ Live GPS Radar**: Real-time map tracking utilizing `flutter_map` and OpenStreetMap to pinpoint user locations and active rescue stations.
- **⚡ Real-Time Communication**: Powered by WebSockets to ensure dispatch requests, acceptances, and status updates happen instantly without polling.
- **🛡️ Role-Based Dashboards**:
  - **Super Admin**: Manage platform organizations and oversee system health.
  - **Organization**: Command center to accept/reject incoming emergencies, view victim details, and dispatch teams.
  - **Volunteer**: Toggle on/off-duty status and accept local dispatch requests.
  - **User**: Update critical medical info (blood type, allergies) and track personal emergency history.
- **🇲🇲 Full Localization**: Seamless, on-the-fly switching between English and Myanmar (Burmese) across all dashboards and user panels.
- **🎨 Modern UI/UX**: A clean, highly legible White, Red, and Black design system optimized for high-stress emergency situations.

---

## 🛠️ Technology Stack

### Frontend (Mobile App)
- **Framework**: Flutter
- **State Management**: Riverpod (`flutter_riverpod`)
- **Routing**: GoRouter
- **Maps**: `flutter_map` (OpenStreetMap integration)
- **Local Storage**: `flutter_secure_storage`

### Backend (Server)
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL
- **Real-time**: WebSockets
- **Authentication**: JWT (JSON Web Tokens) & Passlib (Bcrypt)
- **ORM / Database Driver**: `asyncpg`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19+)
- [Python](https://www.python.org/downloads/) (3.10+)
- PostgreSQL Database

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Set up your `.env` file with your PostgreSQL credentials:
   ```env
   DATABASE_URL=postgresql://user:password@localhost/khunyikalsal
   SECRET_KEY=your_super_secret_key
   ```
5. Run the FastAPI server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

### Frontend Setup
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Ensure the API endpoint in `lib/services/api_service.dart` points to your backend IP address.
4. Run the app on an emulator or physical device:
   ```bash
   flutter run
   ```

---

## 📱 Screenshots & Flow

*(Consider adding screenshots of the Home Radar, Admin Dashboard, and SOS trigger screen here before publishing to GitHub!)*

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! 
Feel free to check the [issues page](https://github.com/Script-By-Lin/KhuNyiKalSal/issues).

---

## 📄 License
This project is licensed under the MIT License. See the `LICENSE` file for details.

## Developer Group
CognitionX
