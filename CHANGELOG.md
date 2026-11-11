# Cambios de HyprFrijol

Cada versión es una etiqueta de git `vX.Y.Z`. `hf-update` muestra esta lista (o la anotación de la etiqueta)
antes de actualizar. Formato: la versión más nueva arriba, una sección `## [X.Y.Z] — AAAA-MM-DD` por versión.

## [0.8.30] — 2026-11-10

- **Modo de ventanas por espacio, guardado**: Super + Ctrl + Espacio (o clic en el icono nuevo junto a los espacios
  de la barra) cambia el modo (mosaico, desplazamiento, flotante) solo del espacio activo. El icono muestra el modo
  del espacio, de color si tiene el suyo. Estas excepciones ya no se pierden al reiniciar el shell.
- **Mover una ventana a otra pantalla**: Super + Ctrl + Shift + flechas.
- **Consola desplegable**: Super + º abre una terminal que baja desde arriba sobre el escritorio atenuado; la misma
  tecla la esconde y vuelve con lo que tenías.
- **Avisos repetidos juntos**: el mismo aviso varias veces (misma app, título y texto) se queda en uno con «×N».
- **Portal cautivo**: si la red pide iniciar sesión (hoteles, aeropuertos), avisa con un botón para abrir la página
  de acceso; el icono de red de la barra se pone en rojo y el botón de Wi-Fi de los ajustes rápidos la abre.

## [0.8.29] — 2026-11-10

- **Espacios por pantalla**: con varias pantallas, cada una tiene sus propios espacios del 1 al 10. Super + número,
  Super + Shift/Alt + número, Super + Ctrl + flechas y Super + rueda se quedan en la pantalla donde estás, y la barra
  de cada pantalla muestra solo los suyos. Por dentro, la principal usa del 1 al 10 y la siguiente del 11 al 20 (la
  vista general las marca con el nombre de la pantalla). Se apaga en Ajustes › Escritorio y gestos › Espacios de
  trabajo (`wsPerMonitor`). Con una sola pantalla no cambia nada.

## [0.8.28] — 2026-11-10

- **El menú de los iconos de la bandeja se cierra** al hacer clic fuera o al volver a pulsar el icono. Antes se
  quedaba abierto y no había forma de quitarlo. Lo mismo con el desplegable de iconos ocultos.
- **Se retiran las web apps**: la sección de Ajustes, el panel lateral web, sus entradas en Spotlight, el PiP de
  YouTube, sus atajos y `hf-webapp`. El panel lateral queda solo para el asistente de IA. Al actualizar se borran sus
  lanzadores, el enlace `~/.local/bin/hf-webapp` y sus claves de `settings.json` (copia en
  `settings.json.antes-sin-webapps`). Las sesiones guardadas en `~/.local/share/hyprfrijol/webapps` no se tocan: se
  pueden borrar a mano.

## [0.8.27] — 2026-11-10

- **Botones de ventana dentro de la ventana**: la barra de título del shell pasa a ser una pastilla pequeña arriba a
  la derecha de la ventana activa (asa para moverla, minimizar, maximizar y cerrar). Al arrastrar el asa la ventana
  sigue al cursor sin retraso: se quita la animación de movimiento mientras dura. Doble clic en el asa: maximizar.
- Enfocar una ventana (desde el dock, Alt + Tab o al restaurarla) ya no lleva el cursor a su centro
  (`cursor:no_warps`).
- Las ventanas flotantes pueden maximizarse y restaurarse con sus propios botones también en mosaico; las de mosaico
  siguen sin poder hacerlo por su cuenta.
- Límite conocido: Hyprland ignora el botón de minimizar de las apps que dibujan su propia barra (Chrome, apps de
  GNOME…). Para minimizarlas: su icono del dock, o Alt + Espacio › Minimizar.

## [0.8.26] — 2026-11-10

- **Barras de título sin plugins**: en el modo flotante, la ventana activa que no trae su propia barra (terminales,
  apps Qt…) lleva una barra dibujada por el shell. Tiene icono, título, menú, minimizar, maximizar o restaurar y
  cerrar. Arrastrarla mueve la ventana, el doble clic maximiza y el clic derecho abre el menú. Si la ventana está
  maximizada, la barra aparece al llevar el cursor al borde de arriba. Se apaga en Ajustes › Escritorio y gestos.
  Si algo falla, como mucho la barra no aparece: el shell va aparte y no puede cerrar la sesión.
- En el modo flotante funciona el botón de maximizar de las apps que traen su propia barra (Chrome, Firefox, GNOME…).
  En mosaico siguen sin poder maximizarse por su cuenta.
- Para redimensionar sin Super basta con arrastrar el borde de la ventana.
- Hyprbars ya no se ofrece en Ajustes › Plugins y el instalador ya no descarga la fuente Nerd Font: ninguno hace falta.

## [0.8.25] — 2026-11-10

- **El instalador trae la fuente de iconos en todas las distros**: en Arch la instala pacman
  (`ttf-jetbrains-mono-nerd`). En Fedora, openSUSE, Debian/Ubuntu y Void, que no la empaquetan, descarga Symbols
  Nerd Font en `~/.local/share/fonts`. En NixOS se añade `nerd-fonts.symbols-only` a la lista de fuentes que
  propone. Si ya tienes una Nerd Font, no descarga nada.

## [0.8.24] — 2026-11-10

- Los botones de las barras de título usan iconos de Nerd Font (cerrar, maximizar, minimizar, chincheta y menú)
  en vez de símbolos de texto. Sin una Nerd Font instalada siguen los símbolos de texto. El instalador añade
  JetBrains Mono Nerd Font en Arch.

## [0.8.23] — 2026-11-10

- Sin emojis en Ajustes ni en la barra de título: el botón de mostrar en todos los espacios es ahora ⊙.

## [0.8.22] — 2026-11-10

- **El modo flotante se comporta como un escritorio clásico** (Openbox, GNOME):
  - **Barras de título** en las ventanas que no traen la suya, con el estilo de la ventana PiP: menú ⋮,
    mostrar en todos los espacios ⊙, minimizar, maximizar y cerrar. Usa el plugin Hyprbars; al elegir Flotante en
    Ajustes › Escritorio y gestos se ofrece instalarlo (se compila una vez).
  - Chrome, Firefox, las apps de GNOME, VS Code, Discord, Spotify… ya dibujan su barra y no se les pone otra.
    La lista se puede cambiar en **Apps con su propia barra**.
  - **Menú de ventana** con **Alt + Espacio** o el botón ⋮: minimizar, maximizar o restaurar, mostrar en todos los
    espacios, organizar, mover a otro espacio y cerrar.
  - **Se enfoca con clic**, no al pasar el cursor.

