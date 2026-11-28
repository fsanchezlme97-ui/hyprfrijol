# Pendientes

Lista de trabajo de HyprFrijol. Al terminar algo, se quita de aquí y va al CHANGELOG. Lo ya hecho está en el
CHANGELOG.

## Pendiente

- [ ] **Escritorio remoto integrado**: interfaz propia sobre las capacidades de Hyprland.
- [ ] **Correo y calendario integrados**: la agenda `.ics` ya existe; falta el correo y un calendario completo.
- [ ] **Visor de máquinas virtuales (QEMU)**: mejorarlo en lo visual y en lo funcional.

### Renovación de la interfaz, por etapas

Referencia: botón «mantener para borrar» (hecho en 0.20.0), pastilla «Escuchando…» (hecha en 0.21.0), isla dinámica, widgets de agenda y
centro de control. Orden: primero lo independiente y de poco riesgo, al final lo grande que depende de la medida.
Cada etapa sale como versión propia y no empieza la siguiente hasta que la anterior esté aplicada.

Reglas de calidad en todas: un interruptor en Ajustes (lo nuevo y vistoso, apagado de fábrica hasta aprobarlo); solo
`Theme.*` (colores, duraciones, radios) y respetar «Reducir movimiento»; probado en claro y oscuro, con dos pantallas y
con teclado; `dev/perf.sh` antes y después; captura antes/después en la sesión anidada; `lint`, `check` y documentación
(`AJUSTES.md`, `BINDS.md` si hay atajos). Listón de reposo medido el 2026-11-27 (0.19.3, sesión anidada): 322 MB de
memoria, 2,85 % de CPU del hilo principal y 0,75 % de render. No pasar de +30 MB ni de +1 % en reposo.

- [ ] **Etapa 1 · Widgets de escritorio con agenda**: calendario del mes, «Próxima reunión» con cuenta atrás y zonas
      horarias, sobre la agenda `.ics` y el cuadro de widgets existente. Va junto a «Correo y calendario integrados».
- [ ] **Etapa 2 · Centro de control y avisos**: fichas con estado en segunda línea, deslizadores anchos de brillo y
      volumen, fila de música; avisos agrupados por aplicación. Se rehace el aspecto, no el contenido.
- [ ] **Etapa 3 · Isla dinámica**, en tres tramos: (a) estructura: pastilla arriba al centro con animación de forma
      (como `Morph`), se expande al pasar el puntero, región de entrada mínima y una sola pantalla; (b) contenido por
      prioridad: dictado, enfoque/Pomodoro, música, descargas y procesos, y avisos entrantes; (c) medir contra el
      listón y decidir si queda «siempre visible» o «solo con actividad». Sin muesca física: es una pastilla flotante.
- [ ] **Etapa 4 · Modo de barra «Isla integrada»** (`barMode`, junto a `archipielago`): la barra se reduce a pastillas
      pequeñas a los lados (espacios y título a la izquierda; estado, reloj y ajustes a la derecha) y el centro queda
      para la isla de la Etapa 3, que pasa a ser parte de la barra: reserva su sitio, se agranda sin tapar a las
      pastillas y se encoge a un punto cuando no hay actividad. Debe funcionar con la barra arriba (lo normal) y, si
      se puede, abajo; con barra a los lados el modo no aplica y se avisa en Ajustes. Reutiliza `BarWidgets` y `barOrder`.
- [ ] **Etapa 5 · Pulido final**: paletas y temas, claro/oscuro, accesibilidad, capturas del README, comparación final
      de rendimiento con el listón y decidir qué se enciende de fábrica.

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
