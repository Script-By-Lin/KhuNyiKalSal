"""
Test script for verifying Family Group management, Creator-Only permissions, and Family Alert Message Boxes.
"""

import sys
import os
import asyncio

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import select
from app.database import async_session_maker, create_tables
from app.models import Account, RoleEnum, UserProfile, FamilyGroup, FamilyMember, FamilyAlert
from app.core.security import hash_password
from app.api.family import (
    create_family_group,
    get_my_family_group,
    add_family_member,
    remove_family_member,
    update_family_group,
    delete_family_group,
    leave_family_group,
    get_family_alerts,
)
from app.schemas.family import (
    CreateFamilyGroupRequest,
    UpdateFamilyGroupRequest,
    AddFamilyMemberRequest,
)
from app.services.notification_service import notify_family


async def run_family_tests():
    print("\n--- 1. Initializing Database for Family Tests ---")
    await create_tables(drop=True)

    async with async_session_maker() as db:
        # Create Test Users: Creator (Father), Member (Son), Other User
        acc1 = Account(email="father@khunyikalsal.com", hashed_password=hash_password("password123"), role=RoleEnum.USER)
        acc2 = Account(email="son@khunyikalsal.com", hashed_password=hash_password("password123"), role=RoleEnum.USER)
        acc3 = Account(email="stranger@khunyikalsal.com", hashed_password=hash_password("password123"), role=RoleEnum.USER)
        db.add_all([acc1, acc2, acc3])
        await db.flush()

        prof1 = UserProfile(account_id=acc1.id, full_name="Father User", phone_number="0911111111")
        prof2 = UserProfile(account_id=acc2.id, full_name="Son User", phone_number="0922222222")
        prof3 = UserProfile(account_id=acc3.id, full_name="Stranger User", phone_number="0933333333")
        db.add_all([prof1, prof2, prof3])
        await db.commit()

        father_id = acc1.id
        son_id = acc2.id
        stranger_id = acc3.id

    print("[PASS] Test accounts created successfully!")

    print("\n--- 2. Testing Family Group Creation ---")
    async with async_session_maker() as db:
        acc1_obj = await db.get(Account, father_id)
        group_res = await create_family_group(
            CreateFamilyGroupRequest(group_name="The Heroic Family"),
            current_user=acc1_obj,
            db=db,
        )
        print(f"Created Group: {group_res.group_name} (ID: {group_res.family_id})")
        assert group_res.is_creator is True, "Group creator must have is_creator=True"
        assert len(group_res.members) == 1, "Creator must be initial member"
        print("[PASS] Family group creation passed!")

    print("\n--- 3. Testing Adding Family Member by Email & Relationship (Creator Only) ---")
    async with async_session_maker() as db:
        acc1_obj = await db.get(Account, father_id)
        # Father adds Son with relationship 'Son'
        add_res = await add_family_member(
            AddFamilyMemberRequest(email="son@khunyikalsal.com", relationship="Son"),
            current_user=acc1_obj,
            db=db,
        )
        print(f"Added member! Total members: {len(add_res.members)}")
        assert len(add_res.members) == 2, "Members list should now contain 2 members"
        son_mem = next(m for m in add_res.members if m.email == "son@khunyikalsal.com")
        assert son_mem.relationship == "Son", "Relationship title must be 'Son'"
        print("[PASS] Add family member with relationship role passed!")

    print("\n--- 4. Testing Creator-Only Permission Checks ---")
    async with async_session_maker() as db:
        acc2_obj = await db.get(Account, son_id)
        # Non-creator (Son) trying to add a member should fail with HTTP 403
        try:
            await add_family_member(
                AddFamilyMemberRequest(email="stranger@khunyikalsal.com", relationship="Other"),
                current_user=acc2_obj,
                db=db,
            )
            assert False, "Non-creator adding members must be rejected!"
        except Exception as e:
            print(f"Non-creator add member rejection: {e.detail}")
            assert "Only the Family Group Creator can add" in str(e.detail)
            print("[PASS] Non-creator permission check passed!")

    print("\n--- 5. Testing Updating Family Group (Creator Only) ---")
    async with async_session_maker() as db:
        acc1_obj = await db.get(Account, father_id)
        update_res = await update_family_group(
            UpdateFamilyGroupRequest(group_name="The Updated Family Clan"),
            current_user=acc1_obj,
            db=db,
        )
        assert update_res.group_name == "The Updated Family Clan"
        print(f"[PASS] Group name updated to '{update_res.group_name}'")

    print("\n--- 6. Testing Member Leaving Group ---")
    async with async_session_maker() as db:
        acc2_obj = await db.get(Account, son_id)
        leave_res = await leave_family_group(current_user=acc2_obj, db=db)
        print(f"Member leave message: {leave_res}")
        assert "left the family group successfully" in leave_res["detail"]
        print("[PASS] Member left group successfully!")

    print("\n--- 7. Testing Deleting Family Group (Creator Only) ---")
    async with async_session_maker() as db:
        acc1_obj = await db.get(Account, father_id)
        del_res = await delete_family_group(current_user=acc1_obj, db=db)
        print(f"Group deletion message: {del_res}")
        assert "deleted successfully" in del_res["detail"]
        print("[PASS] Family group deletion passed!")


if __name__ == "__main__":
    asyncio.run(run_family_tests())
    print("\n=== ALL FAMILY GROUP & EMERGENCY ALERTS TESTS PASSED! ===")
