## NOVA Zoom 6.6.5
Based on the official upstream v6.6.5 release. Use the ARM APK that matches the TV's Android ABI: `armeabi-v7a` is 32-bit, `arm64-v8a` is 64-bit.

- Two automatic TV modes: Fit height and proportional cover.
- Manual proportional zoom: 100%–200%, **3 percentage points per remote press**, with remembered mode and percentage. Select another format to exit manual zoom without losing its percentage.
- Same NOVA Zoom application ID and certificate as the previous build; the official NOVA app remains separate.

The release build checks the APK signing certificate, version, architecture and Android TV launcher. The APKs reuse the original v6.6.5 native libraries. Component sources and exact upstream revisions are listed in [the build manifest](https://github.com/handsomelong922/aos-AVP/blob/nova-zoom/zoom/manifest.xml).

电视播放时打开「格式 → 手动缩放」，用遥控器左右键微调。新版可覆盖旧版 NOVA Zoom。