## [0.8.21] — 2026-11-10

- **El portapapeles muestra las imágenes copiadas desde el gestor de archivos**: Nautilus, Thunar o Dolphin solo
  copian la ruta del archivo y se veía `file:///…/foto.png`. Ahora sale la miniatura y el nombre, y al copiarla desde
  el historial se pega la imagen, no la ruta. Si la fijas, se guarda una copia, así que sigue aunque borres o muevas
  el original. Si copias varias a la vez, siguen saliendo como texto.
- Las miniaturas cargan aunque el nombre del archivo lleve `#`, `?`, `%`, espacios o tildes.

## [0.8.20] — 2026-11-10

- **Dos voces: Helpert y Sophia.** El asistente se llama ahora **Helpert** (antes Samantha), con una personalidad
  nueva, sobria y directa, como un buen mayordomo. Habla con la voz local. **Sophia** pone la voz de Google a los
  avisos puntuales. Se cubren entre sí: sin clave de Google, o si Google falla, los avisos los dice Helpert.
  Tus ajustes se actualizan solos (copia en `settings.json.antes-de-helpert`). Si habías escrito tu propia
  personalidad, se respeta.
- **Sophia te saluda al entrar** con la hora y el tiempo, una sola vez por sesión (Ajustes › Asistente de IA ›
  «Sophia: saludo al entrar»).
- **Sophia lee los avisos importantes**: los recordatorios del asistente y las notificaciones urgentes. Calla en
  «no molestar» y con las apps que hayas silenciado, y no repite el mismo aviso en menos de un minuto («Sophia:
  avisos importantes»). Las dos opciones vienen apagadas.
- `hf-ai announce "texto"` (Sophia) sustituye a `hf-ai speak --google`.

## [0.8.19] — 2026-11-10

- **Samantha habla con una voz local**: Piper con la voz «sharvard» (español de España). Empieza a sonar en ~1 s
  (antes ~4,6 s con Gemini), no necesita internet ni gasta la cuota gratuita de Google, así que ya no se calla al
  llegar al límite. Ocupa ~250 MB y ~150 MB de RAM solo mientras habla. Se instala desde Ajustes › Asistente de IA
  («Instalar la voz local») o con `hf-ai voice-install`. Sin ella, la voz sigue siendo la de Gemini.
- `hf-ai speak --google "texto"` usa la voz de Gemini a propósito, para avisos puntuales.

## [0.8.18] — 2026-11-10

- **Samantha empieza a hablar antes**: la respuesta se lee en dos trozos. Suena la primera frase en unos 4 s y el
  resto se genera mientras tanto, en vez de esperar a tener todo el audio (con respuestas largas eran 15–30 s de
  silencio). Si Gemini falla a mitad, lo ya generado se oye igual. Cortar la voz o una respuesta nueva siguen
  callando la anterior al momento.

## [0.8.17] — 2026-11-09

- **Hablar con Samantha ya no abre el panel lateral**: con «Hablar con voz» activo, Super + Alt + H (o `hf-ai talk`)
  hace la conversación con el panel cerrado y se oye la respuesta. Queda guardada en el historial de chats como
  siempre. El panel solo se abre si la respuesta propone cambios que hay que aprobar; si algo falla, llega un aviso.
  Sin voz, se sigue abriendo el panel para poder leer la respuesta.

## [0.8.16] — 2026-11-09

- **La voz de Samantha suena limpia**: ya no lee en voz alta «dilo con voz cálida…» antes de cada respuesta, y al
  final ya no suena un ruido como de televisor apagándose (Gemini manda ahora un WAV entero y se envolvía en otro,
  así que sus bloques finales se oían como estática).

## [0.8.15] — 2026-11-09

- **Hablar con Samantha por voz: Super + Alt + H** (mantener: hablar · soltar: se lo pregunta; un toque corto deja el
  micrófono abierto hasta volver a pulsar). Lo dicho no se escribe en la ventana: va al asistente, que contesta con
  voz si «Hablar con voz» está activo. Desde la terminal: `hf-ai talk`. El dictado sigue en Super + Alt + D
  (`hf-dictate toggle` desde la terminal) y todos los atajos se ven con Super + / (nuevo grupo «Voz y asistente»).
- **La voz de Samantha se distingue en la barra**: mientras habla, la onda de audio es siempre una onda rellena en el
  color terciario (con música u otros sonidos sigue el estilo de siempre).
- Las preguntas al asistente desde la voz o desde otras apps (`sidepanel ask`) ya no se pierden cuando el chat aún no
  estaba cargado.
- Gemini: el modelo por defecto pasa a «Gemini Flash» (alias que sigue al más nuevo; gemini-2.5-flash ya no se da a
  cuentas nuevas) y, si está saturado, se reintenta una vez con Flash-Lite.

## [0.8.14] — 2026-11-09

- Voz del asistente más segura: el audio temporal y el registro del reproductor van a una carpeta privada (nunca a
  /tmp), y «parar la voz» solo detiene el reproductor de hf-ai.

## [0.8.13] — 2026-11-09

- **El asistente se llama Samantha** y tiene personalidad propia (cálida, curiosa, cercana). Se cambia en Ajustes ›
  Asistente de IA › Personalidad.
- **Samantha puede hablar**: «Hablar con voz» (Ajustes › Asistente de IA › Personalidad) lee cada respuesta en voz
  alta con Gemini TTS y la clave gratuita de Google AI Studio, aunque el asistente use Claude. No lee el código y
  corta la respuesta anterior si llega otra. A mano: `hf-ai speak "texto"` / `hf-ai speak --stop`.
- Se aceptan las claves nuevas de Google AI Studio (las que empiezan por `AQ.`), y si el proyecto de Google tiene la
  facturación sin saldo se dice claramente (antes parecía el límite del plan gratuito).
- **Clic derecho en un icono del desplegable «›» de la bandeja**: vuelve a abrir su menú (antes se cerraba el
  desplegable y no pasaba nada).

## [0.8.12] — 2026-11-09

