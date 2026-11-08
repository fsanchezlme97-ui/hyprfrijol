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
| `Shell` | vista abierta: `Shell.view`, `open(v, arg)`, `toggle(v)`, `close()`, `preload(v)` (carga diferida), `Shell.arg`, `Shell.section` (centro de control: `agenda`/`notificaciones`/`centro` son alias de la vista `ajustes`; `portapapeles`/`emojis` abren Spotlight en sus modos «:» y «;», `Shell.redirects`), `Shell.screen`, `setFocusMode()`, `exec(cmd)`, `dispatch(lua)` · IPC `shell` · atajos globales `hf:<vista>` |
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

## Carga diferida de módulos (`lazyModules`)

Las vistas que solo hacen falta abiertas se crean al abrirlas y se destruyen un rato después de cerrarlas
(`components/LazyView.qml`, registradas en `modules/Modules.qml`):
`LazyView { views: ["spotlight"]; grace: 120000; Spotlight {} }`.
- **Cómo se abre**: `LazyView` crea el contenido dentro de `Shell.open()` (al cambiar `Shell.view`), antes de que se
  emita `Shell.opened`, así que los `Connections { onOpened }` del módulo siguen funcionando. `Overlay`/`ChipPopup` (y
  `Capture`/`ColorPicker`) tienen `ready`: esperan un ciclo antes de `shown`, para que la animación de entrada se vea
  también la primera vez.
- **Cuándo se descarga**: `grace` ms después de cerrarse (45 s; el centro de control, 2 min; Spotlight, el más usado, se queda tras abrirlo una vez: `warm`). `keep: true` lo
  retiene (Captura mientras graba o hay capturas fijadas; Color mientras elige) y `warm: true` no lo descarga nunca.
  Tras descargar se llama a `gc()`.
- **Precarga**: `Shell.preload("<vista>")` lo crea en segundo plano (`LazyLoader.activeAsync`, sin bloquear). Lo usan
  el cursor sobre el botón de apps, el grupo de estado, los chips de la barra, la onda de música y el botón de la IA
  (`IconBtn { preload: "<vista>" }`).
- **Lo que no puede ir dentro**: IPC, atajos globales, vigilantes y avisos tienen que funcionar con la vista cerrada.
  Van en `Modules.qml` (IPC `spotlight`, `capture` y `color`, que crean el módulo con `lazyView.load()` si hace falta),
  en el módulo siempre cargado (`UpdatesCheck.qml`: comprobación en segundo plano; el temporizador de la
  bienvenida) o en `services/`. El atajo `hf:color` está en `Shell`.
- **Siempre cargados** (y por qué, en el comentario de `Modules.qml`): Lock, Polkit, Osd, Dictado, Focus, Pip,
  SidePanel (acopla las web apps; su chat `AiChat.qml` sí es diferido y solo se descarga sin conversación), AltTab
  y Snap (atajos que actúan al momento), Desktop, OmarchyHost (los paneles de plugins ya eran diferidos),
  SettingsApp, Tools y Firmar (su ventana ya era diferida).
- **Módulo nuevo**: si su vista solo hace falta abierta, regístralo con `LazyView`. Si necesita algo con la vista
  cerrada, sepáralo.
- **Depurar**: `lazyModules: false` (Ajustes › Energía y rendimiento › Memoria del escritorio) lo carga todo al
  arrancar, como antes.
- **Medir**: `HF_PROBE_OPEN=1` activa `components/OpenProbe.qml`, que escribe en `qs log` líneas como
  `[probe] spotlight visible=40ms frames=24 maxGap=17ms slow=0`. Mide el tiempo desde `Shell.open` hasta el primer
  fotograma y los saltos durante la animación de entrada. La memoria se mide con `/proc/<pid>/smaps_rollup` del `qs`
  de la sesión anidada.

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
- `config/apply/17-theme-apps.py`: kitty, Qt (qt6ct; kdeglobals solo con el tema de Plasma), btop e iconos Papirus con carpetas del acento. Pruébalo
  siempre con un HOME de prueba (`HOME=… scripts/hf-apply --no-reload`, sin `HF_ROOT`/`HF_SESSION` de tu sesión).

## Nombre anterior (hypr-liquid → hyprfrijol)

