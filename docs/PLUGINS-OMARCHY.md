# Plugins de Omarchy en HyprFrijol

HyprFrijol incluye una **capa de compatibilidad** con los plugins de la shell de Omarchy. No son plugins nativos de HyprFrijol: se cargan dentro de Quickshell con las mismas capacidades que tienen en Omarchy, pero con algunas limitaciones.

> ⚠️ Los plugins de Omarchy son código sin aislar. Al activarlos se ejecutan dentro de la shell con los permisos de tu usuario (archivos, red, procesos). Léelos antes de añadirlos y activa solo los que te fíes.

## Qué se soporta

Tipos de plugin que HyprFrijol puede cargar:

| Tipo | Descripción |
|---|---|
| `bar-widget` | Widget para la barra. |
| `panel` | Panel flotante. |
| `overlay` | Overlay a pantalla completa. |
| `menu` | Menú desplegable. |
| `service` | Servicio sin UI en segundo plano. |

No se soporta el tipo `bar` completo (reemplazar toda la barra). Los widgets de barra (`bar-widget`) pueden añadirse a la barra de HyprFrijol.

## Instalar un plugin

### Desde un repositorio git

```bash
hf-plugin add https://github.com/usuario/mi-plugin-omarchy --enable
```

Esto:

1. Clona el repo en `~/.local/share/hyprfrijol/plugins/<id>/`.
2. Valida el `manifest.json`.
3. Pide confirmación (a menos que uses `--yes`).
4. Lo activa si usas `--enable`.

### Desde una carpeta local

```bash
hf-plugin add /ruta/al/plugin --enable
```

## Gestionar plugins

```bash
hf-plugin list                  # plugins instalados
hf-plugin list --json           # en JSON
hf-plugin info <id>             # manifiesto y estado
hf-plugin enable <id>           # activar
hf-plugin disable <id>          # desactivar
hf-plugin remove <id>           # desactivar y borrar
hf-plugin bar <id> on           # añadir widget a la barra
hf-plugin bar <id> off          # quitar widget de la barra
hf-plugin set <id> '<json>'     # ajustes del widget
hf-plugin summon <id>           # abrir panel/overlay/menu
hf-plugin toggle <id>           # alternar panel/overlay/menu
hf-plugin hide <id>             # cerrar panel/overlay/menu
hf-plugin rescan                # recargar la lista en la shell
```

## Probar un plugin

Después de añadirlo, aparece en Ajustes › Plugins de Omarchy. Desde ahí puedes activarlo, ponerlo en la barra y configurarlo.

También puedes marcar si funciona bien en HyprFrijol:

```bash
hf-plugin mark <id> probado
hf-plugin mark <id> no-probado
```

Esto ayuda a mantener una lista de plugins validados.

## Temas de Omarchy

Además de plugins, puedes importar temas `colors.toml` de Omarchy:

```bash
hf-plugin theme /ruta/al/colors.toml --name "Mi tema Omarchy" --apply
```

O desde un repo:

```bash
hf-plugin theme https://github.com/usuario/tema-omarchy --name "Mi tema" --apply
```

Esto añade la paleta a `~/.config/hyprfrijol/palettes-user.json` y, con `--apply`, la activa.

```bash
hf-plugin themes                # listar temas importados
hf-plugin theme-remove <clave>  # borrar un tema importado
```

## Plugins probados

La lista de plugins que han sido probados en HyprFrijol está en `config/omarchy/probados.json`. Si pruebas uno nuevo, marca su estado y, si quieres compartirlo, abre un PR añadiéndolo a ese archivo.

## Limitaciones

- No se puede reemplazar la barra completa (tipo `bar`).
- Los widgets que dependen de servicios privados de Omarchy (por ejemplo, autenticación propia) pueden no funcionar.
- La API de HyprFrijol (`Shell`, `Settings`, `Theme`) es similar pero no idéntica a la de Omarchy; los plugins que usen APIs propias de Omarchy pueden fallar.
- Los plugins se ejecutan sin sandbox. Revisa el código antes de activarlos.

## Crear un plugin compatible

Un plugin es una carpeta con:

```
mi-plugin/
  manifest.json
  MiWidget.qml        # entryPoint para bar-widget
  MiPanel.qml         # entryPoint para panel
```

Ejemplo de `manifest.json`:

```json
{
  "schemaVersion": 1,
  "id": "usuario.mi-plugin",
  "name": "Mi plugin",
  "version": "1.0.0",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "MiWidget.qml"
  },
  "barWidget": {
    "label": "Mi widget",
    "category": "System",
    "defaultSection": "right"
  }
}
```

Valida el plugin antes de instalarlo:

```bash
hf-plugin validate /ruta/al/mi-plugin
```

## Recursos

- Catálogo de plugins de Omarchy: <https://plugins.omarchy.org>
- Código fuente de Omarchy: <https://github.com/omacom/omarchy>
- Formato de `manifest.json` en `scripts/hf-plugin`.
