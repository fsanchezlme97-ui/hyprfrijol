# Temas en HyprFrijol

HyprFrijol usa un sistema de **paletas**: cada paleta define los colores del shell, de las apps (GTK, Qt, Kitty, hyprlock) y, opcionalmente, del fondo de pantalla.

## Dónde viven los temas

- **Temas de serie**: `config/themes/palettes.json` (viene con el repo; no lo edites a mano, se sobreescribe al actualizar).
- **Temas propios / importados**: `~/.config/hyprfrijol/palettes-user.json` (tuyo, nunca se toca).
- **Temas de Omarchy**: también se leen de `~/.config/hyprfrijol/palettes-user.json` si los importas.

Cada paleta tiene al menos estos roles:

| Rol | Uso |
|---|---|
| `bg` | Fondo general |
| `s1`, `s3`, `s4` | Superficies elevadas (tarjetas, paneles, barra) |
| `p` | Color de acento |
| `onP` | Texto sobre el acento |
| `pc` | Contenedor del acento (chips, toggles activos) |
| `onPc` | Texto sobre `pc` |
| `sc` | Superficie de selección |
| `onSc` | Texto sobre selección |
| `ter` | Color terciario |
| `t` | Texto principal |
| `tv` | Texto secundario |
| `o` | Contorno/bordes |
| `ov` | Contorno sobre superficies elevadas |
| `light` | `true` si es variante clara |
| `pair` | Clave de la pareja oscura/clara (opcional) |
| `variant` | `true` si es la variante clara de un par (opcional) |

## Crear un tema propio

### Desde colores (terminal)

```bash
hf-theme make --name "Mi Tema" --hex "#1A1A2E #E94560 #16213E #0F3460"
```

Esto imprime un JSON con el tema oscuro y claro derivados automáticamente. Si te gusta:

```bash
hf-theme make --name "Mi Tema" --hex "#1A1A2E #E94560 #16213E #0F3460" > /tmp/mi-tema.json
hf-theme save /tmp/mi-tema.json
```

### Desde una imagen

```bash
hf-theme make --name "Mi Tema" --image ~/Imágenes/mi-fondo.jpg
```

Si la imagen tiene códigos hex visibles, los lee con OCR; si no, extrae los colores principales con matugen.

### Guardar, listar y borrar

```bash
hf-theme list
hf-theme remove propio-mi-tema
```

## Probar un tema

Una vez guardado, aparece en Ajustes › Apariencia › Temas. También puedes cambiarlo desde terminal:

```bash
hf-apply set palette propio-mi-tema
```

O cambiar a la variante clara:

```bash
hf-apply set themeMode claro
```

## Exportar e importar

Para compartir un tema:

```bash
hf-theme export propio-mi-tema
```

Esto crea `~/Descargas/propio-mi-tema.json`. Para importar uno:

```bash
hf-theme import ~/Descargas/propio-mi-tema.json
```

## Validar un tema editado a mano

Si editas el JSON directamente, comprueba que el contraste sigue siendo accesible:

```bash
hf-theme check /tmp/mi-tema-editado.json
```

## Crear un tema manualmente (JSON)

Puedes escribir `~/.config/hyprfrijol/palettes-user.json` a mano:

```json
{
  "propio-ejemplo": {
    "name": "Ejemplo",
    "group": "propio",
    "bg": "#121212",
    "s1": "#1E1E1E",
    "s3": "#2A2A2A",
    "s4": "#353535",
    "p": "#FF80AB",
    "onP": "#1A0510",
    "pc": "#5D3A4A",
    "onPc": "#FFE4EC",
    "sc": "#3A3A4A",
    "onSc": "#E6E6F0",
    "ter": "#80D8FF",
    "t": "#EAEAF0",
    "tv": "#A0A0B0",
    "o": "#5A5A6A",
    "ov": "#404050",
    "light": false,
    "pair": "propio-ejemplo-claro"
  },
  "propio-ejemplo-claro": {
    "name": "Ejemplo · claro",
    "group": "propio",
    "variant": true,
    "light": true,
    "bg": "#F5F5F7",
    ...
    "pair": "propio-ejemplo"
  }
}
```

Tras guardar, recarga el shell o selecciona el tema en Ajustes.

## Modos de tema

En Ajustes › Apariencia:

- **Oscuro / Claro**: fijo.
- **Auto**: cambia según la hora (`nightFrom` / `nightTo`) o el fondo.
- **Mono**: usa el fondo como paleta (matugen).

## Fondos y colores automáticos

Si activas `themeWallpaper: true` (o eliges el modo «Mono»), HyprFrijol genera la paleta a partir del fondo actual usando matugen. El tema resultante se guarda en `~/.local/state/hyprfrijol/theme.json`.

## Notas

- Los temas de serie (`palettes.json`) se regeneran con el repo. Para modificarlos, expórtalos, renómbralos y guárdalos como propios.
- Si un color no tiene suficiente contraste, `hf-theme check` o `hf-apply` lo ajustan automáticamente para cumplir al menos AA.
