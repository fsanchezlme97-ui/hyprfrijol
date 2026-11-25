# AGENTS.md — HyprFrijol

Rice/shell para **Hyprland ≥ 0.57** (config en Lua) + **Quickshell ≥ 0.3**, escrito en español.

Esta guía es para agentes de código (Claude Code, Codex, OpenCode, etc.) que modifiquen HyprFrijol.

## Identidad del proyecto

- HyprFrijol no es una distro: es un rice que corre como sesión aparte sin tocar la configuración normal de Hyprland del usuario.
- Cada función tiene un script o comando que funciona solo (`hf-*`); Quickshell es solo la cara visual.
- La fuente de verdad de los ajustes es `~/.config/hyprfrijol/settings.json` mezclado con `config/defaults/settings.json`.

## Convenciones importantes

- **No tocar** `~/.config/hypr`, `~/.config/quickshell` ni `~/.config/matugen`. HyprFrijol corre desde la carpeta del repo como sesión aparte.
- Config generada: `~/.local/state/hyprfrijol/`. Ajustes del usuario: `~/.config/hyprfrijol/local.lua` y `settings.json`.
- Los archivos en `external-skills/`, `node_modules/`, `.opencode/` y `.superpowers/` **no son parte del proyecto**; no los modifiques salvo que el usuario lo pida.
- `__pycache__/` en el árbol del proyecto puede borrarse; está en `.gitignore`.

## Estructura clave

```
config/
  hypr/frijol/        Config Lua de Hyprland (binds, ventanas, monitores...)
  hypr/hyprland.lua   Punto de entrada de Hyprland
  quickshell/         Shell QML: bar/, components/, services/, modules/<vista>/
  quickshell/Theme.qml Tokens de color, tipografía y movimiento
  quickshell/Settings.qml API de lectura/escritura de settings.json
  themes/             Paletas de colores (palettes.json, temas propios en ~/.config/hyprfrijol)
  apply/              Python: hf-apply convierte settings.json → settings.lua
  defaults/           Valores por defecto de settings.json
scripts/              ~45 scripts hf-* (Bash/Python)
install/              Paquetes por distro, bootstrap.sh
install/apps.json     Catálogo de apps por nivel y fuente
install/packages.tsv  Dependencias por distro
dev/                  Herramientas de desarrollo y validación
docs/                 Documentación de usuario
```

## Cómo explorar antes de cambiar

1. Lee `docs/ARQUITECTURA.md` para entender los módulos y el flujo de datos.
2. Busca con `grep` o `glob` dónde se usa una clave, función o componente.
3. Para QML: `Theme.*` para colores, `Settings.get/set/setMany` para preferencias, `Shell.open(...)` para vistas.
4. Para Hyprland: la config se genera en `~/.local/state/hyprfrijol/settings.lua` vía `config/apply/*.py`.
5. Para scripts: casi todo tiene un `hf-*`; usa `--help` para ver uso.

## Flujo de trabajo

1. **Antes de editar**: identifica todos los callers, tests, fixtures y docs que toca el cambio.
2. **Cambia lo mínimo**: sigue el estilo del código que te rodea. No añadas abstracciones ni opciones que nadie pidió.
3. **Valida**:
   ```bash
   ./dev/lint.sh          # bash/python/lua/json/shellcheck/índice de Ajustes
   ./dev/check.sh         # Abre sesión anidada con 24 vistas y 40 secciones (~2 min)
   ./dev/try.sh <vista>   # Probar una vista concreta en sesión anidada
   ```
4. **Si cambias textos** en `config/quickshell/modules/settings/sections/*.qml`, regenera el índice de búsqueda:
   ```bash
   ./dev/gen-settings-index.py
   ```
5. **Prueba el shell**:
   ```bash
   hf-session --nested    # Ventana dentro de tu sesión actual; cierra con Super+Shift+Esc
   ```
6. **Commitea y pushea** a `main` con prefijo claro: `docs:`, `polish:`, `fix:`, `feat:`.

## Patrones por tecnología

### QML

- Colores y tipografía: `Theme.*` (no valores literales).
- Preferencias: `Settings.get("clave", default)` / `Settings.set("clave", valor)` / `Settings.setMany({...})`.
- Preferencias destructivas (pantallas, tema, etc.): `Confirm.change("Etiqueta", { clave: valor }, { undo: [...] })`.
- Abrir vistas: `Shell.open("vista", "argumento")`.
- Textos en español.

### Python (`config/apply/` y scripts)

- Usa el estilo existente (PEP 8 básico, comillas dobles, comentarios en español).
- Los scripts `hf-*` deben soportar `--help` / `-h`.
- Para settings: lee `config/defaults/settings.json` como fallback.

### Lua (`config/hypr/frijol/`)

- Configura Hyprland vía `hl.*` (helpers propios; ver otros archivos).
- `frijol/` se carga desde `hyprland.lua`.

### Bash (scripts `hf-*`)

- `set -euo pipefail` o `set -u` según el script.
- Migración desde `hypr-liquid`: las variables `HL_*` siguen valiendo como `HF_*`.
- Para Quickshell IPC: `qs -p "$HF_ROOT/config/quickshell" ipc call ...`

## Ajustes nuevos

- Añade el valor por defecto en `config/defaults/settings.json`.
- Si afecta a Hyprland, crea/actualiza un script en `config/apply/` (número de orden: 10, 20, 30...).
- Documenta la clave en `docs/AJUSTES.md` (tabla de la sección o índice del resto de claves).
- Regenera `config/quickshell/modules/settings/search-index.json` si cambias etiquetas en QML.

## Atajos y acciones

- Los atajos se definen en `config/hypr/frijol/binds.lua` y acciones en `config/apply/keybind-actions.json`.
- La chuleta visual lee `docs/BINDS.md`.

## Plugins de Omarchy

- Se cargan vía `scripts/hf-plugin` y `config/quickshell/modules/omarchy/`.
- Son código sin aislar; no los refactorices sin permiso del usuario.

## Deuda conocida (`shortcut:`)

Si encuentras comentarios `shortcut:` en el código, son limitaciones conocidas. No los arregles sin hardware o contexto para probar; mejor documenta la deuda si cambias el archivo cercano.

## Dependencias importantes

- Hyprland 0.57+ con soporte Lua (`hyprland-lua` o equivalente).
- Quickshell 0.3+.
- Python 3, bash, ImageMagick, fc-list, etc. Lista completa en `install/packages.tsv`.

## Licencia

MIT. Ver `LICENSE`.
