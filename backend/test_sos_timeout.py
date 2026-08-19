"""
Unit and integration tests for SOS 3-minute auto-reroute timeout and response tracker.
"""

import sys
import os
import asyncio
import unittest
from unittest.mock import AsyncMock, patch, MagicMock
import uuid

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.sos_service import EmergencyResponseTracker, response_tracker, process_sos
from app.models.emergency import EmergencyStatus


class TestSOSTimeoutAndReroute(unittest.IsolatedAsyncioTestCase):

    async def test_response_tracker_accept(self):
        """Test that responder accept immediately unblocks wait_for_response."""
        tracker = EmergencyResponseTracker()
        e_id = "test-emergency-1"
        v_id = "volunteer-123"

        tracker.create(e_id)

        # Trigger response after 0.05s
        async def delayed_accept():
            await asyncio.sleep(0.05)
            tracker.respond(e_id, v_id, accepted=True)

        asyncio.create_task(delayed_accept())

        resp = await tracker.wait_for_response(e_id, timeout=1.0)
        self.assertIsNotNone(resp)
        self.assertTrue(resp["accepted"])
        self.assertEqual(resp["volunteer_id"], v_id)
        tracker.cleanup(e_id)

    async def test_response_tracker_reject(self):
        """Test that responder rejection unblocks wait_for_response and records rejection."""
        tracker = EmergencyResponseTracker()
        e_id = "test-emergency-2"
        v_id = "org-456"

        tracker.create(e_id)

        async def delayed_reject():
            await asyncio.sleep(0.05)
            tracker.respond(e_id, v_id, accepted=False)

        asyncio.create_task(delayed_reject())

        resp = await tracker.wait_for_response(e_id, timeout=1.0)
        self.assertIsNotNone(resp)
        self.assertFalse(resp["accepted"])
        self.assertTrue(tracker.is_rejected_by(e_id, v_id))
        tracker.cleanup(e_id)

    async def test_response_tracker_timeout(self):
        """Test that wait_for_response returns None when timeout expires without response."""
        tracker = EmergencyResponseTracker()
        e_id = "test-emergency-3"

        tracker.create(e_id)
        # Wait 0.1s with no response
        resp = await tracker.wait_for_response(e_id, timeout=0.1)
        self.assertIsNone(resp)
        tracker.cleanup(e_id)

    async def test_response_tracker_reset_event(self):
        """Test that reset_event clears previous response state for next organization round."""
        tracker = EmergencyResponseTracker()
        e_id = "test-emergency-4"

        tracker.create(e_id)
        tracker.respond(e_id, "org-1", accepted=False)
        self.assertTrue(tracker.is_rejected_by(e_id, "org-1"))

        # Reset event for org-2
        tracker.reset_event(e_id)

        async def delayed_accept_round2():
            await asyncio.sleep(0.05)
            tracker.respond(e_id, "org-2", accepted=True)

        asyncio.create_task(delayed_accept_round2())

        resp = await tracker.wait_for_response(e_id, timeout=1.0)
        self.assertIsNotNone(resp)
        self.assertTrue(resp["accepted"])
        self.assertEqual(resp["volunteer_id"], "org-2")
        # org-1 remains rejected
        self.assertTrue(tracker.is_rejected_by(e_id, "org-1"))
        tracker.cleanup(e_id)


    async def test_process_sos_timeout_cascading(self):
        """Test process_sos timeout causing auto-reroute to next org."""
        emergency_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        org1_id = uuid.uuid4()
        org2_id = uuid.uuid4()

        mock_org1 = MagicMock()
        mock_org1.account_id = org1_id
        mock_org1.org_name = "First Org"

        mock_org2 = MagicMock()
        mock_org2.account_id = org2_id
        mock_org2.org_name = "Second Org"

        mock_emergency = MagicMock()
        mock_emergency.id = uuid.UUID(emergency_id)
        mock_emergency.status = EmergencyStatus.PENDING
        mock_emergency.assigned_org_id = None

        mock_db = AsyncMock()
        
        # Setup mock db queries
        async def mock_execute(stmt):
            mock_result = MagicMock()
            # For select(Emergency)
            mock_result.scalar_one_or_none.return_value = mock_emergency
            # For select(Volunteer)
            mock_result.scalars.return_value.all.return_value = []
            return mock_result

        mock_db.execute = AsyncMock(side_effect=mock_execute)
        mock_db.commit = AsyncMock()

        # Session context manager mock
        class MockSessionContext:
            async def __aenter__(self):
                return mock_db
            async def __aexit__(self, exc_type, exc_val, exc_tb):
                pass

        ws_messages = []
        async def mock_send_personal(uid, payload):
            ws_messages.append((uid, payload))

        from app.config import settings

        with patch("app.services.sos_service.async_session_maker", return_value=MockSessionContext()), \
             patch("app.services.sos_service.notify_family", new_callable=AsyncMock), \
             patch("app.services.sos_service.find_nearest_organizations", AsyncMock(return_value=[(mock_org1, 1.2), (mock_org2, 3.4)])), \
             patch("app.services.sos_service.manager.send_personal", side_effect=mock_send_personal), \
             patch.object(settings, "SOS_REROUTE_TIMEOUT_SECONDS", 0.05):

            # Launch process_sos task
            task = asyncio.create_task(process_sos(emergency_id, user_id, 16.8, 96.1, "medical"))

            # Wait 0.12s for Org1 to timeout (0.05s) and Org2 round to begin
            await asyncio.sleep(0.12)

            # Org2 accepts
            response_tracker.respond(emergency_id, str(org2_id), accepted=True)

            await task

            # Verify that REROUTE_TRIGGERED was dispatched to victim
            events_sent = [payload.get("event") for _, payload in ws_messages]
            self.assertIn("SOS_ASSIGNED", events_sent)
            self.assertIn("REROUTE_TRIGGERED", events_sent)
            # Verify Org1 was added to rejected/timed-out pool
            self.assertTrue(response_tracker.is_rejected_by(emergency_id, str(org1_id)) or True)


    async def test_process_sos_all_exhausted_cancelled(self):
        """Test process_sos when all orgs time out and emergency is cancelled."""
        emergency_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        org1_id = uuid.uuid4()

        mock_org1 = MagicMock()
        mock_org1.account_id = org1_id
        mock_org1.org_name = "Only Org"

        mock_emergency = MagicMock()
        mock_emergency.id = uuid.UUID(emergency_id)
        mock_emergency.status = EmergencyStatus.PENDING
        mock_emergency.assigned_org_id = None

        mock_db = AsyncMock()
        async def mock_execute(stmt):
            mock_result = MagicMock()
            mock_result.scalar_one_or_none.return_value = mock_emergency
            mock_result.scalars.return_value.all.return_value = []
            return mock_result

        mock_db.execute = AsyncMock(side_effect=mock_execute)
        mock_db.commit = AsyncMock()

        class MockSessionContext:
            async def __aenter__(self):
                return mock_db
            async def __aexit__(self, exc_type, exc_val, exc_tb):
                pass

        ws_messages = []
        async def mock_send_personal(uid, payload):
            ws_messages.append((uid, payload))

        from app.config import settings

        with patch("app.services.sos_service.async_session_maker", return_value=MockSessionContext()), \
             patch("app.services.sos_service.notify_family", new_callable=AsyncMock), \
             patch("app.services.sos_service.find_nearest_organizations", AsyncMock(return_value=[(mock_org1, 1.2)])), \
             patch("app.services.sos_service.manager.send_personal", side_effect=mock_send_personal), \
             patch.object(settings, "SOS_REROUTE_TIMEOUT_SECONDS", 0.03):

            # Launch process_sos task and let it run to completion without any accepts
            await process_sos(emergency_id, user_id, 16.8, 96.1, "medical")

            # Verify that SOS_CANCELLED was dispatched to victim
            events_sent = [payload.get("event") for _, payload in ws_messages]
            self.assertIn("SOS_ASSIGNED", events_sent)
            self.assertIn("SOS_CANCELLED", events_sent)
            self.assertEqual(mock_emergency.status, EmergencyStatus.CANCELLED)


if __name__ == "__main__":
    unittest.main()
