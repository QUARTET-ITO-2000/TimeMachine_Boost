#!/bin/sh

# Pure-shell TUI for toggling macOS low-priority I/O throttling.
SYSCTL_KEY="debug.lowpri_throttle_enabled"
SYSCTL_BIN=$(command -v sysctl 2>/dev/null || true)
SUDO_BIN=$(command -v sudo 2>/dev/null || true)
TPUT_BIN=$(command -v tput 2>/dev/null || true)
LOG_BIN=""
if [ -x /usr/bin/log ]; then
    LOG_BIN="/usr/bin/log"
else
    LOG_BIN=$(command -v log 2>/dev/null || true)
fi

STATE_VALUE="?"
STATE_LABEL="未知"
STATE_HINT="尚未读取状态"
LAST_MESSAGE="按 R 刷新状态，按 Space 或 T 切换。"
ORIG_STTY=""
TUI_ACTIVE=0
LOG_PID=""

if [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
    printf '%s\n' "错误：这个脚本只支持 macOS。" >&2
    exit 1
fi

if [ -z "$SYSCTL_BIN" ]; then
    printf '%s\n' "错误：找不到 sysctl 命令。" >&2
    exit 1
fi

if [ -t 1 ]; then
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    RED=$(printf '\033[31m')
    CYAN=$(printf '\033[36m')
    BOLD=$(printf '\033[1m')
    RESET=$(printf '\033[0m')
else
    GREEN=""
    YELLOW=""
    RED=""
    CYAN=""
    BOLD=""
    RESET=""
fi

tput_safe() {
    if [ -n "$TPUT_BIN" ] && [ -n "${TERM-}" ]; then
        "$TPUT_BIN" "$@" 2>/dev/null || true
    fi
}

clear_screen() {
    if [ -n "$TPUT_BIN" ] && [ -n "${TERM-}" ]; then
        tput_safe clear
    else
        printf '\033[H\033[2J'
    fi
}

read_state_plain() {
    "$SYSCTL_BIN" -n "$SYSCTL_KEY" 2>/dev/null
}

read_state_cached_sudo() {
    if [ -n "$SUDO_BIN" ] && "$SUDO_BIN" -n true 2>/dev/null; then
        "$SUDO_BIN" -n "$SYSCTL_BIN" -n "$SYSCTL_KEY" 2>/dev/null
        return $?
    fi

    return 1
}

refresh_state() {
    state=$(read_state_plain)
    status=$?

    if [ "$status" -ne 0 ] || [ -z "$state" ]; then
        state=$(read_state_cached_sudo)
        status=$?
    fi

    if [ "$status" -ne 0 ] || [ -z "$state" ]; then
        STATE_VALUE="?"
        STATE_LABEL="无法读取"
        STATE_HINT="可能需要管理员授权，按 A 授权后再刷新。"
        return 1
    fi

    case "$state" in
        0)
            STATE_VALUE="0"
            STATE_LABEL="ON - 加速模式"
            STATE_HINT="低优先级 I/O 节流已关闭；Time Machine 备份可能更快。"
            ;;
        1)
            STATE_VALUE="1"
            STATE_LABEL="OFF - 系统默认"
            STATE_HINT="低优先级 I/O 节流已开启；这是 macOS 默认状态。"
            ;;
        *)
            STATE_VALUE="$state"
            STATE_LABEL="未知值"
            STATE_HINT="系统返回了非预期值，请谨慎操作。"
            ;;
    esac
}

restore_terminal() {
    if [ "$TUI_ACTIVE" -eq 1 ]; then
        if [ -n "$LOG_PID" ]; then
            kill "$LOG_PID" 2>/dev/null || true
            wait "$LOG_PID" 2>/dev/null || true
            LOG_PID=""
        fi
        if [ -n "$ORIG_STTY" ]; then
            stty "$ORIG_STTY" 2>/dev/null || true
        fi
        tput_safe cnorm
        TUI_ACTIVE=0
    fi
}

enter_terminal_mode() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf '%s\n' "错误：TUI 模式需要交互式终端。" >&2
        exit 1
    fi

    if [ -z "$ORIG_STTY" ]; then
        ORIG_STTY=$(stty -g 2>/dev/null || true)
    fi

    stty -echo cbreak 2>/dev/null || stty raw -echo 2>/dev/null || true
    tput_safe civis
    TUI_ACTIVE=1
}

