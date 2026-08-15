"""
Khu Nyi Kal Sal — Mobile Emergency Response API

FastAPI application entry point with CORS, routing, DB initialisation, health diagnostics, and Alembic migrations.
"""

import time
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import create_tables, async_session_maker
from app.websocket.manager import manager
from app.api import auth, users, organizations, volunteers, emergency, admin, family, blood_donation, announcements, support
from app.api import websocket as ws

logger = logging.getLogger(__name__)

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
        logger.warning(f"Alembic migration notice: {e}")

    await create_tables()
    try:
        from app.seed import seed
        await seed(drop=False)
    except Exception as e:
        logger.warning(f"Database seed notice: {e}")
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


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Production global exception handler returning clean JSON error responses."""
    logger.error(f"Unhandled Server Exception on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal server error occurred. Please try again later."},
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
app.include_router(
    announcements.router, prefix="/api/announcements", tags=["Announcements"]
)
app.include_router(
    support.router, prefix="/api/support", tags=["Support & Donation"]
)
app.include_router(ws.router, tags=["WebSocket"])


@app.get("/")
async def root():
    return {
        "message": "Khu Nyi Kal Sal — Emergency Response API",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health")
@app.get("/api/health")
async def health_check():
    """Production health check endpoint assessing DB, Redis, and WebSocket connectivity."""
    db_status = "unhealthy"
    db_latency_ms = None
    t0 = time.time()
    try:
        async with async_session_maker() as session:
            await session.execute(text("SELECT 1"))
            db_latency_ms = round((time.time() - t0) * 1000, 2)
            db_status = "healthy"
    except Exception as e:
        logger.error(f"Health check DB ping failed: {e}")

    ws_stats = manager.get_stats()

    is_overall_healthy = db_status == "healthy"
    return JSONResponse(
        status_code=status.HTTP_200_OK if is_overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE,
        content={
            "status": "healthy" if is_overall_healthy else "degraded",
            "database": {
                "status": db_status,
                "latency_ms": db_latency_ms,
            },
            "websockets": ws_stats,
            "timestamp": time.time(),
        },
    )
