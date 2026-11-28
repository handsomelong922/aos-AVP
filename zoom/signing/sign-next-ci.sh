#!/usr/bin/env bash
# Sign only first-party branch build artifacts. Do not emit secrets or derived secret material.
set -euo pipefail
umask 077
[[ "${GITHUB_REPOSITORY:-}" = handsomelong922/aos-AVP && "${GITHUB_REF:-}" = refs/heads/nova-zoom ]]
[[ $# -eq 3 ]]
in=$(realpath "$1")
out=$(realpath -m "$2")
tools=$(realpath "$3")
[[ ! -e "$out" ]]
mkdir "$out"
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
python3 - "$temp" <<'PY'
import base64,json,os,sys
from pathlib import Path
temp=Path(sys.argv[1])
try:
    d=json.loads(os.environ["NOVA_ZOOM_RELEASE_SIGNING"])
    p=d["password"]
    assert isinstance(p,str) and len(p)>=32 and p.isalnum() and d["alias"]=="nova-zoom-next"
    k=base64.b64decode(d["pkcs12"],validate=True)
    assert 128 < len(k) < 20000
    (temp/"signer.p12").write_bytes(k)
    (temp/"password").write_text(p+"\n")
except (KeyError,ValueError,TypeError,AssertionError):
    raise SystemExit("Missing or invalid NOVA Zoom release signing secret")
PY
unset NOVA_ZOOM_RELEASE_SIGNING
expected=ebc1e154ad9b51a5b42730e2c6d17b141fb12496b319ab1459b4633f4000f8cc
ver=$(sed -nE 's/^VERSION = "v([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' "$(dirname "$0")/../inputs.py")
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
for tuple in armeabi-v7a:32-bit arm64-v8a:64-bit; do
  abi=${tuple%:*}
  bit=${tuple#*:}
  f="NOVA-Zoom-v$ver-$abi-unsigned.apk"
  apk="$out/NOVA-Zoom-Next-v$ver-$bit.apk"
  digest=$(awk -v f="$f" '($2==f || $2=="*"f) {print $1}' "$in/SHA256SUMS")
  [[ "$digest" =~ ^[a-f0-9]{64}$ ]]
  echo "$digest  $in/$f" | sha256sum --check --status
  "$tools/zipalign" -c -P 16 4 "$in/$f"
  "$tools/apksigner" sign --ks "$temp/signer.p12" --ks-key-alias nova-zoom-next --ks-pass "file:$temp/password" --v4-signing-enabled false --out "$apk" "$in/$f"
  "$tools/apksigner" verify --min-sdk-version 28 --verbose --print-certs "$apk" >"$temp/signature"
  grep -Fq "Verified using v3 scheme (APK Signature Scheme v3): true" "$temp/signature"
  grep -Eq "certificate SHA-256 digest: $expected$" "$temp/signature"
  "$tools/zipalign" -c -P 16 4 "$apk"
  "$tools/aapt" dump badging "$apk" >"$temp/badging"
  grep -Eq "^native-code: '$abi' *$" "$temp/badging"
  grep -Fq 'leanback-launchable-activity:' "$temp/badging"
  ! grep -Eq '^(application-debuggable|split:)' "$temp/badging"
  read -r code name < <(sed -nE "s/^package: name='org\.courville\.nova\.zoom\.next' versionCode='([0-9]+)' versionName='([^']+)'.*/\1 \2/p" "$temp/badging")
  [[ "$name" == "$ver"-* ]]
  (( code > 2676382 ))
  [[ -z "${prev:-}" || "$prev" == "$code" ]]
  prev=$code
done
(cd "$out"; sha256sum *.apk > SHA256SUMS.txt; sha256sum -c SHA256SUMS.txt)
printf '%s %s\n' "$ver" "$code" >"$out/version.txt"
