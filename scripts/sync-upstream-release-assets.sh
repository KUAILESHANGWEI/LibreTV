#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-LibreSpark/LibreTV}"
TARGET_REPO="${TARGET_REPO:-KUAILESHANGWEI/LibreTV}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required."
  exit 1
fi

release_json="$(gh release view --repo "$UPSTREAM_REPO" --json tagName,name,body,isPrerelease 2>/dev/null || true)"
if [ -z "$release_json" ]; then
  echo "No upstream release found in $UPSTREAM_REPO; nothing to sync."
  exit 0
fi

tag_name="$(jq -r '.tagName' <<<"$release_json")"
release_name="$(jq -r '.name // .tagName' <<<"$release_json")"
is_prerelease="$(jq -r '.isPrerelease' <<<"$release_json")"

work_dir="$(mktemp -d)"
notes_file="$work_dir/release-notes.md"
trap 'rm -rf "$work_dir"' EXIT

jq -r '.body // ""' <<<"$release_json" > "$notes_file"

create_args=(--repo "$TARGET_REPO" "$tag_name" --target main --title "$release_name" --notes-file "$notes_file")
edit_args=(--repo "$TARGET_REPO" "$tag_name" --title "$release_name" --notes-file "$notes_file")
if [ "$is_prerelease" = "true" ]; then
  create_args+=(--prerelease)
  edit_args+=(--prerelease)
fi

if gh release view --repo "$TARGET_REPO" "$tag_name" >/dev/null 2>&1; then
  gh release edit "${edit_args[@]}"
else
  gh release create "${create_args[@]}"
fi

mapfile -t upstream_assets < <(gh release view "$tag_name" --repo "$UPSTREAM_REPO" --json assets --jq '.assets[].name')
mapfile -t target_assets < <(gh release view "$tag_name" --repo "$TARGET_REPO" --json assets --jq '.assets[].name' 2>/dev/null || true)

if [ "${#upstream_assets[@]}" -eq 0 ]; then
  echo "Upstream release $tag_name has no assets."
else
  gh release download "$tag_name" --repo "$UPSTREAM_REPO" --dir "$work_dir/assets" --clobber
  gh release upload "$tag_name" "$work_dir"/assets/* --repo "$TARGET_REPO" --clobber
fi

for target_asset in "${target_assets[@]}"; do
  keep=false
  for upstream_asset in "${upstream_assets[@]}"; do
    if [ "$target_asset" = "$upstream_asset" ]; then
      keep=true
      break
    fi
  done
  if [ "$keep" = false ]; then
    gh release delete-asset "$tag_name" "$target_asset" --repo "$TARGET_REPO" -y
  fi
done

echo "Synced latest upstream release $tag_name from $UPSTREAM_REPO to $TARGET_REPO."
