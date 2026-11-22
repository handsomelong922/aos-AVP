## NOVA Zoom 6.6.5
Based on the official upstream v6.6.5 release. Select the APK that matches your Android TV: `armeabi-v7a` is 32-bit and `arm64-v8a` is 64-bit.

- Reopening a video restores its manually chosen subtitle when still available; otherwise NOVA's existing preferred-language rules apply.
- During episode playback, a matching local sidecar belongs to the current episode. NOVA doesn't reuse the previous episode's subtitle file.
- Previous features are retained: 1-percentage-point manual zoom and the “Keep this setting” switch for subtitle delay.
- Same app ID and signing certificate for an in-place upgrade. Official NOVA remains separate.

已有 NOVA Zoom 可直接覆盖安装。每集只匹配自己的字幕，找不到时按原有字幕设置选择。
