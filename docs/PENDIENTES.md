# Pendientes

Lista de trabajo de HyprFrijol. Al terminar algo, se quita de aquí y va al CHANGELOG. Lo ya hecho está en el
CHANGELOG.

## Pendiente

- [ ] **Escritorio remoto integrado**: interfaz propia sobre las capacidades de Hyprland.
- [ ] **Correo y calendario integrados**: la agenda `.ics` ya existe; falta el correo y un calendario completo.
- [ ] **Visor de máquinas virtuales (QEMU)**: mejorarlo en lo visual y en lo funcional.

### Renovación de la interfaz, por etapas

Hecho: botón «mantener para borrar» (0.20.0), pastilla «Escuchando…» (0.21.0), widgets de calendario, próxima reunión y
zonas horarias en el panel `Super + G` (0.22.0), fila de música en el centro de control (0.23.0), isla dinámica básica
(0.24.0) y formas de barra «Muesca» y «Marco» (0.26.0, sustituyen a la «Isla integrada» de 0.25.0). Cada etapa sale como versión propia.

Reglas de calidad en todas: un interruptor en Ajustes para lo nuevo y vistoso; solo `Theme.*` y respetar «Reducir
movimiento»; probado en claro y oscuro, con dos pantallas y con teclado; `dev/perf.sh` antes y después; captura en la
sesión anidada (en la sesión anidada hay que sacar la captura dos veces: la primera de `grim` sale con el cuadro
anterior); `lint`, `check` y documentación. Listón de reposo (2026-11-27, 0.23.0, sesión anidada): 323 MB de memoria y
1-3 % de CPU del hilo principal; con la isla activada y sin actividad, 324 MB. No pasar de +30 MB ni de +1 % en reposo.

- [ ] **Isla dinámica, lo que falta**: meter el dictado dentro de la isla (hoy su píldora va aparte, debajo), avisos
      entrantes (se despliega unos segundos al llegar una notificación o al acabar un Pomodoro), varias pantallas
      (hoy solo la principal), probarla en claro y medir su coste con actividad (solo se midió en reposo). «Muesca» y «Marco»: sin probar en
      claro (en la sesión anidada el tema claro no se aplica sin hf-apply) ni con dos pantallas; la isla sigue a la
      pantalla con foco. «Marco» no dibuja franjas finas en los otros bordes, solo las esquinas.
- [ ] **Widgets sobre el escritorio**: los widgets nuevos (y los de siempre) viven en el panel `Super + G`, no sobre el
      escritorio como en las referencias. Falta una capa en el fondo para colocarlos (calendario, próxima reunión,
      zonas horarias) y, si se quiere, el gráfico de contribuciones de GitHub (necesita red y un usuario público).
- [ ] **Centro de notificaciones**: no se ha tocado. Ya agrupa por aplicación e historial; las referencias piden
      acciones rápidas y un aspecto más compacto.
- [ ] **Interruptores en Ajustes** para lo nuevo de 0.20.0 a 0.23.0 (botón de mantener, pastilla de puntos, fila de
      música): hoy sustituyen a lo anterior sin opción de volver.
- [ ] **Medir y probar en claro** lo de 0.20.0 a 0.23.0: solo se probó en oscuro y sin medir rendimiento aparte del reposo.
- [ ] **Pulido final**: paletas y temas, accesibilidad, capturas del README y decidir qué se enciende de fábrica.

## Descartado (2026-11-13)

Se deja de seguir; si vuelve a hacer falta, entra arriba como tarea nueva.

- Un solo motor de paquetes (`hf-pkg`).
- Plugins propios con permisos y registro.
- Más compositores (niri, Sway).
- Desbloqueo facial (Howdy).
- Que la IA asigne los papeles de los colores de un tema.
- Pruebas con uso real que quedaban abiertas: RustDesk entrante, `hf-perfil` en una máquina virtual, IA local y
  dictado con la voz del autor, interrumpir a Harper hablando, micrófono de tres modos, gesto de 3 dedos en un
  touchpad, iconos en hardware real, renumerar espacios al quitar una pantalla, animaciones en la VGA y login tras
  reiniciar.
- Avisos que no tienen arreglo desde HyprFrijol: `eglCreateSyncKHR … EGL_BAD_ATTRIBUTE` (aquamarine copiando a la
  GT 710 con nouveau) y los TRAP de nouveau al regenerar la caché de `gst-plugin-scan` (complemento `va`).

## Descartado (2026-11-26)

Se quita de la lista para dejar solo lo de arriba; si vuelve a hacer falta, entra como tarea nueva.

- Idiomas (inglés primero), ISO live o instalador gráfico, ecosistema de plugins propio, apps nativas propias
  (firmar PDF, reloj mundial, presentaciones), accesibilidad (Orca), sincronización entre máquinas, equivalentes
  de Kernel LTS, snap-pac y OpenTabletDriver fuera de Arch, y la comparación de rendimiento con Caelestia y Noctalia.
