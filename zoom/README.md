# NOVA Zoom fork build
Based on the official [NOVA Video Player v6.6.5 release](https://github.com/nova-video-player/aos-AVP/releases/tag/v6.6.5). The untouched release manifest pins sibling repository revisions. The Android build fetches the four needed source repositories at those pins; it never follows an upstream branch or the stale AVP submodule hints.

- `patches/Video-zoom.patch`: persistent manual zoom and subtitle delay, with standalone Java regression tests.
- `patches/Video-subtitle-memory-{discovery,selection}.patch`: per-video manual subtitle choice and episode-safe local discovery.
- `patches/packaging-overlay-*.patch`: separate `org.courville.nova.zoom` application identity, ARM splits and associated packaging.
- `inputs.py`: verifies the official manifest and both official release APK hashes, extracts their 20 non-Sentry libraries per ABI, and checks all 22 output APK libraries against the official ABI's bytes. The other two come from the pinned project's Maven dependencies. This reuses exact official native binaries rather than rebuilding them; official inputs and applicable source/license references are in the upstream release and its manifest.

On `nova-zoom`, changes to this directory or its workflow trigger two verified **unsigned** standalone APKs, one for each ARM ABI, under [Actions](https://github.com/handsomelong922/aos-AVP/actions/workflows/nova-zoom.yml). Workflow artifacts are not installable until signed. Installable, independently signed builds belong under [Releases](https://github.com/handsomelong922/aos-AVP/releases) after the maintainer checks the certificate, versionCode, supported ABI and SHA-256. No signing credentials are stored or used here. Do not use a new signing certificate for an upgrade to an existing NOVA Zoom install.

To build locally with JDK 17, Android SDK command-line tools (accepted Android SDK licenses), Python 3.11+ and internet access:
```sh
bash zoom/build.sh /tmp/nova-zoom-src /tmp/nova-zoom-dist
```
Both output paths must be new. To update upstream, use a new official **release** (not a rolling branch); verify its published manifest and asset digests, rebase/review the patches onto its exact revisions, update smoke checks, and run both CI APK builds before signing or publishing. Do not auto-publish upstream tags or auto-merge patches that no longer apply.
