#!/usr/bin/env python3
"""Seed tools/asset-import/upload-manifest.json rows from harness/design_manifest.json.

Every image-gated element gets a fixed file path + AssetIds key here, so the
Integrator only ever COPIES files to the path a row already names — it never
invents keys and never edits Luau. Consumers in src/ reference these keys by
name (BuildableRegistry.modelKey, Constants.BIOME.*.floraModelKeys, …).

Rules (id → key is PascalCase of the snake_case element id):
  static_mesh / multi_mesh / rigged → Models.<Pascal>      <folder>/<id>.fbx   (Model)
  texture (not skybox)              → Textures.<Pascal>    <folder>/<id>.png   (Decal)
  cosmetic_decal / cosmetic_trail   → Textures.<Pascal> AND Icons.<Pascal>     (Decal)
  icon                              → Icons.<Pascal>       assets/ui/<id>.png  (Decal)
  image (non-listing)               → Images.<Pascal>      assets/ui/<id>.png  (Decal)
  skybox                            → Skyboxes.<Biome><Face> ×6                (Decal)
  listing / audio                   → rows already exist; skipped

Existing rows (and their assetId) are never touched. Run after seed_manifest.py:

    python3 tools/harness/seed_upload_rows.py && python3 tools/scripts/regen-asset-ids.py
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESIGN = ROOT / "harness" / "design_manifest.json"
UPLOAD = ROOT / "tools" / "asset-import" / "upload-manifest.json"

BIOMES = {"jungle", "volcanic", "ice"}
FACES = ["Ft", "Bk", "Lf", "Rt", "Up", "Dn"]


def pascal(eid: str) -> str:
    return "".join(p.capitalize() for p in eid.split("_"))


def folder_for(el: dict) -> str:
    cls = el["class"]
    biome = el["palette"] if el["palette"] in BIOMES else "shared"
    if cls == "world.arch":
        return f"assets/world/biome_{biome}/arch"
    if cls in ("biome_flora", "cave_overlay"):
        return f"assets/world/biome_{biome}"
    if cls == "skybox":
        return f"assets/world/biome_{biome}/sky"
    if cls == "world_prop":
        return "assets/world/props"
    if cls in ("buildable", "raid"):
        return "assets/world/buildables"
    if cls in ("alien", "cosmetic_skin"):
        return "assets/characters"
    if cls in ("drone", "weapon", "vfx", "damage_state", "ftue"):
        return "assets/effects"
    if cls == "vehicle":
        return "assets/vehicles"
    if cls in ("ui_glyph", "store_art", "cosmetic_decal", "cosmetic_trail", "cosmetic_flair"):
        return "assets/ui"
    if cls == "listing":
        return "assets/icons"
    return "assets/misc"


def rows_for(el: dict) -> list[tuple[str, dict]]:
    eid, tier, cls = el["id"], el["tier"], el["class"]
    key = pascal(eid)
    folder = folder_for(el)
    if tier == "audio" or cls == "listing":
        return []
    if tier in ("static_mesh", "multi_mesh", "rigged"):
        return [(f"{folder}/{eid}.fbx", {"key": f"Models.{key}", "assetType": "Model", "assetId": 0})]
    if cls == "skybox":
        biome = pascal(el["palette"])
        return [
            (f"{folder}/{eid}_{face.lower()}.png", {"key": f"Skyboxes.{biome}{face}", "assetType": "Decal", "assetId": 0})
            for face in FACES
        ]
    if cls in ("cosmetic_decal", "cosmetic_trail"):
        return [
            (f"{folder}/{eid}.png", {"key": f"Textures.{key}", "assetType": "Decal", "assetId": 0}),
            (f"{folder}/{eid}_icon.png", {"key": f"Icons.{key}", "assetType": "Decal", "assetId": 0}),
        ]
    if tier == "texture":
        return [(f"{folder}/{eid}.png", {"key": f"Textures.{key}", "assetType": "Decal", "assetId": 0})]
    if tier == "icon":
        return [(f"{folder}/{eid}.png", {"key": f"Icons.{key}", "assetType": "Decal", "assetId": 0})]
    if tier == "image":
        return [(f"{folder}/{eid}.png", {"key": f"Images.{key}", "assetType": "Decal", "assetId": 0})]
    return []


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if rows are missing")
    args = ap.parse_args()
    design = json.loads(DESIGN.read_text())
    upload = json.loads(UPLOAD.read_text())
    assets: dict = upload["assets"]
    existing_keys = {row["key"] for row in assets.values()}
    added = 0
    for el in design["elements"]:
        for path, row in rows_for(el):
            if path in assets:
                continue
            if row["key"] in existing_keys:
                print(f"::warning::key {row['key']} already used by another path; skipping {path}")
                continue
            assets[path] = row
            existing_keys.add(row["key"])
            added += 1
    if args.check:
        if added:
            print(f"::error::{added} upload-manifest rows missing — run tools/harness/seed_upload_rows.py")
            return 1
        print("upload-manifest rows complete")
        return 0
    UPLOAD.write_text(json.dumps(upload, indent=2, ensure_ascii=False) + "\n")
    print(f"added {added} rows → {UPLOAD.relative_to(ROOT)} ({len(assets)} total)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
