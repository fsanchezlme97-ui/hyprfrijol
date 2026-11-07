# Desarrollo de hyprfrijol

## Reglas
- Cada pantalla del diseño (`design/capturas/<Pantalla>.png`, fuente en `design/*.dc.html`) es la referencia.
  El objetivo es **igual o mejor** que el lienzo: mismas medidas, colores, tipografía, textos en español.
- Todo lo visual usa `Theme` (colores y estilo resueltos) y los componentes de `config/quickshell/components/`.
  Nunca colores fijos, salvo los que el diseño fija (p. ej. sombras).
- Todo lo que el usuario puede cambiar va en `Settings` (`~/.config/hyprfrijol/settings.json`).
  Lee siempre con valor por defecto: `Settings.get("clave", defecto)`.
- La lógica que sirve fuera del shell va en `scripts/hf-*` (la usan atajos, la IA y la terminal).

## Piezas comunes (config/quickshell)
| Pieza | Para qué |
|---|---|
| `Theme` | `Theme.p/pText/pc/pcText/sc/scText/ter/t/tv/o/ov/bg/s1/s3/s4` (= `c.*` del diseño) · `Theme.glass/glassPanel/glassPopup/fill2/border/borderWidth/highlight/barRadius/panelRadius/winRadius/blur/estilo/light` (= `S.*`) · `Theme.fillOn/fillOnText` (relleno de lo activo: acento, o pastel en Suave) · `Theme.selBg/selText/selPill` (selección; pastilla del acento en Mica) · `Theme.font`, `Theme.px()`, `Theme.dur/durIn/ease` |
| `Settings` | `get(k, def)`, `set(k, v)`, `setMany({…})` → guarda y ejecuta `hf-apply` |
| `Shell` | vista abierta: `Shell.view`, `open(v, arg)`, `toggle(v)`, `close()`, `Shell.arg`, `Shell.section` (centro de control: `agenda`/`notificaciones`/`centro` son alias de la vista `ajustes`; `portapapeles`/`emojis` abren Spotlight en sus modos «:» y «;», `Shell.redirects`), `Shell.screen`, `setFocusMode()`, `exec(cmd)`, `dispatch(lua)` · IPC `shell` · atajos globales `hf:<vista>` |
| `Paths` | `home`, `state`, `userDir`, `cache`, `root`, `scripts`, `script(n)` |
| `Notifs` | servidor de notificaciones (`list`, `popups`, `dnd`, `setDnd`, `clearAll`) |
| `components/Overlay` | base de todo panel emergente (vista, posición, Esc/clic fuera, animación softUp, márgenes de barra) |
| `components/Glass` | superficie de vidrio (`kind`: bar/panel/popup/fill) |
| `components/Txt, Icon, Btn, IconBtn, Segmented, Toggle, Tile, SliderBar, Field, Divider, SectionLabel, Kbd` | controles del diseño |
| `components/Icons` | iconos del diseño por nombre; o `Icon { svg: '<path …/>' }` copiando el SVG del diseño |
| `services/` | `Audio`, `Net`, `Bt`, `Battery` (+ modo de energía), `Brightness`, `Media`, `Pomodoro`, `Time`, `Clip` (historial del portapapeles y fijados), `DockPins` (apps fijadas en el dock), `OsLogo` (logo de la distro en monocromo vía `scripts/hf-oslogo`; `HF_OS_LOGO=fedora` lo simula) |
| `modules/capture/Loupe` | lupa de píxeles sobre una pantalla congelada (`hf-capture freeze <salida>` → PNG temporal); la usan Captura y el Selector de color (`modules/colorpicker`, vista `color`) |

Dispatch de Hyprland 0.57 = Lua: `Shell.dispatch('hl.dsp.focus({ workspace = 3 })')`, `hyprctl dispatch 'hl.dsp.exit()'`,
cambios en vivo: `hyprctl eval 'hl.config({ … })'`.

## Probar
```bash
dev/try.sh                         # escritorio
dev/try.sh spotlight               # abre una vista y captura a 1440×900 → /tmp/hf-try/spotlight.png
HF_DEV_MODULES="modules/x/X.qml" dev/try.sh x     # módulo aún no registrado en modules/Modules.qml
dev/try.sh -c 'notify-send Hola' -w 4             # comando dentro de la sesión antes de capturar
dev/try.sh -s 'estilo=flat colorMode=elegir palette=claro' spotlight   # ajustes temporales
```
Imprime avisos/errores de Quickshell: deben salir vacíos. Compara la captura con `design/capturas/`.

## Módulos
Un módulo = carpeta `config/quickshell/modules/<nombre>/` con su `.qml` principal (normalmente un `Overlay`
con `view: "<vista>"`) y sus piezas. Se registra en `modules/Modules.qml`.