read_key() {
    dd bs=1 count=1 2>/dev/null
}

draw_ui() {
    clear_screen
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
    printf '%s|%s %sTime Machine Boost TUI%s                                 %s|%s\n' "$CYAN" "$RESET" "$BOLD" "$RESET" "$CYAN" "$RESET"
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
    printf '  Boost 状态 : '
    case "$STATE_VALUE" in
        0)
            printf '%s%s%s\n' "$GREEN" "$STATE_LABEL" "$RESET"
            ;;
        1)
            printf '%s%s%s\n' "$YELLOW" "$STATE_LABEL" "$RESET"
            ;;
        *)
            printf '%s%s%s\n' "$RED" "$STATE_LABEL" "$RESET"
            ;;
    esac
    printf '  Sysctl     : %s = %s\n' "$SYSCTL_KEY" "$STATE_VALUE"
    printf '  提示       : %s\n' "$STATE_HINT"
    printf '\n'
    printf '  [Space/T] 切换开关      [O] 开启加速      [D] 恢复默认\n'
    printf '  [R]       刷新状态      [A] 授权 sudo     [L] 实时日志\n'
    printf '  [Q]       退出\n'
    printf '\n'
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
    printf '  消息：%s\n' "$LAST_MESSAGE"
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
}

pause_message() {
    LAST_MESSAGE="$1 按任意键继续。"
    draw_ui
    read_key >/dev/null
}

show_live_log() {
    if [ -z "$LOG_BIN" ]; then
        LAST_MESSAGE="找不到 log 命令，无法显示实时日志。"
        return 1
    fi

    clear_screen
    printf '%s\n' "实时 Time Machine 日志（按任意键返回 TUI）"
    printf '%s\n' "提示：备份未运行时通常没有新事件；可另开终端执行 tmutil startbackup。"
    printf '%s\n' "--------------------------------------------------------------"

    "$LOG_BIN" stream \
        --predicate 'subsystem == "com.apple.TimeMachine"' \
        --style compact 2>&1 &
    LOG_PID=$!

    read_key >/dev/null
    kill "$LOG_PID" 2>/dev/null || true
    wait "$LOG_PID" 2>/dev/null || true
    LOG_PID=""
    LAST_MESSAGE="已从实时日志返回 TUI。"
    return 0
}

ensure_sudo() {
    if [ -z "$SUDO_BIN" ]; then
        LAST_MESSAGE="找不到 sudo 命令，无法修改系统设置。"
        return 1
    fi

    if "$SUDO_BIN" -n true 2>/dev/null; then
        return 0
    fi

    restore_terminal
    printf '\n%s\n' "需要管理员授权，才能读取或修改 ${SYSCTL_KEY}。"
    printf '%s\n' "请输入管理员密码；完成后会回到 TUI。"

    if "$SUDO_BIN" -v; then
        enter_terminal_mode
        LAST_MESSAGE="sudo 授权已更新。"
        return 0
    fi

    enter_terminal_mode
    LAST_MESSAGE="sudo 授权失败，未执行任何修改。"
    return 1
}

set_state() {
    target=$1
    label=$2

    if ! ensure_sudo; then
        return 1
    fi

    if "$SUDO_BIN" -n "$SYSCTL_BIN" "$SYSCTL_KEY=$target" >/dev/null 2>&1; then
        refresh_state
        if [ "$STATE_VALUE" = "$target" ]; then
            LAST_MESSAGE="${label}已完成，并已验证当前状态。"
            return 0
        fi

        LAST_MESSAGE="命令已执行，但状态验证未返回目标值。"
        return 1
    fi

    LAST_MESSAGE="${label}失败，系统拒绝了 sysctl 修改。"
    refresh_state
    return 1
}

confirm_action() {
    prompt=$1
    LAST_MESSAGE="${prompt} 按 Y 确认，其他键取消。"
    draw_ui
    key=$(read_key)

    case "$key" in
        y|Y)
            return 0
            ;;
        *)
            LAST_MESSAGE="已取消。"
            return 1
            ;;
    esac
}

toggle_state() {
    refresh_state
    case "$STATE_VALUE" in
        0)
            set_state 1 "恢复系统默认"
            ;;
        1)
            set_state 0 "开启加速模式"
            ;;
        *)
            LAST_MESSAGE="无法切换：当前状态未知。可以先按 A 授权，再按 R 刷新。"
            return 1
            ;;
    esac
}

