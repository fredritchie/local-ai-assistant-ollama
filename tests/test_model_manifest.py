from __future__ import annotations

from scripts.lock_model_manifest import parse_model


def test_parse_model_preserves_versioned_name() -> None:
    model = parse_model("llama3.2:3b:2.0:4.0:true")

    assert model.name == "llama3.2:3b"
    assert model.size_gib == 2.0
    assert model.vram_gib == 4.0
    assert model.preload is True
