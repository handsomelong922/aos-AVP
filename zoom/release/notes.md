## NOVA Zoom 6.6.5
Based on the official upstream v6.6.5 release. Use the ARM APK that matches the TV's Android ABI: `armeabi-v7a` is 32-bit and `arm64-v8a` is 64-bit.

- Manual proportional zoom is now the first entry in Format. Use the remote's left/right buttons to adjust by **one percentage point** between 100% and 200%. Your saved factor is preserved.
- The two added automatic fit modes have been removed. NOVA's original formats remain available.
- Subtitle delay can be remembered across videos and app restarts using the existing-style Keep setting switch.
- Same NOVA Zoom application ID and signing certificate, for in-place updates. Official NOVA remains separate.

The release checks the APK signing certificate, version, architecture and Android TV launcher. The APKs reuse v6.6.5's native libraries. Exact upstream revisions are listed in [the build manifest](https://github.com/handsomelong922/aos-AVP/blob/nova-zoom/zoom/manifest.xml).

电视播放时打开「格式」，第一项就是「手动缩放」。遥控器左右键每次调 1 个百分点。字幕延迟里的「记住此设置」可跨影片记住偏移，包括调回 0。可覆盖安装，原来保存的缩放倍率保留。
