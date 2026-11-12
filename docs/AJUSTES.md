# Ajustes, Bienvenida y Centro de aplicaciones

## Ajustes (`modules/settings/`)
Ventana flotante «Ajustes» (1280×800) con 17 secciones: Apariencia, Fondos, Barra, Escritorio y gestos,
Enfoque y pomodoro, Asistente de IA, Panel lateral y PiP, Plugins, Pantallas, Teclado y atajos,
Red, Sonido, Energía, Sistema y recuperación, Accesibilidad y Acerca del sistema.

- Abrir: vista `ajustesapp` (`hl.dsp.global("hf:ajustesapp")`, `Shell.open("ajustesapp", "<sección>")`) o
  `qs -p <repo>/config/quickshell ipc call settings open <sección>` (también `close`, `toggle`, `section`;
  `open "<sección>#<etiqueta>"` resalta una fila).
- Cada control escribe en `~/.config/hyprfrijol/settings.json` (vía `Settings.set`) → `hf-apply` regenera
  `~/.local/state/hyprfrijol/settings.lua`. Lo que no es un ajuste (red, sonido, nombre del equipo, apps
  predeterminadas, snapper…) se hace directamente con nmcli, pactl, hostnamectl, xdg-mime, pkexec…
- `Daemons.qml` mantiene vivo lo que lo necesita: luz nocturna (hyprsunset), tema claro/oscuro automático,
  ahorro con batería baja, desenfoque con batería, esquinas calientes, cambio de
  salida de audio, brillo automático, Orca, y una vez por sesión: teclado en pantalla, audio mono,
  EasyEffects y fondo al iniciar. En modo sin distracciones activa «No molestar» (`focusMuteNotifs`).
- Todos los valores por defecto están en `config/defaults/settings.json`.

### Búsqueda, «¿Se ve bien?», valores por defecto y copia de los ajustes
- **Buscar un ajuste concreto**: el campo de la barra lateral (Ctrl+F) muestra «Ajustes» (fila · sección ›
  tarjeta) encima de las secciones que coinciden (sin distinguir tildes). Flechas ↑/↓ e Intro, o clic: abre la
  sección, desplaza hasta la fila y la resalta con un pulso del color de acento. Sale de
  `modules/settings/search-index.json`, generado por **`dev/gen-settings-index.py`** a partir de las etiquetas
  literales de `SwRow`, `LabeledRow`, `InfoRow`, `Card`, los títulos de `Section` y los encabezados
  `Txt { …; weight: Font.DemiBold }` de `sections/*.qml`. **Vuelve a ejecutarlo al cambiar textos de una
  sección** (`--check` dice si está desactualizado). La fila se localiza recorriendo la página cargada
  (propiedad `label`/`title`/`text`), así que el texto del índice debe ser el literal de la sección.
- **Ir a una fila desde otra sección**: `Shell.open("ajustesapp", "<sección>#<etiqueta>")`; `ui/LinkRow.qml`
  es la fila «Se configura en <Sección> ›» que lo usa. Cada ajuste tiene **una sola sección dueña**; las demás
  enlazan a ella: bloqueo por inactividad → Privacidad; aviso en la pantalla de bloqueo → Notificaciones;
  silenciar en modo foco → Enfoque; quitar efectos en juegos → Energía; retardo de repetición → Teclado;
  cambio automático del fondo → Fondos; tema claro/oscuro → Apariencia.
- **«¿Se ve bien? Se deshace en 15 s»** (`services/Confirm.qml` + `ui/ConfirmBar.qml`, abajo en la ventana):
  `Confirm.change("Etiqueta", { clave: valor }, { undo: [[órdenes]] })` aplica el cambio y, sin «Mantener»,
  vuelve a los valores anteriores (borra las claves que no estaban). Lo usan resolución, frecuencia, escala,
  orientación y encendido de pantallas (con `hyprctl eval` para deshacer al momento), estilo visual, redondeo,
  esquinas, escala de la interfaz, posición/forma/tamaño de la barra, «Restaurar valores por defecto» e
  importar ajustes. Cambios seguidos se suman: «Deshacer» vuelve al estado anterior al primero.
- **Restaurar valores por defecto** (icono junto a maximizar, en la cabecera): quita de `settings.json` las
  claves que escribe esa sección (`keys` del índice: `Settings.set("k")`, `key: "k"`, `setMany`/`Confirm.change`
  con `{ k: … }`). Pide confirmación y se puede deshacer.
- **Exportar / importar** (Sistema › Tus ajustes, `services/SettingsIO.qml`): exporta una copia de
  `settings.json` (diálogo de zenity; sin él, `~/Documentos/hyprfrijol-ajustes-<fecha>.json`).
  Importar valida el JSON (un objeto, claves válidas y del tipo de su valor por defecto; el resto se ignora),
  lo mezcla con los actuales y lo aplica con «¿Se ve bien?».
- IPC (pruebas): `ipc call settings search <texto>` · `results <texto>` · `goto <sección> "<etiqueta>"` ·
  `confirm "<etiqueta>" <clave> '<json>'` · `keep` · `revert` · `resetSection` · `exportTo <ruta>` ·
  `importFrom <ruta>` · `ioMessage`.

### Extensiones de hf-apply (`config/apply/*.py`)
`hf-apply` ejecuta cada archivo en orden y añade sus líneas Lua a `settings.lua`:

| archivo | ajustes |
|---|---|
| 10-look.py | `rounding` (null = según el estilo), `blurQuality`, `blurAuto`, `colorFilter` (shaders/), `highContrast`; desenfoque según `estilo` (SkySoul: muy amplio, suave y algo oscurecido en modo oscuro); sombras según `shadows` y `activeBorder` (`brillo`) |
| 20-input.py | `kbLayouts`, `kbSwitch`, `kbRepeat*`, `numlock`, `capsEscape`, `focusOnHover`, touchpad, gestos 3/4 dedos |
| 30-layout.py | `windowMode` + `layout` → `general:layout` (dwindle / master, o scrolling en desplazamiento), `scrollColumnWidth`, `scrollFocusFit`, `scrollOneFull`, `snapEdges` |
| 35-windows.py | `windowMode` (regla `hf-float-all` del modo flotante; `no-maximize`: las ventanas en mosaico no se maximizan por su cuenta, las flotantes sí), `floatApps` + `floatAppsSize` (reglas `hf-float-apps` / `hf-float-apps-compact`) |
| 40-monitors.py | `monitors` {salida: {mode, position, scale, vrr, disabled, mirror}} |
| 50-rules.py | ventanas Ajustes/Herramientas flotantes; sin efectos a pantalla completa (`gameNoFx`) |
| 60-binds.py | `keybinds` {descripción: {from, to}} (acciones en `keybind-actions.json`), `overAmplify`, lupa (`magnifier`: sustituye la lupa básica de binds.lua) |
| 15-apps.py | `fileManager` (solo si está instalado; si no, env.lua usa el primero instalado: Nautilus, Dolphin…), `terminal` |
| 16-gtk.py | con `themeApps`: `gtk-adw.css` (colores de libadwaita: barra lateral, popovers, diálogos) importado en gtk-4.0/gtk.css y `gsettings` `color-scheme` (prefer-dark/default), `accent-color` (el de GNOME 47+ más cercano al color principal) y `gtk-theme` adw-gtk3[-dark] |
| 70-plugins.py | `plugins` {id: {on, …opciones}} → `hl.config({ plugin = { … } })`, atajo/gesto de HyprExpo y Hyprspace; solo para los activados y dentro de una guarda (`hl.get_loaded_plugins()`) |
| 85-idle.py | `idleDim`, `idleLock`, `idleScreenOff`, `idleSuspend`, `lockOnSuspend` → `~/.local/state/hyprfrijol/hypridle.conf` (reinicia hypridle si cambia; la suspensión por inactividad es solo de hypridle) |
| 90-files.py | archivo reduce-motion, `themeApps` (gtk.css / kitty.conf, líneas marcadas), `bigCursor` |

