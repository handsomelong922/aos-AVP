#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo "Usage: $0 NEW_SOURCE_DIR NEW_OUTPUT_DIR" >&2; exit 2; }
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src="$(realpath -m "$1")"
out="$(realpath -m "$2")"
[[ ! -e "$src" && ! -e "$out" && "$src" != "$out" ]] || { echo 'Source and output paths must be distinct and unused' >&2; exit 2; }
mkdir "$src" "$out"
sdk=$(bash "$root/provision-sdk.sh" "$src/.android-sdk")
export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk"
python3 "$root/inputs.py" prepare "$root" "$src"
for p in Video MediaLib FileCoreLibrary; do
    git -C "$src/$p" apply "$root/patches/packaging-overlay-$p.patch"
done
git -C "$src/Video" apply "$root/patches/Video-zoom.patch"
git -C "$src/Video" apply "$root/patches/Video-subtitle-memory-discovery.patch" "$root/patches/Video-subtitle-memory-selection.patch"
git -C "$src/Video" apply "$root/patches/Video-zoom-renderer-fix.patch"
(
    cd "$src/Video"
    jvm=$(mktemp -d "$src/test.XXXXXX")
    pkg=src/main/java/com/archos/mediacenter/video/player
    android_jar="$sdk/platforms/android-37.0/android.jar"
    javac -cp "$android_jar" -d "$jvm" "$pkg/VideoDisplayMode.java" "$pkg/VideoZoomLayout.java" \
        "$pkg/SubtitleDelayPreference.java" "$pkg/SubtitleMemoryPolicy.java" "$pkg/LegacyTvManualZoom.java" \
        "$pkg/../browser/subtitlesmanager/LocalSubtitleMatch.java" \
        test/VideoZoomLayoutTest.java test/SubtitleDelayPreferenceTest.java test/SubtitleMemoryPolicyTest.java test/LegacyTvManualZoomTest.java
    java -cp "$jvm:$android_jar" com.archos.mediacenter.video.player.VideoZoomLayoutTest
    java -cp "$jvm:$android_jar" com.archos.mediacenter.video.player.SubtitleDelayPreferenceTest
    java -cp "$jvm:$android_jar" com.archos.mediacenter.video.player.SubtitleMemoryPolicyTest
    java -cp "$jvm:$android_jar" com.archos.mediacenter.video.player.LegacyTvManualZoomTest
    bash ./gradlew --no-daemon --max-workers=4 --console=plain -Psponsor assembleNoamazonRelease lintNoamazonRelease -x :FileCoreLibrary:ndkBuild -x :MediaLib:ndkBuild
)
shopt -s nullglob
build="$src/Video/build/outputs/apk/noamazon/release"
apks=("$build"/*.apk)
[[ ${#apks[@]} == 2 ]]
for abi in armeabi-v7a arm64-v8a; do
    bin=("$build"/*-"$abi"-*unsigned.apk)
    [[ ${#bin[@]} == 1 ]]
    apk="$out/NOVA-Zoom-v6.6.5-$abi-unsigned.apk"
    "$sdk/build-tools/37.0.0/zipalign" -P 16 -f 4 "${bin[0]}" "$apk"
    "$sdk/build-tools/37.0.0/zipalign" -c -P 16 4 "$apk"
    "$sdk/build-tools/37.0.0/aapt" dump badging "$apk" > "$out/badging-$abi.txt"
    grep -Fq "package: name='org.courville.nova.zoom'" "$out/badging-$abi.txt"
    grep -Eq "versionCode='[0-9]+' versionName='6\.6\.5([-'])" "$out/badging-$abi.txt"
    code=$(sed -nE "s/^package:.*versionCode='([0-9]+)'.*/\1/p" "$out/badging-$abi.txt")
    (( code >= 2675845 ))
    [[ -z ${previous_abi_code:-} || "$code" == "$previous_abi_code" ]]
    previous_abi_code=$code
    grep -Fq 'leanback-launchable-activity:' "$out/badging-$abi.txt"
    grep -Fxq "native-code: '$abi' " "$out/badging-$abi.txt" || grep -Fxq "native-code: '$abi'" "$out/badging-$abi.txt"
    ! grep -Eq '^(application-debuggable|split:)' "$out/badging-$abi.txt"
    python3 "$root/inputs.py" verify "$src" "$apk" "$abi"
done
(cd "$out"; sha256sum *.apk > SHA256SUMS)
