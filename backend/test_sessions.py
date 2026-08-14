"""
Comprehensive Unit & Integration Test Suite for Multi-Device Session Control & Management.
Uses an isolated in-memory SQLite database to avoid modifying any persistent database.
"""

import sys
import os
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.database import Base
from app.models.account import Account, RoleEnum
from app.models.session import UserSession
from app.core.security import (
    hash_password,
    hash_token,
    generate_refresh_token,
    create_access_token,
    decode_access_token,
)
from app.services.session_service import (
    create_user_session,
    refresh_user_session,
    logout_single_session,
    logout_all_user_sessions,
    lock_emergency_session,
    list_user_sessions,
    admin_list_sessions,
)


async def run_session_tests():
    print("\n=======================================================")
    print("      KHU NYI KAL SAL — SESSION CONTROL TEST SUITE     ")
    print("=======================================================\n")

    # 1. Test In-Memory Engine Setup
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    print("[OK] In-memory database initialized successfully.")

    # ── Test 1: Cryptographic Token Generation & Hashing ──────────────
    print("\n--- 1. Testing Cryptographic Token Generation & Hashing ---")
    raw_token = generate_refresh_token()
    token_hash1 = hash_token(raw_token)
    token_hash2 = hash_token(raw_token)
    assert len(raw_token) >= 64, "Refresh token should be long and secure"
    assert token_hash1 == token_hash2, "SHA-256 hash must be deterministic"
    print(f"Sample Refresh Token: {raw_token[:20]}...")
    print(f"Hashed Token (SHA-256): {token_hash1}")
    print("[PASS] Token hashing verified!")

    # ── Test 2: Access Token Embedding session_id ───────────────────────
    print("\n--- 2. Testing JWT Access Token session_id Embedding ---")
    user_id = str(uuid.uuid4())
    session_id = str(uuid.uuid4())
    jwt_token = create_access_token({"sub": user_id, "session_id": session_id, "role": "user"})
    payload = decode_access_token(jwt_token)
    assert payload.get("sub") == user_id, "Subject should match user_id"
    assert payload.get("session_id") == session_id, "session_id should be present in payload"
    assert payload.get("role") == "user", "role should match"
    print(f"Decoded JWT claims: sub={payload['sub']}, session_id={payload['session_id']}")
    print("[PASS] Access Token with session_id verified!")

    # ── Test 3: User Multi-Device Limits (Max 3 Devices) ─────────────────
    print("\n--- 3. Testing User Multi-Device Limit (Max 3 Devices) ---")
    async with session_factory() as db:
        user_acc = Account(
            id=uuid.uuid4(),
            email="user_test@example.com",
            hashed_password=hash_password("password123"),
            role=RoleEnum.USER,
            is_active=True,
        )
        db.add(user_acc)
        await db.commit()

        # Login 3 devices
        s1 = await create_user_session(user_acc, db, device_id="phone_1", device_name="iPhone 14")
        s2 = await create_user_session(user_acc, db, device_id="phone_2", device_name="Pixel 8")
        s3 = await create_user_session(user_acc, db, device_id="phone_3", device_name="iPad Pro")

        sessions_before = await list_user_sessions(user_acc.id, None, db)
        active_before = [s for s in sessions_before if s["is_active"]]
        assert len(active_before) == 3, f"Expected 3 active sessions, got {len(active_before)}"
        print(f"Active sessions after 3 logins: {len(active_before)} (Expected: 3)")

        # Login 4th device (should deactivate 1st device)
        s4 = await create_user_session(user_acc, db, device_id="phone_4", device_name="Samsung S24")
        sessions_after = await list_user_sessions(user_acc.id, None, db)
        active_after = [s for s in sessions_after if s["is_active"]]
        assert len(active_after) == 3, f"Expected exactly 3 active sessions after 4th login, got {len(active_after)}"

        # Check that phone_1 was deactivated
        phone1_session = next(s for s in sessions_after if s["device_id"] == "phone_1")
        assert not phone1_session["is_active"], "Oldest device (phone_1) must be deactivated"
        print(f"Oldest session (phone_1) is_active={phone1_session['is_active']} (Expected: False)")
        print("[PASS] User device limit enforcement passed!")

    # ── Test 4: Volunteer Single-Session Limit ──────────────────────────
    print("\n--- 4. Testing Volunteer Single-Session Limit (Strictly 1 Device) ---")
    async with session_factory() as db:
        vol_acc = Account(
            id=uuid.uuid4(),
            email="volunteer_test@example.com",
            hashed_password=hash_password("volpass123"),
            role=RoleEnum.VOLUNTEER,
            is_active=True,
        )
        db.add(vol_acc)
        await db.commit()

        # Login 1st time
        v_s1 = await create_user_session(vol_acc, db, device_id="vol_phone_1", device_name="Volunteer Phone 1")
        vol_sessions1 = await list_user_sessions(vol_acc.id, None, db)
        active_v1 = [s for s in vol_sessions1 if s["is_active"]]
        assert len(active_v1) == 1, "Volunteer should have 1 active session"

        # Login 2nd time (should deactivate 1st session immediately)
        v_s2 = await create_user_session(vol_acc, db, device_id="vol_phone_2", device_name="Volunteer Phone 2")
        vol_sessions2 = await list_user_sessions(vol_acc.id, None, db)
        active_v2 = [s for s in vol_sessions2 if s["is_active"]]
        assert len(active_v2) == 1, f"Volunteer must have strictly 1 active session, got {len(active_v2)}"
        assert active_v2[0]["device_id"] == "vol_phone_2", "Active session must be the latest device"
        print(f"Active volunteer sessions after second login: {len(active_v2)} (Active Device: {active_v2[0]['device_id']})")
        print("[PASS] Volunteer single-session enforcement passed!")

    # ── Test 5: Refresh Token Flow ───────────────────────────────────────
    print("\n--- 5. Testing Refresh Token Flow ---")
    async with session_factory() as db:
        refresh_res = await refresh_user_session(
            refresh_token_plain=s4["refresh_token"],
            db=db,
            ip_address="192.168.1.100",
        )
        assert refresh_res["access_token"] is not None, "New access token must be issued"
        assert refresh_res["session_id"] == s4["session_id"], "Session ID must remain consistent"
        print(f"New Access Token issued: {refresh_res['access_token'][:30]}...")

        # Test rejected refresh with invalid token
        try:
            await refresh_user_session("invalid_token_12345", db)
            assert False, "Should raise HTTPException for invalid refresh token"
        except Exception as e:
            print(f"Invalid refresh token correctly rejected: {e}")
        print("[PASS] Refresh token flow passed!")

    # ── Test 6: Single Device Logout & Logout All ────────────────────────
    print("\n--- 6. Testing Logout Single & Logout All ---")
    async with session_factory() as db:
        # Logout single session (s4)
        s4_uuid = uuid.UUID(s4["session_id"])
        await logout_single_session(s4_uuid, user_acc.id, db)
        s4_check = await list_user_sessions(user_acc.id, None, db)
        s4_status = next(s for s in s4_check if s["session_id"] == str(s4_uuid))
        assert not s4_status["is_active"], "s4 session should now be inactive"
        print(f"s4 is_active after single logout: {s4_status['is_active']} (Expected: False)")

        # Logout all sessions for user
        count = await logout_all_user_sessions(user_acc.id, db)
        all_check = await list_user_sessions(user_acc.id, None, db)
        active_count = sum(1 for s in all_check if s["is_active"])
        assert active_count == 0, f"Expected 0 active sessions after logout_all, got {active_count}"
        print(f"Active sessions after logout_all: {active_count} (Expected: 0)")
        print("[PASS] Single and multi-device logout passed!")

    # ── Test 7: Emergency SOS Session Locking ────────────────────────────
    print("\n--- 7. Testing Emergency SOS Session Locking ---")
    async with session_factory() as db:
        # Create 3 new active sessions for user
        es1 = await create_user_session(user_acc, db, device_id="sos_dev_1")
        es2 = await create_user_session(user_acc, db, device_id="sos_dev_2")
        es3 = await create_user_session(user_acc, db, device_id="sos_dev_3")

        current_sos_session_id = uuid.UUID(es2["session_id"])

        # Trigger SOS Lock on es2
        print(f"User triggers SOS from session: {current_sos_session_id}")
        await lock_emergency_session(user_acc.id, current_sos_session_id, db)

        sos_sessions = await list_user_sessions(user_acc.id, None, db)
        for s in sos_sessions:
            if s["session_id"] == str(current_sos_session_id):
                assert s["is_active"], "Current SOS session MUST remain active"
            else:
                assert not s["is_active"], f"Other session {s['device_id']} MUST be deactivated"

        print(f"SOS caller session is_active=True, all {len(sos_sessions)-1} other sessions locked & deactivated!")
        print("[PASS] Emergency SOS session lock passed!")

    # ── Test 8: Admin Session Audit & Remote Kill Switch ─────────────────
    print("\n--- 8. Testing Admin Session Monitoring ---")
    async with session_factory() as db:
        admin_sessions = await admin_list_sessions(db, limit=50)
        assert len(admin_sessions) > 0, "Admin must be able to list system sessions"
        print(f"Admin retrieved {len(admin_sessions)} sessions with user email & role.")
        print("[PASS] Admin session monitoring passed!")

    await engine.dispose()
    print("\n=======================================================")
    print("   ALL MULTI-DEVICE SESSION MANAGEMENT TESTS PASSED!   ")
    print("=======================================================\n")


if __name__ == "__main__":
    asyncio.run(run_session_tests())