- Prefijos: scripts `hf-*`, variables `HF_*`, atajos globales `hf:<nombre>` (appid `hf`), capas `hf-*`, tabla Lua `HF`
  (con `HL = HF` para un `local.lua` antiguo), módulos Lua en `config/hypr/frijol/`.
- Compatibilidad que se mantiene a propósito: cada script copia las `HL_*` del entorno a `HF_*` si faltan (una línea al
  principio); `Paths.root` acepta `HL_ROOT`; el llavero sigue leyendo los servicios `hypr-liquid`/`hypr-liquid-remote`;
  17-theme-apps/16-gtk/90-files sustituyen las líneas y temas que dejó el nombre anterior; el greeter acepta la sesión
  `hypr-liquid.desktop`.
- `scripts/hf-migrate [--dry-run]` migra una instalación existente (carpetas, repo, `~/.local/bin/hl-*`, lanzadores) e
  imprime los pasos con sudo. Su paso 6 limpia lo que dejaron funciones retiradas (los perfiles de actividad: estado en
  `~/.local/state/hyprfrijol/`, claves de settings.json con copia `.antes-sin-perfiles`); solo ese paso:
  `hf-migrate --retired-only`, que `hf-apply` lanza solo si queda algo. `hf-session`, `hf-apply` y `hyprland.lua` lo llaman con `--dirs-only` si aún existen las
  carpetas `…/hypr-liquid` reales. Pruébalo siempre con `HOME=<carpeta de prueba> scripts/hf-migrate --repo <copia>`.

## Instalador

- `install.sh` lee las dependencias de `install/packages.tsv` (una dependencia lógica por línea, nivel
  base/required/recommended/optional/greeter y el paquete en cada familia: arch, fedora, suse, debian, void).
  Si un script o módulo empieza a usar otro programa, añádelo ahí (y comprueba el nombre en cada distro).
  Columnas 9 y 10 (install.sh no las lee): la **función** que lo usa (clave de las líneas `#@función`, casi siempre
  la sección de Ajustes) y las **órdenes** que trae. Nivel `manual` = solo para cierto hardware (GPU híbrida,
  Limine): ni `--full` lo instala. `--full` instala todos los opcionales; sin él, el resumen lista las funciones
  opcionales saltadas con `hf-deps install <función>`.
- `scripts/hf-deps` — `status [función|id] [--json]`, `missing [--level recommended|optional|manual] [--json]`
  (sale con 1 si falta algo), `install <función|id…|--recommended|--all> [--dry-run] [--yes] [--pkexec]` (sudo en la
  terminal, pkexec sin terminal o con `--pkexec`; AUR con paru/yay) y `explain <orden>`. Da por instalado lo que
  tiene todos sus programas aunque venga de otro paquete. Lo usan `hf-doctor` (recomendadas que faltan, por
  función) y la IA (consulta `deps`, herramienta `check_deps` en hf-ai/hf-mcp). Pruébalo con `HF_DISTRO=fedora
  scripts/hf-deps install vm --dry-run`.
- Las fuentes de Hyprland ≥ 0.57 y Quickshell por distro (COPR, OBS, PPAs) están en `setup_sources` y `hypr_help`.
- Probar sin tocar nada, simulando otra distro y con un HOME de prueba:
  `HOME=/tmp/hf-home HF_DISTRO=fedora ./install.sh --dry-run` (también `HF_DISTRO_VERSION=24.04`, `--full`,
  `--greeter`, `--uninstall --purge`). `--dry-run` nunca ejecuta nada con efectos; solo consulta el gestor de
  paquetes del sistema real cuando no se simula otra distro.
- `install/bootstrap.sh` es la instalación en una línea (`curl … | bash`).

## Que no se rompa: modo seguro, diagnóstico y actualizaciones de HyprFrijol

- **Modo seguro** — `config/hypr/safe.lua` es autónomo a propósito: no carga `frijol/*`, `settings.lua`,
  `local.lua`, Quickshell ni plugins (solo lee `kbLayouts` de settings.json con un patrón, protegido con `pcall`).
  Lo arranca `hf-session --safe` (entrada `hyprfrijol-seguro.desktop` que crea `install.sh`; el greeter la pone al
  final y no la recuerda). Abre una terminal con `hf-safe menu`; Super+R la vuelve a abrir, Super+M sale al login.
  Pruébalo con `dev/try.sh -S` (comprueba que no hay Quickshell en la sesión) y `Hyprland --verify-config --config config/hypr/safe.lua`.
