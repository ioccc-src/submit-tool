"""Regression tests for account eligibility when restoring browser sessions."""

import datetime
import importlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class SessionLoginTests(unittest.TestCase):
    """Use in-memory accounts and an isolated application directory."""

    @classmethod
    def setUpClass(cls):
        # pylint: disable-next=consider-using-with
        cls.directory = cls.enterClassContext(tempfile.TemporaryDirectory())
        root = Path(cls.directory)
        (root / "etc").mkdir()
        (root / "etc" / ".secret").write_text("test-only-secret-" * 8, encoding="utf-8")
        with patch.dict(os.environ, {"IOCCC_BASE_DIR": str(root)}), \
                patch("socket.create_connection", side_effect=OSError("test: no network")):
            cls.web = importlib.import_module("iocccsubmit.ioccc")
        cls.web.application.config["TESTING"] = True
        cls.web.limiter.enabled = False

    def setUp(self):
        self.account = {
            "username": "12345678-1234-4321-abcd-1234567890ab",
            "no_comment": self.web.ioccc_common.NO_COMMENT_VALUE,
            "iocccpasswd_format_version": self.web.ioccc_common.PASSWORD_VERSION_VALUE,
            "pwhash": "test-only-hash",
            "ignore_date": False,
            "force_pw_change": False,
            "pw_change_by": None,
            "email": "session-test@example.org",
            "disable_login": False,
        }
        lookup = patch.object(self.web, "lookup_username", return_value=self.account)
        self.lookup = lookup.start()
        self.addCleanup(lookup.stop)

    def deadline(self, days):
        """Return a deadline in the application's timestamp format."""
        return (datetime.datetime.now(datetime.timezone.utc)
                + datetime.timedelta(days=days)).strftime(
                    self.web.ioccc_common.DATETIME_USEC_FORMAT)

    def test_eligible_accounts_are_restored(self):
        """Allow ordinary accounts and required changes still within grace."""
        for force_change in (False, True):
            with self.subTest(force_change=force_change):
                self.account["force_pw_change"] = force_change
                self.account["pw_change_by"] = self.deadline(1) if force_change else None
                user = self.web.user_loader(self.account["username"])
                self.assertIsNotNone(user)
                self.assertEqual(user.id, self.account["username"])

    def test_deleted_account_is_not_restored(self):
        """A session cannot restore a deleted account."""
        self.lookup.return_value = None
        self.assertIsNone(self.web.user_loader(self.account["username"]))

    def test_ineligible_account_is_not_restored(self):
        """Reject disabled, expired, and malformed accounts."""
        for change in (
                {"disable_login": True},
                {"force_pw_change": True, "pw_change_by": self.deadline(-1)},
                {"force_pw_change": True, "pw_change_by": "invalid deadline"},
        ):
            with self.subTest(change=change):
                self.lookup.return_value = dict(self.account, **change)
                self.assertIsNone(self.web.user_loader(self.account["username"]))

    def test_existing_session_loses_access(self):
        """Recheck eligibility on the next request, before slot access."""
        for reason in ("disabled", "expired", "deleted"):
            with self.subTest(reason=reason):
                self.lookup.return_value = dict(self.account)
                client = self.web.application.test_client()
                with client.session_transaction() as session:
                    session["_user_id"] = self.account["username"]
                    session["_fresh"] = True
                with patch.object(self.web, "get_all_json_slots", return_value=[{}]) as slots, \
                        patch.object(self.web, "render_template", return_value="password form"):
                    response = client.get("/passwd")
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(response.data, b"password form")
                    slots.assert_called_once_with(self.account["username"])
                    slots.reset_mock()
                    if reason == "disabled":
                        self.lookup.return_value["disable_login"] = True
                    elif reason == "expired":
                        self.lookup.return_value.update(
                            force_pw_change=True, pw_change_by=self.deadline(-1))
                    else:
                        self.lookup.return_value = None
                    for method, path, status in (("GET", "/submit", 401),
                                                 ("POST", "/update", 401),
                                                 ("GET", "/passwd", 302)):
                        response = client.open(path, method=method)
                        self.assertEqual(response.status_code, status)
                        slots.assert_not_called()


if __name__ == "__main__":
    unittest.main()