- **Las opciones de los iconos de la bandeja que abren una terminal ya funcionan** (p. ej. «Ejecutar Cachy-Update»):
  GLib no reconocía kitty y no abría nada. Nuevo `scripts/xdg-terminal-exec`, que abre la terminal elegida en
  Ajustes › Predeterminadas. Arregla también cualquier app con `Terminal=true` lanzada desde otra app.

## [0.8.11] — 2026-11-09

- **Dictado en tiempo real**: con Super + Alt + D las palabras se van escribiendo en la ventana con foco mientras
  hablas, y lo provisional se corrige solo (con retrocesos) al terminar cada frase. Hace falta `wtype`; con ydotool o
  «Pegar»/«Portapapeles» sigue yendo frase a frase.
  Mientras hablas solo se añaden las palabras en que coinciden dos provisionales seguidos (en dictados largos ya no se
  borra ni se reescribe lo dicho); si una palabra ya escrita cambia, se corrige una vez al cerrar la frase.
- **Super + Alt + D ya no mueve ventanas ni cambia de espacio**: mientras las teclas del atajo están pulsadas no se
  escribe nada (antes las letras se convertían en atajos de Hyprland, como Super + Alt + S).
- **El dictado ya no agranda la pantalla**: nunca escribe con Ctrl, Mayús, Alt o Super pulsados en el teclado (con
  cualquier atajo, no solo el del dictado; lo mira en el teclado físico y escribe a trozos). Antes, pulsar un atajo
  mientras escribía convertía las letras en atajos y el zoom subía hasta 3× (se quita con Super + -).
- **Botón de dictado en la barra** (módulo «Dictado» en Ajustes › Barra; activo por defecto): clic para empezar o
  terminar, resaltado mientras graba.
- El panel del asistente ya no tiene micrófono propio: el dictado es global y escribe también en su caja de texto.

## [0.8.10] — 2026-11-09

- **Cambiar entre fondos en movimiento ya no dispara la CPU**: la copia a la medida de la pantalla y la del login se
  convierten con 2 hilos y la menor prioridad (antes usaban todos los núcleos a la vez). Al cambiar varias veces
  seguidas se corta la conversión del vídeo que ya no está, y las del login en cola ya no convierten cada una su
  fondo viejo.
- **Código con colores en el asistente**: los bloques de código de las respuestas se ven resaltados por lenguaje
  (SQL, terminal bash/zsh/fish, JSON, Python, diff, yaml/toml/ini, HTML/XML, Lua y estilo C: JS/TS/QML/C/Go/Rust…),
  con paleta clara u oscura según el tema. Sin dependencias nuevas (`modules/sidepanel/highlight.js`).
- **Iconos Catppuccin** (catppuccin/vscode-icons, MIT) para todo lo de archivos y código: lenguaje en la cabecera de los
  bloques de código del asistente, documentos adjuntos, resultados de archivos de Spotlight y archivos y carpetas del
  escritorio (con carpetas especiales: src, .config, Descargas, Documentos…). Mocha con tema oscuro, Latte con tema claro.
  Solo se incluyen los 180 iconos usados (`components/CatIcon.qml`; se regeneran con `dev/gen-catppuccin.py`).

## [0.8.9] — 2026-11-09

- **Arranque más ligero**: Quickshell arranca sin páginas enormes transparentes (THP «always» en CachyOS y otras):
  ~165 MB menos de RAM (de ~470 a ~305 MB). `hf-wallpaper restore` ya no vuelve a sacar el fotograma del vídeo ni a
  calcular la paleta si el fondo no cambió (~1 s de CPU y un PNG 4K menos en cada inicio de sesión).
- **Vigilante del shell sin procesos en reposo**: antes lanzaba `sleep`, `flock`, `timeout` y `hyprctl` cada 3 s
  (~115 000 procesos al día); ahora espera con builtins y solo pregunta a Hyprland si el shell no está.
- La búsqueda de actualizaciones en segundo plano corre con la menor prioridad (`nice 19`).
- Ajustes › Notificaciones: las capturas temporales (`/run/user/…`) ya no se guardan como icono de la app (salía un
  icono roto tras reiniciar).
- **Fondo en vídeo, «Tapado por ventanas»** (Ajustes › Fondos › Pausar): ahora mide cuánto tapan de verdad las
  ventanas (≥ 85 % de cada pantalla), también las flotantes. Antes bastaba una ventana en mosaico y, con el escritorio
  flotante, nunca se pausaba.
- **mpvpaper colgado al cerrar sesión**: si la sesión se cerraba con el vídeo pausado, el reproductor (detenido con
  SIGSTOP) no se enteraba y se quedaba para siempre. Ahora se reanuda para que termine solo, y cada cierre del
  reproductor va seguido de SIGCONT. El vigilante del vídeo ya no lo relanza cuando la sesión se ha ido.
- `hf-doctor`: avisa por los volcados de memoria de este arranque; los de días atrás solo se mencionan.
- Para desarrollar: `dev/lint.sh` (revisión estática) y `dev/check.sh` (abre todas las vistas en una sesión anidada y
  falla si hay errores de QML). Ver `dev/DESARROLLO.md`.
- Botones e interruptores de Ajustes usan el `enabled` de Qt en vez de redeclararlo; paletas internas y el arrastre de
  la captura con nombres que no tapan propiedades de Qt.
- Documentación al día con la 0.8.8 (el panel lateral es solo del asistente; las web apps van en ventana o navegador).

## [0.8.8] — 2026-11-09

- **Esquinas de la barra más suaves**: un anillo tenue de 1 px por fuera del contorno ensancha el suavizado (como
  el de las esquinas de Hyprland); a 1x ya no se ven escalones ni un tramo recto a 45°.
- **Paneles a la misma distancia que las ventanas**: el centro de control, las notificaciones, el panel lateral y
  los demás paneles suman al hueco (`gaps_out`) el filo de las ventanas (`border_size`), así su borde visible cae
  donde empieza el contenido de las ventanas, junto a la barra y al borde de la pantalla.
- **Panel lateral solo para el asistente**: las web apps salen del panel (se veían mal y gastaban recursos que el
  navegador ya pone): las que estaban en él se abren en el navegador (en Spotlight y Ajustes › Web apps sigue la
  opción «Ventana propia»). El panel mide **un cuarto de la pantalla** (una columna de un mosaico de 4; también
  «Un tercio» o 400 px en Ajustes › Panel lateral). `hf-migrate` pasa las web apps de modo «panel» a «navegador»
  y cierra sus procesos.
