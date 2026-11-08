# Cambios de HyprFrijol

Cada versión es una etiqueta de git `vX.Y.Z`. `hf-update` muestra esta lista (o la anotación de la etiqueta)
antes de actualizar. Formato: la versión más nueva arriba, una sección `## [X.Y.Z] — AAAA-MM-DD` por versión.

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
