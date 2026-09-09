#!/bin/sh

# Pure-shell TUI/CLI for toggling macOS low-priority I/O throttling.
# Languages: English (default), 简体中文, Español.
# Language selection: --lang zh|es|en > TIME_MACHINE_BOOST_LANG > LC_ALL/LC_MESSAGES/LANG > en

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

LANG_REQUESTED=""
if [ "${1-}" = "--lang" ]; then
    if [ $# -lt 2 ]; then
        printf '%s\n' "Error: --lang requires a value (en, zh or es)." >&2
        exit 2
    fi
    LANG_REQUESTED=$2
    shift 2
fi

LANG_RAW=${LANG_REQUESTED:-${TIME_MACHINE_BOOST_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}}
case "$LANG_RAW" in
    zh*) LANG_CODE=zh ;;
    es*) LANG_CODE=es ;;
    en*) LANG_CODE=en ;;
    *)   LANG_CODE=en ;;
esac

STATE_VALUE="?"
ORIG_STTY=""
TUI_ACTIVE=0
LOG_PID=""

case "$LANG_CODE" in
    zh)
        M_MACOS_ONLY="错误：这个脚本只支持 macOS。"
        M_NO_SYSCTL="错误：找不到 sysctl 命令。"
        ;;
    es)
        M_MACOS_ONLY="Error: este script solo es compatible con macOS."
        M_NO_SYSCTL="Error: no se encontró el comando sysctl."
        ;;
    *)
        M_MACOS_ONLY="Error: this script only supports macOS."
        M_NO_SYSCTL="Error: sysctl command not found."
        ;;
esac

