# Pendientes

Lista de trabajo de HyprFrijol. Al terminar algo, se quita de aquí y va al CHANGELOG. Lo ya hecho de los planes
está en el CHANGELOG y en `docs/planes/`.

## Pendiente

- [ ] **Idiomas**: textos de la interfaz traducibles; inglés primero (Omarchy tiene 50 y los cambia en vivo).
- [ ] **Sistema en otras distros**: Kernel LTS, snap-pac y OpenTabletDriver siguen siendo solo de Arch (fuera de
      Arch se ocultan); falta su equivalente. Las órdenes de `hf-updates` para dnf, apt, zypper y xbps están sin
      probar en esas distros.
- [ ] **Rendimiento comparado con otros shells**: memoria y CPU en reposo y con paneles abiertos frente a Caelestia
      y Noctalia, con `dev/perf.sh`. Lo medido de HyprFrijol (0.9.75): ~360 MB recién arrancado con dos pantallas,
      estable en reposo, ~0,5 % de un núcleo.

## Descartado (2026-11-13)

Se deja de seguir; si vuelve a hacer falta, entra arriba como tarea nueva.

- Un solo motor de paquetes (`hf-pkg`).
- Plugins propios con permisos y registro.
- Más compositores (niri, Sway).
- Desbloqueo facial (Howdy).
- Que la IA asigne los papeles de los colores de un tema.
- Pruebas con uso real que quedaban abiertas: RustDesk entrante, `hf-perfil` en una máquina virtual, IA local y
  dictado con la voz del autor, interrumpir a Helpert hablando, micrófono de tres modos, gesto de 3 dedos en un
  touchpad, iconos en hardware real, renumerar espacios al quitar una pantalla, animaciones en la VGA y login tras
  reiniciar.
- Avisos que no tienen arreglo desde HyprFrijol: `eglCreateSyncKHR … EGL_BAD_ATTRIBUTE` (aquamarine copiando a la
  GT 710 con nouveau) y los TRAP de nouveau al regenerar la caché de `gst-plugin-scan` (complemento `va`).
