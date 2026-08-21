# 乐鹏蓝牙测试

基于 Flutter 的 KBRP V1.0 蓝牙只读客户端，同一份 Dart 代码支持 Android、iOS 和 Windows。工程可直接用 Android Studio 打开。

## 已实现

- 按协议 Service UUID 扫描、系统安全配对、服务发现、MTU 协商和指数退避重连。
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

Android 可用 Android Studio 选择真机运行。iOS 的编译、签名和真机调试必须在 macOS/Xcode 上完成。Windows Runner 使用 WinRT BLE API，CI 通过 Inno Setup 生成安装程序。

Windows 首次构建 Flutter 插件前需开启 Windows 开发者模式，以允许 Pub 创建符号链接。

## GitHub Actions 云端构建

`.github/workflows/ci.yml` 会在 `main`/`master` 提交和 Pull Request 上执行格式检查、静态分析和测试。

`.github/workflows/build.yml` 在以下情况并行构建三个平台：

- GitHub 项目的 `Actions` -> `Build applications` -> `Run workflow` 手动触发。
- 推送 `v1.0.0` 这类 `v*` Git 标签。

构建完成后，在该 Actions Run 底部的 `Artifacts` 下载：

- `lepeng-bluetooth-test-android-debug`：开发签名 APK，可安装到 Android 真机联调，不能上传 Play Store。
- `lepeng-bluetooth-test-windows`：同时包含带版本号的 `LepengBluetoothTest-Setup-<版本>.exe` 安装程序和 `LepengBluetoothTest-Portable.zip` 便携版。
- `lepeng-bluetooth-test-ios-unsigned`：未签名 `Runner.app` 压缩包，用于确认 iOS 可编译，不能直接安装到 iPhone。

推送 `v1.0.0` 这类标签时，标签版本必须与 `pubspec.yaml` 的版本（忽略 `+` 后的构建号）一致。工作流会自动创建同名 GitHub Release，并将 `LepengBluetoothTest-Setup-1.0.0.exe` 作为 Release 资产发布。用户可从仓库 `Releases` 页面直接下载安装程序，不需要先下载并解压 Actions Artifact。手动运行工作流只生成测试用 Artifact，不会创建正式 Release。

发布 Android AAB 需把生产 Keystore 配置为 GitHub Secrets。生成可安装 IPA 或上传 TestFlight 需 Apple Developer 账号、Distribution Certificate、Provisioning Profile 和 App Store Connect API Key，不应把证书或密码直接提交到仓库。

## Windows 安装和代码签名

Inno Setup 安装器默认安装到当前用户的 `%LOCALAPPDATA%\Programs\LepengBluetoothTest`，不要求管理员权限，支持开始菜单、可选桌面快捷方式和 Windows 标准卸载流程。

安装器不会自动建立 SmartScreen 声誉。要降低“未知发布者”、SmartScreen 和杀毒软件误报，需要从受信任 CA 购买 Windows 代码签名证书，并导出为包含私钥的 `.pfx`。不建议对外发布时使用自签名证书。

在 GitHub 仓库 `Settings` -> `Secrets and variables` -> `Actions` 中添加：

- `WINDOWS_CERTIFICATE_BASE64`：`.pfx` 文件的 Base64 内容。
- `WINDOWS_CERTIFICATE_PASSWORD`：导出 `.pfx` 时设置的密码。

Secrets 配置后，云端工作流会先签名 `lepeng_bluetooth_test.exe`，再签名 `LepengBluetoothTest-Setup.exe`，并使用 DigiCert 时间戳保留证书过期后的签名有效性。未配置 Secrets 时仍会生成安装包，但是未签名产物仍可能被拦截。

## 安全与量产边界

配对码由 Android/iOS/Windows 的系统安全对话框输入，应用不保存、不记录 Passkey。该工程可用于原型和联调，不代表已完成医疗产品验证。量产前必须关闭协议文档第 26 章的待确认项，尤其是 P-006 至 P-009 的单位缩放和报警等级映射，并完成 MTU 23/247、主流手机、长稳、隐私和安全测试。

协议来源：[`docs/手机App蓝牙只读通信协议V1.0.md`](docs/手机App蓝牙只读通信协议V1.0.md)