if [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
    printf '%s\n' "$M_MACOS_ONLY" >&2
    exit 1
fi

if [ -z "$SYSCTL_BIN" ]; then
    printf '%s\n' "$M_NO_SYSCTL" >&2
    exit 1
fi

case "$LANG_CODE" in
    zh)
        STATE_LABEL="未知"
        STATE_HINT="尚未读取状态"
        LAST_MESSAGE="按 R 刷新状态，按 Space 或 T 切换。"
        M_MACOS_ONLY="错误：这个脚本只支持 macOS。"
        M_NO_SYSCTL="错误：找不到 sysctl 命令。"
        M_NO_SUDO="错误：找不到 sudo 命令。"
        M_NO_LOG="找不到 log 命令，无法显示实时日志。"
        M_NO_TTY="错误：TUI 模式需要交互式终端。"
        M_STATE_UNREADABLE="无法读取"
        M_HINT_UNREADABLE="可能需要管理员授权，按 A 授权后再刷新。"
        M_STATE_ON="ON - 加速模式"
        M_HINT_ON="低优先级 I/O 节流已关闭；Time Machine 备份可能更快。"
        M_STATE_OFF="OFF - 系统默认"
        M_HINT_OFF="低优先级 I/O 节流已开启；这是 macOS 默认状态。"
        M_STATE_UNKNOWN_VALUE="未知值"
        M_HINT_UNKNOWN_VALUE="系统返回了非预期值，请谨慎操作。"
        M_UI_BOOST="Boost 状态 : "
        M_UI_SYSCTL="Sysctl     : "
        M_UI_HINT="提示       : "
        M_UI_MESSAGE="消息："
        M_KEYS_1="[Space/T] 切换开关      [O] 开启加速      [D] 恢复默认"
        M_KEYS_2="[R]       刷新状态      [A] 授权 sudo     [L] 实时日志"
        M_KEYS_3="[Q]       退出"
        M_UNKNOWN_ARG="未知参数：%s"
        M_ENABLE_ACTION="开启加速模式"
        M_DEFAULT_ACTION="恢复系统默认"
        M_LOG_HEADER="实时 Time Machine 日志（按任意键返回 TUI）"
        M_LOG_HINT="提示：备份未运行时通常没有新事件；可另开终端执行 tmutil startbackup。"
        M_LOG_RETURN="已从实时日志返回 TUI。"
        M_SUDO_MISSING="找不到 sudo 命令，无法修改系统设置。"
        M_SUDO_NEEDED="需要管理员授权，才能读取或修改 ${SYSCTL_KEY}。"
        M_SUDO_PASSWORD="请输入管理员密码；完成后会回到 TUI。"
        M_SUDO_UPDATED="sudo 授权已更新。"
        M_SUDO_FAIL="sudo 授权失败，未执行任何修改。"
        M_DONE_VERIFIED="%s已完成，并已验证当前状态。"
        M_VERIFY_MISMATCH="命令已执行，但状态验证未返回目标值。"
        M_SET_FAILED="%s失败，系统拒绝了 sysctl 修改。"
        M_CONFIRM="%s 按 Y 确认，其他键取消。"
        M_CANCELLED="已取消。"
        M_TOGGLE_UNKNOWN="无法切换：当前状态未知。可以先按 A 授权，再按 R 刷新。"
        M_CANNOT_READ_STATUS="无法读取 ${SYSCTL_KEY}。可以启动 TUI 后按 A 授权再刷新。"
        M_CLI_START="正在%s，可能需要输入管理员密码……"
        M_CLI_DONE="%s完成。"
        M_CLI_FAILED="%s失败。"
        M_CLI_TOGGLE_UNKNOWN="无法切换：当前状态未知。"
        M_QUIT="已退出。"
        M_REFRESHED="状态已刷新。"
        M_REFRESH_FAIL="刷新失败。按 A 授权后可再试。"
        M_KEY_UNKNOWN="未识别的按键。按 Q 退出，按 R 刷新，按 L 查看实时日志。"
        M_EXIT_TUI="已退出 Time Machine Boost TUI。"
        M_PROMPT_TOGGLE="确定切换当前开关？"
        M_PROMPT_ENABLE="确定开启加速模式？"
        M_PROMPT_DEFAULT="确定恢复系统默认？"
        ;;
    es)
        STATE_LABEL="Desconocido"
        STATE_HINT="Estado aún no leído"
        LAST_MESSAGE="Pulsa R para actualizar y Space o T para cambiar."
        M_MACOS_ONLY="Error: este script solo es compatible con macOS."
        M_NO_SYSCTL="Error: no se encontró el comando sysctl."
        M_NO_SUDO="Error: no se encontró el comando sudo."
        M_NO_LOG="No se encontró el comando log; no se pueden mostrar los registros en vivo."
        M_NO_TTY="Error: el modo TUI requiere una terminal interactiva."
        M_STATE_UNREADABLE="No legible"
        M_HINT_UNREADABLE="Puede que se necesite autorización de administrador. Pulsa A para autorizar y actualizar."
        M_STATE_ON="ON - Modo boost"
        M_HINT_ON="La limitación de I/O de baja prioridad está desactivada; las copias de Time Machine pueden ir más rápido."
        M_STATE_OFF="OFF - Valor predeterminado"
        M_HINT_OFF="La limitación de I/O de baja prioridad está activada (valor predeterminado de macOS)."
        M_STATE_UNKNOWN_VALUE="Valor inesperado"
        M_HINT_UNKNOWN_VALUE="El sistema devolvió un valor inesperado; actúa con precaución."
        M_UI_BOOST="Estado Boost : "
        M_UI_SYSCTL="Sysctl       : "
        M_UI_HINT="Ayuda        : "
        M_UI_MESSAGE="Mensaje      : "
        M_KEYS_1="[Space/T] Cambiar     [O] Activar     [D] Predeterminado"
        M_KEYS_2="[R] Actualizar  [A] Autorizar sudo  [L] Registros"
        M_KEYS_3="[Q] Salir"
        M_UNKNOWN_ARG="Argumento desconocido: %s"
        M_ENABLE_ACTION="Activar modo boost"
        M_DEFAULT_ACTION="Restaurar el valor predeterminado"
        M_LOG_HEADER="Registros de Time Machine en tiempo real (cualquier tecla vuelve a la TUI)"
        M_LOG_HINT="Sugerencia: normalmente no hay eventos si no hay una copia en curso; ejecuta tmutil startbackup en otra terminal."
        M_LOG_RETURN="Se volvió a la TUI desde los registros en vivo."
        M_SUDO_MISSING="No se encontró sudo; no se puede modificar el sistema."
        M_SUDO_NEEDED="Se necesita autorización de administrador para leer o modificar $SYSCTL_KEY."
        M_SUDO_PASSWORD="Introduce la contraseña de administrador; volverás a la TUI al terminar."
        M_SUDO_UPDATED="Autorización de sudo actualizada."
        M_SUDO_FAIL="Falló la autorización de sudo; no se realizó ningún cambio."
        M_DONE_VERIFIED="%s completado y verificado."
        M_VERIFY_MISMATCH="El comando se ejecutó, pero la verificación no devolvió el valor esperado."
        M_SET_FAILED="%s falló; el sistema rechazó el cambio de sysctl."
        M_CONFIRM="%s Pulsa Y para confirmar; cualquier otra tecla cancela."
        M_CANCELLED="Cancelado."
        M_TOGGLE_UNKNOWN="No se puede cambiar: el estado actual es desconocido. Pulsa A para autorizar y R para actualizar."
        M_CANNOT_READ_STATUS="No se pudo leer $SYSCTL_KEY. Inicia la TUI y pulsa A para autorizar."
        M_CLI_START="Ahora %s; puede que se pida la contraseña de administrador…"
        M_CLI_DONE="%s completado."
        M_CLI_FAILED="%s falló."
        M_CLI_TOGGLE_UNKNOWN="No se puede cambiar: el estado actual es desconocido."
        M_QUIT="Saliendo."
        M_REFRESHED="Estado actualizado."
        M_REFRESH_FAIL="No se pudo actualizar. Pulsa A para autorizar e inténtalo de nuevo."
        M_KEY_UNKNOWN="Tecla no reconocida. Pulsa Q para salir, R para actualizar o L para ver registros."
        M_EXIT_TUI="Se salió de Time Machine Boost TUI."
        M_PROMPT_TOGGLE="¿Cambiar el estado actual?"
        M_PROMPT_ENABLE="¿Activar el modo boost?"
        M_PROMPT_DEFAULT="¿Restaurar el valor predeterminado?"
        ;;
    *)
        STATE_LABEL="Unknown"
        STATE_HINT="State not read yet"
        LAST_MESSAGE="Press R to refresh, Space or T to toggle."
        M_MACOS_ONLY="Error: this script only supports macOS."
        M_NO_SYSCTL="Error: sysctl command not found."
        M_NO_SUDO="Error: sudo command not found."
        M_NO_LOG="The log command was not found; cannot show live logs."
        M_NO_TTY="Error: TUI mode requires an interactive terminal."
        M_STATE_UNREADABLE="Unreadable"
        M_HINT_UNREADABLE="Administrator authorization may be required. Press A to authorize, then refresh."
        M_STATE_ON="ON - Boost mode"
        M_HINT_ON="Low-priority I/O throttling is off; Time Machine backups may run faster."
        M_STATE_OFF="OFF - System default"
        M_HINT_OFF="Low-priority I/O throttling is on (macOS default)."
        M_STATE_UNKNOWN_VALUE="Unexpected value"
        M_HINT_UNKNOWN_VALUE="The system returned an unexpected value; proceed with caution."
        M_UI_BOOST="Boost state : "
        M_UI_SYSCTL="Sysctl       : "
        M_UI_HINT="Hint         : "
        M_UI_MESSAGE="Message      : "
        M_KEYS_1="[Space/T] Toggle        [O] Enable       [D] Default"
        M_KEYS_2="[R] Refresh       [A] Sudo auth     [L] Live logs"
        M_KEYS_3="[Q] Quit"
        M_UNKNOWN_ARG="Unknown argument: %s"
        M_ENABLE_ACTION="Enable boost mode"
        M_DEFAULT_ACTION="Restore the system default"
        M_LOG_HEADER="Real-time Time Machine logs (any key returns to TUI)"
        M_LOG_HINT="Hint: there is usually no output while no backup is running; run tmutil startbackup in another terminal."
        M_LOG_RETURN="Returned to TUI from live logs."
        M_SUDO_MISSING="sudo was not found; cannot modify system settings."
        M_SUDO_NEEDED="Administrator authorization is required to read or modify $SYSCTL_KEY."
        M_SUDO_PASSWORD="Enter the administrator password; you will return to the TUI when done."
        M_SUDO_UPDATED="sudo authorization updated."
        M_SUDO_FAIL="sudo authorization failed; nothing was changed."
        M_DONE_VERIFIED="%s completed and verified."
        M_VERIFY_MISMATCH="The command ran, but verification did not return the target value."
        M_SET_FAILED="%s failed; the system rejected the sysctl change."
        M_CONFIRM="%s Press Y to confirm; any other key cancels."
        M_CANCELLED="Cancelled."
        M_TOGGLE_UNKNOWN="Cannot toggle: current state is unknown. Press A to authorize, then R to refresh."
        M_CANNOT_READ_STATUS="Cannot read $SYSCTL_KEY. Start the TUI and press A to authorize."
        M_CLI_START="Now %s; an administrator password may be required…"
        M_CLI_DONE="%s completed."
        M_CLI_FAILED="%s failed."
        M_CLI_TOGGLE_UNKNOWN="Cannot toggle: current state is unknown."
        M_QUIT="Quit."
        M_REFRESHED="State refreshed."
        M_REFRESH_FAIL="Refresh failed. Press A to authorize and try again."
        M_KEY_UNKNOWN="Unrecognized key. Press Q to quit, R to refresh, L for live logs."
        M_EXIT_TUI="Exited Time Machine Boost TUI."
        M_PROMPT_TOGGLE="Toggle the current switch?"
        M_PROMPT_ENABLE="Enable boost mode?"
        M_PROMPT_DEFAULT="Restore the system default?"
        ;;
