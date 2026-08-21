# KJR 呼吸监测

基于 Flutter 的 KBRP V1.0 蓝牙只读客户端，同一份 Dart 代码支持 Android、iOS 和 Windows。工程可直接用 Android Studio 打开。

## 已实现

- 按 KJR Service UUID 扫描、系统安全配对、服务发现、MTU 协商和指数退避重连。
- KBRP 传输头、分片重组、CRC-16/CCITT-FALSE、长度/版本/Schema 校验。
- Protocol Info、Device Status、Realtime Metrics、Waveform Batch、Alarm Status 和 Latest Report 全部解码。
- 设备列表、治疗概览、压力/流量波形、当前报警、最近报告页面。
- 断线后当前数据立即失效，Metrics 和波形分别按 3 秒和 1 秒判断过期。
- 严格只读：业务代码没有 Characteristic Write 路径，仅使用系统配对和 CCCD 订阅。

## 开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Android 可用 Android Studio 选择真机运行。iOS 的编译、签名和真机调试必须在 macOS/Xcode 上完成。Windows 发布为 MSIX 时需在 Package.appxmanifest 声明 `bluetooth` 和 `radios` capability；本地 Win32 Runner 使用 WinRT BLE API。

Windows 首次构建 Flutter 插件前需开启 Windows 开发者模式，以允许 Pub 创建符号链接。

## GitHub Actions 云端构建

`.github/workflows/ci.yml` 会在 `main`/`master` 提交和 Pull Request 上执行格式检查、静态分析和测试。

`.github/workflows/build.yml` 在以下情况并行构建三个平台：

- GitHub 项目的 `Actions` -> `Build applications` -> `Run workflow` 手动触发。
- 推送 `v1.0.0` 这类 `v*` Git 标签。

构建完成后，在该 Actions Run 底部的 `Artifacts` 下载：

- `kjr-monitor-android-debug`：开发签名 APK，可安装到 Android 真机联调，不能上传 Play Store。
- `kjr-monitor-windows`：Windows Release 程序及依赖 DLL 的 ZIP。
- `kjr-monitor-ios-unsigned`：未签名 `Runner.app` 压缩包，用于确认 iOS 可编译，不能直接安装到 iPhone。

发布 Android AAB 需把生产 Keystore 配置为 GitHub Secrets。生成可安装 IPA 或上传 TestFlight 需 Apple Developer 账号、Distribution Certificate、Provisioning Profile 和 App Store Connect API Key，不应把证书或密码直接提交到仓库。

## 安全与量产边界

配对码由 Android/iOS/Windows 的系统安全对话框输入，应用不保存、不记录 Passkey。该工程可用于原型和联调，不代表已完成医疗产品验证。量产前必须关闭协议文档第 26 章的待确认项，尤其是 P-006 至 P-009 的单位缩放和报警等级映射，并完成 MTU 23/247、主流手机、长稳、隐私和安全测试。

协议来源：[`docs/手机App蓝牙只读通信协议V1.0.md`](docs/手机App蓝牙只读通信协议V1.0.md)