- **`scripts/hf-safe`** — `menu`, `status --json`, `reset-settings`, `disable-local`, `disable-plugins` (pone
  `pluginsAutoload=false`, `plugins.*.on=false` y `omarchyPlugins=false` y cualquier interruptor booleano `omarchy*Autoload|Enabled`),
  `snapshot`/`list`/`restore [ID]` (copias de `~/.config/hyprfrijol` en `~/.local/state/hyprfrijol/snapshots/`, 12 +
  la buena), `mark-good`, `normal`, `safe`, `offer`. Toda acción que cambia algo guarda antes una copia; sin terminal
  necesita `--yes`. Usa siempre el repo de su propia ruta (un `HF_ROOT` roto no impide recuperar).
- **Vigilante** — `hf-shell watch` cuenta las caídas del shell en los primeros 5 min; al llegar a `safeModeCrashLimit`
  (3; 0 = nunca) llama a `hf-safe offer` (aviso de Hyprland + `notify-send` con acciones; si no hay servidor de avisos,
  abre la terminal con el menú). Tras 90 s estable llama a `hf-safe mark-good`. Probado matando el Quickshell de la
  sesión de prueba (solo el que tiene su `HYPRLAND_INSTANCE_SIGNATURE`).
- **`scripts/hf-doctor`** — solo lee. Texto o `--json` (deja el último en `~/.cache/hyprfrijol/doctor.json`, que
  muestra Ajustes › Sistema › Diagnóstico), `--copy`, `--save`, `--quick`. Cada comprobación es `add <ok|info|warn|error>
  <nombre> <detalle>` dentro de una `section`; añade las nuevas así. `redact()` oculta `$HOME`, usuario, correos,
  claves (`sk-…`, `ghp_…`, `AIza…`, `Bearer …`, `api_key=…`) y contraseñas en URLs: pásale cualquier texto nuevo.
- **`scripts/hf-update`** (≠ `hf-updates`, que son los paquetes del sistema) — `check|status|list|notes|apply <tag>|rollback|auto`
  sobre el clon donde vive el script (`--repo` para otro). Cambia con `git checkout --detach <tag>`, guarda el historial
  en `~/.local/state/hyprfrijol/hf-update-history`, después enlaza los `hf-*` nuevos, ejecuta `hf-migrate --no-repo`,
  `hf-apply` y `hf-shell restart`. Se niega con cambios locales (código 3) salvo `--stash` o si lo aceptas en la terminal.
  `auto` (lo lanza `hf-shell` en una sesión real) respeta `hfUpdateCheck` (weekly|daily|never) y avisa una vez por versión.
  Probar sin red ni GitHub: `git clone --bare . /tmp/x/remote.git`, un clon «publicador» que crea commits y tags y hace
  push, y otro «instalado»: `HOME=<prueba> scripts/hf-update --repo <instalado> --no-restart check|apply|rollback`
  (sin `HYPRLAND_INSTANCE_SIGNATURE`/`HF_SESSION` de tu sesión).

### Publicar una versión

1. Añade arriba en `CHANGELOG.md` una sección `## [X.Y.Z] — AAAA-MM-DD` con lo nuevo (corto, para usuarios).
2. Si hace falta migrar algo (carpetas, claves renombradas de settings.json…), hazlo idempotente en `hf-migrate`
   o en `hf-apply`: `hf-update` los ejecuta siempre tras cambiar de versión.
3. `dev/gen-settings-index.py --check`, `Hyprland --verify-config` de `hyprland.lua` y `safe.lua`, y `dev/try.sh` de lo tocado.
4. Commit en `main` y etiqueta **anotada** (su texto es lo que se ve antes de actualizar; si es ligera se usa el CHANGELOG):
   `git tag -a vX.Y.Z -m "HyprFrijol X.Y.Z" -m "- novedad 1\n- novedad 2"` y `git push origin main vX.Y.Z`.
   Solo cuentan las etiquetas `vX.Y.Z` (sin sufijos): una `-rc1` no se ofrece.