esac

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
        STATE_LABEL="$M_STATE_UNREADABLE"
        STATE_HINT="$M_HINT_UNREADABLE"
        return 1
    fi

    case "$state" in
        0)
            STATE_VALUE="0"
            STATE_LABEL="$M_STATE_ON"
            STATE_HINT="$M_HINT_ON"
            ;;
        1)
            STATE_VALUE="1"
            STATE_LABEL="$M_STATE_OFF"
            STATE_HINT="$M_HINT_OFF"
            ;;
        *)
            STATE_VALUE="$state"
            STATE_LABEL="$M_STATE_UNKNOWN_VALUE"
            STATE_HINT="$M_HINT_UNKNOWN_VALUE"
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
        printf '%s\n' "$M_NO_TTY" >&2
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
    printf '  %s' "$M_UI_BOOST"
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
    printf '  %s%s = %s\n' "$M_UI_SYSCTL" "$SYSCTL_KEY" "$STATE_VALUE"
    printf '  %s%s\n' "$M_UI_HINT" "$STATE_HINT"
    printf '\n'
    printf '  %s\n' "$M_KEYS_1"
    printf '  %s\n' "$M_KEYS_2"
    printf '  %s\n' "$M_KEYS_3"
    printf '\n'
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
    printf '  %s%s\n' "$M_UI_MESSAGE" "$LAST_MESSAGE"
    printf '%s+------------------------------------------------------------+%s\n' "$CYAN" "$RESET"
}

