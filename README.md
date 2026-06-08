# Wi-Fi 配置工具

一个 macOS 菜单栏工具，用来按当前连接的 Wi-Fi 快速切换网络配置。它适合这类场景：家里的 Wi-Fi 需要固定手动 IP、路由器和 DNS；到了公司、咖啡店、酒店或其他网络时，希望一键恢复 DHCP，或者自动恢复 DHCP。

工具使用 SwiftUI 和 AppKit 构建，常驻菜单栏，不需要打开系统设置来回改网络参数。

## 主要功能

- 菜单栏常驻入口，点击后打开配置面板。
- 提供简约 app 图标，安装到应用目录后可在 Finder 中识别。
- 自动读取当前 Wi-Fi 名称、IP、子网掩码、路由器和 DNS。
- 将当前网络配置保存为一个配置选项。
- 当前 Wi-Fi 名称会默认绑定同名配置。
- 连接到已保存的 Wi-Fi 时，自动选中匹配的配置。
- 支持手动切换到其他配置，刷新时不会立刻覆盖你的手动选择。
- 一键应用选中配置。
- 一键恢复 DHCP，并清空残留的手动 DNS。
- 支持多个 Wi-Fi 配置档。
- 支持手动 IP 和 DHCP 两种配置模式。
- 支持自动应用匹配配置。
- 支持未匹配 Wi-Fi 自动恢复 DHCP。
- 支持开机自动启动。
- 修改网络配置时使用 macOS 授权服务，同一次运行中会复用管理员授权，减少重复输入密码。
- 配置保存在本机 `UserDefaults`，不会上传。

## 推荐使用流程

### 1. 安装并启动

```zsh
./scripts/install_app.sh
open ~/Applications/WiFiConfigTool.app
```

启动后，菜单栏会出现 `WiFi` 入口。点击菜单栏入口即可打开工具；再次打开 app 也会弹出普通配置窗口。

### 2. 允许读取 Wi-Fi 名称

macOS 会把 Wi-Fi 名称视为位置相关信息。第一次启动时，系统可能会弹出位置权限请求。

请选择 `允许`。如果拒绝，工具仍然可以读取 IP、路由器和 DNS，但无法自动读取当前 Wi-Fi 名称，也就无法自动匹配配置。

如果之前点过 `不允许`，可以在：

```text
系统设置 -> 隐私与安全性 -> 定位服务
```

中为 `Wi-Fi 配置工具` 打开权限，然后回到工具里点击刷新。

### 3. 保存当前 Wi-Fi 配置

连接到需要保存的 Wi-Fi 后：

1. 确认面板中的当前网络信息正确。
2. 点击 `保存为选项`。
3. 工具会以当前 Wi-Fi 名称作为默认配置名。

如果 macOS 暂时没有返回 Wi-Fi 名称，也可以手动填写 `Wi-Fi 名称` 后再保存。

### 4. 应用或恢复配置

- 点击 `应用选中配置`：把当前 Wi-Fi 切换到选中的保存配置。
- 点击 `一键恢复 DHCP`：把当前 Wi-Fi 网络服务恢复为 DHCP，并把 DNS 恢复为系统自动状态。

第一次修改网络配置时，macOS 会要求管理员授权。授权后，同一次 app 运行期间会复用授权，避免每次都输入密码。

### 5. 开启自动切换

展开 `高级设置`，可以开启：

- `连接匹配的 Wi-Fi 时自动应用配置`
- `其他 Wi-Fi 自动恢复 DHCP`
- `开机后自动运行`

开启自动应用后，工具会定期刷新当前 Wi-Fi 状态，并按保存的配置执行匹配规则。

## 配置匹配规则

工具使用 Wi-Fi 名称作为匹配依据：

```text
当前 Wi-Fi 名称 == 配置中的 Wi-Fi 名称
```

如果匹配成功，工具会自动选中对应配置。

如果同一个 Wi-Fi 保存了多个配置，当前手动选中的配置会优先保留。

如果连接到了新的 Wi-Fi，工具会重新按新 Wi-Fi 名称匹配配置。

## 权限说明

### 位置权限

