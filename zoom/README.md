# NOVA Zoom fork build
Based on the official [NOVA Video Player v6.6.6 release](https://github.com/nova-video-player/aos-AVP/releases/tag/v6.6.6). The untouched release manifest pins sibling repository revisions. The Android build fetches the four needed source repositories at those pins; it never follows an upstream branch or the stale AVP submodule hints.

- `patches/Video-zoom.patch`: persistent manual zoom and subtitle delay, with standalone Java regression tests.
- `patches/Video-subtitle-memory-{discovery,selection}.patch`: per-video manual subtitle choice and episode-safe local discovery.
- `patches/packaging-overlay-*.patch`: separate `org.courville.nova.zoom.next` application identity, ARM splits and associated packaging.
- `inputs.py`: verifies the official manifest and both official release APK hashes, extracts their 20 non-Sentry libraries per ABI, and checks all 22 output APK libraries against the official ABI's bytes. The other two come from the pinned project's Maven dependencies. This reuses exact official native binaries rather than rebuilding them; official inputs and applicable source/license references are in the upstream release and its manifest.

On `nova-zoom`, [GitHub Actions](https://github.com/handsomelong922/aos-AVP/actions/workflows/nova-zoom.yml) builds two verified unsigned APKs, then signs and publishes standalone ARM32 and ARM64 APKs in a separate job. The signing credential lives only in the repository's encrypted Actions Secret `NOVA_ZOOM_RELEASE_SIGNING` (JSON with PKCS#12 base64, password and alias). Do not commit or log it, and never change the signing certificate for updates to the Next application. NOVA Zoom Next installs alongside the older differently signed NOVA Zoom; it is not an in-place upgrade to that edition.

To build locally with JDK 17, Android SDK command-line tools (accepted Android SDK licenses), Python 3.11+ and internet access:
```sh
bash zoom/build.sh /tmp/nova-zoom-src /tmp/nova-zoom-dist
```
Both output paths must be new. To update upstream, use a new official **release** (not a rolling branch); verify its published manifest and asset digests, rebase/review the patches onto its exact revisions, update smoke checks, and run both CI APK builds before signing or publishing. Do not auto-publish upstream tags or auto-merge patches that no longer apply.
