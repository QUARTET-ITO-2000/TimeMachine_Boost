# Time Machine Boost

> A macOS utility to toggle the low-priority disk I/O throttling used by Time Machine backups, with a real-time Time Machine log viewer.

**Languages:** English | [简体中文](README.zh-CN.md) | [Español](README.es.md)

## Overview

Time Machine backups are treated as low-priority I/O. macOS deliberately throttles them so backups do not slow down the work you are doing. This project gives you two small tools to control that throttle and watch what Time Machine is doing:

- a native macOS **GUI** with an on/off switch;
- a dependency-free **shell TUI/CLI** for terminals and scripts.

> ⚠️ Disabling the throttle can make the whole system feel slower while a backup is running. The setting is runtime-only and resets after you reboot. Keeping it permanently disabled is **not recommended**.

## How it works

macOS exposes the throttle through a kernel parameter:

| Value | Meaning |
| --- | --- |
| `debug.lowpri_throttle_enabled = 1` | System default: low-priority I/O throttling is enabled |
| `debug.lowpri_throttle_enabled = 0` | Boost mode: low-priority I/O throttling is disabled |

The value is applied at runtime and returns to the default after a reboot. This project never installs a permanent startup configuration.

## Features

### GUI

- Native system switch that reads and shows the real current state on launch.
- Toggles through the system administrator authorization dialog, then **reads the value back** to verify the change instead of assuming success.
- Fallback “read with administrator privileges” button when the value cannot be read directly.
- Dedicated log window that streams Time Machine logs in real time, with clear/autoscroll support. Closing the window stops and hides it; the app keeps running.
- Trilingual interface: English (default), 简体中文 and Español. Follows the system language and can also be chosen from the main window.
- No third-party dependencies.

### Shell

- Parameterized CLI: `--status`, `--on`, `--off`, `--toggle`.
- Interactive pure-shell TUI with state refresh, sudo credential management and a live log viewer.
- Language selection through `--lang en|zh|es`, `TIME_MACHINE_BOOST_LANG`, or locale variables (English fallback).
- Same kernel parameter and behavior as the GUI.

## Requirements

- macOS 13 or later (GUI developed and verified on macOS 26 / arm64)
- An administrator account (required when toggling)
- AppKit for the GUI; no third-party dependencies
- Interface languages: English, 简体中文, Español

## Usage

### GUI

```sh
open TimeMachineBoost.app
```

1. The switch shows the current state after launch.
2. Toggling opens the macOS administrator authorization dialog; after approval, the app changes the value and verifies it by reading it back.
3. Click **Real-time logs…** to open the log window. If no backup is running there is usually no new output; run `tmutil startbackup` to trigger one.
4. Closing the log window stops and hides it only. Open it again to start a fresh stream.
5. Use the **Language** menu at the bottom of the window to switch the interface language (English, 简体中文, Español). The app restarts after confirmation.

> In this prototype every toggle asks for administrator authorization. An “authorize once, toggle many times” flow requires a privileged LaunchDaemon helper.

### Shell

```sh
chmod +x boost_time_machine_tui.sh
./boost_time_machine_tui.sh              # interactive TUI
./boost_time_machine_tui.sh --status     # read state only, no sudo prompt
./boost_time_machine_tui.sh --on         # enable boost (value 0)
./boost_time_machine_tui.sh --off        # restore default (value 1)
./boost_time_machine_tui.sh --toggle     # toggle directly
./boost_time_machine_tui.sh --help
./boost_time_machine_tui.sh --lang es    # run in Spanish
TIME_MACHINE_BOOST_LANG=zh ./boost_time_machine_tui.sh --status
```

Language precedence: `--lang` > `TIME_MACHINE_BOOST_LANG` > `LC_ALL`/`LC_MESSAGES`/`LANG` > English.

TUI shortcuts:

| Key | Action |
| --- | --- |
| `Space` / `T` | Toggle boost |
| `O` | Enable boost |
| `D` | Restore default |
| `R` | Refresh state |
| `A` | Refresh sudo authorization |
| `L` | Stream Time Machine logs (any key returns) |
| `Q` | Quit |

## Building from source

No third-party dependencies; only the Xcode Command Line Tools are required.

```sh
cd App
sh build.sh                 # creates App/TimeMachineBoost.app
sh build.sh /tmp/dist       # or pass an output directory
```

Verify the signature:

```sh
codesign --verify --deep --strict TimeMachineBoost.app
```

## Repository layout

```text
TimeMachineBoost/
├── README.md                 # English
├── README.zh-CN.md           # 简体中文
├── README.es.md              # Español
├── LICENSE                   # MIT
├── App/                      # native GUI
│   ├── main.m                # AppKit main program (switch + log window)
│   ├── Info.plist
│   ├── build.sh
│   └── Resources/            # Localizable.strings
│       ├── en.lproj
│       ├── zh-Hans.lproj
│       └── es.lproj
└── boost_time_machine_tui.sh # pure-shell TUI/CLI
```

## Permissions

| Action | What is needed |
| --- | --- |
| Read current state | Usually readable directly; restricted/sandboxed environments need the privileged read fallback |
| Change the value | Root. GUI uses `osascript … with administrator privileges`; shell uses `sudo sysctl` |
| Stream logs | `/usr/bin/log stream --predicate 'subsystem == "com.apple.TimeMachine"'`; normally no admin required |

## FAQ

### Closing the log window quits the app / crashes?

No. Since v0.3 the log window is stopped and hidden instead of being destroyed, avoiding a release-during-close-animation crash. v0.4 adds the trilingual interface. If you still see an unexpected exit, please attach the crash report.

### Why is there no “auto-enable after boot” option?

Deliberately omitted. That kernel parameter protects system responsiveness during backups, and keeping it disabled permanently is not recommended. A persistent version would need a LaunchDaemon plus an explicit risk warning in the UI.

### The toggle succeeded but the state did not change?

The app verifies the result by reading the value back after each change. If the readback fails, it reports “command executed but verification did not return the target value” instead of pretending the operation succeeded. Please confirm your macOS version still supports this parameter.

## Version history

- **v0.5**: Added an in-window language selector (English / 简体中文 / Español).
- **v0.4**: Trilingual UI (English default, 简体中文, Español) for the GUI and shell tools.
- **v0.3**: Fixed the crash when closing the log window; it now stops and hides instead.
- **v0.2**: Added the real-time Time Machine log window.
- **v0.1**: Initial GUI switch prototype.

## License

Released under the [MIT License](LICENSE).

Copyright © 2026 QUARTETTO D'ARCHI