Comprobar: `scripts/hf-apply --print` y `Hyprland --verify-config --config config/hypr/hyprland.lua`.

## Bienvenida (`modules/welcome/`)
Asistente de primer arranque (vista `bienvenida`) en 6 pasos: idioma y región (localectl/timedatectl),
estilo y color, fondo, barra, herramientas (paquetes del catálogo + gestor de archivos) y listo. Se abre solo
2,5 s después del arranque si `welcomeDone` no existe en settings.json; al cerrarlo se guarda `welcomeDone`.

## Centro de aplicaciones (`modules/tools/`)
Vista `herramientas` (argumento `<id>` la preselecciona, `cat:<clave>` abre una categoría, `q:<texto>` busca) o
`ipc call tools open|select <id>|search <texto>|source <id> <fuente>|close`. Catálogo en `config/tools/catalog.json`
(125 apps, categorías y paquetes; flags: s recomendada, n nueva, a alfa, p preview, x XWayland, t terminal, w web).
La lógica es una sola, `services/Pkg.qml`, que usan la tienda, la Bienvenida y Ajustes › Aplicaciones.
Centro de aplicaciones › «Instaladas» (antes en Ajustes › Aplicaciones; `ui/InstalledApps.qml` → `hf-apps installed --json`) lista
todas las apps con lanzador: paquete que las trae (`pacman -Qo` / `rpm -qf` / `dpkg -S` / `xbps-query -o`; AUR con
`pacman -Qm`), Flatpak (usuario o sistema) o AppImage de hyprfrijol, con búsqueda y «Desinstalar» (la orden se abre en
la terminal con `Pkg.runInTerminal`, donde el gestor pide contraseña y confirmación). Protegidas, sin botón: los niveles
`required`/`base` de `install/packages.tsv`, Hyprland, Quickshell, kernel, firmware, systemd, el gestor de paquetes,
portales, la terminal de `terminal`… Avisa si el paquete trae más apps o si otros paquetes dependen de él (Arch).

- **Fuentes por app** (`pkgs`): `pacman` (repos oficiales de Arch), `aur`, `dnf` (+ `dnfRepo`: `rpmfusion-free`,
  `rpmfusion-nonfree` o `copr:usuario/proyecto`), `apt`, `zypper`, `flatpak` (ID de Flathub), `appimage` (página de
  descarga; se integra con Gear Lever), `script` (comando de instalación), `web` (web app) y `url` (descarga manual).
  Si falta `dnf`/`apt`/`zypper` se usa el nombre de `pacman`; `""` = no existe en esa distro. `bin` = ejecutable
  para saber si una app de `script` ya está.
- **Prioridad según la distro**: Arch/CachyOS repos → AUR (paru, si no yay; si no hay ninguno se instala paru antes)
  → Flatpak → AppImage → script → web → descarga; Fedora dnf → Flatpak…; Debian/Ubuntu apt → Flatpak…; openSUSE
  zypper → Flatpak…. Un paquete de `aur` que está en los repos de la distro (`pacman -Slq`, p. ej. los de CachyOS)
  sale como «Repos». Cada tarjeta muestra la fuente (Repos/AUR/Flatpak/AppImage/Web/Script/Descarga); con ▾ se elige
  otra y se guarda en `storeSources` (settings.json, `{id: fuente}`).
- **Instaladas**: `pacman -Qq` (o dpkg/rpm) + `flatpak list`; las instaladas muestran «Abrir» (su .desktop),
  «Desinstalar» (`pacman -Rns`, `apt/dnf/zypper remove`, `flatpak uninstall`) y «Actualizar» si `hf-updates cached`
  tiene una versión nueva (lo de los repos actualiza todo el sistema con `hf-updates run`: Arch no admite
  actualizaciones parciales; AUR `paru -S`, Flatpak `flatpak update`).
- **Búsqueda**: filtra el catálogo; si no hay nada, o con Intro, busca también en repos + AUR + Flathub en segundo
  plano (`pacman -Ss`, `paru -Ss --aur --sortby popularity` / `yay`, `apt-cache search`, `dnf search`,
  `zypper search`, `flatpak search`; 400 ms de espera, máx. 40 resultados, ordenados por relevancia y prioridad de
  fuente). Cada resultado se instala solo o se marca para instalarlo junto con lo demás.
- «Instalar seleccionadas» abre una terminal con los comandos (vista previa en «Ver detalles»), con punto de
  restauración de snapper antes; nunca se instala nada sin que se vea.

## Estilo, redondeo y barra

| Clave | Valores | Qué hace |
|---|---|---|
| `estilo` / `transparencia` | `math` (único desde 0.9.0) / `true` · `false` | estilo Math (Material 3). `transparencia` = paneles de cristal muy transparentes y desenfocados (lo que antes era el estilo SkySoul); con `reduceTransparency` o `highContrast` pasan a tonales sólidos. `hf-migrate` pasa `skysoul`/`aurora` a `transparencia: true` y `flat`/`chroma` a `false` |
| `colorMode` / `palette` | `auto` · `elegir` · `mono` / clave de `config/themes/palettes.json` | `mono` = grises neutros como Chrome (oscuro `#202124`/`#292A2D`/`#35363A`, texto `#E8EAED`, acento `#8AB4F8`; claro con acento `#1A73E8`). Pastel: `rosa` `menta` `lila` `melocoton` `cielo` (grupo `pastel`; cada una con pareja clara `<clave>-claro` vía `"pair"`, que se usa en modo claro en lugar de derivarla con `flip_palette`) |
| `animPreset` | `fluido` · `equilibrado` · `rapido` · `minimo` · `ninguno` | movimiento (Apariencia › Movimiento): curvas y `hl.animation` de Hyprland (`MOTION` en `hf-apply`, va a `settings.lua`) y las duraciones/curvas del shell (`theme.json` → `motion` → `Theme.dur/durIn/durOut/ease/easeIn/easeOut`). Fluido: rebote suave al abrir, espacios con `slide`; Mínimo: solo fundidos. `animado: false` o `reduceMotion` = sin animaciones |
| `animSpeed` | 0.4–2.5 (UI: 0.7 · 0.85 · 1 · 1.25 · 1.5) | multiplicador de velocidad: divide `speed` de Hyprland y las duraciones del shell |
| `workspaceAnim` | `auto` · `slide` · `slidefade` · `fade` · `slidevert` | cambio de espacio (Animaciones y efectos); `auto` = el del preset |
| `dimInactive` | `true` · `false` | oscurece un poco las ventanas sin foco (`decoration.dim_inactive`, fuerza 0.12) |
| Mis temas (Apariencia, `ui/MyThemes.qml`) | `scripts/hf-theme` make/save/list/remove/export/import | pares `propio-<nombre>` + `propio-<nombre>-claro` (group `propio`) en `~/.config/hyprfrijol/palettes-user.json`; se eligen como cualquier paleta (`palette`) |
| `inactiveOpacity` | `0` (automática: 0.97 con desenfoque) · `1` · `0.92` · `0.85` | opacidad de las ventanas sin foco (`decoration.inactive_opacity`) |
| `inactiveOpacityExclude` | clases de ventana | siempre opacas (regla `hf-opaque-apps` de hf-apply) |
| `ripple` | `true` · `false` | onda al pulsar (`components/Ripple.qml`) |
| `shadows` | `ninguna` · `suaves` · `marcadas` | sombras de ventana (10-look.py: `decoration.shadow` range/render_power/offset/color, más tenues y teñidas del acento en modo claro) y de los paneles del shell (`S.shadow*`, `S.shBlur/shY…` → `Glass`) |
| `activeBorder` | `sutil` · `color` · `brillo` · `ninguno` | resaltado de la ventana activa: borde de 1 px con el acento rebajado e inactivas casi invisibles · 2 px con degradado acento → terciario · sutil + halo del acento (`shadow.color` de la activa) · sin borde. Con `highContrast` manda el borde de alto contraste |
| `roundness` | `recto` · `sobrio` · `auto` · `redondo` · `maximo` | multiplica los radios del shell (`Theme.r()`, `Theme.ctl()`) |
| `roundingShape` | `auto` · `circular` · `continua` · `squircle` | `decoration:rounding_power` de las ventanas |
| `rounding` | `null` o px | radio de las ventanas (null = el del estilo) |
| `barHeight` | 24–56 | grosor de la barra; el contenido se escala (`Settings.barScale`) |
| `barPos` / `barMode` | `abajo` `arriba` `izquierda` `derecha` / `fija` `flotante` `isla` `archipielago` | posición y forma (archipiélago: cada grupo en su propia píldora; si flota, el margen con el borde es `gapsOut`, entre 2 y 4 px) |
| `gapsIn` / `gapsOut` | 0–20 | hueco entre ventanas / con el borde y la barra |
| `osdPos` / `osdOffset` | `abajo` `arriba` `centro` `izquierda` `derecha` `inf-der` `sup-der` / px | dónde salen los avisos de volumen, brillo y Bloq Mayús |
| `waveStyle` | `barras` · `onda` · `linea` | onda de audio de la barra (cava a 60 fps) |
| `pipCorner` / `pipFree` | `sup-izq` `sup-centro` `sup-der` `inf-izq` `inf-centro` `inf-der` `libre` / `[x, y]` | posición del PiP; al arrastrarlo se imanta o queda libre |

