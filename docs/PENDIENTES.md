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
4. [ ] [Temas](planes/temas.md), fase 3 (pulido de Math). Hecho (0.9.16): estados uniformes con foco de teclado,
       sombra en dos capas y filo de luz arriba; la fuente se queda en Inter. Falta: la escala de espaciado
       (4/8/12/16/24) y los radios concéntricos, que tocan casi todas las vistas. `Ui/` es la capa de compatibilidad
       con Omarchy y sigue su propio estilo.
5. [ ] [Productividad](planes/productividad.md), fase 5: revisión con uso real (la hace el autor usando el
       escritorio; lo que se mide está en la sección 4 del plan). Los relojes del mundo siguen en Fecha, con un
       enlace desde Agenda y alarmas.
6. [x] [Asistente de IA](planes/asistente-ia.md), fase 7: servidores MCP del usuario, con aprobación por servidor
       y confirmación de todo lo que cambia (0.9.17). Por comando (stdio) o por dirección (HTTP). Endurecido en la
       0.9.18: también se confirma lo de solo lectura salvo con «Consultar sin preguntar», https y sin redirecciones.

Cerrado: [Animaciones y efectos](planes/animaciones.md). Las fases 1–5 están hechas y la 6 (ajustes por zona,
reducción automática) se descartó en las decisiones del plan.

## Baratos de añadir (primero)

- [ ] **Paquete en el AUR** (`hyprfrijol-git`): el PKGBUILD está en `packaging/aur/hyprfrijol-git/` (0.9.28, se
      genera con `dev/gen-pkgbuild.py` y se construye bien con `makepkg`). Falta subirlo con la cuenta del autor
      (instrucciones en la cabecera de `dev/gen-pkgbuild.py`) y añadir «Arch: `paru -S hyprfrijol-git`» al README.

- [x] **Fondos de Wallhaven y Unsplash**: Wallhaven ya estaba (Ajustes › Fondos); Unsplash en 0.9.36 (`hf-unsplash`,
      necesita su clave gratuita). Falta: probarlo con una clave de verdad y darle a la IA `unsplash_search` como a Wallhaven.
- [~] **Entrar desde otro equipo o el móvil**: AnyDesk no acepta entrantes en Wayland (solo Xorg; lo dice su
      documentación y se comprobó: corta con «servidor de pantalla no admitido» sin tocar el portal). Alternativas: RDP
      (hypr-rdp, 0.9.34) y RustDesk (0.9.40) con el portal RemoteDesktop de xdph + PR #448
      (`install/pkgbuilds/xdg-desktop-portal-hyprland-rd`, solo Arch). Falta: probar una conexión real de RustDesk;
      volver al paquete oficial cuando xdph publique RemoteDesktop; Fedora/openSUSE/Debian.

## Donde vamos por detrás

- [ ] **Idiomas**: textos de la interfaz traducibles; inglés primero (Omarchy tiene 50 y los cambia en vivo).
- [ ] **Rendimiento medido**: memoria y CPU del shell en reposo y con paneles abiertos, comparado con Caelestia y
      Noctalia; quitar sondeos (p. ej. la pastilla de ventana pregunta a Hyprland cada 100 ms) y reaccionar a
      eventos. Hecho (v0.8.48): `dev/perf.sh` y reposo de 4,7 % a ~1 % de un núcleo. Falta: los 450 MB de RSS y
      la comparación con los otros shells.
- [ ] **Pulido de animaciones**: paneles que se transforman entre sí (como Caelestia). Desde la v0.9.12 todos se
      abren igual, con una sola animación. Prueba (0.9.33, `components/Morph.qml`): los paneles de los chips de la
      barra y el centro de control se transforman uno en otro al saltar con un clic en la barra. Falta: verlo en uso
      real (y en la GT 710) y decidir si se extiende a Spotlight, energía y los demás.
- [ ] **Plugins propios**: formato, permisos y un registro con versiones fijadas (como DMS); hoy solo los de Omarchy.
- [ ] **Más compositores** (niri, Sway): evaluar qué partes dependen de Hyprland. Grande; después de lo demás.
- [ ] Detalles de otros shells: desbloqueo facial (Howdy). (Cerrar procesos desde el monitor del sistema: 0.9.29;
      perfil de energía según cargador o batería: 0.9.30, sin probar en un portátil; letras de canciones: 0.9.31.)

