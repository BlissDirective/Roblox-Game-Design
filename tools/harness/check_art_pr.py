#!/usr/bin/env python3
"""Guard for `art/*` branches: only allowlisted files, only id/template edits.

Run by .github/workflows/harness-guard.yml on every PR whose head branch
starts with `art/`. A bot that is confused, compromised, or prompt-injected
cannot reach gameplay, security, monetization, persistence, Remotes, or the
workflows themselves — the diff is rejected before a human ever looks at it.

    python3 tools/harness/check_art_pr.py --base origin/main [--head HEAD]

Rules:
  * Free files (any change):      assets/**, harness/design_manifest.json,
                                  tools/asset-import/upload-manifest.json
  * Row-append files:             docs/playbooks/ASSETS.md — only added lines,
                                  each must be a markdown table row.
  * Fields-only files:            src/shared/AssetIds.luau, the Registry
                                  modules, src/shared/Constants.luau — every
                                  changed line must match a FIELD pattern
                                  (asset ids, template refs). No new
                                  functions, no new Remotes, no logic.
  * Everything else:              hard fail.
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import subprocess
import sys

FREE = [
    "assets/**",
    "harness/design_manifest.json",
    "tools/asset-import/upload-manifest.json",
]
ROW_APPEND = ["docs/playbooks/ASSETS.md"]
FIELDS_ONLY = [
    "src/shared/AssetIds.luau",
    "src/shared/Modules/Registry/AlienRegistry.luau",
    "src/shared/Modules/Registry/BuildableRegistry.luau",
    "src/shared/Modules/Registry/CosmeticRegistry.luau",
    "src/shared/Modules/Registry/DroneSwarmRegistry.luau",
    "src/shared/Modules/Registry/AudioRegistry.luau",
    "src/shared/Constants.luau",
]

# A changed line in a fields-only file must match one of these.
FIELD_PATTERNS = [
    re.compile(r"^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*(PLACEHOLDER|\"rbxassetid://\d+\")\s*,?\s*(--.*)?$"),  # AssetIds entries
    re.compile(r"^\s*(iconAssetId|assetId|textureAssetId|decalAssetId|ambientSfxAssetId|skyboxAssetId|particleTextureAssetId|meshAssetId|modelAssetId|beamTextureAssetId)\s*=\s*\d+\s*,?\s*(--.*)?$"),
    re.compile(r"^\s*(meshTemplate|floraTemplate|modelTemplate|template|model)\s*=\s*(nil|AssetIds\.[A-Za-z_.]+|\"rbxassetid://\d+\")\s*,?\s*(--.*)?$"),
    re.compile(r"^\s*--.*$"),  # comment-only lines
    re.compile(r"^\s*$"),
]
ROW = re.compile(r"^\|.*\|\s*$")


def sh(*args: str) -> str:
    return subprocess.check_output(args, text=True)


def matches(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, p) or path == p for p in patterns)


def changed_lines(base: str, head: str, path: str) -> tuple[list[str], list[str]]:
    diff = sh("git", "diff", "-U0", f"{base}...{head}", "--", path)
    added, removed = [], []
    for line in diff.splitlines():
        if line.startswith("+++") or line.startswith("---") or line.startswith("@@") or line.startswith("diff ") or line.startswith("index "):
            continue
        if line.startswith("+"):
            added.append(line[1:])
        elif line.startswith("-"):
            removed.append(line[1:])
    return added, removed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", default="HEAD")
    args = ap.parse_args()

    files = [f for f in sh("git", "diff", "--name-only", f"{args.base}...{args.head}").splitlines() if f]
    errors: list[str] = []
    for f in files:
        if matches(f, FREE):
            if f.startswith("assets/") and f.endswith((".luau", ".lua", ".rbxlx", ".rbxl", ".json", ".sh", ".py", ".ps1", ".exe", ".dll")):
                errors.append(f"{f}: executable/script/place files are not allowed under assets/ on art branches")
            continue
        if matches(f, ROW_APPEND):
            added, removed = changed_lines(args.base, args.head, f)
            if removed:
                errors.append(f"{f}: art branches may only append rows (found {len(removed)} removed/modified lines)")
            for ln in added:
                if not ROW.match(ln):
                    errors.append(f"{f}: added line is not a table row: {ln[:80]!r}")
            continue
        if matches(f, FIELDS_ONLY):
            added, removed = changed_lines(args.base, args.head, f)
            for ln in added + removed:
                if not any(p.match(ln) for p in FIELD_PATTERNS):
                    errors.append(f"{f}: non-field change not allowed on art branches: {ln.strip()[:100]!r}")
            continue
        errors.append(f"{f}: outside the art allowlist")

    if not files:
        print("no changed files")
    for e in errors:
        print(f"::error::{e}")
    print(f"{len(files)} files checked, {len(errors)} violations")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
