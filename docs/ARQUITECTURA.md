# hyprfrijol · Arquitectura y plan de construcción

## Idea

Un **rice de Hyprland con shell propio, hecho desde cero**: la configuración de Hyprland (Lua, 0.57+) y un shell en Quickshell (QML). Se ejecuta desde la carpeta del repo como una sesión aparte (`hf-session`), así que corre en cualquier distro que tenga Hyprland y no pisa otras configuraciones. No es una distro ni un fork.

```
Hyprland (compositor)  ← configuración Lua modular en config/hypr/frijol
    │  IPC (hyprctl / socket; los dispatch son Lua: hl.dsp.…)
Quickshell (shell QML) ← barra, paneles, Spotlight, PiP, OSD, notificaciones, ajustes, login
    │  qs ipc call …   (API del shell: la usan atajos, scripts y la IA)
Scripts (bash)         ← hf-session, hf-shell (arranca el shell y lo reabre si se cae), hf-wallpaper, hf-capture…: lógica que se reutiliza fuera del shell
    │  ~/.local/state/hyprfrijol/  (colores, fondo, «no molestar»: lo generado)
    │
Servicios del sistema  ← PipeWire, NetworkManager, BlueZ, UPower, power-profiles-daemon,
                          fprintd, Snapper, greetd, Flatpak, fwupd
```

**Principio:** cada función tiene un script o comando que funciona solo (`hf-wallpaper`, `hf-capture`…). Quickshell es solo la cara visual. Así la IA, los atajos y la terminal usan lo mismo.

## Pantallas del prototipo → piezas

Todo vive en `config/quickshell/`. Cada vista del diseño es un módulo en `modules/<carpeta>/`, registrado en `modules/Modules.qml`, que se abre con `Shell.open("<vista>")`. Comparten `components/` (Glass, Btn, Toggle, Overlay…) y `services/` (audio, red, Bluetooth, batería, brillo, multimedia, reloj, eventos, clientes de Hyprland…).

| Pantalla | Vista (`Shell.view`) | Módulo | Por debajo |
|---|---|---|---|
| Barra (abajo / arriba / lateral, fija / flotante) | — | `bar/` | `Quickshell.Hyprland`, cava, `SystemTray` |
| Colores automáticos / elegir / mono · Material / SkySoul / Chroma · claro / oscuro / auto | — | `Theme.qml`, `scripts/hf-apply` | matugen, `config/themes/palettes.json` |
| Spotlight | `spotlight` | `modules/spotlight` | `DesktopEntries`, `fd`, `qalc` |
| Ajustes rápidos | `ajustes` | `modules/quicksettings` | nmcli, `Bluetooth`, `UPower`, `PowerProfiles`, hyprsunset |
| Notificaciones y OSD | `notificaciones` | `Notifs.qml`, `modules/notifications`, `modules/osd` | `NotificationServer`, `Pipewire` |
| Panel lateral (asistente de IA), web apps y PiP | `ia` | `modules/sidepanel`, `modules/pip` | `hf-ai` (Claude Code / Ollama / API), `hf-webapp` (QtWebEngine), `hf-mcp` |
| Vista general, Alt+Tab, Snap | `vista`, `alttab`, `snap` | `modules/overview`, `alttab`, `snap` | `ScreencopyView`, `services/HyprClients.qml` |
| Dock (modo flotante: minimizar, maximizar, ocultación inteligente) y escritorio ordenado | — | `modules/desktop` | `FolderListModel` |
| Widgets | `widgets` | `modules/widgets` | Open-Meteo, Moonraker/OctoPrint, `/proc` |
| Fondos | `fondos` | `modules/wallpapers`, `Wallpaper.qml`, `scripts/hf-wallpaper` | matugen, mpvpaper |
| Captura y grabación | `captura` | `modules/capture`, `scripts/hf-capture` | grim, slurp, wf-recorder, tesseract |
| Portapapeles y emojis (modos «:» y «;» de Spotlight) | `portapapeles`, `emojis` → `spotlight` | `modules/spotlight`, `services/Clip.qml` | cliphist, `config/emoji/emojis.json` |
| Agenda | `agenda` | `modules/agenda`, `services/Events.qml` | `.ics` locales o por URL |
| Actualizaciones | `actualizaciones` | `modules/updates`, `scripts/hf-updates` | checkupdates, paru, flatpak, fwupdmgr, snapper |
| Energía, bloqueo, sin distracciones, polkit | `energia` | `modules/power`, `lock`, `focus`, `polkit` | `WlSessionLock` + `Pam`, `Polkit` |
| Ajustes | `ajustesapp` | `modules/settings` | `settings.json` → `hf-apply` |
| Bienvenida y herramientas | `bienvenida`, `herramientas` | `modules/welcome`, `tools` | pacman/paru, dnf, apt, flatpak |
| Login | — | `greeter/` | greetd + `Quickshell.Services.Greetd` |

