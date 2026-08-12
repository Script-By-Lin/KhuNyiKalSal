"""
Seed script — populates the database with sample organisations,
volunteers, and test users for development, including Bago City.

Usage:
    cd backend
    python -m app.seed
"""

import asyncio
from sqlalchemy import select

from app.database import async_session_maker, create_tables
from app.models import Account, RoleEnum, UserProfile, Organization, Volunteer
from app.core.security import hash_password


async def seed():
    await create_tables(drop=True)

    async with async_session_maker() as db:
        # ── Sample organisations ───────────────────────────────────────
        orgs_data = [
            # Yangon
            {
                "name": "Yangon Fire Brigade",
                "category": "Fire",
                "lat": 16.8661,
                "lng": 96.1951,
                "radius": 30,
                "phone": "+959123456001",
            },
            {
                "name": "Yangon Emergency Rescue",
                "category": "Medical",
                "lat": 16.7983,
                "lng": 96.1497,
                "radius": 35,
                "phone": "+959123456007",
            },
            # Mandalay
            {
                "name": "Mandalay Rescue Team",
                "category": "Medical",
                "lat": 21.9588,
                "lng": 96.0891,
                "radius": 40,
                "phone": "+959123456002",
            },
            # Naypyidaw
            {
                "name": "Naypyidaw Emergency",
                "category": "Medical",
                "lat": 19.7633,
                "lng": 96.0785,
                "radius": 50,
                "phone": "+959123456003",
            },
            # Bago City
            {
                "name": "Bago Rescue & Relief Association",
                "category": "Medical",
                "lat": 17.3361,
                "lng": 96.4797,
                "radius": 45,
                "phone": "+959123456004",
            },
            {
                "name": "Bago Red Cross Society",
                "category": "Medical",
                "lat": 17.3220,
                "lng": 96.4650,
                "radius": 40,
                "phone": "+959123456005",
            },
            {
                "name": "Bago Fire Station Center",
                "category": "Fire",
                "lat": 17.3500,
                "lng": 96.4900,
                "radius": 35,
                "phone": "+959123456006",
            },
        ]

        created_orgs = 0
        created_vols = 0

        for od in orgs_data:
            email_slug = od["name"].lower().replace(" ", "_").replace("&", "and")
            email = f"{email_slug}@khunyikalsal.com"

            # Check if email exists
            res = await db.execute(select(Account).where(Account.email == email))
            if res.scalar_one_or_none():
                continue

            account = Account(
                email=email,
                hashed_password=hash_password("password123"),
                role=RoleEnum.ORGANIZATION,
            )
            db.add(account)
            await db.flush()

            org = Organization(
                account_id=account.id,
                org_name=od["name"],
                phone_number=od["phone"],
                geo_lat=od["lat"],
                geo_lng=od["lng"],
                registration_number=f"REG-2026-{created_orgs+100}",
                headquarters_address=f"{od['name']} HQ, Myanmar",
                operating_regions="Yangon" if "Yangon" in od["name"] else "Bago" if "Bago" in od["name"] else "National",
                category=od["category"],
                status="Active",
                coverage_radius_km=od["radius"],
            )
            db.add(org)
            created_orgs += 1

            # Two volunteers per org
            for i in range(1, 3):
                vol_email = f"volunteer{i}_{email_slug}@khunyikalsal.com"
                vol_res = await db.execute(select(Account).where(Account.email == vol_email))
                if vol_res.scalar_one_or_none():
                    continue

                vol_account = Account(
                    email=vol_email,
                    hashed_password=hash_password("password123"),
                    role=RoleEnum.VOLUNTEER,
                )
                db.add(vol_account)
                await db.flush()

                volunteer = Volunteer(
                    account_id=vol_account.id,
                    org_id=account.id,
                    full_name=f"Volunteer {i} — {od['name']}",
                    phone_number=f"+95912345{i:04d}",
                    nrc_number=f"12/YAG(N){i:06d}",
                    date_of_birth="1995-08-15",
                    emergency_contact="+959111222333",
                    assigned_region="Yangon" if "Yangon" in od["name"] else "Bago",
                    is_active=True,
                    current_lat=od["lat"] + (i * 0.01),
                    current_lng=od["lng"] + (i * 0.01),
                )
                db.add(volunteer)
                created_vols += 1

        # ── Test user ──────────────────────────────────────────────────
        test_email = "testuser@khunyikalsal.com"
        res = await db.execute(select(Account).where(Account.email == test_email))
        if not res.scalar_one_or_none():
            user_account = Account(
                email=test_email,
                hashed_password=hash_password("password123"),
                role=RoleEnum.USER,
            )
            db.add(user_account)
            await db.flush()

            profile = UserProfile(
                account_id=user_account.id,
                full_name="Test User",
                phone_number="+959123456789",
                blood_type="A+",
                medical_conditions="None",
                nrc_number="12/YAG(N)123456",
                gender="Male",
                family_id="FAM-9988",
                medical_profile={"previous_conditions": "None", "allergies": "None"},
                address_info={"region": "Yangon", "city": "Yangon", "township": "Kamayut", "detailed_address": "No. 123 Main St"},
                emergency_contacts=[
                    {"name": "Parent", "relation": "Parent", "phone": "+959111111111"},
                    {"name": "Spouse", "relation": "Spouse", "phone": "+959222222222"},
                ],
            )
            db.add(profile)

        # ── Super Admin Account ────────────────────────────────────────
        admin_email = "admin@khunyikalsal.com"
        admin_res = await db.execute(select(Account).where(Account.email == admin_email))
        if not admin_res.scalar_one_or_none():
            admin_acc = Account(
                email=admin_email,
                hashed_password=hash_password("password123"),
                role=RoleEnum.ADMIN,
            )
            db.add(admin_acc)

        await db.commit()

        print("[OK] Seed process completed!")
        print(f"    • Added {created_orgs} new Organisations ({created_vols} Volunteers)")
        print("    • Including Bago City sample rescue organizations")
        print("    • Test user: testuser@khunyikalsal.com / password123")
        print("    • All passwords: password123")


if __name__ == "__main__":
    asyncio.run(seed())