5. Opcional: release de GitHub sobre esa etiqueta con el mismo texto.

## Apps por nivel y menú de Nautilus

- **Catálogo `install/apps.json`** — niveles (`serie`, `productividad`, `destacada`, `creativa`, `experimental`) y una
  entrada por app: `tier`, `task`, `alt_of` (alternativa de otra), `status`, `desktop` (lanzadores posibles), `bin`,
  `roles` (tipos de archivo de `hf-defaults` que hace suyos) y `src`: paquete nativo por familia (`arch`/`fedora`/
  `debian`/`ubuntu`/`suse`; `aur:x`; `-` = no hay), `vendor` (repos de Google y Microsoft en `vendors`), `flatpak`
  (+ `flatpakRemote`, p. ej. el remoto OCI oficial de ArtCraft en `remotes`), `appimage`/`flatpakBundle` (último
  archivo de una release de GitHub que case con `asset`) o `build` (clonar y compilar). `prefer` adelanta una fuente.
  Si cambias o añades una fuente, compruébala: **`dev/check-apps.py`** (red: archlinux.org + AUR RPC, mdapi de Fedora
  44, madison de Debian forky, Launchpad para Ubuntu 26.04, listado de download.opensuse.org para Tumbleweed, Flathub,
  índice OCI de ArtCraft, releases de GitHub) y `--stamp` pone la fecha en `verified`. No inventes fuentes: si no se
  puede comprobar, pon `"status": "sin verificar"` y deja `src` vacío.
- **`scripts/hf-apps`** — `list [nivel] [--json]`, `status`, `plan`, `install <app|nivel|all>`, `remove`, `defaults`,
  `extension [--remove]`. La distro sale de **`install/distro.sh`** (`load_os_release`, `family_of`, `hf_family`; también
  la usa `install.sh`), así que `HF_DISTRO=fedora scripts/hf-apps install all --with-alt --dry-run` enseña los
  comandos de otra distro sin consultar el sistema. Lo de sistema va con `sudo` (terminal) o, con `--pkexec`, en una
  sola autorización de pkexec; `--progress` imprime `@@ i/n paso` (la barra de Ajustes). AppImage en
  `~/.local/share/hyprfrijol/apps/` + lanzador `hf-app-<id>.desktop`; compiladas en `~/.local/src/<id>`.
  `install.sh --apps=…` (por defecto `serie`, pregunta sin `--yes`) lo llama tras la instalación de usuario.
- **Ajustes › Aplicaciones › «Apps de HyprFrijol»** (`modules/settings/ui/AppTiers.qml`) solo enseña `hf-apps list --json`
  y lanza `hf-apps install|remove` en la terminal (`appsInstallMode` "terminal") o con pkexec y progreso ("pkexec").
  Ajustes: `appsPreferFlatpak`, `appsAutoDefaults` (tras instalar las de serie, `hf-apps defaults` → `hf-defaults set`),
  `appsInstallMode`. Ajustes › Apps predeterminadas tiene «Usar las de serie de HyprFrijol».
- **Menú «HyprFrijol» de Nautilus** — `config/nautilus/hyprfrijol.py` (nautilus-python, API 4.0), enlazado en
  `~/.local/share/nautilus-python/extensions/` por `hf-apps extension`. Solo decide qué entradas salen (importa
  `hf-fileact` como módulo, sin lanzar procesos al hacer clic derecho); el trabajo es de **`scripts/hf-fileact`**:
  `ai` (imagen adjunta al asistente; PDF → 1.ª página con `hf-sign render`; texto → su contenido), `sign` (`hf-firmar`),
  `ocr` (tesseract spa+eng, PDF con `pdftoppm` → `wl-copy` + aviso), `convert <fmt>` (ImageMagick / ffmpeg /
  pdftoppm; nunca sobrescribe) y `wallpaper` (`hf-wallpaper <archivo>`). `--print` imprime los comandos sin ejecutar.
  Probar sin Nautilus: stubs de `gi.repository` (Nautilus.Menu/MenuItem) con `python3 -I`, y `notify-send`/`wl-copy`/`qs`
  falsos delante en el `PATH` para no tocar tu escritorio ni tu portapapeles.

