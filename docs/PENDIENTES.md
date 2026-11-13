# Pendientes

Lista de trabajo de HyprFrijol. Sale de la comparación con Caelestia, DankMaterialShell (Dux), Noctalia,
illogical-impulse (end-4) y Omarchy 4.5 (noviembre de 2026). Al terminar algo, se quita de aquí y va al CHANGELOG.

## Planes en curso (en este orden)

Cada plan tiene sus fases y sus decisiones tomadas en `docs/planes/`. Al cerrar una fase se marca aquí.

Estado a 2026-11-11 (v0.9.18). Lo hecho está en el CHANGELOG. Lo que queda de los planes: el espaciado de Math
(punto 4), la revisión con uso real (punto 5) y, opcional, que la IA asigne los papeles de un tema.

1. [x] [Asistente de IA](planes/asistente-ia.md), fase 6 (panel): respuesta en directo con Detener y repetir con
       otro modelo (0.9.13). Los chips de contexto y la lista de conversaciones con búsqueda ya estaban.
2. [x] [Asistente de IA](planes/asistente-ia.md), resto de la fase 1: la página de Inicio (0.9.14). Sin contador de
       uso: el plan lo deja fuera de esta versión.
3. [x] [Temas](planes/temas.md), resto de las fases 4–5: editar los colores uno a uno, editar un tema guardado y la
       vista previa sobre la barra y el centro de control (0.9.15). Queda, opcional en el plan: que la IA asigne los
       papeles de cada color.
4. [x] [Temas](planes/temas.md), fase 3 (pulido de Math). 0.9.16: estados uniformes con foco de teclado, sombra en
       dos capas y filo de luz arriba; la fuente se queda en Inter. 0.9.73: escala de espaciado 4/8/12/16/24 en todo
       el shell (`dev/spacing.py`, vigilada por `dev/lint.sh`) y radios concéntricos (`Theme.inner`) en lo que va
       dentro de un panel: baldosas, rellenos, resumen de avisos y tarjetas del asistente. `Ui/` es la capa de
       compatibilidad con Omarchy y sigue su propio estilo.
5. [x] [Productividad](planes/productividad.md), fase 5 (0.9.57: los cuatro recorridos de la sección 4 en tres pasos o menos): revisión con uso real (la hace el autor usando el
       escritorio; lo que se mide está en la sección 4 del plan). Los relojes del mundo siguen en Fecha, con un
       enlace desde Agenda y alarmas.
6. [x] [Asistente de IA](planes/asistente-ia.md), fase 7: servidores MCP del usuario, con aprobación por servidor
       y confirmación de todo lo que cambia (0.9.17). Por comando (stdio) o por dirección (HTTP). Endurecido en la
       0.9.18: también se confirma lo de solo lectura salvo con «Consultar sin preguntar», https y sin redirecciones.

Cerrado: [Animaciones y efectos](planes/animaciones.md). Las fases 1–5 están hechas y la 6 (ajustes por zona,
reducción automática) se descartó en las decisiones del plan.

## Baratos de añadir (primero)

- [x] **Fondos de Wallhaven y Unsplash**: Wallhaven ya estaba (Ajustes › Fondos); Unsplash en 0.9.36 (`hf-unsplash`)
      y la IA lo busca y pone como Wallhaven (0.9.52; probado con una clave real).
- [~] **Entrar desde otro equipo o el móvil**: AnyDesk no acepta entrantes en Wayland (solo Xorg; lo dice su
      documentación y se comprobó: corta con «servidor de pantalla no admitido» sin tocar el portal). Alternativas: RDP
      (hypr-rdp, 0.9.34) y RustDesk (0.9.40) con el portal RemoteDesktop de xdph + PR #448
      (`install/pkgbuilds/xdg-desktop-portal-hyprland-rd`, solo Arch). Falta: probar una conexión real de RustDesk;
      volver al paquete oficial cuando xdph publique RemoteDesktop; Fedora/openSUSE/Debian.
- [~] **Reinstalar y quedar igual** (`hf-perfil`, 0.9.49): guarda paquetes, servicios, acceso remoto, voz, dictado,
      modelos de Ollama, login y ajustes; `install.sh --perfil=` lo aplica. El repo trae `perfil/perfil.json` sin
      datos personales (0.9.52, `./install.sh --perfil`). Falta: probarlo en una máquina virtual.
- [~] **IA local** (0.9.49): gemma4:e4b en la gráfica (0,5 s; tabla en `docs/IA.md`) como respaldo y, con
      `aiVoiceLocal`, primero en la voz. Medido en 0.9.72 (22 órdenes habladas × 3): todas con su acción en 0,4-0,9 s; las
      dos que «fallaban» (YouTube, Spotify) eran apps sin instalar, ahora abren su web. Ojo: una frase que no es orden
      («te habilité una función para capturar la pantalla») propuso acción 2 de 3 veces y en conversación lo
      reversible se aplica solo. Falta: probarlo con tu voz unos días; ROCm sin probar (gfx1032 no está
      soportado oficialmente y son varios GB).