## Ojo con los Loader por URL

Un archivo cargado con `Loader { source: "…" }` o `LazyLoader` no ve los tipos de su propia carpeta. Los componentes que compartan varias secciones van en una carpeta que se importe explícitamente (p. ej. `modules/settings/ui/`, con `import "../ui"`).

## Índice de búsqueda de Ajustes

`dev/gen-settings-index.py` regenera `config/quickshell/modules/settings/search-index.json` (filas que encuentra
el buscador de Ajustes y claves que restaura «Restaurar valores por defecto» de cada sección). Ejecútalo tras
añadir o renombrar filas en `modules/settings/sections/*.qml`; `dev/gen-settings-index.py --check` sale con 1 si
está desactualizado.

## Opciones útiles de dev/try.sh

- La sesión de prueba se abre en un espacio especial oculto (`special:hftry`), sin quitarte el foco, y con su propio bus D-Bus: las notificaciones de prueba no llegan a tu escritorio.
- `-r 1920x1200` prueba a otra resolución (por defecto 1440×900, la del diseño).
- `-x 'cmd'` ejecuta un comando de diagnóstico ya apuntando a la sesión de prueba (`hyprctl`, `$QS ipc call …`, `notify-send`). No uses `hyprctl` a mano contra una sesión: si te equivocas de instancia, actúa sobre tu escritorio.
- Vista previa del login: `dev/try.sh -c "env HF_GREETER_PREVIEW=1 HF_GREETER_OPEN=1 qs -p $PWD/greeter/quickshell"` (con `HF_GREETER_CONFIG=/ruta/greeter.json` para probar un tema; `scripts/hf-greeter-sync --print` genera uno con el tuyo).

## Paletas, acento y tema en las apps

- Paletas en `config/themes/palettes.json`: `group` ("" originales · "pastel" · "popular"), `pair` + `variant` (pareja clara/oscura),
  `ansi` (16 colores del terminal; si falta, hf-apply los deriva). El selector de Ajustes › Apariencia las filtra y busca.
- `accent` ("#RRGGBB") sustituye al principal en todo el tema (`apply_accent` en hf-apply; contraste automático).
- `config/apply/17-theme-apps.py`: kitty, Qt/KDE (kdeglobals), btop e iconos Papirus con carpetas del acento. Pruébalo
  siempre con un HOME de prueba (`HOME=… scripts/hf-apply --no-reload`, sin `HF_ROOT`/`HF_SESSION` de tu sesión).

## Nombre anterior (hypr-liquid → hyprfrijol)

- Prefijos: scripts `hf-*`, variables `HF_*`, atajos globales `hf:<nombre>` (appid `hf`), capas `hf-*`, tabla Lua `HF`
  (con `HL = HF` para un `local.lua` antiguo), módulos Lua en `config/hypr/frijol/`.
- Compatibilidad que se mantiene a propósito: cada script copia las `HL_*` del entorno a `HF_*` si faltan (una línea al
  principio); `Paths.root` acepta `HL_ROOT`; el llavero sigue leyendo los servicios `hypr-liquid`/`hypr-liquid-remote`;
  17-theme-apps/16-gtk/90-files sustituyen las líneas y temas que dejó el nombre anterior; el greeter acepta la sesión
  `hypr-liquid.desktop`.
- `scripts/hf-migrate [--dry-run]` migra una instalación existente (carpetas, repo, `~/.local/bin/hl-*`, lanzadores) e
  imprime los pasos con sudo. `hf-session`, `hf-apply` y `hyprland.lua` lo llaman con `--dirs-only` si aún existen las
  carpetas `…/hypr-liquid` reales. Pruébalo siempre con `HOME=<carpeta de prueba> scripts/hf-migrate --repo <copia>`.

## Instalador

- `install.sh` lee las dependencias de `install/packages.tsv` (una dependencia lógica por línea, nivel
  base/required/recommended/optional/greeter y el paquete en cada familia: arch, fedora, suse, debian, void).
  Si un script o módulo empieza a usar otro programa, añádelo ahí (y comprueba el nombre en cada distro).
- Las fuentes de Hyprland ≥ 0.57 y Quickshell por distro (COPR, OBS, PPAs) están en `setup_sources` y `hypr_help`.
- Probar sin tocar nada, simulando otra distro y con un HOME de prueba:
  `HOME=/tmp/hf-home HF_DISTRO=fedora ./install.sh --dry-run` (también `HF_DISTRO_VERSION=24.04`, `--full`,
  `--greeter`, `--uninstall --purge`). `--dry-run` nunca ejecuta nada con efectos; solo consulta el gestor de
  paquetes del sistema real cuando no se simula otra distro.
- `install/bootstrap.sh` es la instalación en una línea (`curl … | bash`).
