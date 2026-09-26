<!--
Notes for the release being cut. The release workflow publishes this file as the
release body and appends the digests it just built, so it must mention the version
being tagged: the workflow fails the release when this file does not contain the
tag it is publishing. Replace the text below with the notes for the next version
before tagging, and keep the three translations in step.
-->

# Time Machine Boost v0.6.2

Security fix in the shell TUI/CLI, release digests, and a build-from-source release workflow.

### English

- **Security fix (shell TUI/CLI).** `boost_time_machine_tui.sh` resolved `sysctl` and `sudo` through `PATH`, so a program planted earlier in the caller's `PATH` would have been executed with administrator privileges, and a substitute `sudo` could have captured the administrator password (CWE-426, CWE-427). Both programs are now invoked from fixed absolute paths (`/usr/sbin/sysctl`, `/usr/bin/sudo`), and the script reports a clear error instead of proceeding when either is missing or not executable. `tput` and the `/usr/bin/log` fallback keep their previous behaviour because they never run with privileges.
- The SwiftUI GUI already used absolute paths (`/usr/sbin/sysctl`, `/usr/bin/osascript`); nothing changed there. The archived prototype `archive/pa/boost_time_machine_tui.sh` received the same hardening, and the menu-bar prototype now escapes backslashes as well as quotes when it builds an AppleScript command.
- **Release digests.** Releases now publish `SHA256SUMS` beside the archive: download both, then run `shasum -a 256 -c SHA256SUMS` before opening anything. `RELEASE_CHECKSUMS.txt` records the digests of every release, including the older 0.5 to 0.6.1 archives.
- **Release workflow.** `.github/workflows/release.yml` builds the app from source, verifies the bundle and the shell tool, and publishes tagged versions together with their digests. It also fails the build if the shipped shell tool ever resolves a privileged program through `PATH` again.
- No change to GUI behaviour, the kernel parameter, the administrator authorization model, the log predicate or the macOS 13 deployment target. The app is still **ad-hoc signed only**; public distribution would need a Developer ID certificate and notarization.

Assets:
- `TimeMachineBoost-0.6.2-macOS.zip` — native GUI app (macOS 13+), built from this tag by the release workflow.
- `boost_time_machine_tui.sh` — dependency-free shell TUI/CLI (hardened).
- `SHA256SUMS` — digests for both files above.

---

### 简体中文

- **安全修复（Shell TUI/CLI）**：`boost_time_machine_tui.sh` 之前会通过 `PATH` 解析 `sysctl` 与 `sudo`，攻击者若能在调用者 `PATH` 里更靠前的目录放置同名程序，该程序就会以管理员权限被执行，伪装成 `sudo` 时还能骗走管理员密码（CWE-426、CWE-427）。现在两者都改为固定的绝对路径调用（`/usr/sbin/sysctl`、`/usr/bin/sudo`），缺失或不可执行时脚本会明确报错而不是继续执行。`tput` 与 `/usr/bin/log` 的回退逻辑保持不变，因为它们从不以特权身份运行。
- SwiftUI GUI 本来就使用绝对路径（`/usr/sbin/sysctl`、`/usr/bin/osascript`），未作改动。归档原型 `archive/pa/boost_time_machine_tui.sh` 同步做了同样的加固；菜单栏原型在拼接 AppleScript 命令时现在同时转义反斜杠与引号。
- **发布摘要**：每个版本都会随压缩包发布 `SHA256SUMS`，下载后先执行 `shasum -a 256 -c SHA256SUMS` 再打开。`RELEASE_CHECKSUMS.txt` 记录了所有版本的摘要，包括更早的 0.5 至 0.6.1 压缩包。
- **发布工作流**：`.github/workflows/release.yml` 从源码构建 App、校验应用包与 Shell 工具，并把打标签的版本连同摘要一起发布；如果将来发布的脚本又通过 `PATH` 解析特权程序，构建会直接失败。
- GUI 行为、内核参数、管理员授权模型、日志谓词与 macOS 13 部署目标均未改变。App 仍然**仅做 ad-hoc 签名**；若要公开发布，仍需 Developer ID 证书与公证。

附件：
- `TimeMachineBoost-0.6.2-macOS.zip` — 原生 GUI App（macOS 13 及以上），由发布工作流从该标签构建。
- `boost_time_machine_tui.sh` — 无依赖的 Shell TUI/CLI（已加固）。
- `SHA256SUMS` — 上述两个文件的摘要。

---

### Español

- **Corrección de seguridad (TUI/CLI de shell).** `boost_time_machine_tui.sh` resolvía `sysctl` y `sudo` a través de `PATH`, de modo que un programa colocado antes en el `PATH` del usuario se habría ejecutado con privilegios de administrador, y un `sudo` sustituido podría haber capturado la contraseña de administrador (CWE-426, CWE-427). Ahora ambos se invocan desde rutas absolutas fijas (`/usr/sbin/sysctl`, `/usr/bin/sudo`) y el script muestra un error claro en lugar de continuar cuando falta alguno o no es ejecutable. `tput` y el respaldo de `/usr/bin/log` mantienen su comportamiento porque nunca se ejecutan con privilegios.
- La GUI de SwiftUI ya usaba rutas absolutas (`/usr/sbin/sysctl`, `/usr/bin/osascript`); ahí no cambió nada. El prototipo archivado `archive/pa/boost_time_machine_tui.sh` recibió el mismo endurecimiento, y el prototipo de barra de menús ahora escapa también las barras invertidas además de las comillas al construir un comando de AppleScript.
- **Resúmenes de publicación.** Cada versión publica `SHA256SUMS` junto al archivo: descarga ambos y ejecuta `shasum -a 256 -c SHA256SUMS` antes de abrir nada. `RELEASE_CHECKSUMS.txt` registra los resúmenes de todas las versiones, incluidos los archivos más antiguos de 0.5 a 0.6.1.
- **Flujo de publicación.** `.github/workflows/release.yml` compila la app desde el código fuente, verifica el paquete y la herramienta de shell, y publica las versiones etiquetadas junto con sus resúmenes. También falla la compilación si la herramienta de shell vuelve a resolver un programa privilegiado a través de `PATH`.
- Sin cambios en el comportamiento de la GUI, el parámetro del kernel, el modelo de autorización de administrador, el predicado de los registros ni el objetivo de macOS 13. La app sigue **solo con firma ad-hoc**; la distribución pública requeriría un certificado Developer ID y notarización.

Archivos:
- `TimeMachineBoost-0.6.2-macOS.zip` — app GUI nativa (macOS 13+), compilada desde esta etiqueta por el flujo de publicación.
- `boost_time_machine_tui.sh` — TUI/CLI de shell sin dependencias (endurecida).
- `SHA256SUMS` — resúmenes de los dos archivos anteriores.
