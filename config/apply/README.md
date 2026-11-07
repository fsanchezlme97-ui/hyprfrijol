# config/apply — extensiones de hf-apply

`scripts/hf-apply` ejecuta cada `*.py` de esta carpeta (en orden alfabético) y añade al final de
`~/.local/state/hyprfrijol/settings.lua` las líneas que devuelve `hypr_lua(s, c)`:

- `s`: ajustes resueltos (config/defaults/settings.json + ~/.config/hyprfrijol/settings.json)
- `c`: paleta resuelta (bg s1 s3 s4 p onP pc onPc sc onSc ter t tv o ov)

Como van después de la configuración base, sus `hl.config({...})` la sobrescriben.
Una extensión rota solo deja un comentario `-- x.py: error …`, no rompe el resto.

| Archivo | Ajustes |
|---|---|
| `10-look.py` | rounding, highContrast, blurQuality/blurAuto, colorFilter (shaders/) |
| `20-input.py` | kbLayouts, kbSwitch, kbRepeatDelay/Rate, numlock, capsEscape, touchpad, focusOnHover, gestos |
| `30-layout.py` | windowMode + layout → general:layout (dwindle/master; scrolling en el modo desplazamiento), scrollColumnWidth, scrollFocusFit, scrollOneFull, snapEdges |
| `35-windows.py` | windowMode (mosaico/desplazamiento/flotante; el antiguo mixto = mosaico): regla hf-float-all del flotante |
| `40-monitors.py` | monitors {salida: {mode, position, scale, vrr, hdr, mirror, disabled}}, uiScale |
| `50-rules.py` | ventanas de Ajustes/Herramientas, gameNoFx |
| `52-pip.py` | regla de ventana del PiP: esquina (pipCorner/pipFree) y margen (pipMargin) apartados de la barra (sustituye a HF.rules.pip) |
| `60-binds.py` | keybinds (reasignaciones, ver keybind-actions.json), atajos de webapps (hf-webapp open), overAmplify, lupa (magnifier) |
| `15-apps.py` | fileManager (si está instalado), terminal |
| `17-theme-apps.py` | themeApps + themeKitty/themeQt/themeBtop → include de kitty, esquema «HyprFrijol» en kdeglobals (Dolphin/Qt; qt6ct si está), tema de btop; themeIcons/iconFolders → tema de usuario Papirus-Liquid-* con las carpetas del color del acento (sin root). Recarga en vivo solo con el HOME real |
| `16-gtk.py` | themeApps (+ themeGtk) → colores de libadwaita (gtk-adw.css) y gsettings color-scheme / accent-color / gtk-theme |
| `70-plugins.py` | plugins {id: {on, …}} → opciones de los plugins de hyprpm activados (catálogo en config/tools/plugins.json), con guarda si no están cargados |
| `85-idle.py` | idleDim, idleLock, idleScreenOff, idleSuspend, lockOnSuspend → hypridle.conf (no devuelve Lua) |
| `90-files.py` | efectos fuera de Hyprland: reduce-motion, gtk.css (themeApps + themeGtk), cursor grande |

Probar: `scripts/hf-apply --no-reload && Hyprland --verify-config --config config/hypr/hyprland.lua`