## Modo de ventanas (Escritorio y gestos · `services/WinMode.qml` + `30-layout.py` + `35-windows.py`)

| Clave | Valores | Qué hace |
|---|---|---|
| `windowMode` | `mosaico` (por defecto) · `desplazamiento` · `flotante` | `mosaico`: las ventanas se reparten la pantalla con el diseño `layout` (sin dock salvo `dockInTiling`). `desplazamiento`: columnas en una cinta que se desplaza (diseño `scrolling` nativo de Hyprland 0.57). `flotante`: escritorio clásico, todas las ventanas flotan (regla `hf-float-all`) y hay dock en todos los espacios. El antiguo `mixto` se lee como `mosaico` y `layout = scrolling` con `mosaico` como `desplazamiento`; `floatWorkspace` ya no se usa |
| `floatApps` | lista de clases de ventana (Nautilus, Loupe, mpv, Celluloid, Showtime, Decibels, Calculadora, File Roller…) | «Apps en ventana flotante» (`ui/FloatApps.qml`): estas apps se abren flotando al centro en vez de en el mosaico (`float` + `center` + `size`; sin distinguir mayúsculas). Interruptores por grupo (Archivos, Imágenes, Audio, Vídeo, Calculadora, Comprimidos), × para quitar una y un buscador entre las ventanas abiertas y las apps instaladas (clase = `StartupWMClass` o id del .desktop). Calculadoras y reproductores de audio pequeños flotan con su propio tamaño (`hf-float-apps-compact`). WinMode no las devuelve al mosaico al salir del modo flotante |
| `floatAppsSize` | `0.65` (0.5 · 0.65 · 0.8) | ancho de esas ventanas respecto a la pantalla (el alto, +7 %) |
| `titleBars` | `true` | botones de ventana del shell (`modules/desktop/TitleBar.qml`): una pastilla dentro de la ventana activa de los espacios flotantes, arriba a la derecha, con asa para moverla (sin la animación de movimiento mientras se arrastra; doble clic maximiza), minimizar, maximizar / restaurar y cerrar; clic derecho: menú (`WinMenu.qml`, también Alt + Espacio). Sin plugins de Hyprland |
| `barsOwnFrame` | navegadores, apps de GNOME, editores, Discord, Spotify, Ghostty | clases que ya dibujan su barra con botones: no llevan los del shell («Apps con su propia barra», `ui/FloatApps.qml`) |
| `layout` | `dwindle` (por defecto) · `master` | diseño del modo mosaico (el antiguo `scrolling` es ahora el modo desplazamiento; al elegir otro modo vuelve a `dwindle`) |
| `scrollColumnWidth` | `0.5` (0.333 · 0.5 · 0.667 · 1.0) | ancho de una columna nueva (`scrolling:column_width`) |
| `scrollFocusFit` | `ajustar` (por defecto) · `centrar` | al enfocar una columna se trae justo a la vista o se centra (`scrolling:focus_fit_method` 1 / 0) |
| `scrollOneFull` | `true` | una sola columna ocupa toda la pantalla (`scrolling:fullscreen_on_one_column`) |
| `dockBehavior` | `inteligente` (por defecto) · `fijo` · `auto` | `fijo`: siempre visible y reserva su franja. `auto`: se esconde y vuelve con el cursor en su borde. `inteligente`: esquiva las ventanas (se aparta cuando una pasa por su zona; en un espacio en mosaico reserva su sitio salvo con una ventana maximizada) |
| `dockInTiling` | `false` | dock también en los espacios en mosaico |
| `dockPos` | `auto` (por defecto) · `izquierda` · `abajo` | dónde va el dock. `auto`: a la izquierda, salvo en una pantalla con otra pegada a su izquierda (el cursor se pasaría a ella sin tocar el borde): ahí abajo, en horizontal |
| `barBehavior` | `siempre` (por defecto) · `auto` · `inteligente` | barra siempre visible, oculta (vuelve con el cursor en el borde; antes `barAutoHide = true`, se migra al elegir) o inteligente (se aparta cuando una ventana flotante la tapa o hay una maximizada / a pantalla completa; en mosaico reserva su sitio salvo con una maximizada, en los espacios flotantes no reserva) |
| `wsNumerals` | `japonesa` (por defecto: 一 二 三) · `arabiga` · `romana` · `puntos` | numeración de los espacios en la barra (`services/WsLabel.qml`, fuente Noto Sans CJK JP); los nombres e iconos propios ganan |
| `wsShowAll` | `true` | la barra muestra siempre del 1 al 9 (si no, solo los ocupados y el activo) |
| `wsPerMonitor` | `true` | espacios por pantalla: la principal usa del 1 al 10, la siguiente del 11 al 20 (en su barra, otra vez del 1 al 10); Super + número, Super + Ctrl + flechas y la rueda se quedan en la pantalla activa. Si la principal guardada no está conectada, hace de principal la más grande. Al cambiar las pantallas, los espacios que ya existen se renumeran sin mover sus ventanas (`config/hypr/frijol/workspaces.lua`) |

- Al cambiar de modo, las ventanas abiertas de los espacios afectados pasan a flotar o al mosaico al momento
  (las que hiciste flotar a mano en un espacio que no cambia se quedan como están).
- Ventanas nuevas que flotan por el modo: centradas, en cascada (32 px) y, si la app pide poco, al 62 % × 70 %
  del área útil; diálogos pequeños (< 560×420) y PiP / ventanas del shell se dejan como vienen.
- Atajo `Super + Mayús + Espacio` (`hf:modoventanas`, «Cambiar modo de ventanas»): mosaico → desplazamiento →
  flotante, con los tres modos en el OSD. IPC: `qs ipc call winmode cycle | set <modo> | setWs <espacio> <modo> | get <espacio>`.
- Ajustes rápidos › Ventanas: clic = siguiente modo; el desplegable elige el modo de todos los espacios y el de
  solo el espacio actual (excepción del espacio; elegir el mismo que el general la quita). También
  `Super + Ctrl + Espacio` (`hf:modoespacio`) o clic en el icono de modo junto a los espacios de la barra. Las
  excepciones se guardan en `~/.local/state/hyprfrijol/ws-modes.json` (vuelven al reiniciar el shell; cambiar el
  modo general las borra). Las excepciones de
  flotar convierten las ventanas; las de diseño (mosaico ↔ columnas) son reglas de espacio de Hyprland
  (`hl.workspace_rule({ workspace, layout })`) que el shell vuelve a poner tras cada recarga de la configuración.
