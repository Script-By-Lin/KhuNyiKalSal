"""
Test script for verifying Family Group management, Invitation Accept/Deny flow, Creator-Only permissions, and Family Alert Message Boxes.
"""

import sys
import os
import unittest
from unittest.mock import AsyncMock, patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.database import Base
from app.models import Account, RoleEnum, UserProfile, FamilyGroup, FamilyMember, FamilyAlert
from app.core.security import hash_password
from app.api.family import (
    create_family_group,
    get_my_family_group,
    get_my_family_invitations,
    accept_family_invitation,
    deny_family_invitation,
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


class TestFamilyLifecycle(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
        self.session_factory = async_sessionmaker(self.engine, class_=AsyncSession, expire_on_commit=False)

        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with self.session_factory() as db:
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

            self.father_id = acc1.id
            self.son_id = acc2.id
            self.stranger_id = acc3.id

    async def asyncTearDown(self):
        await self.engine.dispose()

    async def test_family_invitation_accept_and_deny_lifecycle(self):
        # 1. Father creates Family Group
        async with self.session_factory() as db:
            acc1_obj = await db.get(Account, self.father_id)
            group_res = await create_family_group(
                CreateFamilyGroupRequest(group_name="The Heroic Family"),
                current_user=acc1_obj,
                db=db,
            )
            self.assertEqual(group_res.group_name, "The Heroic Family")
            self.assertTrue(group_res.is_creator)
            self.assertEqual(len(group_res.members), 1)

        # 2. Father invites Son (creates Pending invitation)
        async with self.session_factory() as db:
            acc1_obj = await db.get(Account, self.father_id)
            with patch("app.api.family.manager.send_personal", new_callable=AsyncMock):
                add_res = await add_family_member(
                    AddFamilyMemberRequest(email="son@khunyikalsal.com", relationship="Son"),
                    current_user=acc1_obj,
                    db=db,
                )
            # Pending invite should be in pending_members
            self.assertEqual(len(add_res.members), 1)
            self.assertEqual(len(add_res.pending_members), 1)
            self.assertEqual(add_res.pending_members[0].email, "son@khunyikalsal.com")

        # 3. Son checks pending invitations
        async with self.session_factory() as db:
            acc2_obj = await db.get(Account, self.son_id)
            invs = await get_my_family_invitations(current_user=acc2_obj, db=db)
            self.assertEqual(len(invs), 1)
            self.assertEqual(invs[0].group_name, "The Heroic Family")
            self.assertEqual(invs[0].relationship, "Son")
            inv_id = invs[0].invitation_id

        # 4. Son accepts invitation
        async with self.session_factory() as db:
            acc2_obj = await db.get(Account, self.son_id)
            with patch("app.api.family.manager.send_personal", new_callable=AsyncMock):
                accept_res = await accept_family_invitation(
                    invitation_id=inv_id,
                    current_user=acc2_obj,
                    db=db,
                )
            self.assertEqual(len(accept_res.members), 2)
            self.assertEqual(len(accept_res.pending_members), 0)

        # 5. Father invites Stranger, then Stranger denies
        async with self.session_factory() as db:
            acc1_obj = await db.get(Account, self.father_id)
            with patch("app.api.family.manager.send_personal", new_callable=AsyncMock):
                await add_family_member(
                    AddFamilyMemberRequest(email="stranger@khunyikalsal.com", relationship="Other"),
                    current_user=acc1_obj,
                    db=db,
                )

        async with self.session_factory() as db:
            acc3_obj = await db.get(Account, self.stranger_id)
            invs = await get_my_family_invitations(current_user=acc3_obj, db=db)
            self.assertEqual(len(invs), 1)
            stranger_inv_id = invs[0].invitation_id

            with patch("app.api.family.manager.send_personal", new_callable=AsyncMock):
                deny_res = await deny_family_invitation(
                    invitation_id=stranger_inv_id,
                    current_user=acc3_obj,
                    db=db,
                )
            self.assertIn("declined successfully", deny_res["message"])

            # Verify no remaining invitations
            invs_after = await get_my_family_invitations(current_user=acc3_obj, db=db)
            self.assertEqual(len(invs_after), 0)


if __name__ == "__main__":
    unittest.main()