- **Barra: esquinas redondas y suaves**: el contorno de las cápsulas se dibuja con curvas Bézier y suavizado (antes
  tramos rectos que se veían octogonales), +4 px sobre las esquinas de las ventanas por defecto (Ajustes › Barra ›
  Esquinas: +0 / +2 / +4). Sin el contorno gris; en vidrio (Aurora) sin filo, el borde lo da el cristal.
- **Misma distancia que las ventanas**: la barra flotante queda del borde de la pantalla al mismo hueco que las
  ventanas (gaps_out; antes se forzaba a 2–4 px), y con ella el centro de control y los paneles.
- **Ventanas flotantes como en un escritorio clásico** (Ajustes › Escritorio › Ventanas flotantes):
  - **Encajar al soltar**: arrastra una ventana flotante contra un lado y ocupa esa mitad; contra una esquina, ese
    cuarto; arriba (o sobre la barra), toda el área. Soltada lejos de los bordes, una ventana encajada recupera su
    tamaño, centrada bajo el cursor (`config/hypr/frijol/floatsnap.lua` + `snap drop`).
  - **Recordar dónde estaba cada app**: al volver a abrirla flotando, en el mismo sitio y con el mismo tamaño
    (`~/.local/state/hyprfrijol/float-geometry.json`).
  - **Barras de título con botones**: acceso directo a Hyprbars (Ajustes › Plugins), que pone minimizar ·
    maximizar · cerrar en las ventanas flotantes.
  - El antiguo «Acoplar al arrastrar a los bordes» (imán de Hyprland) se llama ahora «Imán al arrastrar».
- **WhatsApp como en la 0.8.6** (si se abre en ventana propia): una columna, la lista o el chat, con «←»; sin la
  línea vertical en medio.

## [0.8.7] — 2026-11-09

- **Personalidad del asistente** (Ajustes › IA › Personalidad): ponle **nombre** (sale en la pestaña del panel y
  en la bienvenida, y sabe que se llama así) y escribe **cómo quieres que sea**: tono, trato, idioma, largo de las
  respuestas… Se suma a sus instrucciones de siempre; no le quita permisos ni la confirmación de cambios, y él no
  puede cambiarla.
- **Pomodoro, temporizador y alarmas** en la ventana del chip, ordenada en tres pestañas:
  - **Pomodoro**: bloque (Foco / Descanso / Largo) y rondas arriba, el anillo, «¿En qué te vas a concentrar?»
    (opcional), y debajo las duraciones y opciones.
  - **Temporizador**: cuenta atrás suelta con minutos rápidos (1 min – 1 h, se recuerdan) o ±1 min, «¿Qué te
    recuerdo?» opcional y alarma con aviso urgente («Repetir») al acabar. Los temporizadores del asistente se ven
    (y se cancelan) ahí. IPC: `pomodoro timer <min> <actividad>`.
  - **Alarmas** (nuevo): a una hora del día, una sola vez o los días que marques (L M X J V S D), con etiqueta.
    Suenan con aviso urgente que trae «Posponer 5 min» y «Detener»; las de una vez se apagan solas. IPC:
    `alarms add <HH:MM> <etiqueta>` · `list` · `remove <id>`.
- **Parlante o auricular, a mano** (Ajustes › Sonido y ajustes rápidos): si tu salida tiene los dos en la misma
  tarjeta (línea trasera + jack frontal), debajo sale un interruptor «Parlante (línea) | Auriculares». Elegir el
  parlante con el auricular enchufado desactiva el silencio automático del chip para que suene igual
  (`scripts/hf-audio`; necesita `amixer` para eso).
- **Web apps**:
  - **Zoom en la cabecera del panel** (− 90 % +; clic en el número: 100 %; rueda encima), el mismo de Ctrl + / Ctrl −.
  - **YouTube (y las demás) ya no se quedan en negro** al volver a su pestaña hasta mover el ratón: se fuerza a
    Chromium a pintar al traerlas.
  - **Avisos con la web app escondida**: la página ahora sabe cuándo está guardada (antes se creía siempre a la
    vista y WhatsApp no avisaba de nada).
  - **Panel lateral más estrecho**: por defecto mide lo mismo que el centro de control (404 px); en Ajustes › Panel
    lateral › Ancho también hay 480 px y un tercio de la pantalla. Las web apps lo siguen salvo que tengan su
    propio ancho («Un tercio», 600 u 800 px en Ajustes › Web apps).
  - **WhatsApp en el panel estrecho**: la lista de chats arriba y el chat abierto abajo, mitad y mitad (con «✕»
    para cerrarlo); sin chat abierto, la lista ocupa todo. Sin encoger el zoom para caber ni la línea vertical que
    quedaba en medio.
  - **Cerrar si no la usas** (Ajustes › Web apps): columna Nunca / 15 / 30 / 60 min en cada fila del panel lateral;
    no aparece en las de mensajería.
- **Fondos en movimiento**:
  - **Sin pantallazo negro al cambiar de vídeo**: el nuevo se pone encima del viejo cuando ya pinta (antes entraba
    con un fundido de capa de Hyprland y a medio camino se veía negro o los dos mezclados). Entre imágenes, la nueva
    aparece encima de la anterior sin dejar ver lo de detrás.
  - **Vídeos a la medida de tu pantalla**: un fondo 4K se convierte una vez, en segundo plano, a la altura de la
    pantalla y a los fps elegidos (caché en `~/.cache/hyprfrijol/wallpapers-scaled`); mpvpaper decodifica hasta 4
    veces menos píxeles. `wallpaperScale: false` lo desactiva.
  - **Pausar cuando está tapado por ventanas** (Ajustes › Fondos): nueva opción, apagada por defecto.
- **Menos CPU**: la onda de audio de la barra pinta sus barras en la GPU y a 30 fps (con música, el shell pasó de
  ~8 % a ~4 %, cava de 1,3 % a 0,7 %).
- **Sin procesos huérfanos al reiniciar el shell**: `nmcli monitor`, `hf-devices watch`, cava y los bucles de la
  barra mueren con él (antes se quedaba una copia por cada reinicio).
