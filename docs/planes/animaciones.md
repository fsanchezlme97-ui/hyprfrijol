# HyprFrijol · Ajustes › Apariencia › Animaciones y efectos

> **Apartado:** Ajustes › Apariencia › Animaciones y efectos
> **Alcance:** movimiento (Hyprland y shell), efectos visuales (transparencia, desenfoque, sombras, resaltado, atenuado), sistema de movimiento del estilo Math y rendimiento de los efectos.
> **Estado:** plan para revisión. Documento de traspaso para continuar en otra sesión de trabajo.
> **Repositorio:** `fsanchezlme97-ui/hyprfrijol` · archivos base: `scripts/hf-apply` (`MOTION`, `motion_preset`, `motion_shell`, `motion_lua`, `SHADOWS`, `style_tokens`, bloque `decoration`), `config/quickshell/Theme.qml` (`dur`, `durIn`, `durOut`, `ease*`), `modules/settings/sections/{Apariencia,Energia,Accesibilidad}.qml`, `components/{Ripple,Glass}.qml`
> **Relacionado:** *Apariencia › Temas* (estilo Math e interruptor de transparencia).

---

## 1. Situación actual

El sistema de movimiento ya está bien resuelto en la base: un solo preset alimenta a la vez las animaciones de Hyprland (curvas y `hl.animation`) y las del shell (`theme.json → motion`). Lo que falla es que los ajustes están repartidos y que el shell no usa los tokens de forma uniforme.

| Qué | Dónde está hoy | Clave |
|---|---|---|
| Preset de animación: *fluido*, *equilibrado*, *rápido*, *mínimo* | Apariencia › Movimiento | `animPreset` |
| Velocidad (×0,4 a ×2,5) | Apariencia › Movimiento | `animSpeed` |
| Animaciones activadas | Apariencia › Movimiento | `animado` |
| Reducir movimiento | Accesibilidad | `reduceMotion` |
| Sombras: ninguna, suaves, marcadas | Apariencia › Ventanas | `shadows` |
| Resaltado de la ventana activa | Apariencia › Ventanas | `activeBorder` |
| Redondeo y forma de esquinas | Apariencia › Redondeo | `rounding`, `roundingShape`, `roundness` |
| Calidad del desenfoque: alta, equilibrada, ahorro | **Energía** | `blurQuality` |
| Quitar desenfoque con batería | **Energía** | `blurOnBattery` |
| Quitar efectos en juegos | **Energía** (enlace desde Apariencia) | `gameNoFx` |
| Reducir transparencia | **Accesibilidad** | `reduceTransparency` |
| Transparencia (SkySoul) | Selector de estilo | `estilo` → pasa a `transparencia` (ver *Temas*) |

**Problemas detectados:**
- Los efectos están en tres secciones distintas (Apariencia, Energía, Accesibilidad).
- En el shell hay unos **175 `Behavior on`**; no todos usan `Theme.dur` / `Theme.ease`, así que algunas animaciones no respetan el preset ni la velocidad.
- `motion_shell()` depende de `estilo == "skysoul"` para el rebote de entrada; con el estilo único Math hay que redefinirlo.
- No hay vista previa: hay que cambiar el preset y abrir algo para ver el efecto.

---

## 2. Nueva sección

Una sola sección **Animaciones y efectos** dentro de Apariencia, con cuatro bloques. Energía y Accesibilidad conservan **enlaces** a los ajustes que hoy tienen, no duplicados.

```
Apariencia › Animaciones y efectos
├── Movimiento        preset · velocidad · por zona · vista previa
├── Efectos           transparencia · desenfoque · sombras · resaltado · atenuado
├── Detalles del shell  pulsación · entradas escalonadas · transición del fondo
└── Rendimiento       batería · juegos · pantalla completa · automático
```

### 2.1 Movimiento
- **Preset:** Fluido · Equilibrado · Rápido · Mínimo · Sin animaciones. Se mantienen los cuatro actuales y "Sin animaciones" sustituye al interruptor `animado`.
- **Velocidad:** deslizador ×0,5 a ×2 con marcas (el rango técnico ×0,4–×2,5 se conserva para quien edite `settings.json`).
- **Por zona** (avanzado, plegado por defecto). Cada zona puede seguir al preset general o tener el suyo:
  - Ventanas (abrir, cerrar, mover)
  - Espacios de trabajo (deslizar, fundido, deslizar vertical)
  - Paneles y menús del shell
  - Notificaciones y OSD