- Desplazamiento (`binds.lua`, `HF.scroll(msg, otro)`: en un espacio con la cinta y la ventana activa en mosaico
  manda `hl.dsp.layout(msg)`, si no hace lo de siempre): `Super + ← / →` y `Super + rueda` cambian de columna
  (`focus l/r`; `Super + Ctrl + rueda` cambia de espacio), `Super + Ctrl + Mayús + ← / →` mueve la columna
  (`swapcol l/r`), `Super + Mayús + ← / →` mete la ventana en la columna de al lado, `Super + ñ / ´` pasa el ancho
  por ⅓ ½ ⅔ y completa (`colresize -conf/+conf`), `Super + Alt + J` saca la ventana a una columna propia
  (`promote`) y `Super + Ctrl + F` encaja las columnas a la vista (`fit visible`). La vista general encoge la cinta
  entera dentro de la miniatura del espacio y enmarca la parte que se ve.
- Minimizar: la ventana va al espacio especial `special:minimized` (`Super + H`, `hf:minimizar`; también el
  botón de minimizar de la app, evento `minimized`). `Super + Mayús + H` (`hf:restaurar`) trae la última al espacio
  actual. En el dock: clic en la app activa la minimiza, clic en una minimizada (icono atenuado, punto apagado)
  la restaura; clic derecho: Maximizar / Restaurar tamaño, Minimizar / Mostrar, Nueva ventana, Fijar y Cerrar.
  Alt + Tab lista las minimizadas al final.
- `Super + ↑` ocupa el área útil, `Super + ↓` restaura el tamaño y sitio previos (o vuelve al mosaico si la ventana
  estaba en mosaico), `Super + ← / →` media pantalla (en desplazamiento, columnas).

## Plugins (`sections/Plugins.qml` + `config/tools/plugins.json` + `70-plugins.py`)
- Catálogo en `config/tools/plugins.json`: id, nombre, descripción, repo para `hyprpm add`, nombre en hyprpm,
  categoría, compatibilidad con Hyprland 0.57 y config Lua (`ok` · `probable` · `sin verificar` · `manual`, con una
  nota de por qué, revisada en los README/hyprpm.toml de cada repo) y las opciones que se ajustan desde la app.
  hyprexpo, hyprtrails, hyprwinwrap, xtra-dispatchers y hyprscrolling salieron de hyprland-plugins en mayo de
  2026: HyprExpo (sandwichfarm) y hyprwinwrap (gen3vra) son forks mantenidos; hyprsplit ya es una biblioteca Lua
  (instalación manual).
- Estado con `hyprpm list` (no instalado · instalado · activado · no compiló); los instalados que no están en el
  catálogo también salen. Sin hyprpm: botón «Instalar hyprpm» (paquete aparte desde 0.57).
- Instalar / Recompilar y «Actualizar todos» abren una terminal (`Pkg.runInTerminal`: `hyprpm update` la primera
  vez, `hyprpm add <repo>` si el repositorio no está, `hyprpm enable <plugin> && hyprpm reload -n`); Activar /
  Desactivar / Recargar corren aquí (`hyprpm enable|disable` + `hyprpm reload`) y traducen los errores
  (cabeceras viejas → «Actualizar todos», no compiló, hace falta reiniciar Hyprland…).
- Opciones por plugin → `plugins` = `{}` ({id: {on, …}}; `on` lo sincroniza la app con hyprpm). `70-plugins.py`
  genera el Lua solo para los activados, dentro de `if has(<plugin>)` + `pcall`: con `--verify-config` o sin el
  plugin cargado no se ejecuta (hyprpm carga el plugin y Hyprland relee la config). Colores de la paleta.
  HyprExpo / Hyprspace: atajo Super + Mayús + Tab o
  Super + Tab (sustituye «Vista general»), sin pisar reasignaciones de Ajustes › Teclado ni gestos en uso.
- «Cargar al iniciar» (`pluginsAutoload` = `true`): `hyprpm reload -n` en `autostart.lua` (no en sesiones anidadas).

## Bluetooth, impresoras, usuarios, fecha e idioma, privacidad

| Sección | Qué usa | Claves |
|---|---|---|
| Bluetooth | `Quickshell.Bluetooth` (`services/Bt.qml`: `paired`, `discovered`, `iconFor`, `kindText`); nombre con `bluetoothctl system-alias`; si el dispositivo pide PIN/código, `bluetoothctl --agent KeyboardDisplay pair` en una terminal; enviar archivo con `bluetooth-sendto`/`blueman-sendto`. Sin adaptador: estado de `bluetooth.service`, rfkill, instalar BlueZ | — |
| Impresoras y escáneres | `lpstat`/`lpoptions` (predeterminada por usuario con `lpoptions -d`), `lp` (página de prueba), `cancel`, `pkexec cupsenable/cupsdisable/lpadmin -x`, `system-config-printer` o http://localhost:631, `scanimage -L`, `simple-scan`; instalación de cups, cups-pdf, gutenprint, hplip, nss-mdns, sane… con `Pkg.commands` en terminal | — |
| Usuarios | AccountsService por `busctl` (`SetRealName`, `SetIconFile`), `~/.face` (recortada a 256 px con ImageMagick), `passwd`/`useradd`/`passwd` en terminal, `pkexec gpasswd -a/-d … wheel`, `pkexec userdel [-r]`; inicio automático = bloque `[initial_session]` de `/etc/greetd/config.toml` (copia en `config.toml.antes-autologin`) | — |
| Fecha, hora e idioma | `timedatectl` (`set-ntp`, `set-timezone`, `set-time`, `set-local-rtc`), `localectl set-locale`, `~/.config/locale.conf` (LANG + LC_TIME/NUMERIC/MONETARY/MEASUREMENT/PAPER), añadir idioma = descomentar `/etc/locale.gen` + `locale-gen` (pkexec) | `clock24` (true; `Time.hhmm`/`Time.ampm`/`Time.fmt()`/`Time.fmtHM()`), `weekStart` (1 lunes · 0 domingo · 6 sábado; calendario de la agenda), `worldClocks`, `calendarCollapsed` (false; botón ⌃ de la cabecera del calendario: solo la semana del día elegido, ‹ › pasan de semana) |
| Privacidad y seguridad | apps que usan micrófono/cámara/pantalla (enlaces de `pw-dump` + `/proc/*/fd` → `/dev/video*`, cada 3 s); borrar recientes (`recently-used.xbel`), `cliphist wipe`, uso de Spotlight (conserva fijados; Spotlight relee el archivo), papelera, miniaturas; `gsettings org.gnome.system.location enabled` y `org.gnome.desktop.privacy remember-recent-files`; estado de cifrado/arranque seguro/TPM/cortafuegos (el interruptor del cortafuegos está en Red) | `idleLock`, `lockOnSuspend` (true; `85-idle.py` quita `before_sleep_cmd`), `notifyLock`, `weatherIpLocation` (true; si es false y no hay ciudad fija, `Weather` no consulta ipapi/ipinfo) |

Componente nuevo: `modules/settings/ui/ConfirmButton.qml` (acción destructiva en dos clics, en `Theme.danger`).

## Dictado y comandos de voz (`sections/Dictado.qml` + `scripts/hf-dictate` + `scripts/hf-voice`)

El dictado es local y **sin IA**. Solo una orden que `hf-voice` no entienda va al asistente (`voiceAiFallback`).

