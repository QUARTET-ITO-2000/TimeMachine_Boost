# Time Machine Boost

> 一个 macOS 小工具：一键控制 Time Machine 备份使用的低优先级磁盘 I/O 节流，并实时查看 Time Machine 日志。

**语言：** [English](README.md) | 简体中文 | [Español](README.es.md)

## 简介

Time Machine 备份属于低优先级 I/O，macOS 会刻意限速，以免备份时拖慢你正在做的事情。本项目提供两个小工具来控制这个节流开关，并观察 Time Machine 正在做什么：

- 原生 macOS **GUI**（带开关）；
- 无第三方依赖的 **Shell TUI/CLI**，适合终端和脚本。

> ⚠️ 关闭节流后，备份期间系统整体可能感觉更卡。该设置只对本次开机生效，重启后恢复系统默认。**不建议**长期关闭。

## 原理

macOS 通过内核参数暴露这个节流开关：

| 值 | 含义 |
| --- | --- |
| `debug.lowpri_throttle_enabled = 1` | 系统默认：低优先级 I/O 节流开启 |
| `debug.lowpri_throttle_enabled = 0` | 加速模式：低优先级 I/O 节流关闭 |

该值在运行时生效，重启后恢复默认。本项目不会写入任何永久启动配置。

## 功能特性

### GUI

- 原生系统开关，启动时读取并显示真实状态；
- 通过系统管理员授权框切换，并在同一轮授权内“设置 + 回读验证”，不会假装成功；
- 直接读取受限时，可用“以管理员权限读取”兜底；
- 独立日志窗口实时展示 Time Machine 日志，支持清空与自动滚动；关闭窗口只会停止并隐藏，App 不退出；
- 界面支持英语（默认）、简体中文和西班牙语，跟随系统语言，也可在主窗口内手动选择；
- 无第三方依赖。

### Shell

- 参数化 CLI：`--status`、`--on`、`--off`、`--toggle`；
- 交互式纯 Shell TUI：状态刷新、sudo 凭据管理、实时日志；
- 通过 `--lang en|zh|es`、`TIME_MACHINE_BOOST_LANG` 或系统区域设置切换语言（兜底英语）；
- 与 GUI 使用同一内核参数，行为一致。

## 系统要求

- macOS 13 或更高（GUI 在 macOS 26 / arm64 上开发验证）
- 管理员账户（切换时需要授权）
- GUI 依赖 AppKit；无第三方依赖
- 界面语言：英语、简体中文、西班牙语

## 使用方法

### GUI

```sh
open TimeMachineBoost.app
```

1. 启动后开关会显示当前真实状态；
2. 拨动开关会弹出系统管理员授权框，授权后完成切换并回读验证；
3. 点击“实时日志…”打开日志窗口；没有备份活动时通常没有新输出，可先执行 `tmutil startbackup`；
4. 关闭日志窗口只会停止并隐藏，再次打开会重新开始监听。
5. 使用主窗口底部的“语言”菜单可切换界面语言（English / 简体中文 / Español），确认后 App 会重启生效。

> 原型阶段每次切换都会请求管理员授权；要做到“授权一次、多次切换”，需要引入特权 LaunchDaemon helper。

### Shell

```sh
chmod +x boost_time_machine_tui.sh
./boost_time_machine_tui.sh              # 进入交互式 TUI
./boost_time_machine_tui.sh --status     # 只读状态，不弹 sudo 密码
./boost_time_machine_tui.sh --on         # 开启加速（= 0）
./boost_time_machine_tui.sh --off        # 恢复系统默认（= 1）
./boost_time_machine_tui.sh --toggle     # 直接切换
./boost_time_machine_tui.sh --help
./boost_time_machine_tui.sh --lang es    # 以西班牙语运行
TIME_MACHINE_BOOST_LANG=zh ./boost_time_machine_tui.sh --status
```

语言优先级：`--lang` > `TIME_MACHINE_BOOST_LANG` > `LC_ALL`/`LC_MESSAGES`/`LANG` > 英语。

