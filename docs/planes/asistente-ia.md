# HyprFrijol · Ajustes › Asistente de IA

> **Apartado:** Ajustes › Asistente de IA
> **Alcance:** configuración del asistente (proveedor, modelos, permisos, personalidad, voz, historial), su interfaz (panel lateral, Spotlight, voz) e integraciones (servidor MCP, traspaso a Claude Desktop y uso de la IA desde otros apartados).
> **Estado:** plan para revisión. Documento de traspaso para continuar en otra sesión de trabajo.
> **Repositorio:** `fsanchezlme97-ui/hyprfrijol` · archivos base: `scripts/hf-ai` (~2 500 líneas), `scripts/hf-mcp`, `scripts/hf-dictate`, `config/quickshell/modules/sidepanel/{SidePanel,AiChat,AiRich}.qml`, `modules/settings/sections/{IA,Panel,Dictado}.qml`, `modules/spotlight/`
> **Relacionado:** *Apariencia › Temas* (creador de temas desde imagen) y *Productividad* (tareas, notas, agenda, perfiles).

---

## 1. Situación actual

El asistente ya es completo. El plan no lo rehace: lo ordena, cierra huecos y lo conecta con el resto del shell.

### 1.1 Lo que ya existe

| Área | Qué hace hoy |
|---|---|
| **Proveedores** | `claude-code` (por defecto, CLI `claude -p`), `ollama`, `openai-compatible`, `gemini`, `off`, y `mock` para pruebas sin gasto |
| **Modelo y conexión** | `aiModel`, `aiEndpoint`, `aiKeyEnv`; clave de Gemini en el llavero (`secret-tool`) o en un archivo con permisos 600; `hf-ai test` y `hf-ai models` |
| **Entradas** | Panel lateral (chat con texto enriquecido y código), Spotlight con `?`, voz (`hf-ai talk`, Super + Alt + H), invocar con la ventana activa (`hf-ai summon`, Super + Ctrl + A) |
| **Contexto** | Ventana activa, portapapeles, capturas (visión o OCR con tesseract), imágenes adjuntas (portapapeles, archivo, URL) |
| **Consultas** | Solo lectura, hasta 3 rondas: ventanas, pantalla, notificaciones, archivos, apps, ajustes, sistema, temporizadores |
| **Acciones** | Ajustes, fondo, espacios, ventanas, apps y webs, música, volumen, brillo, no molestar, cafeína, temporizadores, pomodoro, avisos, vistas, comandos de terminal (siempre con confirmación). Casi todas se deshacen (`hf-ai apply` / `undo`) |
| **Permisos** | `aiContextWindow`, `aiContextClipboard`, `aiContextCapture`, `aiTerminal`, `aiControlShell`, `aiReadDesktop`, `aiConfirm`, `aiSpotlight`, `aiHistory`; lista de "Aprobadas siempre" (`aiAlwaysApprove`) |
| **Personalidad** | Nombre (`aiName`) e instrucciones propias (`aiPersona`), que se suman a las de siempre sin quitar permisos |
| **Voz** | Lectura local con Piper (voz *Helpert*, `es_ES-sharvard-medium`, `hf-ai voice-install`); anuncios con Gemini TTS (voz *Sophia*): saludo al entrar y avisos urgentes, en silencio con no molestar |
| **Dictado** | `hf-dictate` + `hf-ai transform` para reescribir lo dictado |
| **Integraciones** | Servidor MCP `hf-mcp` (las mismas herramientas, con anotaciones de solo lectura o destructivas); traspaso de la conversación a Claude Desktop o a `claude` en kitty (`hf-ai handoff`) |
| **Historial** | `~/.local/share/hyprfrijol/ai` (si `aiHistory`) |