## Plugins de Omarchy (capa de compatibilidad)

Carga plugins del ecosistema Omarchy (`manifest.json` con `schemaVersion: 1`) sin Omarchy. El trabajo lo hace
`scripts/hf-plugin` y la shell solo lo enseña.
- **Dónde viven**: `~/.local/share/hyprfrijol/plugins/<id>/`. El estado (activados, en la barra, ajustes por widget y
  origen) está en `~/.config/hyprfrijol/omarchy-plugins.json`. Los temas importados van a
  `~/.config/hyprfrijol/palettes-user.json`, que `hf-apply` y Apariencia mezclan con `palettes.json`. La lista de
  plugins «probados» está en `config/omarchy/probados.json`; el resto sale como «No probado».
- **CLI**: `hf-plugin add <git-url|ruta>` (solo copia y valida, no ejecuta nada) · `list [--json]` · `info` ·
  `enable` (enseña el origen y pide confirmación; `--yes` la salta) · `disable` · `remove` · `bar <id> on|off` ·
  `set <id> '<json>'` · `mark <id> probado|no-probado` · `validate` · `summon|toggle|hide <id> [payload]` ·
  `theme <colors.toml|carpeta|git-url> [--apply]` · `themes` · `theme-remove`.
- **Shell**: `services/OmarchyPlugins.qml` lee `hf-plugin list --json`. `modules/omarchy/OmarchyHost.qml` mantiene
  vivos los `service` y abre los `panel`, `overlay` y `menu` como vista `omarchy:<id>`. `bar/OmarchySlot.qml` pone
  los `bar-widget` en un hueco de la barra. `Commons/` (qs.Commons) y `Ui/` (qs.Ui) son las capas sobre `Theme` que
  imitan las de Omarchy. El kind `bar` (barra completa) no está soportado.
- **IPC** (equivale a `omarchy-shell shell summon <id>`): `qs ipc call omarchy summon|hide|toggle <id> '<payload>'`
  o `qs ipc call shell open omarchy:<id>`. También `omarchy listPlugins|errors|widgets|rescan`.
- **Ajustes**: `omarchyPlugins` (interruptor general) y `omarchyBarSlot` (`"derecha"` junto a la bandeja,
  `"izquierda"` tras los espacios). Sección «Plugins de Omarchy» en Ajustes, aparte de la de hyprpm (Plugins.qml).
- **Fuentes del formato**, leídas el 2026-11-07:
  - github.com/omacom/omarchy, rama `quattro`: `docs/omarchy-shell.md`, `manual/32-shell-plugins.md`,
    `bin/omarchy-plugin-validate`, `shell/services/PluginRegistry.qml`, `shell/Commons/`, `shell/Ui/` y
    `bin/omarchy-theme-color`;
  - el catálogo: github.com/omacom/omarchy-plugin-marketplace, archivos `site/catalog.json` y `registry.json`.
  - Los plugins deben usar `import qs.Commons as Commons` y `Commons.Color`, porque Qt 6.12 ya tiene un tipo `Color`.
- **Probar**: escribe tus propios plugins de ejemplo (nunca ejecutes código de terceros en pruebas). Usa un HOME
  falso y luego `hf-plugin add <carpeta>`, `hf-plugin enable <id> --yes` y `dev/try.sh -x "omarchy summon <id>"`.

## Día a día: dispositivos, descargas, Wallhaven e IA con aprobación (ronda 8)

