#!/usr/bin/env python3
"""Validate repository Markdown and architecture-diagram assets."""

from __future__ import annotations

import argparse
import concurrent.futures
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRECTORIES = {".git", ".terraform", ".venv", "__pycache__", "node_modules"}
LINK_PATTERN = re.compile(r"(!?)\[([^]]*)\]\(([^)]+)\)")
HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
FENCE_PATTERN = re.compile(r"^\s*(`{3,}|~{3,})")
NUMBERED_DIAGRAM_PATTERN = re.compile(r"^\d+[_. -]")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def markdown_files() -> list[Path]:
    return sorted(
        path
        for path in REPOSITORY_ROOT.rglob("*.md")
        if not any(part in IGNORED_DIRECTORIES for part in path.parts)
    )


def github_slug(value: str) -> str:
    value = re.sub(r"<[^>]+>", "", value)
    value = re.sub(r"[`*_~]", "", value).strip().lower()
    value = re.sub(r"[^\w\- ]", "", value, flags=re.UNICODE)
    return re.sub(r"[\s-]+", "-", value).strip("-")


def split_link_target(raw_target: str) -> str:
    target = raw_target.strip()
    if target.startswith("<"):
        closing = target.find(">")
        return target[1:closing] if closing != -1 else target[1:]
    return re.split(r"\s+[\"']", target, maxsplit=1)[0]


def headings_and_code_lines(
    lines: list[str],
) -> tuple[list[tuple[int, int, str]], set[int], bool]:
    headings: list[tuple[int, int, str]] = []
    code_lines: set[int] = set()
    fence_character = ""
    fence_length = 0

    for line_number, line in enumerate(lines, start=1):
        fence = FENCE_PATTERN.match(line)
        if fence:
            marker = fence.group(1)
            if not fence_character:
                fence_character = marker[0]
                fence_length = len(marker)
                code_lines.add(line_number)
                continue
            if marker[0] == fence_character and len(marker) >= fence_length:
                code_lines.add(line_number)
                fence_character = ""
                fence_length = 0
                continue
        if fence_character:
            code_lines.add(line_number)
            continue
        heading = HEADING_PATTERN.match(line)
        if heading:
            headings.append((line_number, len(heading.group(1)), heading.group(2)))

    return headings, code_lines, bool(fence_character)


def heading_anchors(headings: list[tuple[int, int, str]]) -> set[str]:
    counts: Counter[str] = Counter()
    anchors: set[str] = set()
    for _, _, heading in headings:
        base = github_slug(heading)
        suffix = counts[base]
        counts[base] += 1
        anchors.add(base if suffix == 0 else f"{base}-{suffix}")
    return anchors


def validate_local_target(
    markdown_file: Path,
    line_number: int,
    target: str,
    anchor_cache: dict[Path, set[str]],
) -> list[str]:
    errors: list[str] = []
    decoded = urllib.parse.unquote(target)
    path_text, separator, fragment = decoded.partition("#")
    reference = f"{markdown_file.relative_to(REPOSITORY_ROOT)}:{line_number}"
    target_path = (
        markdown_file if not path_text else (markdown_file.parent / path_text).resolve()
    )

    try:
        target_path.relative_to(REPOSITORY_ROOT)
    except ValueError:
        return [f"{reference}: link escapes repository: {target}"]

    if not target_path.exists():
        return [f"{reference}: missing link target: {target}"]

    if separator and fragment and target_path.suffix.lower() == ".md":
        if target_path not in anchor_cache:
            target_lines = target_path.read_text(encoding="utf-8").splitlines()
            target_headings, _, _ = headings_and_code_lines(target_lines)
            anchor_cache[target_path] = heading_anchors(target_headings)
        normalized_fragment = urllib.parse.unquote(fragment).lower()
        if normalized_fragment not in anchor_cache[target_path]:
            errors.append(
                f"{markdown_file.relative_to(REPOSITORY_ROOT)}:{line_number}: "
                f"missing heading anchor: {target}"
            )
    return errors