| Clave | Por defecto | Qué hace |
|---|---|---|
| `dictationEngine` | `auto` | `auto` = Vosk si están `python-vosk` y el modelo (tiempo real, palabra a palabra); si no, whisper.cpp · `vosk` · `whisper.cpp` (más preciso, por frases) · `hibrido` (Vosk lo provisional, whisper cada frase) · `faster-whisper` |
| `dictationVoskModel` | `vosk-model-small-es-0.42` | modelo de Vosk (39 MB, ~300 MB de RAM); `vosk-model-es-0.42` (1,4 GB) acierta más pero pide varios GB de RAM. Si falta Vosk, la sección ofrece «Instalar» (Arch: `pacman -S python-vosk vosk-api`; otras: `hf-dictate install-vosk`) y se dicta con whisper mientras tanto |
| `dictationModel` | `base` | modelo de whisper.cpp (`tiny` · `base` · `small` · `medium` · `turbo`) |
| `dictationMode` | `ptt` | `ptt` (mantener) · `toggle` · `continuo` (para tras `dictationSilenceSec` s en silencio) |
| `micMode` | `dictado` | botón del micrófono de la barra y Super + Alt + M: `dictado` · `ia` (hablar con el asistente) · `silencio` (silenciar o activar el micrófono); clic derecho o Super + Shift + Alt + M: el siguiente |
| `dictationPauseMs` | `600` | pausa que cierra una frase (Vosk: retardo del fin de frase; whisper: VAD) |
| `dictationLang` / `dictationOutput` / `dictationPrompt` | `es` / `escribir` / `""` | idioma, cómo se entrega el texto (escribe · pega · copia) y vocabulario para whisper |
| `dictationPunct` / `dictationLive` | `true` / `true` | puntuación y mayúsculas automáticas («coma», «punto y aparte»…) · texto provisional en la píldora |
| `dictationWake` / `dictationWakeWord` | `true` / `"Distro"` | «Distro, …» u «oye Distro …» al empezar una frase es una orden. Se valida en Ajustes (una o dos palabras, solo letras). `hf-migrate` cambia «Frijol» (la de antes) por «Distro» si no la habías cambiado |
| `voiceCommands` | `[]` | órdenes propias, antes que las de serie: `{"phrase": "modo cine", "do": "run" \| "app" \| "url" \| "orden", "value": "…"}`; `*` en la frase recoge lo dicho y se usa como `{x}` en `value` |
| `voiceAliases` | `{}` | otras palabras para las órdenes de serie: `{"toca": "reproduce"}` |
| `voiceMusicService` / `voiceAiFallback` | `youtube` / `true` | dónde suena «pon <canción>» · lo que no entienda, al asistente |

«Comprobar» (orden escrita) usa `hf-voice parse` y no ejecuta nada; «Probar una orden» abre el micrófono.

## Notificaciones (`sections/Notificaciones.qml` + `NotifRules.qml`)

Como en GNOME/KDE: «No molestar» (`Notifs.setDnd`) y su horario, avisos emergentes, sonido, pantalla de
bloqueo y una lista por aplicación. Las reglas las aplica `modules/settings/NotifRules.qml` (creado en
`Daemons.qml`) escuchando `Notifs.list` sin tocar `Notifs.qml`: descarta (`n.dismiss()`) los avisos de apps
bloqueadas, quita de los emergentes los de apps sin emergentes y suena con `canberra-gtk-play`/`pw-play`.

| Clave | Por defecto | Qué hace |
|---|---|---|
| `notifyDndSchedule` / `notifyDndFrom` / `notifyDndTo` | `false` / `"22:00"` / `"07:00"` | «no molestar» automático; solo actúa al cruzar el horario (si lo cambias a mano dentro, se respeta) |
| `notifyPosition` | `"auto"` | `auto` (según la barra) · `sup-der` · `sup-centro` · `sup-izq` · `inf-der` · `inf-izq` (`NotificationPopups.qml`) |
| `notifyTimeout` | `6` | segundos de un aviso emergente si la app no pide otro tiempo (cuenta desde que llegó) |
| `notifySound` / `notifySoundName` | `false` / `"message-new-instant"` | sonido del tema freedesktop al mostrarse un aviso (no con «no molestar» ni `suppress-sound`) |
| `notifyLock` | `true` | número de avisos en la pantalla de bloqueo (nunca el contenido) |
| `notifyApps` | `{}` | `{"<app en minúsculas>": {"allow": false, "popups": false, "sound": false}}` (solo se guardan los `false`); los urgentes siempre salen |

Atajos de «no molestar» (flecha del mosaico en los ajustes rápidos y del botón en el centro de notificaciones,
`modules/notifications/DndPresets.qml`): durante 1 h · hasta esta noche (20:00) · hasta mañana (08:00) · hasta
que lo desactive, con el tiempo que queda (`Notifs.dndLeft`). `Notifs.dndPreset(k)` / `setDndUntil(on, ms)`; la
hora de fin (epoch en ms) se guarda dentro de `~/.local/state/hyprfrijol/dnd` (vacío = sin fin) y un temporizador lo apaga al llegar, también tras reiniciar el shell.
IPC: `notifs dndPreset 1h|noche|manana|siempre|off`, `notifs dndFor <min>`, `notifs dndLeft`.

Apps que han avisado: `~/.local/state/hyprfrijol/notify-apps.json` (`{clave: {name, entry, icon, last, count}}`); «Olvidar» la quita.

## Apps predeterminadas e inicio (`sections/Predeterminadas.qml` + `scripts/hf-defaults`)

Sistema y recuperación ya no tiene apps predeterminadas: enlaza a esta sección.

- Roles: navegador (también `xdg-settings set default-web-browser`), correo, calendario, música, vídeo, fotos,
  PDF, texto, archivos (también `fileManager` → Super + E), comprimidos; cada uno asigna todos sus tipos MIME
  con `xdg-mime default`. Las opciones son las apps instaladas cuyo `MimeType` lo admite; «· recomendada» marca
  la de GNOME. Terminal → ajuste `terminal`.
- «Usar las recomendadas» = `hf-defaults recommended --force`: Nautilus, Loupe, Papers, Showtime, Decibels,
  Editor de texto, File Roller… solo si están instaladas; el navegador no se toca. La Bienvenida lo ejecuta
  después de instalar el paquete «Esenciales» (ahora las apps básicas de GNOME).
- Inicio: `~/.config/autostart` + `/etc/xdg/autostart` (se ocultan las que el shell ya hace: polkit, llavero,
  bandejas de Plasma, notificadores…). Desactivar una del sistema crea una copia con `Hidden=true`
  (`X-HF-Override`); activarla la borra. «Añadir una app» copia su `.desktop`; «Quitar» solo en las tuyas.
- Hyprland no lanza las apps de inicio XDG: `autostart.lua` ejecuta `hf-defaults autostart-run` al iniciar
  sesión (no en sesiones anidadas) salvo que `autostartApps` sea `false`.

```sh
scripts/hf-defaults list | autostart | recommended [--force] | set <rol> <app.desktop>
scripts/hf-defaults autostart-add|autostart-remove <id> · autostart-set <id> true|false · autostart-run
```

## Apps de GNOME por defecto

GNOME/libadwaita encaja mejor con el tema (16-gtk.py): Nautilus es el gestor por defecto (`fileManager`,
`HF.files`), `HF.textEditor` prefiere gnome-text-editor, `HF.taskManager` gnome-system-monitor/Resources, el
dock por defecto empieza por Nautilus, Editor de texto y Calculadora, y el catálogo tiene la categoría
«Apps básicas» (Editor de texto, Calculadora, Loupe, Papers, Showtime, Decibels, Amberol, File Roller, Baobab,
Monitor del sistema, Boxes, Conexiones) con las de KDE como alternativa («alt. a …»: Kate, KCalc, Gwenview,
Haruna, Ark, Filelight; Dolphin y Okular siguen en sus categorías).
Nada depende de KDE: el tema de Qt es qt6ct (`QT_QPA_PLATFORMTHEME=qt6ct` en env.lua; el de Plasma solo si no hay
qt6ct), los selectores de archivos son el portal de GTK o zenity (`scripts/hf-pickfile`), y el móvil va con Valent
(`scripts/hf-phone`: D-Bus `ca.andyholmes.Valent`, dispositivos, batería, enviar archivos, hacerlo sonar; kdeconnect-cli
solo si no hay Valent). Las apps de KDE siguen como alternativas en los selectores.

