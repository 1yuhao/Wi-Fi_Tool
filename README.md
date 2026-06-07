# Wi-Fi 配置工具

一个 macOS 菜单栏小工具，用来按当前 Wi-Fi 自动切换网络配置。适合“家里需要手动 IP，其他 Wi-Fi 使用 DHCP”这类场景。

## 功能

- SwiftUI `MenuBarExtra` 菜单栏界面
- 中文界面
- 多 Wi-Fi 配置档
- 每个配置档可选择 `手动 IP` 或 `DHCP`
- 自动识别当前 Wi-Fi SSID、Wi-Fi 服务名和当前 IP 配置模式
- 自动应用匹配配置
- 未匹配 Wi-Fi 可自动恢复 DHCP
- 开机自动启动开关
- IP、子网掩码、路由器和 DNS 基础格式校验
- 当前网络配置快照，可填入选中配置档或保存为新配置档
- 检查配置功能，不修改系统网络也能看到匹配结果
- 成功、警告、错误状态反馈
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

首次启动后，在菜单栏点 Wi-Fi 图标，新增或编辑配置档。打开 `自动应用匹配配置` 后，工具会每 30 秒检测当前 Wi-Fi 并按规则应用配置。

修改网络配置会调用 macOS 自带的 `/usr/sbin/networksetup`，系统会弹出管理员授权窗口。

## 要求

- macOS 13 或更新版本
- Xcode Command Line Tools
- Swift 6 或兼容版本