## Donde vamos por detrás

- [ ] **Idiomas**: textos de la interfaz traducibles; inglés primero (Omarchy tiene 50 y los cambia en vivo).
- [ ] **Rendimiento medido**: memoria y CPU del shell en reposo y con paneles abiertos, comparado con Caelestia y
      Noctalia; quitar sondeos (p. ej. la pastilla de ventana pregunta a Hyprland cada 100 ms) y reaccionar a
      eventos. Hecho (v0.8.48): `dev/perf.sh` y reposo de 4,7 % a ~1 % de un núcleo. Medido en 0.9.75: recién
      arrancado ~360 MB (190 propios) con dos pantallas, estable en reposo; lo que lo subía a 600 MB-1 GB era el
      vídeo de la pantalla de bloqueo en 4K por CPU (ahora usa la copia reducida). Tras desbloquear parte de esa
      memoria no vuelve al sistema (malloc). Falta: la comparación con los otros shells.
- [x] **Pulido de animaciones** (0.9.55): los paneles se transforman entre sí (como Caelestia). Desde la 0.9.33 lo
      hacían los chips de la barra y el centro de control; ahora también Spotlight, energía, actualizaciones, fondos,
      widgets, música y atajos (`morphs: true` en su Overlay). Probado en sesión anidada con capturas a mitad del
      paso. Falta solo verlo en la GT 710 (VGA-1).
- [ ] **Plugins propios**: formato, permisos y un registro con versiones fijadas (como DMS); hoy solo los de Omarchy.
- [ ] **Más compositores** (niri, Sway): evaluar qué partes dependen de Hyprland. Grande; después de lo demás.
- [ ] Detalles de otros shells: desbloqueo facial (Howdy). (Cerrar procesos desde el monitor del sistema: 0.9.29;
      perfil de energía según cargador o batería: 0.9.30, sin probar en un portátil; letras de canciones: 0.9.31.)

## Mejorar lo que ya hay

- [x] **Rendimiento** (cerrado en 0.9.54, medido en la sesión real tras 5 h de uso): arranque en 1-2 s, 0,5 % de un
      núcleo en reposo y ningún proceso lanzado cada pocos segundos (solo vigilantes que esperan eventos). Memoria:
      abrir y cerrar todas las vistas no fuga (`dev/perf.sh -c 3`: se queda en ~330 MB y baja a ~300 al descargarse);
      el chat del asistente recreaba todas las burbujas en cada mensaje y retenía ~2,6 MB por mensaje (ahora ~1,6,
      que es lo que crece la conversación). Limitar los arenas de malloc no cambia nada.
- [x] **Productividad** (revisado en 0.9.57 con los atajos de verdad; ninguno pasa de tres pasos): abrir una app que
      no está en el dock, 3 (Super + Espacio, unas letras, Intro); pegar algo copiado hace 10 minutos, 3 (Super + V,
      elegir, Intro, que ya pega); una ventana a la otra pantalla y vuelta, 2 (Super + Ctrl + Mayús + flecha); entrar y
      salir del modo sin distracciones, 2 (Super + Z). Lo que salga usándolo a diario va a tus pruebas.
- [x] **Ajustes es para ajustes**: Tareas ya es app, las alarmas van en su ventana y las instaladas en el Centro de
      aplicaciones (0.9.21); Conexiones remotas, Máquinas virtuales y Cola de impresión son apps (0.9.24); Puntos de
      restauración es app y las unidades extraíbles se ven en el icono de la barra (0.9.30).
- [x] **Dictado por voz** (medido en 0.9.56 con 10 frases de 4 voces y ruido de fondo): Parakeet (el de serie)
      9 % de palabras mal y 0,13 s por frase; Whisper small 12 % y 1 s; Vosk 17 % y 0,3 s. Los motores no ponían
      «¿» ni «¡» de apertura: ahora sí, solo en frases en español. Probarlo con tu voz va en tus pruebas.
- [x] **Chat en vivo con el asistente** (v0.9.41): Super + Alt + H activa la conversación (escucha, Helpert responde,
      vuelve a escuchar) y la desactiva. Falta: interrumpir a Helpert hablando encima (necesita cancelar el eco del
      altavoz) y probarlo con voz real.
- [x] **Comandos por voz** (v0.9.26): energía (se confirma en el menú), micrófono, hora y fecha, tareas y recordatorios,
      cortesías («¿puedes…?»). Falta probarlo hablando de verdad y, si hace falta, cerrar apps por su nombre.
- [ ] **Micrófono de tres modos** (v0.8.42): probar en uso real dictar y hablar con el asistente con Super + Alt + M
      (mantener); solo se probó por IPC el cambio de modo y el silencio.

