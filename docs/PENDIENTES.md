# Pendientes

Lista de trabajo de HyprFrijol. Sale de la comparación con Caelestia, DankMaterialShell (Dux), Noctalia,
illogical-impulse (end-4) y Omarchy 4.5 (noviembre de 2026). Al terminar algo, se quita de aquí y va al CHANGELOG.

## Planes en curso (en este orden)

Cada plan tiene sus fases y sus decisiones tomadas en `docs/planes/`. Al cerrar una fase se marca aquí.

Estado a 2026-11-11 (v0.9.12), comprobado contra el código y el shell en marcha en el equipo del autor. Lo hecho
entre la 0.9.0 y la 0.9.12 está en el CHANGELOG. Queda, en este orden:

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
       y confirmación de todo lo que cambia (0.9.17). Por comando (stdio) o por dirección (HTTP).

Cerrado: [Animaciones y efectos](planes/animaciones.md). Las fases 1–5 están hechas y la 6 (ajustes por zona,
reducción automática) se descartó en las decisiones del plan.

## Baratos de añadir (primero)

- [ ] **Ajustes de la barra por pantalla**: mostrar u ocultar la barra y sus módulos en cada monitor.
- [ ] **Paquete en el AUR** (`hyprfrijol-git`), para poder probarlo sin clonar.

## Donde vamos por detrás

- [ ] **Idiomas**: textos de la interfaz traducibles; inglés primero (Omarchy tiene 50 y los cambia en vivo).
- [ ] **Rendimiento medido**: memoria y CPU del shell en reposo y con paneles abiertos, comparado con Caelestia y
      Noctalia; quitar sondeos (p. ej. la pastilla de ventana pregunta a Hyprland cada 100 ms) y reaccionar a
      eventos. Hecho (v0.8.48): `dev/perf.sh` y reposo de 4,7 % a ~1 % de un núcleo. Falta: los 450 MB de RSS y
      la comparación con los otros shells.
- [ ] **Pulido de animaciones**: paneles que se transforman entre sí (como Caelestia). Desde la v0.9.12 todos se
      abren igual, con una sola animación (se quitó el nacer del punto pulsado de la v0.8.49). Falta: que un panel
      se transforme en otro al saltar de uno a otro.
- [ ] **Plugins propios**: formato, permisos y un registro con versiones fijadas (como DMS); hoy solo los de Omarchy.
- [ ] **Más compositores** (niri, Sway): evaluar qué partes dependen de Hyprland. Grande; después de lo demás.
- [ ] Detalles de otros shells: desbloqueo facial (Howdy), letras de canciones, perfiles de energía según
      cargador o batería, lista de procesos con gestión.

## Mejorar lo que ya hay

- [ ] **Rendimiento**: arranque del shell, carga diferida de más módulos, menos procesos de `hyprctl` y `nmcli`.
- [ ] **Productividad**: revisar Spotlight, portapapeles, ventanas y atajos con uso real; quitar pasos.
- [ ] **Dictado por voz**: precisión, latencia, puntuación, idioma y que funcione en todas las apps.
- [ ] **Chat en vivo con el asistente** (hablar y que responda en voz): conversación fluida, interrumpirlo,
      latencia baja.
- [ ] **Comandos por voz**: más órdenes, entender frases naturales, confirmar antes de lo peligroso.
- [ ] **Micrófono de tres modos** (v0.8.42): probar en uso real dictar y hablar con el asistente con Super + Alt + M
      (mantener); solo se probó por IPC el cambio de modo y el silencio.
- [ ] **Consumo por programa** (barra secundaria): la memoria suma el RSS de cada proceso (lo compartido cuenta
      varias veces); un programa pequeño que gasta mucha CPU puede quedar escondido tras «+N».

## Ideas propuestas (sin empezar)

- [ ] **Dos pantallas**: abrir ciertas apps en la secundaria, Super + Tab para saltar de pantalla, modo concentración
      que atenúa la secundaria, elegir en qué pantalla salen los avisos, imagen en imagen a la secundaria, reloj en la
      barra secundaria.
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
- [ ] Lo que avisa `hf-doctor` (2026-11-11): faltan los enlaces `hf-clip` y `hf-theme` en `~/.local/bin`
      (`./install.sh --no-deps`), el login de greetd es de otra versión (`hf-greeter-sync`) y faltan 4 paquetes
      recomendados (fuente mono, pavucontrol, nm-connection-editor, impresión).
- [ ] `xdg-document-portal.service` está en fallo en la sesión: ver por qué y si afecta a abrir archivos desde
      apps Flatpak.