Como siempre, los scripts hacen el trabajo; el shell, la IA (`hf-ai`/`hf-mcp`) y los atajos solo los llaman.
- **Dispositivos** — `scripts/hf-devices` (udisks2): `list [--json] [--all]` (sale de `lsblk -J`), `mount`, `unmount`,
  `eject` (desmonta las particiones y hace `power-off`; una imagen hace `loop-delete`), `eject-all`, `open`, `disks`
  (GNOME Discos) y `watch`. `watch` imprime una línea JSON por cambio. Escucha `gdbus monitor --system` de UDisks2 y,
  si no puede, consulta cada 3 s. Al conectar una unidad, la monta (`devicesAutomount`), la abre (`devicesOpenOnPlug`)
  y avisa con «Abrir»/«Expulsar» (`devicesNotify`, mediante `notify-send -A` en un hilo).
  - Los discos internos solo se pueden montar. Nunca se desmontan ni se expulsan.
  - `services/Devices.qml` lee el `watch`. `bar/DevicesChip.qml` (`devicesBarIcon`) solo se ve con alguna montada.
    `modules/devices/DevicesPopup.qml` es la vista `w-dispositivos`.
  - **Probar sin tocar discos**: `HF_DEVICES_LSBLK=<json>` sustituye a `lsblk` (y `watch` vigila ese archivo; si lo
    reescribes, simulas que conectas algo). `HF_DEVICES_DRYRUN=1` imprime las órdenes de `udisksctl` sin ejecutarlas.
    Se exportan antes de `dev/try.sh` y la sesión anidada las hereda. Aquí no se pudo usar `udisksctl loop-setup`
    porque el kernel no tiene `loop-control`.
- **Descargas** — `scripts/hf-download`:
  - **Órdenes**: `add [--type auto|video|audio|image|file] [--format …] [--file lista.txt|-] URL…`,
    `list [--json]`, `pause|resume|cancel|retry|remove <id|all>`, `clear`, `open`, `detect`, `tools` y
    `parse <herramienta> < salida`.
  - **Cola**: `~/.local/state/hyprfrijol/downloads/queue.json` (con un cerrojo `flock`). Un trabajador lleva la cola
    (`_worker`, una sola instancia con `worker.lock`). Arranca solo y se cierra al quedarse sin trabajo.
  - **Pausar** termina el proceso, y **reanudar** lo vuelve a lanzar y sigue desde el `.part` (yt-dlp y aria2c `-c`;
    el descargador propio usa `Range`). **Cancelar** borra lo descargado a medias.
  - **Detección**: por extensión y por dominio. Si la dirección no da pistas, al empezar se hace una petición `HEAD`.
    Con aria2c ausente se usa un descargador propio (`_fetch`).
  - **Progreso**: yt-dlp con `--progress-template` (líneas `HFPROG`, `HFTITLE`, `HFFILE`), las líneas `[#… DL: ETA:]`
    de aria2c y una línea por archivo en gallery-dl.
  - **Shell**: `services/Downloads.qml` vigila el JSON, `bar/DownloadsChip.qml` (`downloadsBarIcon`) muestra el anillo
    de progreso y `modules/downloads/DownloadsPopup.qml` es la vista `w-descargas`. En Spotlight funciona
    «descargar <url…>», y también pegar una URL sola.
  - **Probar**: con un HOME falso, enlaces pequeños como `https://www.w3.org/Icons/w3c_home.png`. Sin las herramientas,
    `hf-download parse yt-dlp < salida-grabada`.
- **Wallhaven** — `scripts/hf-wallhaven`:
  - **Órdenes**: `search` (solo aptos por defecto; NSFW únicamente con clave), `fetch`, `set`, `add` (copia con
    `hf-wallpaper add`), `next`, `cache [clear|prune]` y `key status|set|clear`. La clave se guarda como la de Gemini:
    primero `$WALLHAVEN_API_KEY`, luego `secret-tool service=hyprfrijol provider=wallhaven` y, si no, un archivo 600.
    Con `HF_WALLHAVEN_NO_KEYRING=1` no se usa el llavero.
  - **Rotación**: `hf-wallpaper next|random` usa `wh_next` cuando `wallpaperSource = "wallhaven"`. Si falla, sigue con
    la carpeta.
  - **Ajustes**: tarjeta `modules/settings/ui/WallhavenCard.qml` en Fondos.
  - No ejecutes en las pruebas las rutas de `hf-wallpaper` que ponen el fondo: prueba `hf-wallhaven` por separado.
