# Pendientes

Lista de trabajo de HyprFrijol. Sale de la comparación con Caelestia, DankMaterialShell (Dux), Noctalia,
illogical-impulse (end-4) y Omarchy 4.5 (noviembre de 2026). Al terminar algo, se quita de aquí y va al CHANGELOG.

## Baratos de añadir (primero)

- [ ] **Modo juego**: un atajo que quita animaciones, desenfoque, sombras, redondeo y huecos (y los devuelve).
- [ ] **Ajustes de la barra por pantalla**: mostrar u ocultar la barra y sus módulos en cada monitor.
- [ ] **Paquete en el AUR** (`hyprfrijol-git`), para poder probarlo sin clonar.

## Donde vamos por detrás

- [ ] **Idiomas**: textos de la interfaz traducibles; inglés primero (Omarchy tiene 50 y los cambia en vivo).
- [ ] **Rendimiento medido**: memoria y CPU del shell en reposo y con paneles abiertos, comparado con Caelestia y
      Noctalia; quitar sondeos (p. ej. la pastilla de ventana pregunta a Hyprland cada 100 ms) y reaccionar a
      eventos. Hecho (v0.8.48): `dev/perf.sh` y reposo de 4,7 % a ~1 % de un núcleo. Falta: los 450 MB de RSS y
      la comparación con los otros shells.
- [ ] **Pulido de animaciones**: paneles que salen de la barra y se transforman entre sí (como Caelestia). Hecho
      (v0.8.49): los paneles abiertos con el ratón desde la barra nacen del punto pulsado. Falta: que un panel se
      transforme en otro al saltar de uno a otro, y probar la apertura desde la barra en uso real.
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
      fluidas en esa pantalla.
