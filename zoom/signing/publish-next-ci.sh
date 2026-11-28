#!/usr/bin/env bash
set -euo pipefail
[[ "$GITHUB_REPOSITORY" = handsomelong922/aos-AVP && "$GITHUB_REF" = refs/heads/nova-zoom ]]
[[ "$GITHUB_SHA" =~ ^[a-f0-9]{40}$ ]]
[[ $# -eq 1 ]]
out=$1
read -r version code < "$out/version.txt"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$code" =~ ^[0-9]+$ ]]
(( code > 2676382 ))
[[ "$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/nova-zoom" --jq .object.sha)" == "$GITHUB_SHA" ]] || { echo 'Ref moved; newer run should publish'; exit 1; }
tag="nova-zoom-v$version-$code"
latest=$(gh api "repos/$GITHUB_REPOSITORY/releases/latest" --jq .tag_name)
if [[ "$latest" =~ ^nova-zoom-v[0-9]+\.[0-9]+\.[0-9]+-([0-9]+)$ ]]; then
  (( code > BASH_REMATCH[1] )) || { echo 'An equal or newer release is already published'; exit 1; }
else
  echo 'Unexpected latest release; refusing to publish out of order'; exit 1
fi
(cd "$out"; sha256sum --check SHA256SUMS.txt)
notes=$(mktemp)
trap 'rm -f -- "$notes"' EXIT
cat >"$notes" <<EOF
- 基于上游 NOVA Video Player v$version。保留 Android 9 TV 手动等比缩放、1% 步进和倍率记忆，以及字幕选择和延迟记忆。
- 32 位请选择 32-bit APK（armeabi-v7a），64 位请选择 64-bit APK（arm64-v8a）。
- 从旧签名的 NOVA Zoom 6.6.5 迁移：本版的应用 ID 和签名已更换，可与旧版并存，不能覆盖旧版，设置不会自动迁移。
- 后续 NOVA Zoom Next 版本使用同一个签名，可覆盖这个新系列的版本。
- GitHub Actions：$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID
EOF
gh release create "$tag" "$out/"*.apk "$out/SHA256SUMS.txt" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" --title "NOVA Zoom Next $version ($code)" --notes-file "$notes" --latest