show_live_log() {
    if [ -z "$LOG_BIN" ]; then
        LAST_MESSAGE="$M_NO_LOG"
        return 1
    fi

    clear_screen
    printf '%s\n' "$M_LOG_HEADER"
    printf '%s\n' "$M_LOG_HINT"
    printf '%s\n' "--------------------------------------------------------------"

    "$LOG_BIN" stream \
        --predicate 'subsystem == "com.apple.TimeMachine"' \
        --style compact 2>&1 &
    LOG_PID=$!

    read_key >/dev/null
    kill "$LOG_PID" 2>/dev/null || true
    wait "$LOG_PID" 2>/dev/null || true
    LOG_PID=""
    LAST_MESSAGE="$M_LOG_RETURN"
    return 0
}

ensure_sudo() {
    if [ -z "$SUDO_BIN" ]; then
        LAST_MESSAGE="$M_SUDO_MISSING"
        return 1
    fi

    if "$SUDO_BIN" -n true 2>/dev/null; then
        return 0
    fi

    restore_terminal
    printf '\n%s\n' "$M_SUDO_NEEDED"
    printf '%s\n' "$M_SUDO_PASSWORD"

    if "$SUDO_BIN" -v; then
        enter_terminal_mode
        LAST_MESSAGE="$M_SUDO_UPDATED"
        return 0
    fi

    enter_terminal_mode
    LAST_MESSAGE="$M_SUDO_FAIL"
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
            LAST_MESSAGE=$(printf "$M_DONE_VERIFIED" "$label")
            return 0
        fi

        LAST_MESSAGE="$M_VERIFY_MISMATCH"
        return 1
    fi

    LAST_MESSAGE=$(printf "$M_SET_FAILED" "$label")
    refresh_state
    return 1
}