## VPN, escritorio remoto y máquinas virtuales (`scripts/hf-vpn`, `hf-remote`, `hf-vm`)

Cada sección es solo la cara de su script (salida en líneas JSON, la usan también la IA y la terminal). Las
instalaciones y lo que necesita `sudo` se abren en una terminal (`Pkg.runInTerminal`) para que se vea y confirme.

- **Red › VPN** (`sections/Red.qml`): cualquier VPN de NetworkManager. Lista con conectar/desconectar, editar
  (`nm-connection-editor --edit`, o `nmtui`) y eliminar; «Importar archivo…» (.ovpn, .conf de WireGuard, .pcf…
  con zenity → `nmcli connection import`); «Añadir VPN» por tipo (WireGuard, OpenVPN, Cisco AnyConnect,
  GlobalProtect, Fortinet, Juniper/Pulse, L2TP/IPsec, IKEv2/strongSwan, PPTP, SSTP, Cisco VPNC) con el estado de su
  plugin (`/usr/lib/NetworkManager/VPN/*.name`), botón «Instalar» y un formulario rápido (nombre, servidor,
  usuario) o el editor avanzado. **VPN en malla**: Tailscale y ZeroTier (instalar, activar servicio, conectar,
  unirse a una red).
- **VPN de empresa: FortiGate (FortiClient SSL VPN) y GlobalProtect (Palo Alto)** (`ui/VpnCorpForm.qml`). El formulario
  pide servidor/portal, usuario (opcional), autenticación (`password` · `saml` = SSO en el navegador · `cert`), el aviso
  «Pide código 2FA/OTP» y el **programa** («Automático» elige el mejor instalado; `hf-vpn backends <tipo>`):

  | Caso | Automático | Cómo conecta |
  |---|---|---|
  | FortiGate, contraseña/2FA/certificado | NM fortisslvpn › NM OpenConnect (`--protocol=fortinet`) › openfortivpn | NetworkManager, sin sudo |
  | FortiGate, SSO | NM OpenConnect › openfortivpn | como tu usuario: se abre `https://<gw>/remote/saml/start?redirect=1`, `hf-vpn` escucha la vuelta en `127.0.0.1:8020` (como FortiClient con «navegador externo» y `openfortivpn --saml-login`), pide `SVPNCOOKIE` a `/remote/saml/auth_id` y NM levanta el túnel con la cookie (`nmcli connection up … passwd-file`). Con `openfortivpn-webview` instalado, el SSO va en su ventana (sirve aunque el FortiGate no redirija a 8020) |
  | GlobalProtect, contraseña/2FA/certificado | NM OpenConnect (`--protocol=gp`) › gpclient | NetworkManager, sin sudo |
  | GlobalProtect, SSO | NM OpenConnect + gpclient › gpclient | `gpclient connect --cookie-only --browser` (yuezk, GPL-3; sin root en ese modo) y NM con la cookie. Sin gpclient, la ventana web de NetworkManager-openconnect ≥ 1.2.10 si hay agente (nm-applet) |
  | openfortivpn / gpclient «directos» | solo si no hay NM | en una terminal con `sudo` (pppd/tun y DNS global, sin DNS dividido) |

  **Agente de secretos**: hyprfrijol no trae uno. Si hay uno gráfico en marcha (nm-applet, GNOME, Plasma) NetworkManager
  pide en él contraseña, código y certificado. Si no, `hf-vpn up` abre una terminal: `openconnect --authenticate`
  (contraseña, 2FA y aceptar el certificado) y luego NM con la cookie, o `nmcli --ask connection up` (fortisslvpn).
  **Certificado**: antes de conectar se comprueba el del servidor (openssl); si no lo firma una autoridad conocida, la
  fila muestra la huella `pin-sha256` y «Confiar y conectar» (`hf-vpn trust`: se guarda y se pasa como `gwcert`, o como
  `trusted-cert` a fortisslvpn). **Estado** (`hf-vpn list`): `status` connected/connecting/error y `msg` con un error en
  español (certificado, SSO sin terminar en 5 min, servidor que no responde, portal equivocado, credenciales). Lo propio
  de hyprfrijol va en `~/.config/hyprfrijol/vpn.json` (auth, programa, certificado de confianza) y el estado en
  `$XDG_RUNTIME_DIR/hf-vpn/`. **Clientes oficiales**: FortiClient VPN (`forticlient`, `/opt/forticlient`) y GlobalProtect
  (`globalprotect launch-ui`, `PanGPUI`) salen en la lista con «Abrir» si están; no se toca su configuración.
  **Importar**: una copia `.conf` (XML sin cifrar) de FortiClient crea sus SSL VPN (servidor, usuario si no va cifrado,
  SSO); las `.sconf` cifradas y las IPsec no. **Instalar**: `hf-vpn install fortinet|gp` (paquetes en `hf-vpn pkgs`,
  filas `vpn-fortinet`, `vpn-fortinet-sso` y `vpn-globalprotect` de packages.tsv; gpclient: PPA/COPR de yuezk).
  **Sin servidor real** no se ha probado el túnel: sí el flujo con un `nmcli` y un FortiGate falsos
  (`HF_VPN_NMCLI`, `HF_VPN_BROWSER`, `HF_VPN_FAKE_HAVE`, `HF_VPN_FAKE_CERT`, `--dry-run`, `hf-vpn cmdline`).