### 1.2 Huecos
- Ajustes del asistente repartidos en tres secciones: "Asistente de IA", "Panel lateral y PiP" y "Dictado".
- Un solo modelo para todo: no se puede usar uno rápido para Spotlight y otro mejor para el panel, ni uno con visión solo para imágenes.
- Sin respaldo si el proveedor falla o no hay conexión.
- El historial se guarda, pero no se puede buscar ni continuar desde Ajustes.
- No hay un registro visible de las acciones que hizo el asistente.
- No hay protección contra enviar secretos (claves, tokens, contraseñas) que estén en el portapapeles o en una captura.
- Los nombres de las voces (Helpert, Sophia) y el nombre del asistente (`aiName`) no están unificados en la interfaz.
- El asistente no se puede usar todavía desde otros apartados (Temas, Productividad).
- `hf-mcp` es solo servidor: el asistente no puede usar servidores MCP externos.

---

## 2. Estructura de la sección

```
Ajustes › Asistente de IA
├── Inicio            estado · proveedor activo · prueba · uso
├── Proveedor y modelos  proveedor · modelo por tarea · respaldo · claves
├── Permisos          contexto · consultas · acciones · confirmación · aprobadas siempre
├── Privacidad        filtro de secretos · apps excluidas · historial · registro de acciones
├── Personalidad      nombre · instrucciones · idioma y tono · lo que sabe de ti
├── Voz               lectura (Helpert) · anuncios (Sophia) · hablar con el asistente
├── Dictado           (lo actual de la sección Dictado)
├── Panel lateral y PiP (lo actual de la sección Panel)
├── Acciones rápidas  recetas reutilizables y dónde aparecen
└── Integraciones     servidor MCP · servidores MCP externos · Claude Desktop
```

**Ubicación en la barra lateral:** el plan de *Productividad* la coloca como sección dentro de esa categoría. Por su tamaño, se propone que **Asistente de IA sea categoría propia** con estas subsecciones (ver decisiones pendientes). Las claves antiguas (`ia`, `panel`, `dictado`) se conservan como alias.

---

## 3. Detalle por subsección

### 3.1 Inicio · *nuevo*
- Estado en una línea: proveedor, modelo y si responde ("Claude Code · sonnet · listo").
- Botón **Probar conexión** (`hf-ai test`).
- Uso aproximado del día y del mes: número de peticiones y, si el proveedor lo informa, tokens. Solo local.
- Atajos: abrir el panel, hablar, invocar con la ventana.

### 3.2 Proveedor y modelos · *existe, se amplía*
- Proveedor y conexión: lo actual.
- **Modelo por tarea** (nuevo), cada una con "el mismo que el general" por defecto:
  - Chat del panel
  - Respuestas rápidas (Spotlight `?`, transformar dictado)
  - Visión (capturas, crear tema desde imagen)
- **Respaldo** (nuevo): si el proveedor principal falla o no hay red, usar otro (por ejemplo, Ollama local). Se avisa en la respuesta cuando se usó el respaldo.
- **Modo local** (nuevo): un interruptor que fuerza Ollama y desactiva todo lo que salga del equipo, incluidas las voces en la nube.
- Claves: siempre en el llavero o en un archivo 600, nunca en `settings.json`. Botones de ver estado, cambiar y borrar.

### 3.3 Permisos · *existe, se reordena*
Agrupados por nivel de riesgo, con una frase clara en cada uno:

| Grupo | Permisos |
|---|---|
| **Qué puede ver** | Ventana activa, portapapeles, capturas adjuntas, consultar el escritorio (ventanas, avisos, archivos, estado) |
| **Qué puede proponer** | Comandos de terminal (siempre con confirmación) |
| **Qué puede hacer** | Controlar el escritorio (ajustes, ventanas, apps, música, volumen, temporizadores…) |
| **Cómo** | Confirmar antes de aplicar, aprobadas siempre (con botón para retirar cada una) |

Se añade un **nivel rápido** arriba: Solo conversar · Ver y sugerir · Control completo (con confirmación). Cada nivel marca los interruptores de abajo, que siguen siendo editables.

