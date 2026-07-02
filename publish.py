#!/usr/bin/env python3
"""
Automated publish pipeline for بوابة الجحيم (Gateway to Hell).

Steps:
  1. Lint all Luau source files (selene + luau-analyze)
  2. Build: generate GatewayToHell.rbxlx from src/ via build_all.py
  3. Validate XML structure
  4. Strip XML declaration if present
  5. Upload to Roblox Open Cloud API

Requires:
  - Environment variable ROBLOX_PUBLISH_API_KEY
  - selene on PATH
  - luau-analyze on PATH (optional, skipped if missing)

Important:
  - Set UNIVERSE_ID and PLACE_ID below before publishing for real.
  - They are intentionally left as REPLACE_ME until the user provides IDs.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

# --- Configuration ---
UNIVERSE_ID = "3795513409"     # Gateway to Hell experience (Lovzutt).
PLACE_ID = "10405945147"       # Start place of the experience.
RBXLX_FILE = "GatewayToHell.rbxlx"
SRC_DIR = "src"
API_URL = f"https://apis.roblox.com/universes/v1/{UNIVERSE_ID}/places/{PLACE_ID}/versions?versionType=Published"


def run(cmd, capture=True):
    result = subprocess.run(cmd, capture_output=capture, text=True)
    return result.returncode, result.stdout, result.stderr


def lint():
    print("\n=== STEP 1: Linting Luau sources ===")

    lua_files = sorted(
        os.path.join(SRC_DIR, filename)
        for filename in os.listdir(SRC_DIR)
        if filename.endswith(".lua")
    )
    if not lua_files:
        sys.exit("ERROR: No .lua files found in src/")

    print(f"Found {len(lua_files)} Lua files")

    errors = 0

    selene_path = subprocess.run(["which", "selene"], capture_output=True, text=True).stdout.strip()
    if selene_path:
        print(f"\nRunning selene ({selene_path})...")
        _, out, err = run(["selene", "--display-style=quiet"] + lua_files)
        lines = [line for line in (out + err).splitlines() if line.strip()]
        actual_errors = [line for line in lines if ": error[" in line]
        warnings = [line for line in lines if ": warning[" in line]
        if actual_errors:
            print(f"  selene: {len(actual_errors)} ERROR(s):")
            for line in actual_errors:
                print(f"    {line}")
            errors += len(actual_errors)
        else:
            print(f"  selene: 0 errors, {len(warnings)} warnings (non-blocking)")
    else:
        print("WARNING: selene not found on PATH, skipping")

    luau_path = subprocess.run(["which", "luau-analyze"], capture_output=True, text=True).stdout.strip()
    if luau_path:
        print(f"\nRunning luau-analyze ({luau_path})...")
        _, out, err = run(["luau-analyze"] + lua_files)
        lines = [line for line in (out + err).splitlines() if line.strip()]
        actual_errors = [
            line
            for line in lines
            if ": Error" in line
            and "Unknown global" not in line
            and "Unknown type" not in line
            and "is not a valid member" not in line
        ]
        warnings = [line for line in lines if ": Warning" in line]
        if actual_errors:
            print(f"  luau-analyze: {len(actual_errors)} ERROR(s):")
            for line in actual_errors[:20]:
                print(f"    {line}")
            errors += len(actual_errors)
        else:
            print(f"  luau-analyze: 0 errors, {len(warnings)} warnings (non-blocking)")
    else:
        print("WARNING: luau-analyze not found on PATH, skipping")

    if errors > 0:
        print(f"\nLINT FAILED: {errors} error(s) found. Fix them before publishing.")
        sys.exit(1)

    print("\nLint passed! All files are clean.")


def build():
    print("\n=== STEP 2: Building (generating GatewayToHell.rbxlx) ===")
    code, out, err = run([sys.executable, "build_all.py"])
    if code != 0:
        print(f"BUILD FAILED:\n{out}\n{err}")
        sys.exit(1)
    print(out.strip())
    print("Build complete.")


def validate_xml():
    print("\n=== STEP 3: Validating XML ===")
    try:
        ET.parse(RBXLX_FILE)
        print(f"  {RBXLX_FILE} is valid XML")
    except ET.ParseError as exc:
        print(f"XML VALIDATION FAILED: {exc}")
        sys.exit(1)


def strip_xml_declaration():
    print("\n=== STEP 4: Stripping XML declaration ===")
    with open(RBXLX_FILE, "r", encoding="utf-8") as handle:
        content = handle.read()

    if content.startswith("<?xml"):
        newline_index = content.index("\n")
        content = content[newline_index + 1 :]
        with open(RBXLX_FILE, "w", encoding="utf-8") as handle:
            handle.write(content)
        print("  Removed XML declaration")
    else:
        print("  No XML declaration found (already clean)")


def publish():
    print("\n=== STEP 5: Publishing to Roblox ===")

    if UNIVERSE_ID == "REPLACE_ME" or PLACE_ID == "REPLACE_ME":
        sys.exit("ERROR: Set UNIVERSE_ID and PLACE_ID in publish.py before publishing.")

    api_key = os.environ.get("ROBLOX_PUBLISH_API_KEY")
    if not api_key:
        sys.exit("ERROR: ROBLOX_PUBLISH_API_KEY environment variable not set")

    file_size = os.path.getsize(RBXLX_FILE)
    print(f"  Uploading {RBXLX_FILE} ({file_size:,} bytes)...")
    print(f"  Universe: {UNIVERSE_ID} | Place: {PLACE_ID}")

    with open(RBXLX_FILE, "rb") as handle:
        data = handle.read()

    request = urllib.request.Request(
        API_URL,
        data=data,
        method="POST",
        headers={
            "x-api-key": api_key,
            "Content-Type": "application/octet-stream",
            "Content-Length": str(len(data)),
        },
    )

    try:
        with urllib.request.urlopen(request) as response:
            body = json.loads(response.read().decode())
            version = body.get("versionNumber", "?")
            print(f"\n  Published successfully! Version: {version}")
            return version
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode()
        print(f"\n  PUBLISH FAILED (HTTP {exc.code}): {error_body}")
        sys.exit(1)


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    skip_lint = "--skip-lint" in sys.argv
    lint_only = "--lint-only" in sys.argv

    if not skip_lint:
        lint()

    if lint_only:
        print("\n--lint-only: stopping after lint.")
        return

    build()
    validate_xml()
    strip_xml_declaration()
    publish()
    print("\n=== Pipeline complete! ===")


if __name__ == "__main__":
    main()
