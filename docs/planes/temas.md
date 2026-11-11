# HyprFrijol · Ajustes › Apariencia › Temas

> **Apartado:** Ajustes › Apariencia › Temas
> **Alcance:** estilo Math, transparencia, temas oficiales y temas propios (creador de temas).
> **Estado:** borrador para revisión. Documento de traspaso para continuar en otra sesión de trabajo.
> **Repositorio:** `fsanchezlme97-ui/hyprfrijol` · archivos base: `config/quickshell/Theme.qml`, `scripts/hf-apply`, `config/themes/palettes.json`, `config/quickshell/modules/settings/sections/Apariencia.qml`

---

## 1. Resumen

| Antes | Después |
|---|---|
| 3 estilos: *Material* (`flat`), *SkySoul* (`skysoul`), *Chroma* (`chroma`) | **1 estilo: Math** (Material Design pulido) |
| SkySoul = estilo aparte con cristal y blur | **Transparencia**: interruptor que funciona con cualquier tema |
| Chroma = estilo aparte (Nothing Phone) | **Se elimina** |
| 66 paletas en `config/themes/palettes.json` | **24 temas como máximo**: 12–14 oficiales + espacios para temas propios |
| Paletas solo oscuras o solo claras | **Cada tema es un par oscuro + claro** |
| — | **Creador de temas** a partir de una imagen, una foto o códigos hex |

Hay tres ejes independientes:

```
Estilo:        Math (único)
Tema:          oficial (12–14) | propio (hasta 10–12)
Transparencia: activada | desactivada
Modo:          oscuro | claro | automático (amanecer/atardecer)
```

---

## 2. Estilo Math

Un solo estilo basado en Material Design 3, con acabado más cuidado.

### 2.1 Lo que define Math
- **Movimiento:** curvas *emphasized* / *spring* de Material 3 y entradas escalonadas (*stagger*) en las listas. Respeta `reduceMotion`.
- **Profundidad:** sombra en dos capas (una cercana y nítida, otra amplia y difusa).
- **Bordes:** línea fina (*hairline*) de 1 px y un borde interior algo más claro arriba en las superficies elevadas.
- **Espaciado:** escala fija 4 / 8 / 12 / 16 / 24 y radios concéntricos (radio interno = radio externo − padding).
- **Tipografía:** fuente variable (Inter o Geist), pesos medios en lugar de negrita y cifras tabulares en el reloj y las estadísticas.
- **Estados:** hover, foco (anillo visible), presionado y deshabilitado uniformes en todos los componentes de `Ui/` y `components/`.

### 2.2 Transparencia (antes SkySoul)
- Es un ajuste booleano, `transparencia`, en Ajustes › Apariencia.
- Cuando está activa, `hf-apply` aplica sobre los tokens de Math el alfa de `bg` / `bgPanel` / `bgPopup`, el blur de Hyprland y el borde claro superior.
- Las ventanas grandes (Ajustes, Centro de aplicaciones) siguen siendo más opacas que los paneles.
- En `Theme.qml`, `glassy` pasa a leer el ajuste en vez del estilo:
  ```qml
  readonly property bool glassy: data.transparencia ?? false
  ```
- Cada tema oficial lleva un ajuste de alfa y contraste revisado a mano para el modo con blur.

---

## 3. Eliminación de Chroma y SkySoul

### 3.1 En `Theme.qml`
Las propiedades que solo existían para Chroma quedan fijas en su valor de Math. Así los componentes que las leen siguen funcionando, y se limpian en una segunda pasada.

| Propiedad | Valor fijo |
|---|---|
| `chroma` | `false` (luego se borra) |
| `capsLabels` | `false` |
| `labelFont` / `labelSpacing` | `font` / valor de Material |
| `displayFont` / `displayWeight` | `font` / `Font.Normal` |
| `selPill`, `selPillColor` | valor de Material |
| `fillOn`, `fillOnText`, `segThumb`, `segText`, `selBg`, `selText` | rama de Material o de transparencia |
| `danger` | `light ? "#B3261E" : "#F2B8B5"` |
| `estilo` | `"math"` |

### 3.2 Archivos con referencias a Chroma o SkySoul

- **Scripts:** `scripts/hf-apply` (`STYLES`, `STYLE_ALIAS`, `norm_style`, `chroma_colors()`, `style_tokens()`, `motion_shell()`), `scripts/hf-ai`, `config/apply/10-look.py`, `config/apply/16-gtk.py`
- **Tema:** `config/quickshell/Theme.qml`
- **Barra:** `bar/Workspaces.qml`, `bar/StatusGroup.qml`, `bar/ProgressRing.qml`
- **Componentes:** `components/Segmented.qml`, `components/SliderBar.qml`, `components/Tile.qml`, `components/Txt.qml`
- **Módulos:** `modules/media/MediaControls.qml`, `modules/osd/Osd.qml`, `modules/quicksettings/QuickSettings.qml`, `modules/spotlight/Spotlight.qml`, `modules/welcome/Welcome.qml`
- **Ajustes:** `modules/settings/SettingsApp.qml`, `sections/Apariencia.qml`, `ui/Section.qml`, `ui/StylePreview.qml`
- **Greeter:** `greeter/quickshell/shell.qml`, `greeter/quickshell/palettes.json`
- **Fuente:** `assets/fonts/Doto` queda sin uso y se puede borrar.