confirm_action() {
    prompt=$1
    LAST_MESSAGE=$(printf "$M_CONFIRM" "$prompt")
    draw_ui
    key=$(read_key)

    case "$key" in
        y|Y)
            return 0
            ;;
        *)
            LAST_MESSAGE="$M_CANCELLED"
            return 1
            ;;
    esac
}

toggle_state() {
    refresh_state
    case "$STATE_VALUE" in
        0)
            set_state 1 "$M_DEFAULT_ACTION"
            ;;
        1)
            set_state 0 "$M_ENABLE_ACTION"
            ;;
        *)
            LAST_MESSAGE="$M_TOGGLE_UNKNOWN"
            return 1
            ;;
    esac
}

show_help() {
    case "$LANG_CODE" in
        zh)
            cat <<EOF
用法：
  $(basename "$0") [--lang en|zh|es]            启动 Shell TUI
  $(basename "$0") --status                     只显示当前状态，不弹出 sudo 密码
  $(basename "$0") --on                         开启加速模式
  $(basename "$0") --off                        恢复系统默认
  $(basename "$0") --toggle                     直接切换当前状态
  $(basename "$0") -h|--help                    显示帮助

TUI 快捷键：
  Space / T   切换开关
  O           开启加速模式
  D           恢复系统默认
  R           刷新状态
  A           更新 sudo 授权
  L           实时查看 Time Machine 日志（任意键返回）
  Q           退出

语言：
  默认跟随 LC_ALL/LC_MESSAGES/LANG；也可用 TIME_MACHINE_BOOST_LANG
  或 --lang 指定 en/zh/es。不匹配时回退为英语。

说明：
  加速模式会将 $SYSCTL_KEY 设为 0。
  恢复默认会将 $SYSCTL_KEY 设为 1。
  实时日志通过 /usr/bin/log stream 显示，不会修改任何系统设置。
  这是全局运行时设置，本脚本不会写入永久启动配置。
EOF
            ;;
        es)
            cat <<EOF
Uso:
  $(basename "$0") [--lang en|zh|es]            Inicia la TUI
  $(basename "$0") --status                     Solo muestra el estado, sin pedir sudo
  $(basename "$0") --on                         Activa el modo boost
  $(basename "$0") --off                        Restaura el valor predeterminado
  $(basename "$0") --toggle                     Cambia el estado directamente
  $(basename "$0") -h|--help                    Muestra la ayuda

Atajos de la TUI:
  Space / T   Cambiar el boost
  O           Activar el boost
  D           Restaurar el valor predeterminado
  R           Actualizar el estado
  A           Renovar la autorización de sudo
  L           Ver los registros de Time Machine en vivo (cualquier tecla vuelve)
  Q           Salir

Idiomas:
  Sigue LC_ALL/LC_MESSAGES/LANG por defecto; usa TIME_MACHINE_BOOST_LANG
  o --lang con en/zh/es. Si no coincide, se usa inglés.