- **Escritorio remoto** (`sections/Remoto.qml`; con `app: true` es la app «Conexiones remotas», `modules/apps`): conexiones guardadas en `remoteHosts`
  (`[{name, proto: rdp|vnc|ssh|spice, host, port, user, domain, opts: {fullscreen, dynamicRes, sound, clipboard,
  drives, multimon, gateway}}]`), conexión rápida por URL y clientes. `remoteClient`: `auto|remmina|freerdp|connections`;
  «Automático» = Remmina (recomendado para Windows: RD Gateway, varias pantallas, carpetas, impresoras, sonido, NLA; se le
  pasa un perfil `~/.local/share/hyprfrijol/remmina/<nombre>.remmina` con puerta de enlace, `multimon`, portapapeles,
  sonido y carpeta, conservando la contraseña que guarde Remmina) › FreeRDP 3 (`sdl-freerdp3` › `wlfreerdp3` ›
  `xfreerdp3`: el más rápido, sin interfaz; se usa primero si hay contraseña en el llavero) › Conexiones (la más sencilla,
  sin puerta de enlace: avisa si la conexión la necesita). TigerVNC es solo VNC. `HF_REMOTE_DRY_RUN=1` imprime la orden. Las contraseñas nunca van a
  settings.json: el cliente las pide o se guardan en el llavero (`secret-tool`, servicio `hyprfrijol-remote`) y
  se pasan a FreeRDP por stdin (`/args-from:stdin`). **Compartir**: VNC con wayvnc (`vncListen`, `vncPort`,
  `vncOutput`; `vncListen` = `"127.0.0.1"` por defecto). Sin contraseña wayvnc nunca escucha en la red: `hf-remote
  server start` se queda en 127.0.0.1 y avisa, y «Toda la red» pide antes poner la contraseña (el mosaico de los
  ajustes rápidos dice «Solo este equipo» o «Red · con contraseña»). «Pedir usuario y contraseña» genera `~/.config/wayvnc/config` con TLS y RSA-AES. **Entrar desde Windows
  (RDP)**: hypr-rdp (AUR) comparte esta misma sesión por RDP (mstsc). `rdpServer` (se arranca al iniciar sesión,
  `hf-remote rdp boot`), `rdpListen` (`"tailscale"` por defecto: solo la IP de Tailscale · `"red"` · `"local"`),
  `rdpOutput` (`""` = la principal o, si no está conectada, la más grande · nombre · `"virtual"` = una pantalla
  nueva para la conexión), `rdpPort` (3389). Usuario: el tuyo; contraseña propia de RDP en
  `~/.config/hypr-rdp/password` (600, `hf-remote rdp password`): sin ella nunca se arranca, porque hypr-rdp sin
  credenciales deja entrar a cualquiera. Corre como unidad de usuario `hf-rdp` (se reintenta cada 10 s si Tailscale
  aún no está conectado). **RustDesk** (`hf-remote rustdesk status|portal`): necesita el portal RemoteDesktop
  (`hf-remote rustdesk portal` instala xdph con la PR #448) y el servicio `rustdesk`; la primera conexión se acepta en
  el equipo marcando «recordar». AnyDesk no acepta conexiones entrantes en Wayland (solo Xorg).
- **Máquinas virtuales** (`sections/Virtualizacion.qml`; con `app: true` es la app «Máquinas virtuales», `modules/apps`, con tus máquinas y contenedores): requisitos (VT-x/AMD-V y `/dev/kvm`, QEMU + libvirt,
  socket de libvirt, grupo `libvirt`, Cockpit + cockpit-machines y `cockpit.socket`), «Instalar Cockpit + Máquinas»
  (paquetes por distro, activa los servicios, te añade al grupo y arranca la red `default`), «Abrir Cockpit»
  (`cockpitUrl`), GNOME Boxes, virt-manager, virt-viewer, lista de máquinas (`virsh`, `qemu:///system` solo si
  estás en el grupo, para no disparar polkit) con encender/apagar/pantalla, y contenedores (Podman, Distrobox,
  BoxBuddy) con «Nuevo contenedor».

```sh
scripts/hf-vpn list | plugins | mesh | up|down|delete|edit <uuid|nombre> | import [archivo] [tipo]
scripts/hf-vpn add <tipo> <nombre> <servidor> [usuario] | create <tipo> | install <tipo|editor|tailscale|zerotier>
scripts/hf-vpn add fortinet|gp <nombre> <servidor> [usuario] --auth password|saml|cert [--otp] [--backend …] [--cert f] [--realm r]
scripts/hf-vpn backends fortinet|gp | cmdline <vpn> | trust <vpn> | official | open-official forticlient|globalprotect   (--dry-run)
scripts/hf-remote list | clients | connect <nombre|rdp://usuario@equipo> | secret set|clear <nombre>
scripts/hf-remote server status|start|stop|auth [usuario]|noauth
scripts/hf-vm status | list | start|shutdown|destroy|console <vm> [uri] | install cockpit|virtmanager|boxes|viewer|containers|boxbuddy
scripts/hf-vm enable cockpit|libvirt|group|network | containers | box create <nombre> <imagen> | box enter|stop|rm <nombre>
```

## Ratón y panel táctil, pantallas, sonido y energía (segunda tanda)

| Sección | Qué usa | Claves |
|---|---|---|
| Ratón y panel táctil (`Raton.qml`, `20-input.py`) | `input.sensitivity`, `accel_profile`, `left_handed`, `natural_scroll`, `scroll_factor`, `misc.middle_click_paste`; touchpad `tap_to_click`, `tap_and_drag`, `natural_scroll`, `disable_while_typing`, `clickfinger_behavior`, `scroll_factor`; velocidad y `scroll_method` del touchpad con `hl.device` (nombres guardados + `hl.get_devices()` al cargar); tableta `input.tablet.output` / `left_handed`; OpenTabletDriver (AUR) | `mouseSpeed` (-1…1), `mouseAccel` (adaptive·flat), `leftHanded`, `mouseNatural`, `mouseScroll`, `middlePaste`, `touchpadSpeed`, `tapAndDrag`, `touchpadScroll` (2fg·edge), `clickMethod` (areas·clickfinger), `touchpadScrollFactor`, `touchpadNames`, `tabletOutput`, `tabletLeftHanded` `tapToClick`, `naturalScroll`, `disableWhileTyping` |
| Pantallas | `transform` por monitor (girar con «¿Se ve bien?» y vuelta atrás a los 15 s), pantalla principal → espacios 1–10 (`frijol/workspaces.lua`) y `Shell.primaryScreen`, identificar 3 s | `monitors[*].transform`, `primaryMonitor` |
| Sonido | salida y entrada con icono según el tipo (altavoces, auriculares —puerto activo de `pactl -f json list sinks`—, HDMI, Bluetooth, USB, webcam) y volumen por app con icono, deslizador y silencio: piezas compartidas `components/AudioDevices.qml` y `AudioStreams.qml` (también en los ajustes rápidos: flecha junto al volumen, o clic derecho en el altavoz de la barra → `Shell.open("ajustes", "audio")`); balance (`Audio.balance` / `setBalance`, volúmenes por canal), sobreamplificar (`Audio.maxVolume` 1,5 y la tecla de volumen con `wpctl -l 1.5` en `60-binds.py`), perfil de cada tarjeta (`pactl set-card-profile`), sonidos del sistema (apaga los del pomodoro y de los avisos; `gsettings org.gnome.desktop.sound event-sounds`) | `overAmplify`, `systemSounds` |
| Energía | tapa (con batería / con cargador) y botón de encendido → `/etc/systemd/logind.conf.d/hyprfrijol.conf` (pkexec, `systemctl kill -s HUP systemd-logind`); «Mostrar el menú de apagado» = `HandlePowerKey=ignore` + `XF86PowerOff` → `hf:energia` (`20-input.py`); hibernación (`CanHibernate`); salud y ciclos de la batería (`/sys/class/power_supply/BAT*`, o `$HF_POWER_SUPPLY` para pruebas) con historial diario (`modules/settings/BatteryLog.qml` → `~/.local/state/hyprfrijol/battery-history.json` `[{d, health, full, cycles}]`, línea en la tarjeta); límite de carga 80/90/100 % (pkexec escribe `charge_control_end_threshold` —baja `…start_threshold` si estorba— y deja `/etc/udev/rules.d/99-hyprfrijol-charge.rules`; 100 % la quita; sin pkexec, en una terminal con sudo) | `powerKey`, `chargeLimit` (100) |
| Productividad › Agenda (`ui/IcsCalendars.qml`) | calendarios .ics de la agenda: añadir URL (https/webcal) o archivo, nombre, color (token del tema o `#RRGGBB`), quitar, «Actualizar ahora», estado por calendario (eventos o error de curl en español) y hora de la última sincronización (`Events.status`, `Events.lastSync`) | `calendarIcs` = `[{url, name, color}]` (sigue aceptando solo la URL como texto) |
| Escritorio y gestos (`ui/WsNames.qml`) | nombre e icono/emoji de los espacios 1–10; la barra (`bar/Workspaces.qml`) muestra «icono nombre» en horizontal (icono o número en vertical) y la vista general los usa | `wsNames` = `{}`, `wsIcons` = `{}`, `wsBarNames` = `true`, `wsNumerals` = `"japonesa"`, `wsShowAll` = `true` |

## Índice del resto de claves
Claves de `config/defaults/settings.json` que no salen en las tablas de arriba, con su valor por defecto,
agrupadas por la sección de Ajustes que las cambia. Los controles leen el mismo valor por defecto que este archivo.

| Sección | Claves |
|---|---|
| sin control en Ajustes | `weatherLat` / `weatherLon` = `""` (los pone solos «Ciudad del clima» al buscar la ciudad; vacíos = ubicación por IP) · `printerKind` = `"auto"` · `printerApiKey` = `""` |
| Accesibilidad | preajustes «Alto contraste» (`highContrast` + `reduceTransparency`) y «Texto grande» (`fontScale` = `1.25`) · `highContrast` = `false` (hf-apply `fix_contrast`: texto ≥ 7:1, `o`/`ov` más marcados, Aurora sin vidrio, bordes en Material; 10-look.py: bordes de 2 px) · `reduceTransparency` = `false` · `reduceMotion` = `false` · `kbRepeatDelay` = `400` · `screenReader` = `false` · `magnifier` = `false` · `osk` = `false` · `visualBell` = `false` · `monoAudio` = `false` |
| Acerca | `syncMethod` = `"git"` · `syncApps` = `true` · `syncWallpapers` = `false` |
| Apariencia | `colorMode` = `"elegir"` · `palette` = `"oxocarbon"` · `themeMode` = `"oscuro"` (`auto` = Automático) · `themeSchedule` = `"horas"` (`horas`: claro de `lightFrom` a `lightTo`; `sol`: del amanecer al atardecer de `services/Sun.qml`, el mismo que la luz nocturna; hf-apply `sun_times` hace el mismo cálculo) · `lightFrom` = `7` · `lightTo` = `19` · `themeWallpaper` = `false` · `fontFamily` = `"Inter"` (Tipografía: familias de `fc-list`; con `themeApps` también gsettings `font-name`) · `fontScale` = `1.0` (Tamaño del texto; con `themeApps` también `text-scaling-factor`) · `animado` = `true` · `animPreset` = `"fluido"` · `animSpeed` = `1.0` · `shadows` = `"suaves"` · `activeBorder` = `"sutil"` · `wallpaperRotateMin` = `0` · `wallpaperRandom` = `false` · `monoFondo` = `true` · `wallpaperHora` = `false` · `uiScale` = `1.0` · `wallpaperOnStart` = `false` |
| Barra | `barModules` = `["espacios", "titulo", "musica", "clima…` · `barBehavior` = `"siempre"` · `barScreens` = `{}` (por pantalla: `completa` · `sencilla` · `oculta`) · `barAllScreens` = `true` (pantallas sin elegir: sencilla; `false`: sin barra) · `barSecondaryClock` = `true` · `barTransparentEmpty` = `false` · `barWeatherText` = `false` · `barStatsStyle` = `"barras"` (widgets de la barra: módulos `clima`, `recursos`, `impresora`) |
| Energia | `blurOnBattery` = `true` · `idleSuspend` = `15` · `gpuMode` = `"auto"` · `lowBatterySaver` = `true` · `autoBrightness` = `false` · `idleDim` = `0` · `idleScreenOff` = `10` |
| Enfoque | `pomodoroFocus` = `25` · `pomodoroBreak` = `5` · `pomodoroLong` = `15` · `pomodoroCycles` = `4` · `focusHideBar` = `true` · `focusNoGaps` = `true` · `focusAutoBreak` = `true` · `focusSound` = `true` · `focusBlock` = `[]` |
| Escritorio | `deskSort` = `"tipo"` · `deskIcons` = `"todos"` · `deskIconSize` = `"mediano"` · `weatherCity` = `""` · `printerUrl` = `""` · `hotCorners` = `{"tl": "vista", "tr": "ninguna", "bl"…` · `hotCornerDelay` = `150` · `gesture3Up` = `"vista"` · `gesture3Down` = `"escritorio"` · `gesture4Up` = `"spotlight"` · `gesture4Down` = `"notificaciones"` |
| Escritorio y dock (Desktop.qml, Dock.qml) | `deskOrder` = `{}` · `dockApps` = `[]` · `dockBehavior` = `"inteligente"` · `dockInTiling` = `false` · `dockPos` = `"auto"` |
| Fondos | `wallpaperTransition` = `"fundido"` · `wallpaperNoFullscreen` = `true` · `wallpaperMotion` = `true` · `wallpaperMotionKind` = `"video"` · `wallpaperFps` = `30` · `wallpaperPauseOn` = `["fullscreen", "bateria", "juego"]` |
| IA | `aiProvider` = `"claude-code"` · `aiModel` = `""` · `aiEndpoint` = `""` · `aiKeyEnv` = `"HF_AI_KEY"` · `aiContextWindow` = `true` · `aiContextClipboard` = `true` · `aiContextCapture` = `true` · `aiTerminal` = `true` · `aiControlShell` = `true` · `aiConfirm` = `true` · `aiSpotlight` = `true` · `aiHistory` = `true` · `aiHistoryDays` = `0` (0 = siempre; `hf-ai` borra las conversaciones más viejas al hablar) · `aiRedactSecrets` = `true` (filtro de secretos de `hf-ai redact`) · `aiModelQuick`/`aiModelVision` = `""` (el general) · `aiFallbackProvider`/`aiFallbackModel` = `""` (respaldo) · `aiLocalOnly` = `false` (solo Ollama, sin voces en la nube) · `privateApps` = gestores de contraseñas (clases de ventana; con una delante el asistente no lee ventana, pantalla ni portapapeles). Asistente de IA tiene pestañas: Asistente, Privacidad (`sections/IAPrivacidad.qml`, con el registro de `hf-ai log` y Deshacer), Recetas (`sections/IARecetas.qml`: `hf-ai recipes`/`recipe <id>`/`recipe-save`/`recipe-remove`, las propias en `~/.local/share/hyprfrijol/ai-recetas.json`; salen en Spotlight con el grupo `recetas` de `spotlightGroups`), Dictado y Panel lateral y PiP (`under: "ia"`; sus claves de sección siguen valiendo en enlaces) |
| Panel | `pipSize` = `"pequeno"` · `pip` = `true` · `pipMargin` = `12` · `pipOpacity` = `1.0` · `pipAllWs` = `true` · `pipHoverControls` = `false` · `pipFadeNear` = `false` · `sidePanelApps` = `["ia"]` · `sideWidth` = `"cuarto"` · `sideSide` = `"derecha"` · `sidePanelPinned` = `false` (chincheta de la cabecera o «Fijar el panel»: el panel pasa a formar parte del mosaico en la pantalla principal; una capa invisible `hf-ia-zone` reserva su franja como zona exclusiva y las ventanas se apartan; sigue abierto en todos los espacios, Esc no lo cierra, se aparta con una ventana a pantalla completa y en el modo sin distracciones; Super + A y la × lo esconden en la sesión —`Shell.sideHidden`— y Super + A lo vuelve a mostrar fijado) |
| Pantallas | `nightLight` = `"off"` · `nightTemp` = `5500` (2500–6500 K; al arrastrar se previsualiza con hyprsunset y al soltar se guarda y se vuelve al estado anterior) · `sunAuto` = `true` (amanecer/atardecer con la ecuación de NOAA a partir de la ubicación del clima: `weatherLat`/`weatherLon` o la última por IP en `~/.cache/hyprfrijol/weather.json`) · `sunset` = `"19:00"` · `sunrise` = `"07:00"` (a mano, o si no hay ubicación) · `nightFrom` = `"22:00"` · `nightTo` = `"07:00"` |
| Sistema | `updatesSnapshot` = `true` · `updatesMode` = `"avisar"` · `updatesFlatpak` = `true` · `updatesFirmware` = `true` |
| Sonido | `noiseSuppression` = `false` · `audioAutoSwitch` = `true` |
| Teclado | `kbRepeatRate` = `35` |
| Productividad (pestañas Enfoque, Spotlight (`spotlightGroups`, `spotlightOrder` = `[]` por relevancia, `webSearch` = `"duckduckgo"` o una URL con `%s`), Portapapeles y Agenda; `under: "enfoque"`. Tareas y Alarmas son apps aparte) | `clipboardAutoPaste` = `true` · `clipboardClearOnLogin` = `false` · `clipMaxItems` = `750` · `clipExpireDays` = `0` (0 = nunca; los aplica `scripts/hf-clip store`, que también descarta lo copiado en `privateApps`) · `calendarCollapsed` · `alarms`. Tareas: `~/.local/share/hyprfrijol/tasks.json` (`services/Tasks.qml`; `+texto` en Spotlight; acción `task` de `hf-ai`) |
| Widgets | `widgets` = `["clima", "impresora", "sistema"]` |