## Compatibilidad entre distros

| | Arch / CachyOS | Fedora | Ubuntu / Debian | openSUSE | NixOS |
|---|---|---|---|---|---|
| Hyprland | repos | COPR | repos recientes | repos | nixpkgs |
| Quickshell | AUR / repos CachyOS | COPR | compilar | compilar / OBS | nixpkgs |
| matugen | AUR | cargo | cargo | cargo | nixpkgs |
| Puntos de restauración | Snapper + snap-pac (btrfs) | Snapper (btrfs) | Timeshift o Snapper si btrfs | Snapper (de serie) | generaciones de Nix |

- Escribe las funciones que dependen de la distro (actualizaciones, instalar herramientas, restauración) detrás de un único script `hf-pkg` con un `case` por gestor, como hace `install.sh`.
- Más adelante: PKGBUILD para AUR, spec para COPR y un flake de Nix con módulo de home-manager.

## API del shell (para atajos, scripts y la IA)

Atajos de Hyprland: `hl.dsp.global("hf:<vista>")` abre o cierra una vista (también `hf:enfoque`, `hf:cerrar`, `hf:altnext`, `hf:snapleft`…).

Desde la terminal (`qs -p <repo>/config/quickshell ipc call <objetivo> <función> …`):

| Objetivo | Para qué |
|---|---|
| `shell` | `toggle`, `open`, `openWith <vista> <arg>`, `close`, `current`, `focus` |
| `settings` | leer y cambiar ajustes |
| `sidepanel` | `ask`, `tab`, `pip`, `pipBack` |
| `notifs` | `toggleDnd`, `setDnd`, `clear`, `count` |
| `osd`, `pomodoro`, `capture`, `events`, `lock`, `tools` | lo de cada módulo |

`qs … ipc show` lista todas las funciones. `scripts/hf-mcp` expone esto a la IA como herramientas MCP. Cada cambio de la IA pasa por **vista previa → Aplicar → Deshacer** (ver `docs/IA.md`).

## Ajustes

- Una sola fuente de verdad: `~/.config/hyprfrijol/settings.json`, mezclado con `config/defaults/settings.json`.
- La app de Ajustes, los ajustes rápidos y la IA lo escriben. `hf-apply` genera en `~/.local/state/hyprfrijol/` el tema (`theme.json`, que Quickshell lee en vivo), `settings.lua` para Hyprland, y los colores de hyprlock, kitty y GTK. Después recarga Hyprland.
- Lo que el usuario edita a mano va en `~/.config/hyprfrijol/local.lua` y nunca se sobrescribe.

## Desarrollo

`dev/try.sh [-s 'clave=valor …'] [-c 'comando'] <vista>` arranca una sesión anidada con un monitor virtual de 1440×900, abre la vista, guarda una captura en `/tmp/hf-try/` y muestra los avisos de Quickshell. Ver `dev/DESARROLLO.md`.

## Riesgos conocidos

- **Hyprland cambió a Lua en 0.57.** `hyprland.conf` ya no se lee. Valida siempre con `Hyprland --verify-config --config config/hypr/hyprland.lua` (detecta claves y campos desconocidos).
- **QML:** las propiedades no pueden empezar por `on` + mayúscula ni por mayúscula; `data` no vale como id, `escape` no vale como señal y `show` no vale como función de IPC.
- **QtWebEngine dentro de Quickshell 0.3.2 se cierra solo.** Por eso las web apps son ventanas `qml6` aparte que el panel acopla (`hf-webapp`).

- **Quickshell cambia rápido.** Fija una versión en el README y prueba cada actualización.
- **Rendimiento del vidrio:** el blur de muchas capas pesa en gráficas integradas. Hace falta el interruptor «Reducir transparencia», y «Quitar efectos en juegos» (`gameNoFx`) ya lo apaga en pantalla completa.
- **Claude Desktop en Linux** es beta y solo para Debian/Ubuntu. El botón de pasar la conversación debe detectar qué hay instalado.
- **Login:** un greeter roto te deja sin entrar. Deja tuigreet como respaldo y prueba en otra TTY.
