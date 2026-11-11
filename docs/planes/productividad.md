# HyprFrijol · Ajustes › Productividad

> **Apartado:** Ajustes › Productividad
> **Alcance:** Spotlight, portapapeles, enfoque y pomodoro, agenda y alarmas, tareas, espacios ocultos y atajos.
> **Estado:** plan. Escrito a partir de lo que ya hay en el código (noviembre de 2026).
> **Archivos base:** `modules/spotlight/Spotlight.qml`, `services/{Clip,Events,Alarms,Pomodoro}.qml`,
> `modules/agenda/AgendaCard.qml`, `modules/focus/Focus.qml`, `modules/settings/sections/Enfoque.qml`,
> `config/hypr/frijol/binds.lua`, `modules/cheatsheet/Cheatsheet.qml`
> **Relacionado:** *Asistente de IA* (acciones rápidas: crear tarea, crear evento; apps excluidas compartidas).

---

## 1. Situación actual

Casi todo existe; lo que falta es orden en Ajustes y una lista de tareas.

| Área | Qué hace hoy | Dónde se ajusta |
|---|---|---|
| **Spotlight** | Apps, web apps, acciones, ventanas, archivos, calculadora, portapapeles, emojis, IA y web, con prefijos `> = ? @ / : ; !` | Repartido (IA en Asistente, portapapeles en Privacidad) |
| **Portapapeles** | Historial de `cliphist` con miniaturas, fijados, pegar al elegir (`clipboardAutoPaste`); Super + V | Privacidad |
| **Pomodoro** | Foco / descanso / largo / ciclos, encadenar, sonido; chip de la barra | Enfoque y pomodoro |
| **Modo sin distracciones** | Super + Z: píldora con el pomodoro, no molestar, cierre de apps por categoría durante el foco (`focusBlock`) | Enfoque y pomodoro |
| **Agenda** | Calendario del mes, eventos locales + `.ics` (`calendarIcs`), «Unirse», relojes del mundo | Fecha, hora e idioma |
| **Alarmas** | Alarmas por hora y días, posponer 5 min | Ventana del pomodoro |
| **Espacios ocultos** | Super + S (espacio oculto), consola desplegable (`special:consola`) | Teclado y atajos |
| **Atajos** | Hoja de atajos (`Cheatsheet`) | Teclado y atajos |

### 1.1 Huecos
- No hay **tareas**: el asistente no tiene dónde «crear tarea» y la agenda solo muestra eventos.
- Los ajustes de productividad están en cinco secciones (Enfoque, Fecha, Privacidad, Teclado, Asistente).
- Spotlight no deja elegir qué grupos salen ni en qué orden.
- El portapapeles guarda todo: no hay **apps excluidas** (gestores de contraseñas) ni caducidad.
- Pendiente de `PENDIENTES.md`: revisar Spotlight, portapapeles, ventanas y atajos con uso real y quitar pasos.

---

## 2. Estructura

Una categoría **Productividad** en la barra lateral de Ajustes que agrupa secciones que ya existen, más una nueva.

```
Ajustes › Productividad
├── Spotlight          grupos visibles · orden · prefijos · búsqueda web
├── Portapapeles       historial · tamaño · caducidad · apps excluidas · fijados
├── Enfoque y pomodoro (lo actual de Enfoque.qml)
├── Agenda y alarmas   calendarios .ics · semana contraída · relojes · alarmas
└── Tareas             nuevo: lista simple con fecha opcional
```

Las claves de sección antiguas (`enfoque`) se conservan; Fecha conserva un enlace a «Agenda y alarmas».
El Asistente de IA queda como categoría propia (ver su plan); no entra aquí.

---

## 3. Detalle

### 3.1 Spotlight
- **Grupos visibles** (apps, ventanas, archivos, acciones, web apps, calculadora, IA, web): interruptor por grupo.
- **Orden de los grupos** cuando no hay prefijo.
- **Buscador web** para `!` (DuckDuckGo por defecto; Google, Brave, Kagi o una URL con `%s`).
- La lista de prefijos se muestra en la sección (solo lectura) para descubrirlos.

### 3.2 Portapapeles
- **Tamaño del historial** (pasa a `cliphist -max-items`) y **caducidad** (borrar lo que no está fijado tras N días).
- **Apps excluidas:** si la ventana activa es una de ellas al copiar, la entrada se borra al momento. Lista por clase
  de ventana, con KeePassXC, Bitwarden y 1Password por defecto. Es la misma lista que usa el asistente
  (`aiExcludeApps` lee esta, no hay dos).
- Borrar todo y gestionar fijados (lo actual).

### 3.3 Agenda y alarmas
- Se mueve aquí lo de calendarios `.ics` (hoy en Fecha) y la vista contraída.
- Las alarmas se ven y se editan también desde Ajustes, no solo desde la ventana del pomodoro.

### 3.4 Tareas · *nuevo, mínimo*
- Lista en `~/.local/share/hyprfrijol/tasks.json`: `[{ id, text, done, due? (AAAA-MM-DD), created }]`.
- **Dónde se ven:** en la agenda, bajo los eventos del día (las que vencen ese día y las sin fecha), con casilla para
  marcarlas. Las vencidas salen arriba en otro color.
- **Cómo se crean:** el «+» de la agenda (evento o tarea), Spotlight con `+texto` y el asistente (`hf-ai`, acción
  `task.add`, con deshacer como el resto).
- Sin proyectos, etiquetas, prioridades ni sincronización: si hacen falta, se usa una app de tareas.

---

## 4. Revisión con uso real (quitar pasos)

Se hace usando el escritorio, no leyendo código. Lista de lo que se mide:
- Abrir una app que no está en el dock: pulsaciones hasta que aparece.
- Pegar algo copiado hace 10 minutos: pulsaciones.
- Pasar una ventana a otra pantalla y volver.
- Empezar un bloque de foco y salir de él.
Lo que lleve más de tres pasos se apunta y se recorta.

---

## 5. Fases

| Fase | Contenido |
|---|---|
| **1. Categoría** | Categoría Productividad en `SettingsApp.qml`; mover Enfoque; «Agenda y alarmas» con lo de Fecha; enlaces; búsqueda |
| **2. Portapapeles** | Sección propia, tamaño, caducidad, apps excluidas |
| **3. Tareas** | `services/Tasks.qml`, lista en la agenda, `+` en Spotlight, acción del asistente |
| **4. Spotlight** | Grupos visibles, orden, buscador web |
| **5. Uso real** | La revisión de la sección 4 |

**Claves nuevas en `settings.json`:** `spotlightGroups`, `spotlightOrder`, `webSearch`, `clipMaxItems`,
`clipExpireDays`, `clipExcludeApps`.

---

## 6. Decisiones tomadas

- El Asistente de IA es categoría propia, no sección de Productividad (es demasiado grande).
- Tareas mínimas: una lista con fecha opcional; nada de proyectos ni sincronización.
- Las apps excluidas son una sola lista, compartida por portapapeles y asistente.
- Sin «perfiles de trabajo» por ahora: el modo sin distracciones ya cubre el caso principal.
