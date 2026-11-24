# Scripts de HyprFrijol

Cada función de HyprFrijol tiene un script o comando que funciona solo. Quickshell es solo la cara visual. Así la IA, los atajos y la terminal usan lo mismo.

## Sesión y shell

- **hf-session** — arranca Hyprland con la configuración de HyprFrijol. También modo anidado (`hf-session --nested`).
- **hf-shell** — arranca Quickshell (fondo, barra, paneles) y lo mantiene vivo.
- **hf-lock** — bloquea la sesión con la pantalla de bloqueo de HyprFrijol.

## Apariencia y temas

- **hf-apply** — aplica los ajustes de `settings.json` y genera el tema, `settings.lua` y colores de hyprlock.
- **hf-theme** — cambia el tema desde terminal.
- **hf-wallpaper** — cambia el fondo y regenera los colores con matugen.
- **hf-wallhaven** — busca y descarga fondos de Wallhaven.
- **hf-unsplash** — busca y descarga fondos de Unsplash con crédito.
- **hf-greeter-sync** — copia el tema actual al login (greetd).
- **hf-sunset** — luz nocturna (hyprsunset) para esta sesión.

## Productividad

- **hf-capture** — capturas y grabaciones de pantalla (zona, pantalla, OCR, traducción, IA).
- **hf-clip** — guarda lo copiado en el historial (cliphist).
- **hf-download** — cola de descargas de vídeo, audio, imágenes y archivos (yt-dlp, gallery-dl, aria2c).
- **hf-fileact** — acciones sobre archivos: IA, firmar, convertir, etc.
- **hf-firmar** — abre «Firmar documentos» con un PDF o imagen.
- **hf-pickfile** — selector de archivos para scripts.
- **hf-tareas** — abre/añade tareas.

## IA y voz

- **hf-ai** — asistente de HyprFrijol. Lo usan el panel lateral, Spotlight «?» y `hf-mcp`.
- **hf-mcp** — servidor MCP: expone la API del shell a Claude Code u otros clientes.
- **hf-dictate** — dictado local y comandos de voz.
- **hf-voice** — órdenes de voz (integración con el asistente).
- **hf-screen** — control de pantalla para la IA: OCR, cursor fantasma, clic, teclas.

## Audio y dispositivos

- **hf-audio** — cambia de puerto de audio (auriculares, altavoces, Auto-Mute).
- **hf-devices** — memorias USB, tarjetas SD e imágenes de disco (montar, expulsar).
- **hf-caffeine** — modo cafeína: evita apagado/ Bloqueo por inactividad.

## Sistema y mantenimiento

- **hf-update** — actualiza HyprFrijol por versiones etiquetadas (git tags).
- **hf-updates** — centro de actualizaciones del sistema (pacman, flatpak, fwupd).
- **hf-deps** — dependencias de HyprFrijol por función.
- **hf-doctor** — diagnóstico copiable para pedir ayuda.
- **hf-safe** — modo seguro y recuperación.
- **hf-remove-gtk** — quita apps GTK/GNOME instaladas por defecto.
- **hf-migrate** — migra desde `hypr-liquid` (nombre anterior).
- **hf-vm** — máquinas virtuales y contenedores.
- **hf-vpn** — VPN de NetworkManager, FortiGate y GlobalProtect.
- **hf-remote** — escritorio remoto (RDP, VNC, SSH, SPICE).

## Utilidades de barra y widgets

- **hf-bongo** — escucha el teclado para el gato bongo de la barra.
- **hf-launch** — abre la primera app instalada de una lista.
- **hf-oslogo** — logo del sistema operativo para la barra.

## Apps y catálogo

- **hf-apps** — catálogo de apps por nivel (`serie`, `productividad`, `destacada`, `creativa`, `experimental`).
- **hf-appfile** — ruta, paquete y desinstalación de una app desde su `.desktop`.
- **hf-defaults** — apps predeterminadas (xdg-mime) y autostart.
- **hf-plugin** — carga plugins de Omarchy compatibles.

## Otros

- **hf-perfil** — perfiles de equipo (GPU/CPU) para asistente y dictado.
- **hf-phone** — integración con el móvil (Valent/KDE Connect).
- **hf-sign** — firma de documentos (backend).
- **hf-wine** — utilidades para apps de Windows/Wine.

---

Para la ayuda completa de un script, la mayoría acepta `--help`. Ejemplo:

```bash
hf-ai --help
hf-capture --help
hf-deps --help
```

Para usar un script sin instalarlo en `PATH`:

```bash
cd ~/hyprfrijol
./scripts/hf-doctor
```