## De la revisión completa (2026-11-11, v0.9.22)

Lo que la revisión encontró y no se arregló en la 0.9.22, por orden de valor:

- [ ] **Sistema en otras distros**: Kernel LTS, snap-pac y OpenTabletDriver siguen siendo solo de Arch (ahora se
      ocultan fuera de Arch); falta su equivalente. Las órdenes nuevas de `hf-updates` para dnf, apt, zypper y xbps
      están sin probar en esas distros.

Añadidos sugeridos (sin empezar):

- [ ] **Un solo motor de paquetes** (`hf-pkg`) para actualizaciones, VPN, máquinas virtuales y apps, en vez de
      cuatro detecciones de distro distintas.

## Ideas propuestas (sin empezar)

- [x] **Dos pantallas** (0.9.73, Ajustes › Pantallas › Con varias pantallas): apps que abren en la secundaria
      (`secondaryApps`), el PiP en la otra pantalla (`pipScreen`) y el modo sin distracciones oscurece las demás
      (`focusDimOthers`). Antes (0.9.28–0.9.29): barra por pantalla, Super + Ctrl + Tab salta de pantalla, elegir la
      pantalla de los avisos y reloj en la barra sencilla. Probado con dos salidas en sesión anidada; falta verlo con
      tu VGA de verdad (va en «Equipo del autor»).
- [x] **Transiciones** (0.9.73): minimizar al dock (la miniatura vuela hasta su icono, `animMinimize`), inercia en el
      gesto de 3 dedos (`gestureInertia`: lo que ofrece Hyprland, un deslizamiento rápido termina el cambio aunque sea
      corto; no hay inercia real con desaceleración), los avisos se deslizan a su sitio (ya se apilaban por app desde
      antes) y el preset «Cinemático». Falta: probar el gesto en un touchpad de verdad.

## Equipo del autor

- [ ] Ver en hardware real los iconos que solo se vieron en vista previa: wifi por señal, batería cargando, volumen
      silenciado y micrófono silenciado (v0.8.44).
- [ ] Conectar y quitar una pantalla de verdad para comprobar que los espacios se renumeran sin mover ventanas
      (v0.8.40; solo se probó en sesión anidada).
- [ ] VGA por la GT 710 (`nouveau`): ya da imagen, pero la copia entre GPUs puede hacer las animaciones menos
      fluidas en esa pantalla. Los `eglCreateSyncKHR … EGL_BAD_ATTRIBUTE` del registro de Hyprland (~4 por segundo
      con la VGA encendida, unos 6 MB en 3 h, en RAM) vienen de ahí: aquamarine copia cada cuadro a la GT 710 y pide
      una sincronización que nouveau no tiene, así que espera de la otra forma. No se arregla desde la configuración;
      es de aquamarine (comprobar la extensión antes de pedirla). Mirarlo si actualizan aquamarine.
- [ ] Login sin congelarse (0.9.70–0.9.71: el login, el fondo en vídeo, el shell y RustDesk ya no usan la GT 710 para
      vídeo ni para dibujar; RustDesk del todo en 0.9.74). Comprobado en 0.9.75 sin reiniciar: el Hyprland del login
      pasa `DRI_PRIME` a la otra gráfica y `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=none` al Quickshell que lanza, y lo
      instalado en `/etc/greetd` es igual al repo. Los TRAP de esta mañana (07:27 login, 07:28 shell) son de antes.
      Falta: reiniciar y ver `journalctl -k -b | grep 'nouveau.*TRAP'` vacío.
- [ ] `gst-plugin-scan` (el buscador de complementos de GStreamer, lo lanza cualquier app que reproduce algo) cuelga
      un canal de la GT 710 al regenerar su caché (tras actualizar GStreamer). Medido en 0.9.75: es el complemento
      `va` (11 TRAP; vulkan, opengl y nvcodec, ninguno). `LIBVA_DRIVER_NAME=radeonsi` lo baja a 3 (Mesa vuelve a
      elegir nouveau por el dispositivo) y quitar el acceso a `renderD128` rompería la VGA (Hyprland lo usa). Sin
      arreglo seguro; sin efecto visible.
- [x] Lo que avisaba `hf-doctor` (2026-11-11): recomendados instalados el 2026-11-12 (fuente mono, pavucontrol,
      nm-connection-editor, impresión con cups.socket activo, pymupdf). QtMultimedia ya estaba (el aviso de
      `hf-greeter-sync` era falso: 0.9.46). Login al día (0.9.42) y `primaryMonitor` = HDMI-A-2.
- [x] `xdg-document-portal.service` fallido (código 21): lo tumbaban las pruebas anidadas al desmontar `/run/user/…/doc`;
      arreglado en `dev/try.sh` (0.9.53).