### 3.3 Migración de `settings.json`

| Valor anterior | Resultado |
|---|---|
| `estilo: "skysoul"` (o alias `aurora`, `liquid`, `tonal`) | `estilo: "math"`, `transparencia: true` |
| `estilo: "chroma"` (o alias `mica`) | `estilo: "math"`, `transparencia: false` |
| `estilo: "flat"` (o alias `suave`, `soft`) | `estilo: "math"`, `transparencia: false` |
| paleta que deja de existir | la más parecida de la lista oficial (tabla de equivalencias en `hf-migrate`) o Grafito |

La migración la hacen `hf-migrate` y `STYLE_ALIAS` en `hf-apply`, y debe ser idempotente.

---

## 4. Temas oficiales (12–14)

Regla: **cada tema es un par oscuro + claro**, ajustado a mano para los dos modos y para la transparencia.

| # | Tema | Oscuro | Claro | Estado |
|---|---|---|---|---|
| 1 | Grafito | `grafito` | `claro` | Emparejar las dos existentes |
| 2 | Oxocarbon | `oxocarbon` | — | **Crear variante clara** (base: IBM Carbon claro) |
| 3 | Ciruela | — | — | **Nuevo**, desde la paleta de referencia (ver 4.1) |
| 4 | Rosa pastel | `rosa` | `rosa-claro` | Existe |
| 5 | Catppuccin | `catppuccin-mocha` | `catppuccin-latte` | Existe |
| 6 | Rosé Pine | `rose-pine` | `rose-pine-dawn` | Existe |
| 7 | Nord | `nord` | `nord-claro` | Existe |
| 8 | Tokyo Night | `tokyo-night` | `tokyo-night-dia` | Existe |
| 9 | Gruvbox | `gruvbox` | `gruvbox-claro` | Existe (por confirmar) |
| 10 | Everforest | `everforest` | `everforest-claro` | Existe |
| 11 | Kanagawa | `kanagawa` | `kanagawa-lotus` | Existe (por confirmar) |
| 12 | Lila pastel | `lila` | `lila-claro` | Existe |
| 13 | Monocromo | `mono` | `monoclaro` | Existe (neutro) |
| 14 | *(libre)* | | | Opcional: Ámbar otoñal, Menta, Melocotón o Dracula |

**Se retiran:** Catppuccin Macchiato y Frappé, Tokyo Night Storm, Rosé Pine Moon, Kanagawa Dragon, Ayu (las tres), GitHub, Flexoki, Solarized, One Dark/Light, Monokai Pro, Nightfox, Dracula/Alucard, Menta, Melocotón, Cielo, Azul, Verde, Ámbar, Lavanda, Pizarra, Medianoche, Carbón, Bosque, Vino, Océano, Cobre, Neón, Hielo, Papel, Arena y Salvia (salvo las que se elijan para el n.º 14).

### 4.1 Tema nuevo: Ciruela

Colores de referencia: `#482A41`, `#E2D2C8`, `#CEB2BD`, `#8E7692`, `#572E54`. Borrador de tokens, por afinar:

| Token | Oscuro | Claro |
|---|---|---|
| `bg` | `#1E1219` | `#E2D2C8` |
| `s1` | `#2C1B27` | `#F3EAE4` |
| `s3` | `#482A41` | `#EADDD5` |
| `p` | `#CEB2BD` | `#572E54` |
| `onP` | `#2C1B27` | `#F3EAE4` |
| `pc` | `#572E54` | `#CEB2BD` |
| `t` | `#E2D2C8` | `#2E1B2A` |
| `tv` | `#B9A5B3` | `#6E5A6C` |

### 4.2 Ejemplo de tema derivado: Ámbar otoñal

Colores de referencia: `#241B1C`, `#3D3539`, `#4F484F`, `#766058`, `#F0B569`. La imagen solo trae colores oscuros, así que la variante clara se deriva.

| Token | Oscuro | Claro (derivado) |
|---|---|---|
| `bg` | `#1A1314` | `#E9E1DB` |
| `s1` | `#241B1C` | `#F7F2EE` |
| `s3` | `#3D3539` | `#EFE7E1` |
| `p` | `#F0B569` | `#8A5A12` |
| `pc` | `#766058` | `#F6DDB3` |
| `t` | `#EDE3DA` | `#241B1C` |
| `tv` | `#B5A8A6` | `#4F484F` |

### 4.3 "Auto · Atardecer"
Pendiente: decidir si se mantiene como paleta especial o si basta con el modo automático (amanecer/atardecer) aplicado a cualquier tema. Esto último es lo más coherente con la regla de pares.

---

## 5. Temas propios y creador de temas

