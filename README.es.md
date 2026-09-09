# Time Machine Boost

> Una utilidad para macOS que controla la limitación de I/O de baja prioridad que Time Machine usa en las copias de seguridad y permite ver sus registros en tiempo real.

**Idiomas:** [English](README.md) | [简体中文](README.zh-CN.md) | Español

## Resumen

Las copias de Time Machine se tratan como I/O de baja prioridad. macOS las limita a propósito para que no ralenticen lo que estás haciendo. Este proyecto ofrece dos pequeñas herramientas para controlar esa limitación y observar lo que hace Time Machine:

- una **GUI** nativa de macOS con un interruptor;
- una **CLI/TUI** en shell puro, sin dependencias, para terminales y scripts.

> ⚠️ Desactivar la limitación puede hacer que el sistema se sienta más lento durante una copia. El ajuste solo es válido en esta sesión y se restablece al reiniciar. Mantenerlo desactivado permanentemente **no se recomienda**.

## Cómo funciona

macOS expone la limitación a través de un parámetro del kernel:

| Valor | Significado |
| --- | --- |
| `debug.lowpri_throttle_enabled = 1` | Predeterminado del sistema: la limitación está activada |
| `debug.lowpri_throttle_enabled = 0` | Modo boost: la limitación está desactivada |

El valor se aplica en tiempo de ejecución y vuelve al predeterminado tras reiniciar. Este proyecto nunca instala una configuración de arranque permanente.

## Funciones

### GUI

- Interruptor nativo que lee y muestra el estado real al iniciar.
- Cambia el valor mediante el diálogo de autorización de administrador del sistema y, después, **lo verifica leyéndolo de nuevo**, en lugar de dar por hecho que funcionó.
- Botón alternativo de “lectura con privilegios de administrador” cuando el estado no se puede leer directamente.
- Ventana de registros dedicada que transmite los logs de Time Machine en tiempo real, con opciones de limpiar y desplazamiento automático. Cerrar la ventana solo detiene y oculta la transmisión; la app sigue abierta.
- Interfaz trilingüe: inglés (predeterminado), 简体中文 y Español. Sigue el idioma del sistema y también se puede elegir desde la ventana principal.
- Sin dependencias de terceros.

### Shell

- CLI parametrizada: `--status`, `--on`, `--off`, `--toggle`.
- TUI interactiva en shell puro con actualización de estado, gestión de credenciales de sudo y visor de registros en vivo.
- Selección de idioma con `--lang en|zh|es`, `TIME_MACHINE_BOOST_LANG` o variables de locale (respaldo en inglés).
- Usa el mismo parámetro del kernel y el mismo comportamiento que la GUI.

## Requisitos

- macOS 13 o posterior (la GUI se desarrolló y verificó en macOS 26 / arm64)
- Una cuenta de administrador (necesaria al cambiar el valor)
- AppKit para la GUI; sin dependencias de terceros
- Idiomas de la interfaz: English, 简体中文, Español

## Uso

### GUI

```sh
open TimeMachineBoost.app
```

1. El interruptor muestra el estado actual después de iniciar.
2. Al cambiarlo se abre el diálogo de autorización de administrador; tras aprobarlo, la app modifica el valor y lo verifica leyéndolo de nuevo.
3. Pulsa **Registros en tiempo real…** para abrir la ventana de logs. Si no hay ninguna copia en curso, normalmente no hay salida; ejecuta `tmutil startbackup` para iniciar una.
4. Cerrar la ventana de registros solo la detiene y oculta. Ábrela de nuevo para iniciar una transmisión nueva.
5. Usa el menú **Idioma** al final de la ventana para cambiar el idioma de la interfaz (English, 简体中文, Español). La app se reinicia después de confirmar.

> En este prototipo, cada cambio solicita autorización de administrador. Para “autorizar una vez y cambiar muchas veces” se necesitaría un helper LaunchDaemon con privilegios.

### Shell