- **IA con aprobación**:
  - **Preview de cada paso**: `hf-ai meta()` añade `kind` (la clave de «aprobar siempre», p. ej. `set:barPos` o
    `device:mount`) y `preview` (qué cambia, p. ej. «abajo → arriba», la ventana o la carpeta).
  - **Plan**: `parse_reply` devuelve `auto` cuando todo está en `aiAlwaysApprove` y no hay ningún paso sin vuelta atrás.
  - **Panel**: `AiChat.qml` tiene una casilla por paso (`sel`), «Aprobar siempre esta acción» y la tarjeta de primera
    vez (`aiOnboarded`). Ajustes › IA › «Aprobadas siempre» (`hf-ai approvals`) sirve para revocar.
  - **Acciones nuevas**: `device`, `download`, `download_ctl` y `wallhaven`.
  - **Consultas nuevas**: `devices`, `downloads` y `wallhaven`.
  - **Herramientas**: `list_devices`, `device_action`, `list_downloads`, `download`, `download_control`,
    `wallhaven_search` y `wallhaven_wallpaper`. `hf-mcp` las publica con anotaciones: `readOnlyHint` para las consultas
    (sin aprobación) y `destructiveHint` para lo que no se puede deshacer.
  - `wallhavenPurity` está en `DENY_KEYS`: la IA no puede cambiarla.
  - **Probar**: `aiProvider: "mock"` con `~/.cache/hyprfrijol/ai-mock.json` y, en la sesión anidada,
    `qs ipc call sidepanel ask "…"`.

## Dictado en tiempo real y comandos de voz (ronda 9)

- **`scripts/hf-dictate`**: VAD por energía (frases cortadas por pausas de `dictationPauseMs`), texto provisional
  (`partial`) y escritura frase a frase (`phrase`) sin reescribir lo ya escrito. whisper.cpp va en un `whisper-server`
  residente por modelo (`$XDG_RUNTIME_DIR/hf-dictate-server-<modelo>.json`) que se cierra tras `dictationKeepLoaded` s
  sin uso; con un modelo grande y sin GPU, lo provisional sale de «base» en otro servidor (`live_model`). Vosk/híbrido si
  hay `python-vosk` (o `hf-dictate install-vosk`). Modos `ptt` (con `--hold`: no escribe hasta «release» por stdin),
  `toggle` y `continuo`.
- **Sin IA en el dictado** (ronda 10): `dictationAI` retirada (hf-migrate paso 6, copia `settings.json.antes-sin-ia-dictado`).
  `auto` prefiere **Vosk** si está instalado con su modelo: `VoskEngine.stream()` da parciales palabra a palabra y la frase
  final con el fin de frase de Kaldi (`SetEndpointerDelays(…, dictationPauseMs, …)`), sin VAD propio ni reescrituras; si
  falta, whisper.cpp. Wake word por defecto **«Distro»** (`hf-voice` `WAKE_ALTS`/`WAKE_LOOSE`: «oye/hey Distro», «distro,»,
  «destro», «distrito» solo si lo que sigue es una orden conocida). `voiceCommands` y `voiceAliases` se miran antes que las
  intenciones de serie (intención nueva `run`); están en `DENY_KEYS` de hf-ai.
- **`scripts/hf-voice`**: intenciones en español sin IA (`parse`/`run`/`test`), YouTube (`yt-dlp --get-id`, o el primer
  `videoId` de la página de resultados, o la búsqueda), teclas al navegador con wtype. Lo demás → `sidepanel ask`.
  hf-ai/hf-mcp: acciones `youtube` y `browser` (herramientas `play_music`, `browser_control`).
- **Píldora**: `modules/dictado/Dictado.qml` usa la geometría de `services/OsdStack.qml` (la misma del OSD); si se ven
  las dos, el OSD se aparta (`OsdStack.push`).
- **Probar sin micrófono** (HOME falso y `HF_DICTATE_RUNTIME=<carpeta>` para no compartir el servidor con tu sesión):
  `hf-dictate record --file clip.wav --simulate-live` (eventos JSON; `HF_DICTATE_OUTPUT=ninguna` no escribe,
  `HF_VOICE_DRY=1` no ejecuta órdenes, `HF_DICTATE_DUMP=<dir>` guarda el audio de cada frase); en la sesión anidada
  `qs ipc call dictado file <clip.wav> [dictado|comando]`. `HF_VOICE_OPEN=<orden>` abre las direcciones con otra orden
  (un navegador falso), nunca tu navegador. Pon `aiProvider: "mock"` en el HOME de prueba: lo no entendido va al asistente.

