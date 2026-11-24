# Pulidos y documentación — plan inmediato

Mientras los proyectos estratégicos (i18n, ISO, marketplace de plugins, apps propias) siguen en `PENDIENTES.md`, este documento recoge los **pulidos y mejoras de documentación** que se pueden hacer ya con el código actual. La idea es reducir fricción para usuarios y colaboradores sin añadir dependencias ni funciones grandes.

## Principios

1. **No añadir funciones nuevas** salvo que sean un atajo evidente para algo ya existente.
2. **Cada pieza debe tener una página o una sección** que explique: qué hace, cómo se usa desde la UI, cómo se usa desde terminal y qué archivo toca.
3. **Revisar todos los `shortcut:`** del código: o los resolvemos, o los documentamos como deuda conocida.
4. **Inglés y español**: la documentación nueva va en español con al menos un resumen en inglés si es referencia técnica.
5. **Validar siempre**: tras cambios de docs o de comentarios se pasa `./dev/lint.sh && ./dev/check.sh`.

---

## 1. Documentar los `shortcut:` actuales

Lugares encontrados:

| Archivo | Línea | Qué dice el `shortcut:` |
|---|---|---|
| `config/hypr/frijol/env.lua:30` | Apagar hardware aunque nouveau no sea la primera gráfica. | Revisar si aún pasa con Hyprland 0.57+; documentar o afinar. |
| `config/quickshell/modules/sidepanel/AiChat.qml:452` | Detener mata bash; un proceso hijo en segundo plano seguiría. | Evaluar `setsid` + matar grupo si realmente ocurre. |
| `config/quickshell/services/WinMode.qml:469` | Diálogo grande de GTK 3 se maximiza. | Documentar el límite; valorar si hyprctl ya expone `xdg_toplevel parent`. |
| `install.sh:946` | Intel Arc no expone VRAM y cuenta como «cpu». | Documentar en `docs/HARDWARE.md` o `TROUBLESHOOTING.md`; no cambiar heurística sin probar. |

Acción: para cada uno, decidir si se arregla, se deja con documentación clara o se mueve a `PENDIENTES.md` con contexto.

---

## 2. Índice de scripts (`docs/SCRIPTS.md`)

Hay ~45 scripts `hf-*`. Hoy solo `install.sh` y algunos tienen `--help`. Un índice central ayuda a:

- Saber qué comando usar sin abrir el código.
- Que la IA y los agentes entiendan la superficie de comandos.
- Detectar duplicados o scripts huérfanos.

Estructura propuesta:

```markdown
# Scripts de HyprFrijol

## Sesión y shell
- `hf-session` — iniciar/cerrar sesión, modo anidado.
- `hf-shell` — arrancar/reiniciar Quickshell.

## Apariencia y temas
- `hf-apply`, `hf-theme`, `hf-wallpaper`, `hf-wallhaven`, `hf-unsplash`...

## IA y voz
- `hf-ai`, `hf-mcp`, `hf-dictate`, `hf-voice`...

## Productividad
- `hf-capture`, `hf-clip`, `hf-download`, `hf-fileact`...

## Sistema
- `hf-update`, `hf-deps`, `hf-doctor`, `hf-safe`, `hf-remove-gtk`...
```

Cada entrada debe tener: propósito de una línea, ejemplo mínimo y dónde está el código.

---

## 3. Referencia de atajos (`docs/BINDS.md`)

La config de atajos vive en `config/hypr/frijol/binds.lua`, pero no hay una cheatsheet legible. Proponemos:

- Extraer automáticamente los binds de `binds.lua` a una tabla markdown.
- Agrupar por categoría: ventanas, espacios, shell, IA, capturas, multimedia.
- Incluir tanto los atajos de Hyprland como los gestos y los del panel lateral.

Esto también alimenta la vista `cheatsheet` del shell.

---

## 4. Ampliar `README.en.md`

Actualmente es un resumen corto. Debería cubrir:

- Qué es y qué no es (rice, no distro).
- Arquitectura de alto nivel (igual que `ARQUITECTURA.md` pero en inglés).
- Cómo contribuir (`dev/try.sh`, `dev/lint.sh`, `dev/check.sh`).
- Troubleshooting básico (login roto, shell no arranca, cómo volver a tuigreet).
- Enlace a `docs/`.

---

## 5. `docs/TROUBLESHOOTING.md`

Problemas que aparecen una y otra vez y merecen página propia:

- Pantalla negra tras actualización de Hyprland / Quickshell.
- Login roto tras `--greeter`.
- `qs` no encuentra el shell.
- Las ventanas flotantes desaparecen (hoy ya no debería pasar tras quitar `ocultas`).
- El asistente no responde: cómo probar `hf-ai test`.
- NVIDIA: `nvidia_drm.modeset=1`, stuttering, etc.
- Nouveau y los TRAP de `gst-plugin-scan` (avisos sin arreglo).

---

## 6. `docs/TEMAS.md`

Guía para crear un tema propio:

- Dónde van las paletas (`config/themes/`).
- Formato de `colors.toml` y compatibilidad con Omarchy.
- Cómo probarlo con `hf-theme` o `hf-apply`.
- Cómo añadir un par claro/oscuro.

---

## 7. `docs/PLUGINS-OMARCHY.md`

HyprFrijol ya carga plugins de Omarchy (`scripts/hf-plugin`, `config/quickshell/modules/omarchy`). Falta documentar:

- Qué plugins están probados.
- Cómo añadir uno (`hf-plugin add ...`).
- Limitaciones (solo widgets/paneles que no dependan de servicios privados de Omarchy).
- Cómo crear un plugin propio compatible.

---

## 8. `docs/MIGRACION.md`

- Desde `hypr-liquid` (nombre anterior): `install.sh --migrate`.
- Desde Omarchy: diferencias de rutas, ajustes, plugins.
- Desde otros rices de Hyprland: guardar `~/.config/hypr`, usar `hf-session`.

---

## 9. Revisar `--help` de scripts

Muchos scripts no responden a `--help` o no listan ejemplos. Acciones:

- Añadir `case "--help"|-h)` en los bash que no lo tengan.
- En Python, usar `argparse` con `description` y `epilog` con ejemplos.
- El linter bash/python ya pasa; esto es solo documentación de CLI.

---

## 10. Unificar nombres y comentarios

- Revisar si queda alguna referencia a "hypr-liquid" fuera de `hf-migrate`.
- Revisar si los comentarios de QML usan `Theme.*` y `Settings.*` correctamente.
- Revisar que los docstrings de Python estén en español y sean actuales.

---

## Cómo se trabaja cada pulido

1. Se elige una sección de este documento.
2. Se escribe/modifica el archivo correspondiente.
3. Se ejecuta `./dev/lint.sh && ./dev/check.sh`.
4. Se hace commit con prefijo `docs:` o `polish:`.
5. Se tacha aquí y, si es relevante, se actualiza `PENDIENTES.md`.

## Próximos candidatos a pulir (después de la documentación)

- Mejorar la vista `cheatsheet` para que use `docs/BINDS.md` o viceversa.
- Hacer que `hf-doctor` enlace a `docs/TROUBLESHOOTING.md`.
- Añadir `--help` a todos los scripts y regenerar `docs/SCRIPTS.md` automáticamente.
