# FRAME/SHIFT iPad 原生版

这是使用 SwiftUI 和 AVPlayer 制作的 iPad 应用源码。它直接从“文件”选取本地视频，提供 0.25×–4× 倍速、进度拖动、音量、全屏和外接键盘左右键每次跳 1 秒。鼠标或触控板移到底部时控制栏显示，移开 0.3 秒后隐藏；触屏唤出时会多停留几秒，方便点选。

## 安装到自己的 iPad

需要一台 Mac、Xcode、自己的 Apple Account 和 iPad。无需付费开发者会员。

1. 在 Mac 上安装 Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。
2. 在本目录运行 `xcodegen generate`，打开生成的 `FrameShift.xcodeproj`。
3. 在 Xcode 的 Signing & Capabilities 中选自己的 Personal Team，并将 Bundle Identifier 改为属于自己的唯一名称。
4. 用线缆或无线配对 iPad，在 Xcode 选择该 iPad，点 Run。按系统提示信任设备或启用开发者模式。

免费 Personal Team 的描述文件有效期为 7 天，过期后需要通过 Xcode 重新安装。它不能生成可从网站直接分发安装的正式应用包。网站上的一键下载入口必须等到有合适的签名与发布渠道后才能接通。
