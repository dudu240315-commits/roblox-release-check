#!/usr/bin/env python3
"""Build and verify a deterministic install ZIP for this skill."""
from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT.parent / f"{ROOT.name}.zip"
EXCLUDED_DIRS = {".git", "__pycache__", "dist"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo"}
REQUIRED = {
    "SKILL.md",
    "README.md",
    "agents/openai.yaml",
    "references/review-guide.md",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def package_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if any(part in EXCLUDED_DIRS for part in relative.parts):
            continue
        if path.is_symlink():
            fail(f"symbolic links are not packaged: {relative.as_posix()}")
        if path.is_file() and path.suffix.lower() not in EXCLUDED_SUFFIXES:
            files.append(path)
    files.sort(key=lambda item: item.relative_to(ROOT).as_posix())
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"destination ZIP (default: {DEFAULT_OUTPUT})",
    )
    args = parser.parse_args()

    output = args.output.expanduser().resolve()
    try:
        output_relative = output.relative_to(ROOT)
    except ValueError:
        output_relative = None
    if output_relative and (not output_relative.parts or output_relative.parts[0] != "dist"):
        fail("an output inside the package must be under dist/ so it cannot enter the archive")

    files = package_files()
    relative_files = {path.relative_to(ROOT).as_posix() for path in files}
    missing = REQUIRED - relative_files
    if missing:
        fail("missing required files: " + ", ".join(sorted(missing)))

    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            info = zipfile.ZipInfo(f"{ROOT.name}/{relative}", date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())

    expected_names = {f"{ROOT.name}/{relative}" for relative in relative_files}
    with zipfile.ZipFile(output, "r") as archive:
        names = set(archive.namelist())
        if names != expected_names:
            fail("archive contents do not match the package files")
        if any("__pycache__" in PurePosixPath(name).parts or name.endswith((".pyc", ".pyo")) for name in names):
            fail("archive contains generated Python cache files")
        bad_entry = archive.testzip()
        if bad_entry is not None:
            fail(f"CRC check failed for {bad_entry}")

    print(f"PASS: {output} ({len(expected_names)} files, top-level {ROOT.name}/, CRC OK)")


if __name__ == "__main__":
    main()

