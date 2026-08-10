#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import urllib.request
from dataclasses import dataclass


@dataclass(frozen=True)
class RequestedModel:
    name: str
    size_gib: float
    vram_gib: float
    preload: bool


def parse_model(value: str) -> RequestedModel:
    try:
        name, size, vram, preload = value.rsplit(":", 3)
        return RequestedModel(
            name=name,
            size_gib=float(size),
            vram_gib=float(vram),
            preload=preload.lower() in {"1", "true", "yes"},
        )
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "Use NAME:TAG:SIZE_GIB:VRAM_GIB:PRELOAD"
        ) from exc


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a digest-locked manifest from an Ollama server."
    )
    parser.add_argument("--ollama-url", default="http://127.0.0.1:11434")
    parser.add_argument("--model", action="append", type=parse_model, required=True)
    args = parser.parse_args()

    tags_url = f"{args.ollama_url.rstrip('/')}/api/tags"
    with urllib.request.urlopen(tags_url, timeout=10) as response:
        installed = {
            model["name"]: model for model in json.load(response).get("models", [])
        }

    manifest = []
    for requested in args.model:
        model = installed.get(requested.name)
        if model is None:
            parser.error(f"{requested.name} is not installed on the Ollama server")
        digest = model["digest"]
        manifest.append(
            {
                "name": requested.name,
                "digest": f"sha256:{digest.removeprefix('sha256:')}",
                "preload": requested.preload,
                "size_gib": requested.size_gib,
                "vram_gib": requested.vram_gib,
            }
        )

    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