- **Avisos de kitty** (y de apps cuyo icono es una ruta): ya no se toman por avisos con imagen.
- **Barra**:
  - La zona de la campana ya no tapa la bandeja: al pulsar un icono de la bandeja (p. ej. actualizaciones) se abre
    su menú y no el centro de notificaciones.
  - **Cápsulas (archipiélago / isla) con las esquinas de las ventanas** y el mismo filo que una ventana sin foco;
    Ajustes › Barra › Esquinas les da +0, +2 (por defecto) o +4 px sobre las de las ventanas.
  - **Bongo Cat junto al pomodoro** y un separador entre los botones propios (asistente, ajustes) y los iconos de
    las apps (bandeja).
- **Ajustes**: «Plugins de Omarchy» pasa a ser una pestaña dentro de Plugins (Hyprland · Omarchy).

## [0.8.6] — 2026-11-08

- **El login recuerda tu usuario y tu sesión**: el usuario del greeter tiene la carpeta personal en `/` y no podía
  guardar nada. Ahora usa `/var/lib/hyprfrijol-greeter` (la crea `hf-greeter-sync` o `install.sh --greeter`).
- **Menos gasto en reposo**: la onda de audio de la barra ya no deja cava funcionando a 60 fps cuando no ha sonado
  nada desde el arranque; Bloq Mayús se vigila sin lanzar procesos (antes ~13 por segundo); la red se entera de los
  cambios por eventos (`nmcli monitor`) en vez de preguntar cada 6 s; el brillo no se sondea en equipos sin
  retroiluminación; la lista de ventanas usa un solo `hyprctl` (antes 7 procesos), los títulos llegan del propio
  evento y una ventana que cambia de título sin parar ya no deja la lista sin actualizar; las estadísticas de la
  barra leen `/proc` y `/sys` sin `cat`/`grep` (la mitad de procesos cada 2 s).
- **Cambiar de fondo dos veces seguidas** ya no deja reproductores de vídeo huérfanos: los cambios van uno detrás de
  otro.
- **Avisos**: los botones de acción ya no dejan el aviso a medio cerrar.
- **hf-doctor**: sin el falso aviso de «nvidia sin modeset» cuando ese parámetro solo lo puede leer root.
- **Web apps: Atrás / Adelante** en la cabecera del panel (y Alt + →), salvo en las de mensajería; se puede cambiar
  en Ajustes › Web apps › Más opciones.
- **Web apps: «Cerrar si no la usas»** (Nunca, 15 min, 30 min o 1 h; por defecto Nunca): libera memoria cerrando las
  del panel que llevan ese tiempo sin abrirse. Nunca cierra la que está a la vista, en PiP o sonando.
- **Bloqueo, ajustes rápidos y polkit**: si tu usuario no tiene nombre completo (o no está en `/etc/passwd`, p. ej.
  LDAP), ya no aparece «nofp» en vez de tu nombre.
- **Ajustes › Plugins de Omarchy** muestra la ruta con `~`.
- **Capturas nuevas** en el README (0.8.6, 1920×1080, configuración por defecto).
- **PiP de YouTube**: al salir, el vídeo recupera su tamaño (antes se quedaba a pantalla completa dentro de la web).
- **Indicador de sesión de prueba** en la barra: solo aparece con una prueba de `dev/try.sh` en marcha; clic para
  verla u ocultarla.
- **La onda de audio** escucha menos en silencio: comprobaciones de 2,5 s cada vez más espaciadas (15 → 60 s).
- **Estadísticas de la barra** con un solo proceso en marcha en vez de uno nuevo cada 2 s.
- **hf-doctor** avisa de los volcados de memoria (cuántos, de qué programa y cuánto ocupan).
- **Pruebas** (`dev/try.sh`): cierra los portales antes que el Hyprland anidado (dejaban cientos de volcados de
  memoria), sin la ventana de novedades de Hyprland (también daba segfault) y con su propia carpeta de web apps (antes
  veía las de la sesión real como abiertas y podía mandarles órdenes).

## [0.8.5] — 2026-11-08

- **Imágenes del portapapeles de vuelta**: si habías copiado texto desde Chrome (que lo guarda en UTF-16), la lista
  del historial tenía bytes nulos y `grep` la tomaba por binaria: no salía ninguna miniatura. Esos textos también se
  ven ya bien (antes «h t t p s : / /…»).
- **Filtros por app también en Recientes**: la misma fila que el historial, con cuántos avisos tiene cada app y
  desplazamiento horizontal si no caben; «Borrar estos» borra solo los de la app elegida.
