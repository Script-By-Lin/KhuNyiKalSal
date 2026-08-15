"""
Khu Nyi Kal Sal — Mobile Emergency Response API

FastAPI application entry point with CORS, routing, DB initialisation, and Alembic migrations.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import create_tables
from app.api import auth, users, organizations, volunteers, emergency, admin, family, blood_donation
from app.api import websocket as ws

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Run Alembic database migrations and seed initial data on startup."""
    try:
        from migrate import run_migrations
        run_migrations()
    except Exception as e:
        logging.warning(f"Alembic migration notice: {e}")

    await create_tables()
    try:
        from app.seed import seed
        await seed(drop=False)
    except Exception as e:
        logging.warning(f"Database seed notice: {e}")
    yield


app = FastAPI(
    title="Khu Nyi Kal Sal API",
    description="Real-time Mobile Emergency Response System",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Route registration ─────────────────────────────────────────────────────
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(admin.router, prefix="/api/admin", tags=["Admin"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(
    organizations.router, prefix="/api/organizations", tags=["Organizations"]
)
app.include_router(
    volunteers.router, prefix="/api/volunteers", tags=["Volunteers"]
)
app.include_router(
    emergency.router, prefix="/api/emergency", tags=["Emergency"]
)
app.include_router(
    family.router, prefix="/api/family", tags=["Family"]
)
app.include_router(
    blood_donation.router, prefix="/api/blood-donations", tags=["Blood Donation"]
)
app.include_router(ws.router, tags=["WebSocket"])


@app.get("/")
async def root():
    return {
        "message": "Khu Nyi Kal Sal — Emergency Response API",
        "docs": "/docs",
    }