Notas:
  El modo boost establece $SYSCTL_KEY en 0.
  Restaurar el valor predeterminado lo establece en 1.
  Los registros usan /usr/bin/log stream; no modifican el sistema.
  Este ajuste es temporal y este script no instala configuración de arranque.
EOF
            ;;
        *)
            cat <<EOF
Usage:
  $(basename "$0") [--lang en|zh|es]            Start the shell TUI
  $(basename "$0") --status                     Show state only, no sudo prompt
  $(basename "$0") --on                         Enable boost mode
  $(basename "$0") --off                        Restore the system default
  $(basename "$0") --toggle                     Toggle the current state
  $(basename "$0") -h|--help                    Show this help

TUI shortcuts:
  Space / T   Toggle boost
  O           Enable boost
  D           Restore default
  R           Refresh state
  A           Refresh sudo authorization
  L           Stream Time Machine logs (any key returns)
  Q           Quit

Language:
  Defaults to LC_ALL/LC_MESSAGES/LANG; override with TIME_MACHINE_BOOST_LANG
  or --lang en/zh/es. Falls back to English when unmatched.

Notes:
  Boost mode sets $SYSCTL_KEY to 0.
  Restoring the default sets $SYSCTL_KEY to 1.
  Live logs use /usr/bin/log stream and never modify system settings.
  This is a runtime setting; the script does not install startup configuration.
EOF
            ;;
    esac
}

print_status() {
    if refresh_state; then
        printf '%s\n' "$STATE_LABEL"
        printf '%s = %s\n' "$SYSCTL_KEY" "$STATE_VALUE"
        return 0
    fi

    printf '%s\n' "$M_CANNOT_READ_STATUS" >&2
    return 1
}

cli_set_state() {
    target=$1
    label=$2

    if [ -z "$SUDO_BIN" ]; then
        printf '%s\n' "$M_NO_SUDO" >&2
        return 1
    fi

    printf '%s\n' "$(printf "$M_CLI_START" "$label")"
    if "$SUDO_BIN" "$SYSCTL_BIN" "$SYSCTL_KEY=$target"; then
        refresh_state >/dev/null 2>&1 || true
        printf '%s\n' "$(printf "$M_CLI_DONE" "$label")"
        return 0
    fi

    printf '%s\n' "$(printf "$M_CLI_FAILED" "$label")" >&2
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
            cli_set_state 1 "$M_DEFAULT_ACTION"
            ;;
        1)
            cli_set_state 0 "$M_ENABLE_ACTION"
            ;;
        *)
            printf '%s\n' "$M_CLI_TOGGLE_UNKNOWN" >&2
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
                LAST_MESSAGE="$M_QUIT"
                break
                ;;
            r|R)
                if refresh_state; then
                    LAST_MESSAGE="$M_REFRESHED"
                else
                    LAST_MESSAGE="$M_REFRESH_FAIL"
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
                if confirm_action "$M_PROMPT_TOGGLE"; then
                    toggle_state
                fi
                ;;
            o|O)
                if confirm_action "$M_PROMPT_ENABLE"; then
                    set_state 0 "$M_ENABLE_ACTION"
                fi
                ;;
            d|D)
                if confirm_action "$M_PROMPT_DEFAULT"; then
                    set_state 1 "$M_DEFAULT_ACTION"
                fi
                ;;
            *)
                LAST_MESSAGE="$M_KEY_UNKNOWN"
                ;;
        esac
    done

    restore_terminal
    trap - INT TERM EXIT
    printf '%s\n' "$M_EXIT_TUI"
}

case "${1-}" in
    "")
        run_tui
        ;;
    --status)
        print_status
        ;;
    --on)
        cli_set_state 0 "$M_ENABLE_ACTION"
        ;;
    --off)
        cli_set_state 1 "$M_DEFAULT_ACTION"
        ;;
    --toggle)
        cli_toggle
        ;;
    -h|--help)
        show_help
        ;;
    *)
        printf '%s%s%s\n\n' "$RED" "$(printf "$M_UNKNOWN_ARG" "$1")" "$RESET" >&2
        show_help >&2
        exit 2
        ;;
esac