- **Gato bongo con los dibujos del Bongo Cat de VS Code** ([kitgore/BongoCat](https://github.com/kitgore/BongoCat),
  licencia MIT, en `config/quickshell/assets/bongocat`): el gato de línea tumbado, en el color del texto del tema, que
  baja la pata izquierda o derecha al escribir. Calcado con trazos lisos (`bar/bongo.js`; la fuente original se veía
  ondulada a tamaño de icono) y del tamaño de los iconos de la bandeja.
- **Pantalla de carga como la de KDE**: solo el frijolito y una barrita fina que se va llenando, y solo cuando hace
  falta: si el fondo está listo en menos de un cuarto de segundo, no aparece.
- **Super + flechas respeta el mosaico**: cada pulsación lee el estado real de las ventanas (`hyprctl`) y, si hay
  una vecina en esa dirección, se intercambia con ella; si no, la ventana se recoloca en su hueco (arriba/abajo o
  izquierda/derecha de su vecina), así una ventana a media pantalla pasa a ser un cuarto arriba a la izquierda.
  ↑ ya no maximiza encima de las demás (maximizar sigue en Super + D, y cualquier flecha lo deshace); pulsar hacia
  un lado en el que ya está no hace nada. Las apps que flotan siempre (Nautilus, visores…) entran en el mosaico en
  ese lado con la primera flecha, en vez de quedarse encima de las demás (Super + Alt + Espacio las vuelve a soltar).
  En el modo flotante las flechas recorren mitades y cuartos (← y luego ↑ = cuarto de arriba a la izquierda).
- **Panel lateral en columnas**: las web apps del panel miden un tercio de la pantalla (una columna de un mosaico de 3,
  en vez de 560–800 px) y se abren al 90 % de zoom. Fijado, el panel ocupa siempre ese tercio, también en la pestaña
  del asistente: el mosaico queda en tres columnas y las demás ventanas se reparten y se mueven en los otros dos
  tercios. «Ancho en el panel» de cada web app sigue permitiendo 600/800 px o el del panel.
- **Paneles alineados con las ventanas**: el panel lateral (también fijado), el centro de control, las
  notificaciones y el resto de paneles dejan con el borde de la pantalla y con la barra el mismo hueco que las
  ventanas en mosaico (gaps_out), y entre el panel fijado y la ventana vecina el mismo que entre dos ventanas.
- **Asistente más ancho y con respuestas ricas**: mide lo mismo que las web apps (un tercio; Ajustes › Panel lateral ›
  Ancho). Las respuestas se dibujan con formato: bloques de comandos y código con «Copiar», gráficos de barras, líneas
  o sectores (bloque `hf-chart` que el modelo usa cuando aporta o se lo pides) e imágenes.
- **Centro de control sin desplazar todo**: los avisos ocupan el hueco entre los ajustes rápidos y la agenda; con
  muchos solo se desplazan las listas de Recientes e Historial y la agenda queda a la vista.
- **Dictado más preciso y rápido, en español e inglés**:
  - Motor nuevo **Parakeet v3** (NVIDIA, con onnx-asr; `hf-dictate install-parakeet` o el botón de Ajustes › Dictado):
    entiende español, inglés y 23 idiomas más sin elegir, puntúa solo y en CPU tarda ~0,3 s por frase (whisper small
    ~2 s). En «Automático» se usa si está instalado.
  - Antes el automático usaba Vosk, que fallaba mucho y no entendía inglés: ahora va Parakeet → whisper → Vosk.
  - whisper: idioma «Español + inglés» (por defecto; cada frase en el idioma que oye, sin traducir), contexto de audio
    a la medida de la frase y búsqueda en haz: ~2 s por frase en CPU (antes ~3 s) y menos errores.
  - GPU: con `ggml-vulkan` instalado se mide una vez la GPU frente a la CPU y se usa la más rápida (con algunas
    tarjetas y versiones de ggml-vulkan la GPU va varias veces más lenta). `dictationGpu`: auto | si | no.
- **Centro de control en páginas**: los mosaicos se deslizan en horizontal (rueda, Mayús + rueda o arrastrando, con
  puntitos de página). En la segunda página: claro/oscuro, escritorio remoto, cafeína, selector de color y dos
  mosaicos nuevos, **Teléfono** (Valent: abrir, hacer sonar, enviar archivo) y **Duplicar móvil** (scrcpy: instalar,
  abrir, comprobar). La tarjeta del teléfono ya no ocupa sitio abajo.
- **Super + Mayús + S hace lo mismo que Impr Pant**: abre la herramienta de captura (región, ventana, pantalla o
  grabar) en vez de recortar directamente.
- **Grabar un GIF o un clip corto**: en la barra de grabación se elige Vídeo, Clip (hasta 60 s, MP4 ligero) o GIF
  (hasta 30 s, 15 fps, ≤ 960 px). Al terminar se copia el archivo para pegarlo en un chat y el aviso ofrece abrirlo o
  abrir la carpeta. Para enseñar rápido algo que falla.
- **Desenfoque en todos los estilos**: el desenfoque del fondo de SkySoul (selector de espacios, paneles, barra)
  ahora también en Material y Chroma. Se quita con Calidad del desenfoque › Ahorro, modo concentración o Reducir
  transparencia.
- **Web apps más rápidas y sin pantallazo negro**: nacen escondidas, se precargan las del panel al abrirlo la primera
  vez y Chromium ya no congela las que no se ven (por eso YouTube tardaba y al volver se veía negro un momento).
- **Asistente con historial y documentos**:
  - Botón del reloj en la cabecera: todas las conversaciones guardadas con título, fecha y nº de mensajes, buscador
    (también dentro del texto), abrir para seguirla, borrar y «Nueva».
  - Arrastrar y soltar (o el clip) también documentos: PDF, texto, Markdown, código, CSV, DOCX/ODT… El asistente lee
    su texto (hasta 8 por mensaje); se ven como etiquetas en el mensaje y con un clic se abren.
  - Bajo cada respuesta: Copiar y, en la última, «Otra respuesta». Los gráficos usan marcas redondas en el eje.
- **Instalar gallery-dl ya funciona**: no está en los repos oficiales de Arch y se intentaba con pacman; ahora va por
  AUR (yay/paru). Ajustes › Almacenamiento explica para qué sirve cada herramienta de descarga.

## [0.8.4] — 2026-11-08

- **Entrar es ~2,5 s más rápido**: el login esperaba a que pasaran sus cuatro mensajes («Comprobando…»,
  «Bienvenido»…) antes de arrancar la sesión; ahora arranca en cuanto la contraseña es correcta.
- **Pantalla de carga al entrar**: el logo de HyprFrijol y una barrita mientras el fondo y la barra terminan de
  cargar (un segundo o menos; solo al iniciar sesión, no al reiniciar el shell). Se quita en Ajustes › Energía y
  rendimiento › «Pantalla de carga al entrar».
- **Logo de HyprFrijol en Ajustes › Acerca del sistema**, con la versión instalada.
- **Centro de control más rápido**: Spotlight y el centro de control se precargan en segundo plano poco después de
  entrar y el centro se queda cargado (la primera apertura con el teclado tardaba ~220 ms; ahora ~50 ms).
- **Muchas notificaciones sin salirse de la pantalla**: en el centro de control la lista ocupa el hueco que queda bajo
  los ajustes rápidos y se desplaza por dentro (con barra fina); la pila de avisos emergentes tampoco pasa del alto
  de la pantalla. Los filtros por app del historial van en una sola fila que se desplaza en horizontal.
- **Gato bongo** (Ajustes › Barra › «Gato bongo»): un gatito en la barra que golpea la mesa con la pata izquierda o
  derecha al escribir. `scripts/hf-bongo` solo dice la mano, nunca la tecla, y no guarda nada; necesita estar en el
  grupo `input`. Clic: dormirlo.
- **Iconos en vez de «CPU», «GPU» y «RAM»** en el chip de sistema de la barra (estilo texto).
- **Super + flechas respetan el mosaico**: ← → cambian la ventana de sitio con la vecina sin cambiar su tamaño, ↑ la
  maximiza dentro del mosaico y ↓ lo deshace (antes la sacaban a flotante con media pantalla). Una ventana que flotaba
  por un acople anterior vuelve al mosaico. En los espacios flotantes siguen acoplando a mitades.
- **Islas de la barra más juntas**: la de los chips (clima, sistema, pomodoro, cafeína…) y la del estado.
- **Apps GTK de cristal de verdad en SkySoul**: además del desenfoque, el mismo esmerilado claro arriba y el
  resplandor del acento que los paneles del shell, y menos capas opacas encima (antes se veían solo translúcidas).

## [0.8.3] — 2026-11-08

- **Login arreglado**: la sesión ya no vuelve al login nada más entrar. greetd (con `source_profile`) unía los
  argumentos de `sh -c`; ahora la sesión se lanza en palabras sueltas.
- **Tu foto en el login**: `hf-greeter-sync` copia `~/.face` al login, porque el greeter no puede leer tu carpeta personal.
- **El login con tu mismo fondo, también en movimiento**: si tu fondo es un vídeo, el login lo reproduce en bucle y
  sin sonido (una copia ligera; necesita `qt6-multimedia` y `qt6-multimedia-ffmpeg`; si no están, se ve un fotograma).
  La carpeta `/etc/greetd/quickshell/live` pasa a ser tuya: después de la primera sincronización, el login se pone al
  día solo al cambiar de fondo, de tema o de foto, sin pedir contraseña.
- **Fondo en vídeo más fiable**: un vigilante relanza mpvpaper si se cierra (por ejemplo, cuando una pantalla se
  enciende y se apaga al iniciar sesión) y, si no hay manera, vuelve a la imagen fija en lugar de dejar el escritorio
  en negro. `hf-wallpaper` solo cierra el reproductor de su propia sesión.
- **Movimiento del fondo**: activarlo o quitarlo en Ajustes › Fondos se aplica al momento.
- **Cambiar de un fondo en vídeo a otro sin pantallazo negro**: el reproductor anterior sigue hasta que el nuevo ya
  pinta y, mientras tanto, se ve el primer fotograma del nuevo (antes se cerraba primero y a veces el escritorio se
  quedaba en negro hasta otro clic).
- **El selector de fondos (Super+Mayús+W) enseña los vídeos en movimiento**: al pararte en uno se reproduce en
  grande, en bucle y sin sonido (necesita `qt6-multimedia-ffmpeg`; sin él, la imagen fija de siempre).
- **La pantalla de bloqueo también se mueve** con un fondo en vídeo (quieta con «Reducir movimiento» o, si así está
  en Ajustes › Fondos, con batería).
- **El escritorio ya no se queda en negro con un fondo en vídeo** al iniciar sesión: la capa del fondo nacía opaca y
  Quickshell no la dejaba volverse transparente después.
- **Cambiar de estilo ya no cambia tu redondeo**: el estilo solo cambia el material (colores, transparencia, bordes,
  brillos); los radios, las píldoras y las esquinas los decide Ajustes › Apariencia › Redondeo, igual en todos.
- **Estilos renovados**: ahora hay tres, Material, **SkySoul** y **Chroma**.
  - **SkySoul** (antes *Aurora*): el orden de Material hecho de cristal. Muy transparente sobre un desenfoque muy
    amplio, esmerilado más claro arriba, un resplandor suave del acento que se desliza despacio por los paneles
    abiertos (se para con «Reducir movimiento») y bordes de dos trazos: un filo exterior oscuro casi invisible que lo
    separa de cualquier fondo y un filo interior de luz que da grosor al cristal.
  - **Chroma** (sustituye a *Mica*), como los Nothing Phone: negro puro, gris carbón, títulos y reloj con letra de
    puntos (Doto, incluida en `config/quickshell/assets/fonts`, licencia OFL), espacios de trabajo como puntos Glyph,
    deslizadores y anillos de puntos, lo activo en blanco y el rojo solo para lo importante. Usa su propia paleta.
  - SkySoul de verdad translúcido: Ajustes, Herramientas y Firmar nacían opacos en Material y se quedaban negros
    al pasar a SkySoul; y el desenfoque, más fino y luminoso, deja intuir el fondo en vez de un gris plano.
  - Chroma: el aviso de volumen y brillo es una barra de puntos, en rojo si está silenciado.
  - Bordes de SkySoul suaves: el borde de las ventanas es un filo de luz casi transparente (antes una línea del
    color del acento); los paneles y las islas de la barra ya no tienen contorno oscuro, solo un filo de luz que
    se desvanece hacia abajo, y la sombra es tan tenue que no se transparenta por el cristal.
  - **Las apps GTK cambian con el estilo** (con «Aplicar a las apps»): en SkySoul, Nautilus, Loupe y compañía son
    de cristal desenfocado; en Chroma, negro Nothing con lo activo en blanco, filos de 1 px y títulos con Doto
    (se enlaza en `~/.local/share/fonts/hyprfrijol`). Las apps abiertas lo toman al volver a abrirlas.
  - Se retira *Suave*. Quien tenía Aurora pasa a SkySoul, Mica a Chroma y Suave a Material, sin hacer nada.

## [0.8.2] — 2026-11-07

- **Dictado sin IA y en tiempo real con Vosk**: si está Vosk (`python-vosk` + `vosk-api`, ahora recomendado), cada
  palabra aparece mientras hablas y cada frase se escribe al hacer una pausa; whisper.cpp queda como alternativa más
  precisa, por frases (y es el que se usa mientras Vosk no esté: Ajustes › Dictado lo instala con un clic). Se retira
  «Mejorar el texto con IA» (`dictationAI`; `hf-migrate` la quita con copia). La IA solo recibe las órdenes de voz que
  no se entienden. Con el modelo pequeño en español (40 MB): 7,7 % de palabras erróneas en una lectura de 93 s, 33×
  más rápido que el tiempo real en CPU (whisper «base»: 12 %).
- **«Distro»** es la palabra para dar órdenes al dictar («Distro, sube el volumen», «oye Distro…»), en homenaje a las
  distribuciones de Linux; se puede cambiar en Ajustes › Dictado. Quien tuviera «Frijol» sin tocar pasa a «Distro».
- **Órdenes de voz propias**: frase → comando, app, web u otra orden (con `*` para lo que digas), y otras palabras para
  las de serie («toca» = «reproduce»). Se comprueban escribiéndolas, sin ejecutar nada.

## [0.8.1] — 2026-11-07

- **Dictado en tiempo real** (whisper.cpp residente): el texto aparece mientras hablas, en la misma posición que
  los avisos de volumen y mayúsculas, y se escribe por frases. Modelos gestionables desde Ajustes › Dictado,
  GPU (Vulkan) si está instalada y motores Vosk / faster-whisper opcionales.
- **Órdenes de voz** (Super+Alt+V, o «Frijol, …» mientras dictas; `hf-voice`): música en YouTube, YouTube Music
  o Spotify («Reproduce Walk de los Foo Fighters desde YouTube»), volumen, brillo, controles multimedia, el
  navegador (abrir sitios, buscar, pestañas, desplazarse, zoom), espacios, ventanas, fondos, temporizadores… Lo que
  no entiende pasa al asistente, con su aprobación.
- **VPN de empresa**: FortiGate (FortiClient) y GlobalProtect (Palo Alto) con usuario y contraseña, 2FA,
  certificado o SSO/SAML en el navegador, sin sudo (NetworkManager + OpenConnect / openfortivpn / gpclient);
  confianza en el certificado del servidor e importación de copias de FortiClient. Los clientes oficiales
  aparecen si están instalados.
- **Escritorio remoto**: Remmina por defecto para Windows (RDP), con puerta de enlace, varias pantallas, carpetas
  y sonido; FreeRDP 3 y Conexiones como alternativas.
- **Apps en ventana flotante** (Ajustes › Escritorio y gestos): archivos, imágenes, audio, vídeo, calculadora o
  cualquier app se abren flotantes y centradas en vez de en mosaico.
- **Desinstalar apps** desde Ajustes › Aplicaciones › «Instaladas en este equipo» (paquetes y Flatpak), con las
  esenciales protegidas y aviso de lo que se lleva cada paquete.
- **Panel lateral fijable**: el asistente puede quedarse fijo como parte del mosaico en vez de por encima.
- **Calendario plegable** en el centro de control: una sola fila con la semana actual.
- **Sin KDE**: Valent sustituye a KDE Connect (`hf-phone`), las apps Qt usan qt6ct y los selectores de archivo,
  el portal GTK (`hf-pickfile`). Las apps de KDE siguen como alternativa opcional.
- **Selector de fondos** rediseñado, con animaciones más fluidas.
- **Arreglado**: las apps GTK (Nautilus, Loupe…) tardaban hasta 15 s en abrir porque cada recarga repetía las
  rutas de `XDG_DATA_DIRS`; montaje de discos NTFS/exFAT con mensaje claro si falta el controlador o reiniciar.
- **Se retiran los perfiles de actividad** (Trabajo, Diseño 3D, Juego, Personal; `hf-profile`, Ctrl+Super+P).
  Los avisos siguen solo «no molestar» y el modo sin distracciones; la barra, sus propios ajustes (Super+J la
  esconde en la sesión). `hf-migrate` (y `hf-apply` al arrancar) borra su estado y quita `profiles`,
  `profileRules` y `notifyFavorites` de settings.json, con copia. El modo de energía no se toca.

## [0.8.0] — 2026-11-07

Primera versión publicada con etiqueta.

- **Sesión aparte** «Hyprland (HyprFrijol)»: Hyprland 0.57+ configurado en Lua (`config/hypr/`), sin tocar
  `~/.config/hypr`; tus cambios en `~/.config/hyprfrijol/local.lua`.
- **Shell en Quickshell**: barra (abajo, arriba o izquierda; fija o flotante), Spotlight (apps, archivos,
  calculadora, comandos, ventanas, portapapeles, emojis), centro de control (ajustes rápidos, notificaciones,
  agenda), OSD, vista general, Alt+Tab, Snap, dock, widgets y escritorio.
- **Aspecto**: estilos Aurora, Material, Mica y Suave; colores del fondo (matugen) o 45 paletas; claro/oscuro/auto;
  el tema llega a kitty, GTK, Qt/KDE, btop e iconos.
- **Panel lateral** con el asistente de IA: aprobación paso a paso con vista previa, «aprobar siempre» revocable
  y primeros pasos con ejemplos (`hf-ai`, `hf-mcp`); web apps opcionales.
- **PiP** para vídeos, videollamadas (Meet, Teams, Zoom, Jitsi) y reproductores (Spotify, YouTube Music), con los
  botones por fuera de la ventana, en el lado contrario a su posición.
- **Herramientas**: selector de fondos (por monitor, por hora), captura y grabación con lupa, OCR y anotación,
  selector de color, modo sin distracciones, bloqueo, menú de energía, agente de polkit.
- **Ajustes** completos (Apariencia, Barra, Pantallas, Sonido, Red, Bluetooth, Energía, Plugins, Sistema…)
  con buscador; centro de actualizaciones del sistema con punto de restauración (`hf-updates`).
- **Login** propio con greetd + Quickshell, sincronizado con tu tema (`hf-greeter-sync`).
- **Instalador** para Arch, Fedora, openSUSE, Debian/Ubuntu y Void (`install.sh`, `install/packages.tsv`),
  también en sistemas mínimos sin escritorio.
- **Que no se rompa**: modo seguro en el login (`hf-safe`, `config/hypr/safe.lua`), copias «buenas» de tus
  ajustes, diagnóstico copiable (`hf-doctor`) y actualización por versiones con vuelta atrás (`hf-update`).
- **Plugins de Omarchy**: carga widgets de barra, paneles, menús, superposiciones y servicios de la shell de Omarchy,
  e importa sus temas `colors.toml` (`hf-plugin`, Ajustes › Plugins de Omarchy).
- **Aplicaciones por niveles** (de serie, productividad, destacadas, creativas, experimentales) con `hf-apps` y
  Ajustes › Aplicaciones; extensión de Nautilus (preguntar a la IA, firmar PDF, OCR, convertir, poner de fondo).
- **Día a día**: memorias USB con aviso, «Abrir» y «Expulsar» (`hf-devices`, Ajustes › Almacenamiento); cola de
  descargas de vídeo, audio e imágenes (`hf-download`); fondos de Wallhaven (`hf-wallhaven`); discos NTFS y exFAT.
- **Dependencias por función** (`hf-deps`): qué falta para cada parte del escritorio y cómo instalarlo.
- **Carga diferida**: las vistas se cargan al abrirlas (unos 55 MB menos de RAM en reposo).
- **Aspecto por defecto**: paleta Oxocarbon, estilo Material, barra arriba en archipiélago.
