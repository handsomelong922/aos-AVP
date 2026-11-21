#!/usr/bin/env bash
# Resolve standard SDK locations and provision the two archives used by the verified build.
# Stdout is the resolved SDK path; diagnostics and downloads go to stderr.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ $# == 1 ]]
sdk=
for candidate in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME:-}/Android/Sdk" /usr/local/lib/android/sdk /opt/android-sdk /opt/android; do
    if [[ -n "$candidate" && -d "$candidate" && -w "$candidate" ]]; then
        sdk="$candidate"
        break
    fi
done
sdk=${sdk:-$1}
mkdir -p "$sdk"
sdk=$(realpath "$sdk")
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
install_archive() {
    local asset=$1 sha1=$2 sha256=$3 dest=$4 xml=$5
    local zip="$scratch/$asset" unpack="$scratch/${asset%.zip}"
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --max-time 360 \
        -o "$zip" "https://dl.google.com/android/repository/$asset"
    printf '%s  %s\n' "$sha1" "$zip" | sha1sum --check --status
    printf '%s  %s\n' "$sha256" "$zip" | sha256sum --check --status
    mkdir "$unpack"
    unzip -q "$zip" -d "$unpack"
    test -d "$unpack/android-37.0"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" || -L "$dest" ]]; then
        echo "Existing SDK component is incomplete: $dest; use a clean writable SDK" >&2
        exit 1
    fi
    cp "$xml" "$unpack/android-37.0/package.xml"
    mv "$unpack/android-37.0" "$dest"
}
platform="$sdk/platforms/android-37.0"
if [[ ! -f "$platform/android.jar" || ! -f "$platform/package.xml" ]]; then
    install_archive platform-37.0_r02.zip ed8ebf7f8822a4de5686d427f237d2fa30ff7410 \
        840b23e827f96e64aea4c89a1194aac3dc5f6bad37edb231c5c795d890330e8d \
        "$platform" "$root/sdk/platform-37.0.xml"
fi
buildtools="$sdk/build-tools/37.0.0"
if [[ ! -x "$buildtools/zipalign" || ! -x "$buildtools/aapt" || ! -x "$buildtools/aapt2" || ! -f "$buildtools/package.xml" ]]; then
    install_archive build-tools_r37_linux.zip 70954e99f4c3d9d46ee70fa32624672fe7cd6ebe \
        01af179347cbcd9c208b7f8171f7b21f6dd1d2f85bcd15e88caa51d5d7b86060 \
        "$buildtools" "$root/sdk/build-tools-37.0.0.xml"
fi
printf '%s\n' "$sdk"
