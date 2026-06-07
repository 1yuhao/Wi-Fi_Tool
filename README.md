# Wi-Fi Config Tool

一个 macOS 菜单栏小工具，用来在指定的家庭 Wi-Fi 下套用手动 IP 配置，并在连接到其他 Wi-Fi 时切回 DHCP。

## 功能

- SwiftUI `MenuBarExtra` 菜单栏界面
- 自动识别当前 Wi-Fi SSID、Wi-Fi 服务名和当前 IP 配置模式
- 家庭 Wi-Fi：套用手动 IP、子网掩码、路由器和 DNS
- 其他 Wi-Fi：切换回 DHCP
- 自动应用开关，避免每 30 秒重复弹管理员授权
- 本地保存配置到 `UserDefaults`

## 构建

```zsh
./scripts/build_app.sh
```

构建完成后会输出：

```text
/private/tmp/WiFiConfigToolBuild/WiFiConfigTool.app
```

## 安装到本机用户应用目录

```zsh
./scripts/install_app.sh
```

安装完成后会输出：

```text
~/Applications/WiFiConfigTool.app
```

首次启动后，在菜单栏点 Wi-Fi 图标，填写家庭 Wi-Fi 的 SSID、固定 IP、子网掩码、路由器和 DNS。打开 `Auto apply` 后，工具会每 30 秒检测当前 Wi-Fi 并按规则应用配置。

修改网络配置会调用 macOS 自带的 `/usr/sbin/networksetup`，系统会弹出管理员授权窗口。

## 要求

- macOS 13 或更新版本
- Xcode Command Line Tools
- Swift 6 或兼容版本