读取当前 Wi-Fi 名称需要位置权限。这是 macOS 的系统限制，不是工具额外采集位置。

工具只使用该权限读取当前 SSID，用于保存和匹配网络配置。

### 管理员权限

修改 IP、路由器、DNS 或恢复 DHCP 需要管理员权限。工具通过 macOS Authorization Services 执行 `/usr/sbin/networksetup`。

管理员授权只在当前 app 运行期间缓存。退出 app 后，下次修改网络配置可能需要重新授权。

## 构建

要求：

- macOS 13 或更新版本
- Xcode Command Line Tools
- Swift 6 或兼容版本

调试构建：

```zsh
swift build
```

打包 `.app`：

```zsh
./scripts/build_app.sh
```

打包脚本会自动生成 `AppIcon.icns`，写入 app bundle，并对应用做本地签名。

构建完成后会输出：

```text
/private/tmp/WiFiConfigToolBuild/WiFiConfigTool.app
```

安装到当前用户的应用目录：

```zsh
./scripts/install_app.sh
```

安装位置：

```text
~/Applications/WiFiConfigTool.app
```

## 项目结构

```text
Package.swift
Sources/
  AuthorizationShim/
    AuthorizationShim.c
    include/AuthorizationShim.h
  WiFiConfigTool/
    AdministratorCommandRunner.swift
    ContentView.swift
    Models.swift
    NetworkSetup.swift
    StatusBarController.swift
    WiFiConfigToolApp.swift
    WiFiController.swift
    WiFiNameAccess.swift
scripts/
  build_app.sh
  generate_app_icon.swift
  install_app.sh
```

核心模块：

- `ContentView.swift`：SwiftUI 配置界面。
- `StatusBarController.swift`：菜单栏入口、弹窗和普通配置窗口。
- `WiFiController.swift`：配置状态、自动匹配、自动应用和用户操作。
- `NetworkSetup.swift`：读取和应用 macOS 网络配置。
- `WiFiNameAccess.swift`：请求读取 Wi-Fi 名称所需的位置权限。
- `AdministratorCommandRunner.swift`：缓存管理员授权并执行网络修改命令。
- `AuthorizationShim`：用于调用 macOS 授权执行接口的 C shim。
- `generate_app_icon.swift`：生成简约 app 图标并供打包脚本转换为 `.icns`。

## 常见问题

### 菜单栏没有看到 app

确认 app 正在运行：

```zsh
pgrep -afil WiFiConfigTool
```

如果安装后没有出现，可以重新打开：

```zsh
open ~/Applications/WiFiConfigTool.app
```

如果使用 Bartender 等菜单栏管理工具，也可能需要检查是否被隐藏。

### 当前 Wi-Fi 显示“名称不可用”

通常是位置权限没有允许。请到系统设置中为 `Wi-Fi 配置工具` 打开定位服务权限，然后点击刷新。

### 为什么修改配置还要管理员权限

macOS 修改网络服务配置必须经过管理员授权。工具已经尽量减少重复输入密码，但首次应用配置仍需要系统授权。

### 恢复 DHCP 后 DNS 会怎样

`一键恢复 DHCP` 会同时执行两件事：

```text
networksetup -setdhcp <Wi-Fi 服务名>
networksetup -setdnsservers <Wi-Fi 服务名> Empty
```

也就是说，手动 DNS 会被清空，DNS 会回到系统自动获取状态。

### 自动应用没有生效

请确认：

- `高级设置` 中已经开启自动应用。
- 当前 Wi-Fi 名称可以被读取。
- 已保存配置中的 Wi-Fi 名称和当前 Wi-Fi 完全一致。
- 配置中的 IP、子网掩码、路由器和 DNS 格式有效。

## 数据存储

配置保存在当前用户的 `UserDefaults` 中，key 为：

```text
WiFiConfigTool.settings.v2
```

工具不会上传配置，也不会写入云端。

## 适用场景

- 家庭网络需要固定 IP，外出网络使用 DHCP。
- 多个 Wi-Fi 环境需要不同 IP/DNS 配置。
- 经常需要在手动 IP 和 DHCP 之间切换。
- 希望把网络配置切换变成菜单栏里的一次点击。