### 3.4 Privacidad · *nuevo*
- **Filtro de secretos:** antes de enviar, se ocultan patrones de claves de API, tokens, claves privadas, contraseñas en URLs y números de tarjeta. Se avisa en el chat ("se ocultó 1 dato sensible").
- **Apps excluidas:** el asistente no lee la ventana, el título ni las capturas de estas apps (gestores de contraseñas, banca, etc.). Comparte la lista con *Productividad › Portapapeles*.
- **Historial:** activar o desactivar, días que se guardan, buscar, abrir una conversación anterior, exportar y borrar todo.
- **Registro de acciones:** lista de lo que hizo el asistente (fecha, acción, resultado) con **Deshacer** cuando aplique. Se guarda en `~/.local/state/hyprfrijol/ai-acciones.json`.
- Enlace desde Privacidad y seguridad.

### 3.5 Personalidad · *existe, se amplía*
- Nombre e instrucciones: lo actual.
- **Idioma y tono** como opciones simples (formal o cercano, respuestas cortas o largas), que se traducen en instrucciones.
- **Lo que sabe de ti** (nuevo): notas breves que el usuario escribe y edita (nombre, trabajo, preferencias). El asistente nunca las añade por su cuenta sin preguntar.
- Vista previa: un saludo de prueba con la personalidad elegida.

### 3.6 Voz · *existe, se ordena*
- **Lectura de respuestas:** voz local Piper (Helpert); instalar o actualizar la voz desde aquí; velocidad.
- **Anuncios:** saludo al entrar y avisos urgentes (Sophia, Gemini TTS, con respaldo a la voz local); respeta no molestar.
- **Hablar con el asistente:** atajo, pulsar para hablar o alternar, sonido al empezar y terminar.
- **Nombres:** se decide si Helpert y Sophia siguen siendo voces con nombre propio o si toman el nombre del asistente (`aiName`).

### 3.7 Dictado y Panel lateral · *se mueven aquí*
Sin cambios de función: los contenidos actuales de `Dictado.qml` y `Panel.qml` pasan a ser subsecciones.

### 3.8 Acciones rápidas · *nuevo*
Recetas reutilizables: una instrucción + de dónde sale el texto + qué se hace con el resultado.

| Receta (ejemplos incluidos) | Entrada | Salida |
|---|---|---|
| Resumir | portapapeles o selección | panel |
| Traducir al español / al inglés | selección | reemplazar o copiar |
| Corregir redacción | selección | reemplazar |
| Explicar error | último comando de la terminal o captura | panel |
| Crear tarea | selección o nota | *Productividad › Enfoque* (tareas) |
| Crear evento | texto con fecha | *Productividad › Agenda* |
| Crear tema desde imagen | imagen | *Apariencia › Temas* (creador) |

- Se pueden crear, editar y borrar recetas propias.
- **Dónde aparecen:** Spotlight (escribir el nombre), menú del panel lateral, atajo propio y, opcionalmente, un menú contextual sobre el texto seleccionado.
- Se guardan en `~/.local/share/hyprfrijol/ai-recetas.json`.
- Cada receta indica qué permisos usa; si falta uno, se pide en el momento.

### 3.9 Integraciones · *existe, se amplía*
- **Servidor MCP de HyprFrijol** (`hf-mcp`): estado, comando para añadirlo a Claude (`claude mcp add hyprfrijol -- …`) con botón de copiar, y lista de herramientas expuestas con su tipo (solo lectura, cambio, destructiva).
- **Claude Desktop:** traspaso de la conversación (`hf-ai handoff`) y a `claude` en kitty.
- **Servidores MCP externos** (nuevo, fase final): permitir que el asistente use servidores MCP del usuario (calendario, GitHub, archivos…). Cada servidor se aprueba aparte y sus herramientas de cambio siempre piden confirmación.

---

## 4. Interfaz del asistente (fuera de Ajustes)

- **Panel lateral:**
  - Respuestas en streaming donde el proveedor lo permita.
  - Chips de contexto visibles antes de enviar (ventana, portapapeles, captura); se pueden quitar con un clic.
  - Lista de conversaciones con búsqueda.
  - Botón para repetir con otro modelo.