def validate_markdown(files: list[Path]) -> tuple[list[str], set[str]]:
    errors: list[str] = []
    external_links: set[str] = set()
    anchor_cache: dict[Path, set[str]] = {}

    for path in files:
        relative_path = path.relative_to(REPOSITORY_ROOT)
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        headings, code_lines, open_fence = headings_and_code_lines(lines)

        if text and not text.endswith("\n"):
            errors.append(f"{relative_path}: file must end with a newline")
        if open_fence:
            errors.append(f"{relative_path}: unclosed fenced code block")
        if sum(level == 1 for _, level, _ in headings) != 1:
            errors.append(f"{relative_path}: expected exactly one level-1 heading")
        first_content_line = next(
            (index for index, line in enumerate(lines, 1) if line.strip()), None
        )
        if not headings or headings[0][0] != first_content_line or headings[0][1] != 1:
            errors.append(f"{relative_path}: first content must be the level-1 heading")

        previous_level = 0
        for line_number, level, _ in headings:
            if previous_level and level > previous_level + 1:
                errors.append(
                    f"{relative_path}:{line_number}: heading level jumps from "
                    f"H{previous_level} to H{level}"
                )
            previous_level = level

        for line_number, line in enumerate(lines, start=1):
            if line_number not in code_lines and line.rstrip() != line:
                errors.append(f"{relative_path}:{line_number}: trailing whitespace")
            if line_number in code_lines:
                continue
            for match in LINK_PATTERN.finditer(line):
                is_image, label, raw_target = match.groups()
                target = split_link_target(raw_target)
                if is_image and not label.strip():
                    errors.append(
                        f"{relative_path}:{line_number}: image requires alt text"
                    )
                if not target:
                    errors.append(f"{relative_path}:{line_number}: empty link target")
                elif target.startswith(("http://", "https://")):
                    external_links.add(target)
                elif not target.startswith(("mailto:", "tel:")):
                    errors.extend(
                        validate_local_target(path, line_number, target, anchor_cache)
                    )

    return errors, external_links


def validate_diagrams() -> list[str]:
    errors: list[str] = []
    diagram_directory = REPOSITORY_ROOT / "docs" / "diagrams"
    source_directory = diagram_directory / "source"
    sources = {path.stem: path for path in source_directory.glob("*.drawio")}
    renders = {path.stem: path for path in diagram_directory.glob("*.png")}

    if not sources:
        errors.append("docs/diagrams/source: no Draw.io source files found")
    missing_renders = sorted(sources.keys() - renders.keys())
    orphaned_renders = sorted(renders.keys() - sources.keys())
    for name in missing_renders:
        errors.append(f"docs/diagrams/{name}.png: render is missing")
    for name in orphaned_renders:
        errors.append(f"docs/diagrams/{name}.png: no same-named Draw.io source")

    for name, source in sorted(sources.items()):
        relative_source = source.relative_to(REPOSITORY_ROOT)
        if NUMBERED_DIAGRAM_PATTERN.match(source.name):
            errors.append(f"{relative_source}: numbered filename is not allowed")
        try:
            root = ET.parse(source).getroot()
        except ET.ParseError as error:
            errors.append(f"{relative_source}: invalid XML: {error}")
            continue
        if root.tag != "mxfile":
            errors.append(f"{relative_source}: root element must be mxfile")
        title = next(
            (
                cell.get("value", "")
                for cell in root.iter()
                if cell.get("id") == "title"
            ),
            "",
        )
        if title and re.match(r"^\s*\d+[.) -]", title):
            errors.append(f"{relative_source}: numbered diagram title is not allowed")

    for name, render in sorted(renders.items()):
        relative_render = render.relative_to(REPOSITORY_ROOT)
        if NUMBERED_DIAGRAM_PATTERN.match(render.name):
            errors.append(f"{relative_render}: numbered filename is not allowed")
        if render.read_bytes()[:8] != PNG_SIGNATURE:
            errors.append(f"{relative_render}: invalid PNG signature")

    return errors


def check_external_link(url: str) -> str | None:
    headers = {"User-Agent": "local-ai-assistant-docs-check/1.0"}
    last_error = "unknown error"
    for attempt in range(2):
        try:
            request = urllib.request.Request(url, headers=headers, method="HEAD")
            with urllib.request.urlopen(request, timeout=20) as response:
                if response.status < 400:
                    return None
        except urllib.error.HTTPError as error:
            if error.code in {401, 403, 429}:
                return None
            if error.code == 405:
                try:
                    request = urllib.request.Request(url, headers=headers, method="GET")
                    with urllib.request.urlopen(request, timeout=20) as response:
                        if response.status < 400:
                            return None
                except (
                    urllib.error.HTTPError,
                    urllib.error.URLError,
                    TimeoutError,
                ) as get_error:
                    last_error = str(get_error)
            else:
                last_error = f"HTTP {error.code}"
                if error.code in {404, 410}:
                    break
        except (urllib.error.URLError, TimeoutError) as error:
            last_error = str(error)
        if attempt == 0:
            time.sleep(1)
    return f"{url}: {last_error}"


def validate_external_links(links: set[str]) -> list[str]:
    errors: list[str] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        results = executor.map(check_external_link, sorted(links))
    for result in results:
        if result:
            errors.append(f"external link failed: {result}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check-external",
        action="store_true",
        help="also verify HTTP and HTTPS links",
    )
    arguments = parser.parse_args()

    files = markdown_files()
    errors, external_links = validate_markdown(files)
    errors.extend(validate_diagrams())
    if arguments.check_external:
        errors.extend(validate_external_links(external_links))

    if errors:
        print("Documentation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    external_summary = (
        f" and {len(external_links)} external links" if arguments.check_external else ""
    )
    diagram_count = len(
        list((REPOSITORY_ROOT / "docs/diagrams/source").glob("*.drawio"))
    )
    print(
        f"Validated {len(files)} Markdown files, "
        f"{diagram_count} diagrams{external_summary}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
