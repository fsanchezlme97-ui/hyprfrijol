# Cambios de HyprFrijol

Cada versión es una etiqueta de git `vX.Y.Z`. `hf-update` muestra esta lista (o la anotación de la etiqueta)
antes de actualizar. Formato: la versión más nueva arriba, una sección `## [X.Y.Z] — AAAA-MM-DD` por versión.

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
  selector de color, perfiles de actividad, modo sin distracciones, bloqueo, menú de energía, agente de polkit.
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