- **Acciones propuestas:** tarjeta con lo que va a hacer, permisos usados y botones Aplicar / Deshacer, igual en el panel y en Spotlight.
- **Spotlight `?`:** usa el modelo de respuestas rápidas; con Intro abre la conversación en el panel.
- **Estilo Math:** el panel usa los componentes de `Ui/` y los tokens de movimiento de *Animaciones y efectos*.

---

## 5. Principios
- **Opcional:** nada del shell depende de que haya IA configurada.
- **Local cuando se quiera:** el modo local garantiza que nada sale del equipo.
- **Confirmación y deshacer:** todo cambio es visible, confirmable y, si se puede, reversible.
- **Mínimo contexto:** se envía solo lo necesario, y el usuario ve qué se envía.
- **Claves seguras:** nunca en texto plano en la configuración ni en argumentos de comandos.

---

## 6. Archivos

| Nuevo | Se modifica |
|---|---|
| `modules/settings/sections/ia/` (una página por subsección) | `modules/settings/SettingsApp.qml` (categoría, alias `ia`/`panel`/`dictado`) |
| `modules/settings/ui/AiStatus.qml` | `modules/settings/sections/{IA,Panel,Dictado}.qml` (se dividen o se mueven) |
| `~/.local/share/hyprfrijol/ai-recetas.json` | `scripts/hf-ai` (modelo por tarea, respaldo, modo local, filtro de secretos, apps excluidas, registro de acciones, recetas, uso) |
| `~/.local/state/hyprfrijol/ai-acciones.json` | `scripts/hf-mcp` (herramientas de recetas; cliente MCP en la fase final) |
| `~/.local/state/hyprfrijol/ai-uso.json` | `modules/sidepanel/AiChat.qml` (chips de contexto, lista de conversaciones, streaming) |
| | `modules/spotlight/` (recetas) |
| | `modules/settings/sections/Privacidad.qml` (enlaces) |
| | `scripts/hf-migrate`, `modules/settings/search-index.json` |

**Claves nuevas en `settings.json`:** `aiModelChat`, `aiModelQuick`, `aiModelVision`, `aiFallbackProvider`, `aiFallbackModel`, `aiLocalOnly`, `aiRedactSecrets`, `aiExcludeApps`, `aiHistoryDays`, `aiActionLog`, `aiLevel`, `aiTone`, `aiAbout`, `aiMcpServers`.

---

## 7. Fases

| Fase | Contenido |
|---|---|
| **1. Reorganización** | Sección con subsecciones, fusión de IA + Panel + Dictado, alias, búsqueda; página de Inicio |
| **2. Privacidad** | Filtro de secretos, apps excluidas, historial con búsqueda, registro de acciones |
| **3. Modelos** | Modelo por tarea, respaldo, modo local |
| **4. Acciones rápidas** | Recetas incluidas y propias, en Spotlight y en el panel |
| **5. Conexión con otros apartados** | Crear tema desde imagen, crear tarea, crear evento |
| **6. Panel** | Chips de contexto, streaming, lista de conversaciones, repetir con otro modelo |
| **7. MCP externo** | El asistente usa servidores MCP del usuario, con aprobación por servidor |

---

## 8. Decisiones tomadas

- El Asistente de IA es categoría propia en la barra lateral de Ajustes.
- Proveedor por defecto para usuarios nuevos: el actual (Claude Code).
- Las voces mantienen sus nombres (Helpert y Sophia).
- El filtro de secretos viene activado.
- Sin menú contextual sobre el texto seleccionado: Spotlight y atajos.
- «Lo que sabe de ti» se guarda en un archivo aparte que el usuario puede leer y editar.
- El cliente MCP externo queda para después de esta versión. Se hizo en la 0.9.17 (pestaña Integraciones): cada
  servidor se aprueba con un interruptor tras ver sus herramientas; las claves, en variables de entorno.
- Fuera de esta versión también: el contador de uso y tokens (cada proveedor lo informa distinto).
