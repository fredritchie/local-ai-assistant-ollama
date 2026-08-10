from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


def run_script(script_name: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["DUCKDNS_TOKEN"] = "test-token"
    return subprocess.run(
        [str(REPOSITORY_ROOT / "scripts" / script_name), *arguments],
        capture_output=True,
        check=False,
        env=environment,
        text=True,
    )


def test_update_rejects_invalid_ipv4_before_network_request() -> None:
    result = run_script("update_duckdns.sh", "valid-name", "999.1.1.1")

    assert result.returncode == 2
    assert "must be an IPv4 address" in result.stderr


def test_certificate_script_rejects_invalid_subdomain_before_tool_checks() -> None:
    result = run_script(
        "issue_letsencrypt_duckdns.sh",
        "operator@example.com",
        "Invalid_Name",
    )

    assert result.returncode == 2
    assert "lowercase DuckDNS label" in result.stderr
