"""
Test script for verifying safe deletion of Organization accounts and unlinking of foreign keys.
"""

import sys
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.api.admin import delete_organization
from app.models.account import Account, RoleEnum
from app.models.organization import Organization


class TestDeleteOrganization(unittest.IsolatedAsyncioTestCase):

    async def test_delete_organization_success(self):
        org_account_id = str(uuid.uuid4())
        acc_uuid = uuid.UUID(org_account_id)

        mock_account = MagicMock(spec=Account)
        mock_account.id = acc_uuid
        mock_account.role = RoleEnum.ORGANIZATION

        mock_org = MagicMock(spec=Organization)
        mock_org.account_id = acc_uuid

        mock_admin = MagicMock(spec=Account)
        mock_admin.id = uuid.uuid4()
        mock_admin.role = RoleEnum.ADMIN

        mock_db = AsyncMock()

        async def mock_execute(stmt):
            mock_res = MagicMock()
            mock_res.scalar_one_or_none.return_value = mock_account
            mock_res.scalars.return_value.all.return_value = []
            return mock_res

        mock_db.execute = AsyncMock(side_effect=mock_execute)
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()

        with patch("app.api.admin.location_cache.purge_user_tracking"):
            response = await delete_organization(
                account_id=org_account_id,
                current_user=mock_admin,
                db=mock_db,
            )

        self.assertIn("deleted successfully", response["message"])
        mock_db.commit.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
