# Bettbox WhiteLabel

基于 [appshubcc/Bettbox](https://github.com/appshubcc/Bettbox) 分支改造的轻量白牌客户端模板。

Bettbox 是一款基于 Mihomo 内核的多平台代理客户端。本仓库保留 Bettbox 的核心能力，并在其基础上增加适合机场服务商二次定制的登录、订阅同步、用户中心、公告/教程/工单/购买、在线更新和一键导入能力。

> 本仓库不是 Bettbox 官方仓库。请优先关注并尊重上游项目 [appshubcc/Bettbox](https://github.com/appshubcc/Bettbox)。

## 适用场景

- 机场服务商需要一个只面向自家面板用户的客户端。
- 用户使用邮箱和密码登录后自动获取订阅，不在客户端展示订阅链接。
- 当前白牌业务流程主要适配 Android 和 Windows 客户端。
- 支持 V2Board / xiaoV2b 兼容接口。
- 支持网站一键导入登录态，例如 `yourapp://install-config?authData=...`。
- 支持通用客服入口，不绑定 Crisp，可替换为任意客服系统或自建 H5 页面。

## 平台改造范围

本仓库目前只对白牌业务流程做了 Android 和 Windows 适配。

- Android：已适配登录、订阅同步、用户中心、公告、教程、工单、购买、支付页、一键导入、客服 WebView、在线更新等白牌能力。
- Windows：已适配登录、订阅同步、用户中心、公告、教程、工单、购买、支付页、一键导入、客服 WebView 窗口、在线更新和安装包元数据。
- macOS / Linux / 其他平台：仍保留上游 Bettbox 原样，没有针对白牌登录、购买、客服和一键导入流程做完整适配。若其他机场需要这些平台，应基于本模板自行补充和测试。

## 与原版 Bettbox 的关系

本项目通过 Bettbox 分支改造而来，核心代理能力、Mihomo 集成、多平台基础能力均继承自 Bettbox。

本模板主要增加或调整：

- 白牌构建配置，品牌名、包名、Scheme、官网、更新接口、客服地址均通过构建参数配置。
- 登录页和会话管理。
- V2Board 用户订阅自动同步。
- 公告、教程、工单、购买、订单和支付页面。
- Android / Windows 一键导入协议。
- 通用在线更新入口。
- 去除特定机场的私有域名、密钥、DNS TXT、内置代理、客服 ID 和私有图标。

## 白牌配置

其他机场接入时，推荐不要直接把自己的面板地址、客服 ID、内置代理、更新地址写死进源码，而是在构建时通过 `--dart-define` 注入。这样同一份源码可以给多个品牌复用。

最少需要配置：

```bash
--dart-define=APP_DISPLAY_NAME="Your App"
--dart-define=APP_URI_SCHEME="yourapp"
--dart-define=APP_HOME_URL="https://example.com"
--dart-define=V2BOARD_PANEL_URL="https://panel.example.com"
```

`V2BOARD_API_BASE_URL` 可选。未配置时默认使用：

```text
$V2BOARD_PANEL_URL/api/v1
```

更多配置见 [WHITE_LABEL.md](WHITE_LABEL.md)。

### 配置项说明

| 配置项 | 必填 | 说明 |
| --- | --- | --- |
| `APP_DISPLAY_NAME` | 是 | 客户端显示名称，例如 `Example VPN`。 |
| `APP_URI_SCHEME` | 是 | 一键导入协议头，例如 `examplevpn`，对应 `examplevpn://install-config?...`。 |
| `APP_HOME_URL` | 否 | 官网地址，用于关于页、更多页等入口。 |
| `V2BOARD_PANEL_URL` | 是 | 机场面板地址，例如 `https://panel.example.com`。 |
| `V2BOARD_API_BASE_URL` | 否 | API 地址。默认是 `$V2BOARD_PANEL_URL/api/v1`。 |
| `SUPPORT_WEB_URL` | 否 | 客服页面地址，可接 Crisp、Intercom、自建工单、Telegram Bot 页面等。 |
| `WINDOWS_UPDATE_URL` | 否 | Windows 在线更新 manifest 地址。 |
| `ANDROID_UPDATE_URL` | 否 | Android 在线更新 manifest 地址。 |
| `BOOTSTRAP_PROXY_URI` | 否 | 面板 API 需要代理访问时使用的启动代理。为空则直连。 |
| `BOOTSTRAP_PROXY_NAME` | 否 | 启动代理节点名称，默认 `bootstrap`。 |
| `BACKEND_PROXY_PORT` | 否 | 启动代理本地端口，默认 `7891`。 |
| `DELAY_MULTIPLIER` | 否 | 延迟显示优化倍数，默认 `1.0`。 |
| `CONFIG_TXT_HOST` | 否 | 如需远程配置密文，可放 DNS TXT 主机名。模板默认不绑定任何 DNS。 |
| `CONFIG_CIPHERTEXT` | 否 | 可选配置密文。模板默认不包含任何私有密文。 |

### 机场接入流程

1. Fork 或复制本仓库。
2. 准备自己的 V2Board / xiaoV2b 面板，并确认接口兼容 `/api/v1`。
3. 在构建命令中填入自己的 `APP_DISPLAY_NAME`、`APP_URI_SCHEME`、`V2BOARD_PANEL_URL`。
4. 替换图标和启动图资源。
5. Android 设置独立包名和 Scheme。
6. Windows 设置安装包名称、可执行文件名称、发布者和 Scheme。
7. 可选配置客服地址、在线更新地址、启动代理。
8. 构建 Android APK 和 Windows 安装包。
9. 在自己官网添加一键导入链接。
10. 用真实账号登录测试：登录、订阅同步、节点刷新、公告/教程、工单、购买、支付、退出登录、在线更新。

### 品牌资源替换

默认模板使用中性占位图标。其他机场发布前应替换：

| 位置 | 用途 |
| --- | --- |
| `assets/images/icon.png` | Flutter 内显示的主图标。 |
| `assets/images/icon_light.png` / `icon_dark.png` | 不同主题图标。 |
| `android/app/src/main/res/drawable/` | Android 启动图、通知图标等资源。 |
| `android/app/src/main/res/mipmap-*` | Android 桌面图标。 |
| `windows/runner/resources/app_icon.ico` | Windows 桌面图标和 exe 图标。 |
| `snapshots/` | README 截图，可按品牌重新生成。 |

替换资源后建议重新执行 Android 和 Windows 构建，确认安装包图标、启动页和任务栏图标都正确。

## 可选功能

```bash
--dart-define=WINDOWS_UPDATE_URL="https://example.com/client/win/update.json"
--dart-define=ANDROID_UPDATE_URL="https://example.com/client/android/update.json"
--dart-define=SUPPORT_WEB_URL="https://support.example.com"
--dart-define=BOOTSTRAP_PROXY_URI="protocol://user:password@host:port?option=value"
--dart-define=BOOTSTRAP_PROXY_NAME="bootstrap"
--dart-define=BACKEND_PROXY_PORT=7891
--dart-define=DELAY_MULTIPLIER=1.0
```

`SUPPORT_WEB_URL` 是通用客服入口，可以是 Crisp、Intercom、LiveChat、Telegram Bot 页面、自建工单系统或任意客服 H5 页面。

`BOOTSTRAP_PROXY_URI` 为空时，客户端直连面板 API；配置后可用于面板 API 无法稳定直连的场景。

## 一键导入

Android 和 Windows 均支持：

```text
yourapp://install-config?authData=<v2board-auth-data>
```

网站侧可以在订阅页或用户中心生成该链接。客户端收到后会保存登录态并自动同步订阅。

网页按钮示例：

```html
<a href="yourapp://install-config?authData=USER_AUTH_DATA">一键导入客户端</a>
```

如果要同时兼容 Android 和 Windows，只要两端构建时使用同一个 `APP_URI_SCHEME` 即可。

注意：

- `authData` 应由面板为当前登录用户生成。
- 不建议在页面展示真实订阅 URL。
- 如果用户未安装客户端，可以在网页里提供 Android / Windows 下载按钮作为兜底。

## Android 构建

可在 `android/local.properties` 中设置：

```properties
appId=com.example.yourapp
appScheme=yourapp
```

也可以通过 Gradle 参数传入：

```bash
cd android
./gradlew assembleRelease -PAPP_ID=com.example.yourapp -PAPP_SCHEME=yourapp
```

示例：

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi \
  --dart-define=APP_DISPLAY_NAME="Your App" \
  --dart-define=APP_URI_SCHEME="yourapp" \
  --dart-define=V2BOARD_PANEL_URL="https://panel.example.com" \
  --dart-define=SUPPORT_WEB_URL="https://support.example.com"
```

签名文件不要提交到仓库。`android/app/keystore.jks`、`*.keystore`、`*.p12`、`*.pfx` 已在 `.gitignore` 中忽略。

### Android 发布前检查

- `appId` 必须使用自己的唯一包名。
- `appScheme` 必须和官网一键导入链接一致。
- 签名证书由机场自行生成并保管。
- 若要覆盖安装旧版本，包名和签名必须保持一致。

## Windows 构建

修改 `windows/packaging/exe/make_config.yaml`：

```yaml
app_name: Your App
publisher: Your Company
publisher_url: https://example.com
display_name: Your App
executable_name: YourApp.exe
output_base_file_name: YourApp-1.0.0-windows-setup
uri_scheme: yourapp
helper_service_name: YourAppHelperService
```

示例：

```bash
flutter build windows --release \
  --dart-define=APP_DISPLAY_NAME="Your App" \
  --dart-define=APP_URI_SCHEME="yourapp" \
  --dart-define=V2BOARD_PANEL_URL="https://panel.example.com"
```

### Windows 发布前检查

- `uri_scheme` 必须和 `APP_URI_SCHEME` 一致。
- `executable_name` 建议使用自己的品牌名，例如 `YourApp.exe`。
- `helper_service_name` 建议使用自己的品牌名，避免和其他客户端服务冲突。
- 如需兼容 Windows 7，需要额外测试兼容运行环境。

## 在线更新

如果配置了 `WINDOWS_UPDATE_URL` 或 `ANDROID_UPDATE_URL`，客户端会读取远程 JSON manifest。

示例：

```json
{
  "version": "1.0.1",
  "releaseNotes": "Bug fixes and experience improvements.",
  "packageUrl": "https://example.com/download/yourapp-1.0.1.apk",
  "packageUrlFallback": "https://mirror.example.com/yourapp-1.0.1.apk",
  "sha256": "optional-file-sha256",
  "size": 52428800,
  "setupUrl": "https://example.com/download/yourapp-1.0.1-setup.exe",
  "setupSha256": "optional-setup-sha256",
  "setupSize": 73400320
}
```

Android 会优先使用 `packageUrl`；Windows 如果提供 `setupUrl`，会优先使用安装包。

## 客服系统

模板只要求配置一个 `SUPPORT_WEB_URL`，不会绑定任何客服供应商。

可用形式：

- Crisp 页面
- Intercom 页面
- LiveChat 页面
- Telegram Bot 页面
- 自建工单系统
- 面板内客服 H5 页面

Windows 会使用独立 WebView 窗口打开客服；Android 会使用应用内 WebView，并保留返回后悬浮入口的逻辑。

## 启动代理

如果机场面板 API 在部分地区无法直连，可以配置：

```bash
--dart-define=BOOTSTRAP_PROXY_URI="protocol://user:password@host:port?option=value"
```

模板不会内置任何代理节点。其他机场应在自己的构建流程中注入自己的启动代理。

## 验证

当前模板已验证：

- `flutter analyze`
- Android arm64 release APK 构建
- Windows x64 release 构建

## 上游与致谢

本项目基于以下开源项目：

- [Bettbox](https://github.com/appshubcc/Bettbox)
- [Mihomo](https://github.com/MetaCubeX/mihomo)
- [FlClash](https://github.com/chen08209/FlClash)

## License

延续上游项目的 GPL-3.0 license。使用、修改和分发时请遵守对应开源协议。
