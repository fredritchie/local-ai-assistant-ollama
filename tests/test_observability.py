from __future__ import annotations

import json
import logging

from observability import JsonFormatter


def test_json_formatter_emits_structured_log() -> None:
    record = logging.LogRecord(
        name="test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="request completed",
        args=(),
        exc_info=None,
    )
    record.request_id = "request-123"

    payload = json.loads(JsonFormatter().format(record))

    assert payload["level"] == "INFO"
    assert payload["logger"] == "test"
    assert payload["message"] == "request completed"
    assert payload["request_id"] == "request-123"
    assert payload["timestamp"].endswith("+00:00")