show_help() {
    cat <<EOF
用法：
  $(basename "$0")            启动 Shell TUI
  $(basename "$0") --status   只显示当前状态，不弹出 sudo 密码
  $(basename "$0") --on       开启加速模式
  $(basename "$0") --off      恢复系统默认
  $(basename "$0") --toggle   直接切换当前状态
  $(basename "$0") --help     显示帮助

TUI 快捷键：
  Space / T   切换开关
  O           开启加速模式
  D           恢复系统默认
  R           刷新状态
  A           更新 sudo 授权
  L           实时查看 Time Machine 日志（任意键返回）
  Q           退出

说明：
  加速模式会将 $SYSCTL_KEY 设为 0。
  恢复默认会将 $SYSCTL_KEY 设为 1。
  实时日志通过 /usr/bin/log stream 显示，不会修改任何系统设置。
  这是全局运行时设置，本脚本不会写入永久启动配置。
EOF
}

print_status() {
    if refresh_state; then
        printf '%s\n' "$STATE_LABEL"
        printf '%s = %s\n' "$SYSCTL_KEY" "$STATE_VALUE"
        return 0
    fi

    printf '%s\n' "无法读取 ${SYSCTL_KEY}。可以启动 TUI 后按 A 授权再刷新。" >&2
    return 1
}

cli_set_state() {
    target=$1
    label=$2

    if [ -z "$SUDO_BIN" ]; then
        printf '%s\n' "错误：找不到 sudo 命令。" >&2
        return 1
    fi

    printf '%s\n' "正在${label}，可能需要输入管理员密码……"
    if "$SUDO_BIN" "$SYSCTL_BIN" "$SYSCTL_KEY=$target"; then
        refresh_state >/dev/null 2>&1 || true
        printf '%s\n' "${label}完成。"
        return 0
    fi

    printf '%s\n' "${label}失败。" >&2
    return 1
}

cli_toggle() {
    refresh_state >/dev/null 2>&1
    if [ "$STATE_VALUE" = "?" ]; then
        if [ -n "$SUDO_BIN" ]; then
            "$SUDO_BIN" -v || return 1
            refresh_state >/dev/null 2>&1 || true
        fi
    fi

    case "$STATE_VALUE" in
        0)
            cli_set_state 1 "恢复系统默认"
            ;;
        1)
            cli_set_state 0 "开启加速模式"
            ;;
        *)
            printf '%s\n' "无法切换：当前状态未知。" >&2
            return 1
            ;;
    esac
}

run_tui() {
    enter_terminal_mode
    trap 'restore_terminal; printf "\n"; exit 130' INT TERM
    trap 'restore_terminal' EXIT

    refresh_state >/dev/null 2>&1 || true

    while :; do
        draw_ui
        key=$(read_key)

        case "$key" in
            q|Q)
                LAST_MESSAGE="已退出。"
                break
                ;;
            r|R)
                if refresh_state; then
                    LAST_MESSAGE="状态已刷新。"
                else
                    LAST_MESSAGE="刷新失败。按 A 授权后可再试。"
                fi
                ;;
            a|A)
                ensure_sudo
                refresh_state >/dev/null 2>&1 || true
                ;;
            l|L)
                show_live_log
                ;;
            t|T|" ")
                if confirm_action "确定切换当前开关？"; then
                    toggle_state
                fi
                ;;
            o|O)
                if confirm_action "确定开启加速模式？"; then
                    set_state 0 "开启加速模式"
                fi
                ;;
            d|D)
                if confirm_action "确定恢复系统默认？"; then
                    set_state 1 "恢复系统默认"
                fi
                ;;
            *)
                LAST_MESSAGE="未识别的按键。按 Q 退出，按 R 刷新。"
                ;;
        esac
    done

    restore_terminal
    trap - INT TERM EXIT
    printf '%s\n' "已退出 Time Machine Boost TUI。"
}

case "${1-}" in
    "")
        run_tui
        ;;
    --status)
        print_status
        ;;
    --on)
        cli_set_state 0 "开启加速模式"
        ;;
    --off)
        cli_set_state 1 "恢复系统默认"
        ;;
    --toggle)
        cli_toggle
        ;;
    -h|--help)
        show_help
        ;;
    *)
        printf '%s未知参数：%s%s\n\n' "$RED" "$1" "$RESET" >&2
        show_help >&2
        exit 2
        ;;
esac
