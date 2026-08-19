"""
Unit test for verifying Blood Donation and Blood Request cancellation by user.
"""

import sys
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch
import uuid
from datetime import datetime, timezone

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.api.blood_donation import update_blood_donation_status
from app.models.account import Account, RoleEnum
from app.models.blood_donation import BloodDonation
from app.schemas.blood_donation import BloodDonationStatusUpdate


class TestBloodDonationCancellation(unittest.IsolatedAsyncioTestCase):

    async def test_user_cancel_own_blood_request_success(self):
        user_id = uuid.uuid4()
        donation_id = uuid.uuid4()

        mock_user = MagicMock(spec=Account)
        mock_user.id = user_id
        mock_user.role = RoleEnum.USER

        mock_donation = MagicMock(spec=BloodDonation)
        mock_donation.id = donation_id
        mock_donation.user_id = user_id
        mock_donation.request_type = "request"
        mock_donation.status = "Pending"
        mock_donation.accepted_org_id = None
        mock_donation.target_org_id = None
        mock_donation.patient_name = "Ko Min"
        mock_donation.hospital_name = "Yangon General Hospital"
        mock_donation.donor_name = "Ko Min"
        mock_donation.get_decrypted_phone.return_value = "09123456789"
        mock_donation.blood_type = "O+"
        mock_donation.age = 28
        mock_donation.gender = "Male"
        mock_donation.medical_notes = None
        mock_donation.target_location_name = None
        mock_donation.target_lat = None
        mock_donation.target_lng = None
        mock_donation.preferred_date = None
        mock_donation.appointment_date = None
        mock_donation.appointment_location = None
        mock_donation.appointment_notes = None
        mock_donation.pickup_location_message = None
        mock_donation.notes = None
        mock_donation.created_at = datetime.now(timezone.utc)
        mock_donation.updated_at = None
        mock_donation.units = 2
        mock_donation.urgency_level = "Emergency"
        mock_donation.target_org = None
        mock_donation.accepted_org = None

        mock_db = AsyncMock()

        async def mock_execute(stmt):
            mock_res = MagicMock()
            mock_res.scalar_one_or_none.return_value = mock_donation
            return mock_res

        mock_db.execute = AsyncMock(side_effect=mock_execute)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        status_update = BloodDonationStatusUpdate(status="Cancelled")

        with patch("app.api.blood_donation.manager.broadcast_all", new_callable=AsyncMock) as mock_broadcast:
            response = await update_blood_donation_status(
                donation_id=str(donation_id),
                data=status_update,
                current_user=mock_user,
                db=mock_db,
            )

        self.assertEqual(mock_donation.status, "Cancelled")
        mock_db.commit.assert_awaited_once()
        mock_broadcast.assert_awaited_once()

    async def test_unauthorized_user_cannot_cancel_others_request(self):
        owner_id = uuid.uuid4()
        other_user_id = uuid.uuid4()
        donation_id = uuid.uuid4()

        other_user = MagicMock(spec=Account)
        other_user.id = other_user_id
        other_user.role = RoleEnum.USER

        mock_donation = MagicMock(spec=BloodDonation)
        mock_donation.id = donation_id
        mock_donation.user_id = owner_id
        mock_donation.status = "Pending"

        mock_db = AsyncMock()
        async def mock_execute(stmt):
            mock_res = MagicMock()
            mock_res.scalar_one_or_none.return_value = mock_donation
            return mock_res

        mock_db.execute = AsyncMock(side_effect=mock_execute)

        status_update = BloodDonationStatusUpdate(status="Cancelled")

        from fastapi import HTTPException
        with self.assertRaises(HTTPException) as ctx:
            await update_blood_donation_status(
                donation_id=str(donation_id),
                data=status_update,
                current_user=other_user,
                db=mock_db,
            )

        self.assertEqual(ctx.exception.status_code, 403)

    async def test_user_cannot_cancel_when_org_has_accepted(self):
        user_id = uuid.uuid4()
        donation_id = uuid.uuid4()

        mock_user = MagicMock(spec=Account)
        mock_user.id = user_id
        mock_user.role = RoleEnum.USER

        mock_donation = MagicMock(spec=BloodDonation)
        mock_donation.id = donation_id
        mock_donation.user_id = user_id
        mock_donation.status = "Accepted"  # Already accepted by an organization

        mock_db = AsyncMock()
        async def mock_execute(stmt):
            mock_res = MagicMock()
            mock_res.scalar_one_or_none.return_value = mock_donation
            return mock_res

        mock_db.execute = AsyncMock(side_effect=mock_execute)

        status_update = BloodDonationStatusUpdate(status="Cancelled")

        from fastapi import HTTPException
        with self.assertRaises(HTTPException) as ctx:
            await update_blood_donation_status(
                donation_id=str(donation_id),
                data=status_update,
                current_user=mock_user,
                db=mock_db,
            )

        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("already accepted", ctx.exception.detail)


if __name__ == "__main__":
    unittest.main()