TUI 快捷键：

| 按键 | 功能 |
| --- | --- |
| `Space` / `T` | 切换开关 |
| `O` | 开启加速 |
| `D` | 恢复默认 |
| `R` | 刷新状态 |
| `A` | 更新 sudo 授权 |
| `L` | 实时查看 Time Machine 日志（任意键返回） |
| `Q` | 退出 |

## 从源码构建

无第三方依赖，只需要 Xcode Command Line Tools。

```sh
cd App
sh build.sh                 # 生成 App/TimeMachineBoost.app
sh build.sh /tmp/dist       # 或指定输出目录
```

校验签名：

```sh
codesign --verify --deep --strict TimeMachineBoost.app
```

## 工程结构

```text
TimeMachineBoost/
├── README.md                 # English
├── README.zh-CN.md           # 简体中文
├── README.es.md              # Español
├── LICENSE                   # MIT
├── App/                      # 原生 GUI
│   ├── main.m                # AppKit 主程序（开关 + 日志窗口）
│   ├── Info.plist
│   ├── build.sh
│   └── Resources/            # Localizable.strings
│       ├── en.lproj
│       ├── zh-Hans.lproj
│       └── es.lproj
└── boost_time_machine_tui.sh # 纯 Shell TUI/CLI
```

## 代码签名与分发说明

- 发布包仅做了 **ad-hoc 签名**，本项目**未加入 Apple Developer Program**。
- GUI 未使用 Developer ID 签名，也未经过 Apple 公证，因此从网上下载后 macOS 可能提示“无法验证开发者”。
- 打开方式：右键点击 App → 选择**打开**；或在终端中移除隔离属性：
  ```sh
  xattr -dr com.apple.quarantine /Applications/TimeMachineBoost.app
  ```
- 若要向公众分发，需要加入 Apple Developer Program、申请 Developer ID Application 证书并完成公证；在此之前请把 Release 构建视为个人/测试用途。
- Shell TUI/CLI 不受代码签名影响。

## 权限说明

| 操作 | 所需权限 |
| --- | --- |
| 读取当前状态 | 普通环境通常可直接读取；受限/沙盒环境需要“以管理员权限读取” |
| 修改状态 | root。GUI 用 `osascript … with administrator privileges`，Shell 用 `sudo sysctl` |
| 实时日志 | `/usr/bin/log stream --predicate 'subsystem == "com.apple.TimeMachine"'`，一般不需要管理员权限 |

## 常见问题

### 关闭日志窗口会导致程序退出/崩溃？

不会。v0.3 起日志窗口关闭时只“停止并隐藏”，不再销毁窗口，避免关闭动画期间释放导致的崩溃。v0.4 加入了三语界面。若仍异常退出，请附上崩溃报告。

### 为什么没有“开机自动加速”选项？

刻意不加。该内核参数用于保护备份期间的系统响应速度，长期关闭并不推荐。若要持久化，需要 LaunchDaemon 并在 UI 中明确提示风险。

### 切换成功但状态没有变化？

工具每次修改后都会回读验证。若回读失败，界面会提示“命令已执行但验证未返回目标值”，不会假装成功。请确认你的 macOS 版本仍支持该参数。

## 版本记录

- **v0.5.2**：加入自定义 App 图标。
- **v0.5.1**：修复启动后开关需先点击“刷新状态”才能使用的问题。
- **v0.5**：主窗口新增语言选择器（English / 简体中文 / Español）。
- **v0.4**：GUI 与 Shell 工具支持三语界面（英语默认、简体中文、西班牙语）。
- **v0.3**：修复关闭日志窗口导致的崩溃；改为停止并隐藏。
- **v0.2**：新增实时 Time Machine 日志窗口。
- **v0.1**：GUI 开关原型。

## 许可证

本项目以 [MIT License](LICENSE) 发布。

Copyright © 2026 QUARTETTO D'ARCHI
