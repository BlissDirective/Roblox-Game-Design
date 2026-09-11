#!/usr/bin/env bash
#
# Outpost-7 — Open Cloud asset uploader.
#
# Reads tools/asset-import/upload-manifest.json, uploads any asset whose file
# exists on disk but whose recorded assetId is still 0, records the returned
# id back into the manifest, and regenerates src/shared/AssetIds.luau.
#
# Roblox asset IDs are IMMUTABLE once issued, so this only uploads rows still
# at assetId 0 — re-running is safe and idempotent. Run it via the
# `upload-assets.yml` workflow (workflow_dispatch), not on every push.
#
# Env:
#   ROBLOX_API_KEY   required unless DRY_RUN=true — Open Cloud key with
#                    asset:read + asset:write on the target creator. Audio
#                    uploads also require the creator to be ID-verified.
#   ROBLOX_CREATOR_ID   the user or group id that will own the uploaded assets.
#   ROBLOX_CREATOR_TYPE "User" (default) or "Group".
#   DRY_RUN          "true" → print what would upload, mutate nothing.
#
# Reference: https://create.roblox.com/docs/cloud/guides/usage-assets
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/tools/asset-import/upload-manifest.json"
OUT_LUA="$ROOT/src/shared/AssetIds.luau"
API="https://apis.roblox.com/assets/v1/assets"

DRY_RUN="${DRY_RUN:-false}"
CREATOR_ID="${ROBLOX_CREATOR_ID:-0}"
CREATOR_TYPE="${ROBLOX_CREATOR_TYPE:-User}"

if [[ ! -f "$MANIFEST" ]]; then
  echo "::error::manifest not found at $MANIFEST"
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "::error::jq is required"; exit 1; }

echo "== Outpost-7 asset upload =="
echo "manifest: $MANIFEST"
echo "dry_run:  $DRY_RUN"

# Iterate rows whose file exists and assetId == 0.
mapfile -t PENDING < <(jq -r '.assets | to_entries[] | select(.value.assetId == 0) | .key' "$MANIFEST")

if [[ ${#PENDING[@]} -eq 0 ]]; then
  echo "Nothing to upload — every manifest row already has an assetId."
fi

for FILE_REL in "${PENDING[@]}"; do
  FILE_ABS="$ROOT/$FILE_REL"
  KEY="$(jq -r --arg f "$FILE_REL" '.assets[$f].key' "$MANIFEST")"
  ASSET_TYPE="$(jq -r --arg f "$FILE_REL" '.assets[$f].assetType' "$MANIFEST")"

  if [[ ! -f "$FILE_ABS" ]]; then
    echo "  skip (no file yet): $FILE_REL  [$KEY]"
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  would upload: $FILE_REL  [$KEY, $ASSET_TYPE]"
    continue
  fi

  if [[ -z "${ROBLOX_API_KEY:-}" ]]; then
    echo "::error::ROBLOX_API_KEY is required for a real upload"
    exit 1
  fi

  # H3: explicit MIME per asset type. Open Cloud accepts Audio (mp3/ogg),
  # Decal (png/jpeg/bmp/tga) and Model (fbx). Anything else is a manifest
  # bug — fail loudly rather than let Roblox reject it with a vague 400.
  EXT="${FILE_ABS##*.}"
  case "$ASSET_TYPE:$EXT" in
    Audio:ogg) MIME="audio/ogg" ;;
    Audio:mp3) MIME="audio/mpeg" ;;
    Decal:png) MIME="image/png" ;;
    Decal:jpg|Decal:jpeg) MIME="image/jpeg" ;;
    Decal:bmp) MIME="image/bmp" ;;
    Decal:tga) MIME="image/tga" ;;
    Model:fbx) MIME="model/fbx" ;;
    *) echo "::error::unsupported assetType/extension $ASSET_TYPE/.$EXT for $FILE_REL"; exit 1 ;;
  esac

  echo "  uploading: $FILE_REL  [$KEY, $ASSET_TYPE, $MIME]"
  REQUEST=$(jq -n \
    --arg at "$ASSET_TYPE" \
    --arg ct "$CREATOR_TYPE" \
    --arg cid "$CREATOR_ID" \
    --arg name "$KEY" \
    '{assetType:$at, displayName:$name, description:"Outpost-7 asset", creationContext:{creator:( ($ct=="Group") | if . then {groupId:($cid|tonumber)} else {userId:($cid|tonumber)} end )}}')

  # Multipart: the JSON "request" part + the binary "fileContent" part.
  RESPONSE=$(curl --fail-with-body --silent --show-error \
    -X POST "$API" \
    -H "x-api-key: $ROBLOX_API_KEY" \
    -F "request=$REQUEST" \
    -F "fileContent=@$FILE_ABS;type=$MIME")

  # The upload returns a long-running operation; poll it for the assetId.
  OP_PATH=$(echo "$RESPONSE" | jq -r '.path // empty')
  ASSET_ID=$(echo "$RESPONSE" | jq -r '.response.assetId // empty')

  if [[ -z "$ASSET_ID" && -n "$OP_PATH" ]]; then
    for _ in $(seq 1 30); do
      sleep 2
      OP=$(curl --fail-with-body --silent --show-error \
        -H "x-api-key: $ROBLOX_API_KEY" \
        "https://apis.roblox.com/assets/v1/$OP_PATH")
      ASSET_ID=$(echo "$OP" | jq -r '.response.assetId // empty')
      [[ -n "$ASSET_ID" ]] && break
    done
  fi

  if [[ -z "$ASSET_ID" ]]; then
    echo "::error::no assetId returned for $FILE_REL — response: $RESPONSE"
    exit 1
  fi

  echo "    → assetId $ASSET_ID"

  # H3: moderation status. Uploads are moderated asynchronously; a
  # "Rejected" asset must never reach AssetIds.luau. Poll briefly; if the
  # review is still pending we record the id (it is immutable) and the
  # harness QA step re-checks before the element is marked `staged`.
  MOD_STATE="Unknown"
  for _ in $(seq 1 10); do
    ASSET_JSON=$(curl --silent --show-error \
      -H "x-api-key: $ROBLOX_API_KEY" \
      "$API/$ASSET_ID?readMask=moderationResult" || true)
    MOD_STATE=$(echo "$ASSET_JSON" | jq -r '.moderationResult.moderationState // "Unknown"')
    [[ "$MOD_STATE" != "Reviewing" && "$MOD_STATE" != "Unknown" ]] && break
    sleep 3
  done
  echo "    moderation: $MOD_STATE"
  if [[ "$MOD_STATE" == "Rejected" ]]; then
    echo "::error::asset $ASSET_ID for $FILE_REL was REJECTED by moderation — not recording it"
    exit 1
  fi

  # Record it back into the manifest (atomic write).
  TMP="$(mktemp)"
  jq --arg f "$FILE_REL" --argjson id "$ASSET_ID" '.assets[$f].assetId = $id' "$MANIFEST" > "$TMP"
  mv "$TMP" "$MANIFEST"
done

# --- Regenerate src/shared/AssetIds.luau from the manifest --------------------
# H3: the generator is a standalone script so the harness seeders and CI's
# `--check` share one implementation.
echo "Regenerating $OUT_LUA"
python3 "$ROOT/tools/scripts/regen-asset-ids.py"

echo "== done =="