- **Estilo de cambio de espacio:** deslizar · deslizar con fundido · fundido · vertical.
- **Vista previa en vivo:** una tarjeta que reproduce abrir, mover y cerrar con los valores elegidos, sin salir de Ajustes.
- **Reducir movimiento:** se muestra el estado y se enlaza a Accesibilidad. Cuando está activo, todo pasa a fundidos cortos (no a cero, para no perder la orientación).

### 2.2 Efectos
- **Transparencia:** el interruptor del estilo Math (definido en *Temas*). Aquí se ajusta su intensidad: opacidad de paneles y popups.
- **Desenfoque:** calidad alta · equilibrada · ahorro (se mueve desde Energía) y tamaño del desenfoque.
- **Sombras:** ninguna · suaves · marcadas (actual), con la sombra en dos capas del estilo Math.
- **Resaltado de la ventana activa:** el actual `activeBorder`, más la opción de borde con degradado del color de acento.
- **Atenuar ventanas inactivas:** nuevo (`dim_inactive` de Hyprland), con intensidad.
- **Opacidad de ventanas inactivas:** nuevo, opcional, con lista de apps excluidas (reproductores, videollamadas).
- **Esquinas:** enlace a Apariencia › Redondeo.

### 2.3 Detalles del shell
- **Efecto de pulsación** (`components/Ripple.qml`, usado en 6 componentes): activado o desactivado.
- **Entradas escalonadas** en listas (Spotlight, notificaciones, centro de control): activado o desactivado.
- **Animación del hover** en botones y chips: ninguna, cambio de color o elevación leve.
- **Transición del fondo de pantalla:** fundido, deslizar, crecer desde el cursor, ninguna; y duración.
- **Animación de la barra** al ocultarse o aparecer.

### 2.4 Rendimiento
- **Con batería:** bajar la calidad del desenfoque (actual `blurOnBattery`) y, nuevo, pasar al preset Rápido.
- **Juegos y pantalla completa:** sin desenfoque ni sombras (actual `gameNoFx`).
- **Modo foco:** sin desenfoque (ya ocurre en `hf-apply`, se hace visible aquí).
- **Automático (nuevo):** si la GPU va cargada o caen los FPS de forma sostenida, se reducen los efectos y se avisa una vez.

---

## 3. Sistema de movimiento de Math

Para que todo el shell se mueva igual, se definen tokens de movimiento al estilo de Material 3 y se usan en **todos** los `Behavior` y transiciones.

### 3.1 Tokens

| Token | Uso | Base (Equilibrado) |
|---|---|---|
| `Theme.durShort` | hover, cambios de color, interruptores | 100–150 ms |
| `Theme.durMedium` | chips, menús, tooltips | 200–250 ms |
| `Theme.durLong` | paneles, popups, centro de control | 300–400 ms |
| `Theme.durXLong` | transiciones de pantalla completa, overview | 450–550 ms |
| `Theme.easeStandard` | cambios dentro de la pantalla | `(0.2, 0, 0, 1)` |
| `Theme.easeEmphasized` | entradas importantes | `(0.05, 0.7, 0.1, 1)` |
| `Theme.easeDecelerate` | elementos que entran | `(0, 0, 0, 1)` |
| `Theme.easeAccelerate` | elementos que salen | `(0.3, 0, 1, 1)` |
| `Theme.spring` | rebote leve (solo en Fluido) | `(0.34, 1.2, 0.64, 1)` |

- Los valores de cada token salen del preset activo y se dividen por la velocidad, igual que hoy `dur`/`durIn`/`durOut`.
- `dur`, `durIn`, `durOut`, `ease`, `easeIn`, `easeOut` se conservan como alias durante la transición.
- El rebote de entrada deja de depender de SkySoul: lo decide el preset (Fluido sí, el resto no).

### 3.2 Reglas
- Lo que entra decelera; lo que sale acelera y dura menos que lo que entra.
- Nada pasa de `durXLong` salvo transiciones de fondo.
- Movimiento corto: los desplazamientos de entrada son de 8–16 px, no de pantalla completa.
- Un solo elemento con rebote por pantalla.
- Con `reduceMotion`: sin desplazamientos ni escalas; solo fundidos de `durShort`.