## Mejorar lo que ya hay

- [ ] **Rendimiento**: arranque del shell y carga diferida de más módulos. Hecho (0.9.23): en reposo ya no se lanza
      ningún proceso (antes `hyprctl` cada 600 ms con flotantes o PiP, `hf-caffeine` cada 30 s, `nmcli` también por
      cable, `nvidia-smi` cada 2 s); los lectores se paran con la barra escondida o la sesión bloqueada. Queda: el hilo
      principal sigue en ~1,5 % de un núcleo en reposo, casi todo la lectura de SysStats cada 2 s para la pastilla.
      0.9.28: con dos pantallas, el consumo por programa de la barra sencilla lee los procesos cada 4 s y no cada 2.
- [ ] **Productividad**: revisar Spotlight, portapapeles, ventanas y atajos con uso real; quitar pasos. Hecho
      (0.9.25): deshacer al borrar tareas o vaciar el historial de avisos, «Copiado» al copiar un aviso, las teclas de
      Alt + Tab a la vista, botones pequeños más fáciles de acertar. Queda lo que pide uso real.
- [x] **Ajustes es para ajustes**: Tareas ya es app, las alarmas van en su ventana y las instaladas en el Centro de
      aplicaciones (0.9.21); Conexiones remotas, Máquinas virtuales y Cola de impresión son apps (0.9.24); Puntos de
      restauración es app y las unidades extraíbles se ven en el icono de la barra (0.9.30).
- [ ] **Dictado por voz**: precisión, latencia, puntuación, idioma y que funcione en todas las apps. Nombres propios
      e internet: vocabulario con todos los motores y corrección con la IA (0.9.20); falta probarlo con voz real.
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

- [ ] **Dos pantallas**: abrir ciertas apps en la secundaria, modo concentración que atenúa la secundaria, imagen en
      imagen a la secundaria. Hecho (0.9.28–0.9.29): barra por pantalla, Super + Ctrl + Tab salta de pantalla (Super +
      Tab ya es la vista general), elegir la pantalla de los avisos y reloj en la barra sencilla.
- [ ] **Transiciones**: minimizar al dock, inercia al cambiar de espacio con gestos, avisos apilados, un preset de
      animaciones «Cinemático» (los paneles que salen de su botón ya están en «Pulido de animaciones»).

## Equipo del autor

- [ ] Elegir otra vez la pantalla principal (HDMI-A-2) en Ajustes › Pantallas: la guardada sigue siendo «HDMI-A-1»,
      de antes de añadir la gráfica (ahora se usa la más grande y funciona, pero el ajuste está desfasado).
- [ ] Ver en hardware real los iconos que solo se vieron en vista previa: wifi por señal, batería cargando, volumen
      silenciado y micrófono silenciado (v0.8.44).
- [ ] Conectar y quitar una pantalla de verdad para comprobar que los espacios se renumeran sin mover ventanas
      (v0.8.40; solo se probó en sesión anidada).
- [ ] VGA por la GT 710 (`nouveau`): ya da imagen, pero la copia entre GPUs puede hacer las animaciones menos
      fluidas en esa pantalla. El registro de Hyprland repite `eglCreateSyncKHR … EGL_BAD_ATTRIBUTE` (300 veces
      en este arranque); ver si viene de esa gráfica.
- [ ] Lo que avisa `hf-doctor` (2026-11-11): el login de greetd es de otra versión (`hf-greeter-sync`, pide la
      contraseña de administrador) y faltan 4 paquetes recomendados (fuente mono, pavucontrol, nm-connection-editor,
      impresión: `hf-deps install --recommended`). Los enlaces `hf-clip` y `hf-theme` ya están.
- [ ] `xdg-document-portal.service` salió a las 17:28 con el código 21 y quedó como fallido. Se vuelve a lanzar
      solo cuando una app lo pide (D-Bus), así que no bloquea nada; si se repite, mirar si coincide con una prueba
      anidada (`dev/try.sh`), que arranca sus propios portales.
