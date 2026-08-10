from __future__ import annotations

import os
import subprocess
import sys
from unittest.mock import patch

import bcrypt

from auth import bootstrap_admin, verify_credentials

DEFAULT_ADMIN_HASH = "$2b$12$nvfStXs4ON327eP6n6vR9OxG8IUFYEMLLIHzxp/9Mi9GaBHFN2CcK"


def test_verify_credentials_accepts_default_admin() -> None:
    with patch(
        "auth.get_user",
        return_value={"password_hash": DEFAULT_ADMIN_HASH},
    ):
        assert verify_credentials("admin", "changeme") is True


def test_verify_credentials_rejects_wrong_password() -> None:
    with patch(
        "auth.get_user",
        return_value={"password_hash": DEFAULT_ADMIN_HASH},
    ):
        assert verify_credentials("admin", "wrong-password") is False


def test_verify_credentials_rejects_wrong_username() -> None:
    with patch("auth.get_user", return_value=None):
        assert verify_credentials("other-user", "changeme") is False


def test_bootstrap_admin_creates_the_configured_administrator() -> None:
    with patch("auth.create_admin") as create_admin:
        bootstrap_admin()

    create_admin.assert_called_once()


def test_auth_configuration_from_environment() -> None:
    custom_hash = bcrypt.hashpw(b"secret", bcrypt.gensalt()).decode()
    environment = os.environ.copy()
    environment.update(
        {
            "ADMIN_USERNAME": "ops",
            "ADMIN_PASSWORD_HASH": custom_hash,
            "AUTH_ENABLED": "false",
        }
    )

    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import config; "
                "print(config.ADMIN_USERNAME); "
                "print(config.ADMIN_PASSWORD_HASH); "
                "print(config.AUTH_ENABLED)"
            ),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
    )

    assert result.stdout.splitlines() == ["ops", custom_hash, "False"]
