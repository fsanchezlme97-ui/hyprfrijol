# Cambios de HyprFrijol

Cada versión es una etiqueta de git `vX.Y.Z`. `hf-update` muestra esta lista (o la anotación de la etiqueta)
antes de actualizar. Formato: la versión más nueva arriba, una sección `## [X.Y.Z] — AAAA-MM-DD` por versión.

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