### 5.1 Límites
- **Máximo total: 24 temas.**
- Oficiales: 12–14, que no se pueden borrar.
- Propios: los espacios restantes (10–12). Se pueden crear, renombrar, editar, borrar y reemplazar.
- Con los espacios llenos, al crear uno nuevo el selector pide cuál reemplazar.

### 5.2 Entradas aceptadas
1. **Imagen de paleta** con los códigos hex escritos (como las de referencia).
2. **Foto o fondo de pantalla** cualquiera.
3. **Códigos hex** pegados a mano (de 2 a 8 colores).

### 5.3 Proceso

```
Entrada ─▶ 1. Extracción ─▶ 2. Roles ─▶ 3. Completar ─▶ 4. Validar ─▶ 5. Vista previa ─▶ Guardar
           (sin IA)         (IA opc.)    (sin IA)       (sin IA)
```

1. **Extracción (sin IA)**
   - Imagen de paleta: OCR con tesseract (ya lo usa `hf-ai capture`) para leer los hex exactos.
   - Foto: colores dominantes con **matugen** (motor de color de Material, ya integrado).
   - Hex pegados: se validan con `valid_hex()`.
2. **Asignación de roles (IA opcional)**
   - La IA (`hf-ai`, con visión) decide qué color es `bg`, `s1`, `p`, `pc`, `ter` cuando no es obvio, y propone un nombre.
   - Sin IA, se usa una heurística: el más oscuro o el más claro como `bg`, el más saturado como `p`, el resto por luminancia.
3. **Completar (sin IA)**
   - Se genera la variante que falte (oscura o clara) con `flip_palette()`.
   - Se derivan los tokens restantes (`onP`, `onPc`, `onSc`, `tv`, `o`, `ov`, ANSI) con las funciones existentes (`best_on`, `mix`, ANSI armónicos).
4. **Validar (sin IA)**
   - `fix_contrast()` con un mínimo de AA (4.5:1 para el texto, 3:1 para los elementos de interfaz).
   - Prueba con transparencia activada: contraste del texto sobre el alfa del panel.
   - Si algo no se puede corregir, se avisa en la vista previa.
5. **Vista previa**
   - Barra, centro de control, Spotlight y una notificación, en oscuro, en claro y con transparencia.
   - Acciones: *Guardar*, *Editar colores*, *Descartar*.

### 5.4 Almacenamiento
- Archivo aparte: `~/.local/state/hyprfrijol/temas-propios.json`. Nunca se mezcla con `config/themes/palettes.json`, así que las actualizaciones no lo tocan.
- Esquema propuesto:
  ```json
  {
    "version": 1,
    "temas": {
      "propio-ciruela": {
        "name": "Ciruela",
        "origen": "imagen",
        "creado": "2026-11-11",
        "oscuro": { "bg": "#1E1219", "s1": "#2C1B27", "...": "..." },
        "claro":  { "bg": "#E2D2C8", "s1": "#F3EAE4", "...": "..." }
      }
    }
  }
  ```
- Los temas propios se marcan como **"Propio"** en el selector: la validación garantiza que sean legibles, no que tengan el acabado de uno oficial.

### 5.5 Compartir
- Exportar un tema a un `.json` pequeño (un solo tema).
- Importar valida el esquema y el contraste antes de ocupar un espacio.

---

## 6. Interfaz: Ajustes › Apariencia

```
Estilo          Math
Transparencia   [ interruptor ]
Modo            Oscuro · Claro · Automático
Temas oficiales [ cuadrícula de 12–14 ]
Mis temas       [ cuadrícula de propios ]  [ + Crear tema ]   n/10
```

El flujo de **Crear tema**: elegir la entrada (imagen, foto o hex), ver la vista previa, ajustar si hace falta y guardar.

---

## 7. Fases de implementación

1. **Estilo único:** Math + interruptor de transparencia + eliminación de Chroma/SkySoul + migración.
2. **Temas oficiales:** podar `palettes.json`, emparejar oscuro/claro, crear Oxocarbon claro y Ciruela, ajustar cada uno con transparencia. Sincronizar `greeter/quickshell/palettes.json`.
3. **Pulido de Math:** movimiento, sombras, bordes, espaciado y estados en `Ui/` y `components/`.
4. **Temas propios:** almacenamiento, selector con límite, exportar e importar.
5. **Creador de temas:** extracción (OCR / matugen / hex), roles (heurística + IA opcional), validación y vista previa.

---

## 8. Decisiones tomadas

- 13 temas oficiales; el espacio n.º 14 queda libre por ahora.
- Gruvbox y Kanagawa se mantienen.
- Rosa pastel se mantiene junto a Ciruela.
- «Auto · Atardecer» se quita: el modo automático (amanecer/atardecer) vale para cualquier tema.
- El estilo se llama Math.
- Fuente: se decide en la fase 3 (pulido); si se añade una, va al instalador en todas las distros.
- Sin tope de temas propios: el tope obligaba a un selector de «cuál reemplazo» y no ahorra nada.
- Creador: heurística primero; la IA para asignar roles llega después, como opción.