```sh
chmod +x boost_time_machine_tui.sh
./boost_time_machine_tui.sh              # TUI interactiva
./boost_time_machine_tui.sh --status     # solo lee el estado, sin pedir sudo
./boost_time_machine_tui.sh --on         # activa el boost (valor 0)
./boost_time_machine_tui.sh --off        # restaura el valor predeterminado (1)
./boost_time_machine_tui.sh --toggle     # cambia directamente
./boost_time_machine_tui.sh --help
./boost_time_machine_tui.sh --lang es    # se ejecuta en español
TIME_MACHINE_BOOST_LANG=zh ./boost_time_machine_tui.sh --status
```

Precedencia del idioma: `--lang` > `TIME_MACHINE_BOOST_LANG` > `LC_ALL`/`LC_MESSAGES`/`LANG` > inglés.

Atajos de la TUI:

| Tecla | Acción |
| --- | --- |
| `Space` / `T` | Cambiar el boost |
| `O` | Activar el boost |
| `D` | Restaurar el valor predeterminado |
| `R` | Actualizar el estado |
| `A` | Renovar la autorización de sudo |
| `L` | Ver los registros de Time Machine en vivo (cualquier tecla vuelve) |
| `Q` | Salir |

## Compilar desde el código fuente

Sin dependencias de terceros; solo se necesitan las Xcode Command Line Tools.

```sh
cd App
sh build.sh                 # crea App/TimeMachineBoost.app
sh build.sh /tmp/dist       # o indica un directorio de salida
```

Verifica la firma:

```sh
codesign --verify --deep --strict TimeMachineBoost.app
```

## Estructura del repositorio

```text
TimeMachineBoost/
├── README.md                 # English
├── README.zh-CN.md           # 简体中文
├── README.es.md              # Español
├── LICENSE                   # MIT
├── App/                      # GUI nativa
│   ├── main.m                # programa principal en AppKit (interruptor + ventana de logs)
│   ├── Info.plist
│   ├── build.sh
│   └── Resources/            # Localizable.strings
│       ├── en.lproj
│       ├── zh-Hans.lproj
│       └── es.lproj
└── boost_time_machine_tui.sh # TUI/CLI en shell puro
```

## Permisos

| Acción | Qué se necesita |
| --- | --- |
| Leer el estado actual | Normalmente se puede leer directamente; en entornos restringidos se necesita la lectura privilegiada |
| Cambiar el valor | Root. La GUI usa `osascript … with administrator privileges`; el shell usa `sudo sysctl` |
| Ver registros | `/usr/bin/log stream --predicate 'subsystem == "com.apple.TimeMachine"'`; normalmente no requiere administrador |

## Preguntas frecuentes

### ¿Cerrar la ventana de registros cierra la app o provoca un fallo?

No. Desde la v0.3, la ventana de registros se detiene y se oculta en lugar de destruirse, evitando el fallo por liberación durante la animación de cierre. La v0.4 añade la interfaz trilingüe. Si aun así la app se cierra de forma inesperada, adjunta el informe de fallo.

### ¿Por qué no hay una opción de “activar automáticamente al iniciar”?

Es una omisión deliberada. Ese parámetro protege la capacidad de respuesta del sistema durante las copias y no se recomienda mantenerlo desactivado permanentemente. Una versión persistente necesitaría un LaunchDaemon y una advertencia de riesgo explícita en la interfaz.

### ¿El cambio se aplicó pero el estado no cambió?

La app verifica el resultado leyendo el valor después de cada cambio. Si la verificación falla, muestra “el comando se ejecutó pero la verificación no devolvió el valor esperado”, en lugar de fingir que todo funcionó. Confirma que tu versión de macOS todavía admite este parámetro.

## Historial de versiones

- **v0.5**: selector de idioma en la ventana principal (English / 简体中文 / Español).
- **v0.4**: interfaz trilingüe (inglés predeterminado, 简体中文, Español) en GUI y herramientas de shell.
- **v0.3**: corregido el fallo al cerrar la ventana de registros; ahora se detiene y se oculta.
- **v0.2**: añadida la ventana de registros de Time Machine en tiempo real.
- **v0.1**: prototipo inicial del interruptor GUI.

## Licencia

Publicado bajo la [MIT License](LICENSE).

Copyright © 2026 QUARTETTO D'ARCHI