### 3.3 Componente común
Nuevo `components/Motion.qml` (o funciones en `Theme.qml`) con transiciones listas para usar: `fadeIn`, `fadeOut`, `slideUp`, `scaleIn`, `stagger(index)`. Los componentes de `Ui/` y `components/` dejan de declarar duraciones a mano.

---

## 4. Auditoría y migración

1. **Inventario:** listar los ~175 `Behavior on` y las `NumberAnimation` / `ColorAnimation` que usan duraciones o curvas fijas.
2. **Sustituir** cada valor fijo por el token que corresponda (tabla 3.1).
3. **Revisar** que todo respete `reduceMotion` (hoy lo leen 22 archivos).
4. **Migrar ajustes** en `hf-migrate`:

| Antes | Después |
|---|---|
| `animado: false` | `animPreset: "ninguno"` |
| `blurQuality`, `blurOnBattery`, `gameNoFx` | mismas claves, nueva ubicación en la interfaz |
| `estilo: "skysoul"` (rebote de entrada) | `transparencia: true`; el rebote lo decide el preset |

5. **Enlaces:** Energía y Accesibilidad muestran filas de enlace (`LinkRow`) hacia esta sección.
6. **Búsqueda:** actualizar `modules/settings/search-index.json` y las palabras clave (`kw`) de Apariencia.

---

## 5. Archivos

| Nuevo | Se modifica |
|---|---|
| `modules/settings/sections/Animaciones.qml` (o bloque dentro de `Apariencia.qml`) | `scripts/hf-apply` (`MOTION` por zona, `motion_shell`, `dim_inactive`, opacidad inactivas, transición de fondo) |
| `modules/settings/ui/MotionPreview.qml` | `config/quickshell/Theme.qml` (tokens de movimiento) |
| `components/Motion.qml` | `components/Ripple.qml` (respeta el ajuste) |
| | `modules/settings/sections/{Apariencia,Energia,Accesibilidad}.qml` |
| | `scripts/hf-migrate`, `modules/settings/search-index.json` |
| | Componentes con duraciones fijas (resultado de la auditoría) |

**Claves nuevas en `settings.json`:** `animZones` (objeto por zona), `workspaceAnim`, `dimInactive`, `inactiveOpacity`, `inactiveOpacityExclude`, `ripple`, `stagger`, `hoverAnim`, `wallpaperTransition`, `wallpaperTransitionDur`, `fxAuto`, `batteryFastMotion`.

---

## 6. Fases

| Fase | Contenido |
|---|---|
| **1. Tokens de Math** | Tokens de movimiento en `Theme.qml`, `motion_shell` sin dependencia de SkySoul, alias de compatibilidad |
| **2. Auditoría** | Sustituir duraciones y curvas fijas en `Ui/` y `components/`; revisar `reduceMotion` |
| **3. Sección unificada** | Nueva sección con Movimiento, Efectos y Rendimiento; mover desenfoque desde Energía; enlaces |
| **4. Vista previa** | Tarjeta de vista previa en vivo |
| **5. Efectos nuevos** | Atenuado y opacidad de las ventanas inactivas, borde con degradado, transición de fondo, detalles del shell |
| **6. Por zona y automático** | Ajustes por zona y reducción automática de efectos |

---

## 7. Decisiones tomadas

- «Animaciones y efectos» es una sección propia dentro de la categoría Apariencia.
- Preset por defecto: Fluido (el actual).
- Se mantienen los cuatro presets y se añade «Sin animaciones» (sustituye al interruptor `animado`).
- Sin ajustes por zona: demasiado detalle para casi nadie.
- Sin reducción automática por FPS: medirlos de forma fiable en Hyprland es frágil. Queda el modo juego (atajo).
- Sin opciones de hover ni de animación de la barra: nadie las pidió.
- La transición del fondo sigue siendo la de `hf-wallpaper`.
- La vista previa en vivo va al final.
- Nota al comprobar el código: hay 39 duraciones escritas a mano (157 ya usan `Theme`), así que la auditoría es
  corta; y la opacidad de las ventanas inactivas ya existe (`inactive_opacity` 0.97 con desenfoque).
