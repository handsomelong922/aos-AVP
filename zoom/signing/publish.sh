#!/bin/bash
set -euo pipefail
d=$(cd "$(dirname "$0")"/.. && pwd)
cfg="$d/release/release.json"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
[[ "$GITHUB_REPOSITORY" = handsomelong922/aos-AVP && "$GITHUB_REF" = refs/heads/nova-zoom ]]
read -r run sha version code tag < <(python3 - "$cfg" <<'PY'
import json,re,sys
d=json.load(open(sys.argv[1]))
assert type(d['run']) is int and d['run']>0
assert re.fullmatch('[0-9a-f]{40}',d['sha'])
assert re.fullmatch('[0-9]+\.[0-9]+\.[0-9]+',d['version'])
assert type(d['code']) is int and 2675798 < d['code'] < 2100000000
assert d['tag'] == f"nova-zoom-v{d['version']}-{d['code']}"
print(d['run'],d['sha'],d['version'],d['code'],d['tag'])
PY
)
gh run view "$run" --repo "$GITHUB_REPOSITORY" --json headSha,conclusion,headBranch,workflowName |
  jq -e --arg sha "$sha" '.headSha==$sha and .headBranch=="nova-zoom" and .conclusion=="success" and .workflowName=="NOVA Zoom APK build"'
gh run download "$run" --repo "$GITHUB_REPOSITORY" -n nova-zoom-unsigned-apks -D "$tmp/input"
(cd "$tmp/input" && sha256sum -c SHA256SUMS)
# Build-Tools archive is Google's Linux release, pinned to the exact known revision.
curl -fsSL --retry 3 https://dl.google.com/android/repository/build-tools_r37_linux.zip -o "$tmp/build-tools.zip"
echo "70954e99f4c3d9d46ee70fa32624672fe7cd6ebe  $tmp/build-tools.zip" | sha1sum -c -
unzip -q "$tmp/build-tools.zip" -d "$tmp/tools"
tools="$tmp/tools/android-37.0"
mkdir "$tmp/dist"
for abi in armeabi-v7a arm64-v8a; do
  unsigned="$tmp/input/NOVA-Zoom-v$version-$abi-unsigned.apk"
  signed="$tmp/dist/NOVA-Zoom-v$version-$abi.apk"
  cat "$d/release/$abi"/delta-* > "$tmp/$abi.delta"
  python3 "$d/signing/apk_delta.py" apply "$unsigned" "$tmp/$abi.delta" "$signed"
  "$tools/zipalign" -c -P 16 4 "$signed"
  "$tools/apksigner" verify --verbose --print-certs "$signed" > "$tmp/signer"
  grep -Eq 'certificate SHA-256 digest: 07c530b2782251ecdb27b4d4727f7df03e42dcbd41c8fc5942cd92750c786567$' "$tmp/signer"
  "$tools/aapt" dump badging "$signed" > "$tmp/badging"
  grep -Fq "package: name='org.courville.nova.zoom' versionCode='$code' versionName='$version-" "$tmp/badging"
  grep -Eq "^native-code: '$abi' *$" "$tmp/badging"
  grep -Fq "leanback-launchable-activity:" "$tmp/badging"
done
(cd "$tmp/dist" && sha256sum ./*.apk > SHA256SUMS.txt && sha256sum -c SHA256SUMS.txt)
gh release create "$tag" "$tmp/dist/"* --repo "$GITHUB_REPOSITORY" --target "$sha"   --title "NOVA Zoom $version ($code)" --notes-file "$d/release/notes.md" --latest
