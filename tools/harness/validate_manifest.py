#!/usr/bin/env python3
"""Validate harness/design_manifest.json — structure, state machine, budgets.

Stdlib only (no jsonschema dependency) so it runs anywhere: CI, a Grok Bot
cloud computer, or a laptop. The JSON schema in harness/schemas/ is the
human-readable contract; this script enforces the rules that a schema can't
express (legal transitions, evidence required per state, budget caps).

    python3 tools/harness/validate_manifest.py            # validate
    python3 tools/harness/validate_manifest.py --strict   # also fail on warnings
Exit 0 = ok, 1 = errors.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "harness" / "design_manifest.json"

STATES = [
    "pending_brief", "concepts_generated", "awaiting_approval", "approved", "rejected",
    "model_generated", "validated", "integrated", "uploaded", "staged", "studio_audited",
    "verified", "parked", "dropped",
]
TIERS = {"static_mesh", "multi_mesh", "rigged", "texture", "icon", "image", "audio"}

# Legal transitions. Anything not listed is a validation error — the
# Orchestrator cannot skip a gate by editing the JSON.
TRANSITIONS: dict[str, set[str]] = {
    "pending_brief": {"concepts_generated", "parked", "dropped"},
    "concepts_generated": {"awaiting_approval", "parked", "dropped"},
    "awaiting_approval": {"approved", "rejected", "dropped"},
    "rejected": {"concepts_generated", "parked", "dropped"},
    "approved": {"model_generated", "validated", "parked"},  # texture/icon/image skip 3D
    "model_generated": {"validated", "model_generated", "parked"},
    "validated": {"integrated", "model_generated", "parked"},
    "integrated": {"uploaded", "parked"},
    "uploaded": {"staged", "parked"},
    "staged": {"studio_audited", "parked"},
    "studio_audited": {"verified", "rejected", "parked"},
    "verified": set(),
    "parked": {"pending_brief", "concepts_generated", "approved", "validated", "dropped"},
    "dropped": set(),
}

# Only these actors may author an approve/reject transition. The Orchestrator
# records the GitHub URL that proves it (approval_ref). CI cross-checks the
# author of that comment against OWNER_LOGINS when it runs with a token.
OWNER_LOGINS = {"BlissDirective"}
HUMAN_ONLY = {("awaiting_approval", "approved"), ("awaiting_approval", "rejected"), ("studio_audited", "verified"), ("studio_audited", "rejected")}

SHA = re.compile(r"^[0-9a-f]{64}$")
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, eid: str, msg: str) -> None:
        self.errors.append(f"[{eid}] {msg}")

    def warn(self, eid: str, msg: str) -> None:
        self.warnings.append(f"[{eid}] {msg}")


def check_element(el: dict, palettes: dict, rep: Report) -> None:
    eid = el.get("id", "<no id>")
    for key in ("id", "group", "name", "tier", "class", "integration_target", "palette", "brief", "reference", "priority", "gated", "state", "artifacts", "asset_ids", "cost_usd", "attempts", "history", "budget"):
        if key not in el:
            rep.err(eid, f"missing field '{key}'")
    if rep.errors and rep.errors[-1].startswith(f"[{eid}] missing"):
        return
    if not re.fullmatch(r"[a-z0-9_]+", eid):
        rep.err(eid, "id must be lowercase snake_case")
    if el["tier"] not in TIERS:
        rep.err(eid, f"unknown tier {el['tier']!r}")
    if el["state"] not in STATES:
        rep.err(eid, f"unknown state {el['state']!r}")
        return
    if el["palette"] not in palettes:
        rep.err(eid, f"palette {el['palette']!r} not in manifest.palettes")
    if len(el["brief"]) < 20:
        rep.err(eid, "brief too short")

    # History must be a valid walk from pending_brief to the current state.
    cur = "pending_brief"
    for i, h in enumerate(el["history"]):
        for k in ("at", "by", "from", "to"):
            if k not in h:
                rep.err(eid, f"history[{i}] missing '{k}'")
        if h.get("from") != cur:
            rep.err(eid, f"history[{i}] from={h.get('from')} but previous state was {cur}")
        if h.get("to") not in TRANSITIONS.get(h.get("from", ""), set()):
            rep.err(eid, f"history[{i}] illegal transition {h.get('from')} -> {h.get('to')}")
        if (h.get("from"), h.get("to")) in HUMAN_ONLY:
            if not h.get("approval_ref"):
                rep.err(eid, f"history[{i}] {h.get('from')}->{h.get('to')} needs approval_ref (GitHub URL from the owner)")
            if h.get("by") not in OWNER_LOGINS:
                rep.err(eid, f"history[{i}] {h.get('from')}->{h.get('to')} authored by {h.get('by')!r}; only {sorted(OWNER_LOGINS)} may approve")
        cur = h.get("to", cur)
    if cur != el["state"]:
        rep.err(eid, f"state={el['state']} but history ends at {cur}")

    # Evidence required per state.
    st = el["state"]
    arts = el["artifacts"]
    kinds = {a.get("kind") for a in arts.values()}
    for key, a in arts.items():
        if not SHA.match(a.get("sha256", "")):
            rep.err(eid, f"artifact {key!r} has no sha256")
        if not (a.get("path") or a.get("url")):
            rep.err(eid, f"artifact {key!r} has neither path nor url")
    if st in ("awaiting_approval", "approved", "model_generated", "validated", "integrated", "uploaded", "staged", "studio_audited", "verified"):
        if el["tier"] != "audio" and "contact_sheet" not in kinds:
            rep.err(eid, f"state {st} requires a contact_sheet artifact")
    if st in ("approved", "model_generated", "validated", "integrated", "uploaded", "staged", "studio_audited", "verified"):
        if el["tier"] != "audio" and not el.get("approved_variant"):
            rep.err(eid, f"state {st} requires approved_variant")
        elif el.get("approved_variant") and el["approved_variant"] not in arts:
            rep.err(eid, "approved_variant does not name an artifact")
    if st in ("validated", "integrated", "uploaded", "staged", "studio_audited", "verified"):
        lic = el.get("license")
        if not lic or not lic.get("commercial_ok"):
            rep.err(eid, f"state {st} requires a license record with commercial_ok=true")
        if el["tier"] in ("static_mesh", "multi_mesh", "rigged") and "fbx" not in kinds:
            rep.err(eid, f"state {st} requires an fbx artifact for tier {el['tier']}")
        if el["tier"] == "rigged" and "rig_request" not in kinds:
            rep.warn(eid, "rigged element without a rig_request artifact")
    if st in ("uploaded", "staged", "studio_audited", "verified") and not el["asset_ids"]:
        rep.err(eid, f"state {st} requires asset_ids")
    if st in ("studio_audited", "verified"):
        if "audit_json" not in kinds or "screenshot" not in kinds:
            rep.err(eid, f"state {st} requires audit_json + screenshot artifacts")

    # Budgets.
    b = el["budget"]
    at = el["attempts"]
    if at.get("concept_rounds", 0) > b.get("concept_rounds", 0):
        rep.err(eid, "concept_rounds exceeds budget — park or raise the cap")
    if at.get("model_generations", 0) > b.get("model_generations", 0):
        rep.err(eid, "model_generations exceeds budget — park or raise the cap")
    if at.get("validations", 0) > 3 and st not in ("parked", "dropped", "verified", "studio_audited", "staged", "uploaded", "integrated"):
        rep.err(eid, "more than 3 validation attempts without parking (three-strikes rule)")
    if el["cost_usd"] > b.get("usd_cap", 0):
        rep.err(eid, f"cost_usd {el['cost_usd']} exceeds usd_cap {b.get('usd_cap')}")
    hist_cost = sum(h.get("cost_usd", 0) for h in el["history"])
    if abs(hist_cost - el["cost_usd"]) > 0.005:
        rep.warn(eid, f"cost_usd {el['cost_usd']} != sum of history costs {hist_cost:.2f}")
    if el["gated"] and st not in ("pending_brief", "parked", "dropped"):
        rep.warn(eid, "gated element has been dispatched — confirm the owner unlocked the group")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--manifest", default=str(MANIFEST))
    args = ap.parse_args()
    rep = Report()
    try:
        m = json.loads(Path(args.manifest).read_text())
    except Exception as exc:  # noqa: BLE001
        print(f"::error::cannot parse manifest: {exc}")
        return 1
    if m.get("manifest_version") != 1:
        rep.err("manifest", "manifest_version must be 1")
    gb = m.get("global_budget", {})
    if gb.get("usd_spent_month", 0) > gb.get("usd_cap_monthly", 0):
        rep.err("manifest", "monthly spend exceeds cap — HALT until the owner raises it")
    palettes = m.get("palettes", {})
    for pname, p in palettes.items():
        for k, v in p.items():
            if not HEX.match(v):
                rep.err("manifest", f"palette {pname}.{k} is not a hex color")
    ids: set[str] = set()
    for el in m.get("elements", []):
        if el.get("id") in ids:
            rep.err(el.get("id", "?"), "duplicate id")
        ids.add(el.get("id", "?"))
        check_element(el, palettes, rep)
    total = sum(e.get("cost_usd", 0) for e in m.get("elements", []))
    if total > gb.get("usd_spent_month", 0) + 0.005 and gb.get("month"):
        rep.warn("manifest", f"sum of element costs {total:.2f} exceeds recorded monthly spend {gb.get('usd_spent_month')}")

    for w in rep.warnings:
        print(f"::warning::{w}")
    for e in rep.errors:
        print(f"::error::{e}")
    n = len(m.get("elements", []))
    by_state: dict[str, int] = {}
    for el in m.get("elements", []):
        by_state[el.get("state", "?")] = by_state.get(el.get("state", "?"), 0) + 1
    print(f"{n} elements, states: {by_state}, errors: {len(rep.errors)}, warnings: {len(rep.warnings)}")
    if rep.errors or (args.strict and rep.warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
