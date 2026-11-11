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
      eventos.
- [ ] **Pulido de animaciones**: paneles que salen de la barra y se transforman entre sí (como Caelestia).
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

## Equipo del autor

- [ ] Tras reiniciar, comprobar que la GT 710 usa `nouveau` y que la pantalla VGA da imagen (antes fallaba la copia
      entre GPUs con `nvidia-470xx`, ya desinstalado).
