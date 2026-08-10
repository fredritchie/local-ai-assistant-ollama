from __future__ import annotations

import os
import urllib.request

import pytest

BASE_URL = os.getenv("INTEGRATION_BASE_URL", "").rstrip("/")
pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not BASE_URL,
        reason="Set INTEGRATION_BASE_URL to test a deployed environment.",
    ),
]


def test_application_health() -> None:
    with urllib.request.urlopen(f"{BASE_URL}/healthz", timeout=15) as response:
        assert response.status == 200


def test_application_page_is_served() -> None:
    with urllib.request.urlopen(f"{BASE_URL}/", timeout=15) as response:
        body = response.read().decode()
    assert "streamlit" in body.lower()
