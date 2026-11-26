#!/usr/bin/env python3
"""Dependency-free packaging checks; does not run Luau or certify skill behavior."""
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "SKILL.md",
    "README.md",
    "VALIDATION.md",
    "CONTRIBUTING.md",
    "PUBLISHING.md",
    "SECURITY.md",
    ".gitignore",
    ".github/workflows/validate.yml",
    "agents/openai.yaml",
    "references/review-guide.md",
    "tests/security-server.luau",
    "tests/security-client.luau",
    "tests/studio-regression.luau",
    "tests/failure-regression.luau",
    "tests/receipt-regression.luau",
    "tests/MUTATIONS.md",
)


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


for relative in REQUIRED:
    if not (ROOT / relative).is_file():
        fail(f"missing required package file: {relative}")

for path in ROOT.rglob("*"):
    if path.is_dir() and path.name == "__pycache__":
        fail(f"generated Python cache directory must not be packaged: {path.relative_to(ROOT)}")
    if path.is_file() and (path.suffix in {".pyc", ".pyo"}):
        fail(f"generated Python bytecode must not be packaged: {path.relative_to(ROOT)}")

skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
match = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n", skill, re.S)
if not match:
    fail("SKILL.md is missing frontmatter delimiters")
# These lightweight checks catch common packaging mistakes; this script does
# not parse or validate the full YAML specification.
frontmatter = match.group(1)
name = re.search(r"(?m)^name:\s*([a-z0-9-]+)\s*$", frontmatter)
description = re.search(r"(?m)^description:\s*(\S.*)$", frontmatter)
if not name or name.group(1) != ROOT.name:
    fail("frontmatter name must match the skill folder name")
if not description:
    fail("frontmatter description must be non-empty")
if len(description.group(1)) > 1024:
    fail("frontmatter description exceeds 1024 characters")

metadata = (ROOT / "agents/openai.yaml").read_text(encoding="utf-8")
for key in ("display_name", "short_description", "default_prompt"):
    if not re.search(rf"(?m)^\s*{key}:\s*\"[^\"]+\"\s*$", metadata):
        fail(f"agents/openai.yaml is missing a quoted {key}")
if "$roblox-release-check" not in metadata:
    fail("default_prompt must invoke $roblox-release-check")

for path in ROOT.rglob("*.md"):
    if any(part in {".git", ".github"} for part in path.parts):
        continue
    content = path.read_text(encoding="utf-8")
    if re.search(r"(?m)^\s*\[TODO:[^\]]*\]\s*$", content):
        fail(f"unfinished TODO placeholder in {path.relative_to(ROOT)}")
    for target in re.findall(r"!?(?:\[[^\]]*\])\(([^)]+)\)", content):
        target = target.strip().split()[0] if target.strip() else ""
        if not target or target.startswith(("https://", "http://", "mailto:", "#")):
            continue
        local = unquote(target.split("#", 1)[0])
        if not local:
            continue
        resolved = (path.parent / local).resolve()
        if ROOT.resolve() not in resolved.parents and resolved != ROOT.resolve():
            fail(f"link escapes package in {path.relative_to(ROOT)}: {target}")
        if not resolved.exists():
            fail(f"broken local link in {path.relative_to(ROOT)}: {target}")

print(f"PASS: package structure, metadata, placeholders, and local links ({len(REQUIRED)} required files)")
print("NOTE: this check does not run Luau/Studio tests or assess security-review accuracy")
if not (ROOT / "LICENSE").exists():
    print("ACTION: choose a license and add LICENSE before inviting reuse")
