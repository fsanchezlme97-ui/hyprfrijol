# AGENTS.md — HyprFrijol

Rice/shell para **Hyprland ≥ 0.57** (config en Lua) + **Quickshell ≥ 0.3**, escrito en español.

## Convenciones importantes

- **No tocar** `~/.config/hypr`, `~/.config/quickshell` ni `~/.config/matugen`. HyprFrijol corre desde la carpeta del repo como sesión aparte.
- Config generada: `~/.local/state/hyprfrijol/`. Ajustes del usuario: `~/.config/hyprfrijol/local.lua` y `settings.json`.
- Los archivos en `external-skills/`, `node_modules/`, `.opencode/` y `.superpowers/` **no son parte del proyecto**; no los modifiques salvo que el usuario lo pida.
- `__pycache__/` en el árbol del proyecto puede borrarse; está en `.gitignore`.

## Estructura clave

```
config/
  hypr/frijol/        Config Lua de Hyprland (binds, ventanas, monitores...)
  quickshell/         Shell QML: bar/, components/, services/, modules/<vista>/
  themes/             Paletas de colores
  apply/              Python: hf-apply convierte settings.json → settings.lua
  defaults/           Valores por defecto de settings.json
scripts/              ~45 scripts hf-* (Bash/Python)
install/              Paquetes por distro, bootstrap.sh
dev/                  Herramientas de desarrollo y validación
docs/                 Documentación de usuario
```

## Validar cambios

```bash
./dev/lint.sh          # bash/python/lua/json/shellcheck/índice de Ajustes
./dev/check.sh         # Abre sesión anidada con 24 vistas y 40 secciones (~2 min)
./dev/try.sh <vista>   # Probar una vista concreta en sesión anidada
```

Si cambias textos en `config/quickshell/modules/settings/sections/*.qml`, regenera el índice de búsqueda:

```bash
./dev/gen-settings-index.py
```

## Probar el shell

```bash
hf-session --nested    # Ventana dentro de tu sesión actual; cierra con Super+Shift+Esc
```

## Dependencias importantes

- Hyprland 0.57+ con soporte Lua (`hyprland-lua` o equivalente).
- Quickshell 0.3+.
- Python 3, bash, ImageMagick, fc-list, etc. Lista completa en `install/packages.tsv`.

## Notas de estilo

- Código y comentarios en español.
- QML: usa `Theme.*` para colores, `Settings.get/set` para preferencias.
- Los ajustes nuevos deben tener valor por defecto en `config/defaults/settings.json` y, si afectan a Hyprland, un script en `config/apply/`.
- Los cambios de configuración destructivos usan `Confirm.change(...)` con barra «¿Se ve bien?».

## Licencia

MIT. Ver `LICENSE`.
