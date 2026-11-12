# IA en hyprfrijol

El asistente vive en el **panel lateral** (`SUPER + A`, vista `ia`), solo con el asistente (desde la 0.8.8 las apps web
ya no van en el panel: se abren en su ventana o en el navegador, ver «Apps web» abajo). Todo lo que la IA hace en el escritorio pasa por un
esquema fijo de acciones que **tú apruebas** antes de aplicarlas, y que se pueden deshacer.

**Fijar** (chincheta de la cabecera · Ajustes › Panel lateral y PiP › «Fijar el panel», `sidePanelPinned`): el panel
deja de flotar encima y pasa a ser parte del mosaico. Una capa invisible (`hf-ia-zone`, layer-shell Overlay) reserva su
franja como zona exclusiva, igual que la barra, y Hyprland recoloca las ventanas en mosaico a su lado (a `gaps_out`,
sin hueco doble; si la barra está en el mismo lado se descuenta lo que ya reserva). Va en la pantalla principal, sigue
abierto en todos los espacios y al abrir otras vistas, no se cierra con Esc (Esc devuelve el teclado a la última
ventana) y las apps web acopladas vuelven a su sitio si se arrastran. Se aparta con una ventana a pantalla completa
(la maximizada respeta la franja), en el modo sin distracciones y durante la captura de la IA. `SUPER + A` y la ×
lo esconden en esta sesión (se libera la franja; sigue fijado) y `SUPER + A` lo vuelve a mostrar; para desfijarlo,
la chincheta o el ajuste. El estado se guarda en settings.json: tras reiniciar el shell vuelve fijado.

## Piezas

| Pieza | Qué hace |
|---|---|
| `config/quickshell/modules/sidepanel/SidePanel.qml` | Panel de 400 px a la derecha: pestañas, apps web acopladas, PiP de YouTube |
| `config/quickshell/modules/sidepanel/AiChat.qml` | Conversación, contexto, tarjetas Aplicar / Descartar / Deshacer, «Continuar en Claude ↗» |
| `config/quickshell/modules/pip/Pip.qml` | Coloca y controla las ventanas de imagen en imagen |
| `scripts/hf-ai` | Habla con el modelo, valida acciones, las aplica y las deshace |
| `scripts/hf-mcp` | Servidor MCP: la misma API del shell para Claude Code u otros clientes |

## Proveedor del modelo

En `~/.config/hyprfrijol/settings.json` (o Ajustes › IA):

| Clave | Valores | Por defecto |
|---|---|---|
| `aiProvider` | `claude-code` · `gemini` · `ollama` · `openai-compatible` · `off` | `claude-code` |
| `aiModel` | p. ej. `haiku`, `sonnet` · `gemini-2.5-flash` · `gemma4:e4b` · `gpt-4o-mini` | (el del proveedor) |
| `aiEndpoint` | `http://localhost:11434` · `https://…/v1` | (el del proveedor) |
| `aiKeyEnv` | variable de entorno con la clave (openai-compatible) | `HF_AI_KEY` |
| `aiContextWindow` | enviar el título de la ventana activa | `true` |
| `aiContextClipboard` | enviar el portapapeles (máx. 4000 caracteres) | `true` |

- **claude-code** usa tu sesión de Claude Code: `claude -p --output-format json`, sin herramientas, sin MCP
  y sin guardar sesión (`--tools "" --strict-mcp-config --no-session-persistence`).
- Si el proveedor no responde, la conversación muestra el error con **Reintentar** y **Ajustes de IA**.
- Al cambiar de proveedor en Ajustes, `aiModel` vuelve a `""` (el predeterminado de ese proveedor).

### Google Gemini (clave gratuita)

1. Consigue una clave en <https://aistudio.google.com/apikey> (cuenta de Google, plan gratuito con cuota diaria).
2. Ajustes › Asistente de IA › **Gemini** → pega la clave (campo oculto) → **Guardar** → **Probar conexión**.
3. Elige el modelo: la lista sale de `GET /v1beta/models` (solo los que admiten `generateContent`; sin clave se
   ofrecen `gemini-2.5-flash`, `gemini-2.5-flash-lite` y `gemini-2.5-pro`). Por defecto `gemini-2.5-flash`;
   si `aiModel` no es un modelo de Gemini (`gemini*`, `gemma*`) se usa el predeterminado.

Petición: `POST https://generativelanguage.googleapis.com/v1beta/models/<modelo>:generateContent` con la
cabecera `x-goog-api-key`, `system_instruction` (el mismo prompt y esquema de acciones `hf-actions` que el resto
de proveedores, más el contexto del escritorio) y `contents` con los papeles `user`/`model`. Si adjuntas una
imagen (o usas «+ Captura») y «Ver capturas que adjuntes» está activado, va como `inline_data` en base64 en
lugar de pasar por OCR. Como el resto de proveedores, la respuesta llega entera (sin streaming).

**La clave nunca se guarda en settings.json.** Se busca en este orden:

1. variables de entorno `GEMINI_API_KEY` o `GOOGLE_API_KEY`;
2. el llavero del sistema (libsecret, `secret-tool` con `service=hyprfrijol provider=gemini`);
3. `~/.config/hyprfrijol/secrets/gemini.key` (carpeta 700, archivo 600) si no hay llavero.

Errores en español: falta la clave, clave no válida, modelo inexistente, límite del plan gratuito (429),
servidores caídos y sin conexión.

```sh
scripts/hf-ai key status gemini                    # {"stored": true, "where": "llavero|archivo|env:…", "hint": "AIza…1234"}
printf %s "$CLAVE" | scripts/hf-ai key set gemini  # o HF_AI_KEY_IN=… (nunca como argumento)
scripts/hf-ai key clear gemini
scripts/hf-ai models gemini                        # {"models": [[id, nombre]…], "error": null}
scripts/hf-ai test                                 # {"ok": true, "text": "Conectado · gemini-2.5-flash respondió «listo»"}
scripts/hf-ai chat --print-request '{"messages":[{"role":"user","text":"Pon la barra arriba"}]}'
                                                   # imprime la petición sin enviarla (la clave sale oculta)
```

`HF_AI_NO_KEYRING=1` fuerza el archivo en lugar del llavero y `HF_GEMINI_API=<url>` cambia el servidor (pruebas).

Probar desde la terminal:

```sh
scripts/hf-ai status
scripts/hf-ai ask "¿qué hace hyprctl reload?"
scripts/hf-ai chat '{"messages":[{"role":"user","text":"Pon la barra arriba"}],"context":{"window":false,"clipboard":false}}'
```

### IA local con Ollama (respaldo y voz)

Ollama con `ollama-vulkan` usa la gráfica (AMD, Intel o NVIDIA). Con respaldo Ollama (`aiFallbackProvider`), si la
nube falla o tarda contesta el modelo local; en la voz la espera a Gemini es de 10 s. Con **Voz con el modelo local
primero** (`aiVoiceLocal`) es al revés: la voz pregunta a Ollama y la nube queda de respaldo.

Pruebas del 2026-11-12 en una RX 6600 XT (8 GB) con 18 órdenes de voz reales (el prompt de verdad de `hf-ai`,
temperatura 0). La mediana es el tiempo hasta tener el plan, con el modelo ya cargado; la primera carga son 4-6 s.

| Modelo | Órdenes bien | Mediana | Tokens/s | Imágenes |
|---|---|---|---|---|
| **gemma4:e4b** (recomendado) | 18/18 | 0,44-0,67 s | 78 | sí (1,4 s) |
| qwen3:4b-instruct-2507 | 16/18 | 0,7 s | 75 | no |
| qwen3.5:4b | 16/18 | 1,7 s | 61 | sí (0,8 s) |
| qwen2.5:7b | 14/18 | 0,9 s | 48 | no |
| gemma3:4b | 10/18 | 0,8 s | 71 | sí (0,9 s) |
| granite4.1:8b | 12/12 | 3,2 s | 19 | no (no cabe en 8 GB) |
| Gemini Flash-Lite (nube) | 11/18 (7 fallos 503) | 10-12 s | — | sí |

LM Studio (llama.cpp Vulkan) va igual de rápido que Ollama (47 frente a 48 tokens/s con el mismo archivo) pero
ocupa 1,2 GB de RAM frente a 0,2 GB y no está en los repositorios; el llama.cpp de Arch va a la mitad (23 tokens/s).
Con modelos que piensan (qwen3.5…) `hf-ai` manda `"think": false`: pensar tardaba más de 30 s.

## Contexto

Los chips de la cabecera eligen qué se envía con cada pregunta:
**Documento activo** (clase y título de la ventana con foco), **Portapapeles** y **+ Captura**
(el panel se aparta, se hace una captura con `grim` y se pasa por OCR con `tesseract spa+eng`; opcional).
Además siempre va un resumen del estado del shell (estilo, color, barra).

## Acciones del shell

El modelo termina su respuesta con un bloque ` ```hf-actions [ … ] ``` `. `hf-ai` lo valida
contra este esquema (todo lo demás se descarta) y genera las etiquetas en español de la tarjeta:

| Acción | Ejemplo | Etiqueta |
|---|---|---|
| `set` | `{"type":"set","key":"estilo","value":"flat"}` | Estilo: Flat |
| `wallpaper` | `{"type":"wallpaper","value":"next"}` (`prev`, `random`, ruta) | Siguiente fondo |
| `workspace` | `{"type":"workspace","value":5}` | Ir al espacio 5 |
| `dnd` | `{"type":"dnd","value":true}` | Activar No molestar |
| `pomodoro` | `{"type":"pomodoro","value":"start","minutes":25}` | Iniciar pomodoro de 25 min |
| `focus` | `{"type":"focus","value":true}` | Entrar en modo sin distracciones |
| `open` | `{"type":"open","value":"fondos"}` | Abrir selector de fondos |
| `run` | `{"type":"run","command":"journalctl -b -p 3"}` | bloque de código: **Ejecutar (pide confirmación)** / Copiar |
| `device` | `{"type":"device","op":"eject","dev":"/dev/sdb1"}` (`mount`, `unmount`, `open`, `eject-all`) | Expulsar «KINGSTON» |
| `download` | `{"type":"download","urls":["https://…"],"kind":"audio","format":"mp3"}` | Descargar el audio (mp3) de youtube.com/… |
| `download_ctl` | `{"type":"download_ctl","op":"pause","id":"all"}` (`resume`, `cancel`, `retry`) | Pausar todas las descargas |
| `wallhaven` | `{"type":"wallhaven","op":"add","id":"abc123"}` (`set`) | Añadir el fondo abc123 de Wallhaven a mis fondos |
| `youtube` | `{"type":"youtube","query":"Walk Foo Fighters","service":"youtube"}` (`music`, `spotify`) | Reproducir «Walk Foo Fighters» en YouTube |
| `browser` | `{"type":"browser","op":"new-tab"}` (`close-tab`, `back`, `reload`, `scroll-down`, `find`/`search`/`open` con `value`…) | Nueva pestaña |

Claves de `set`: `estilo`, `colorMode`, `palette`, `themeMode`, `barPos`, `barMode`, `animado`,
`reduceTransparency`, `reduceMotion`, `gapsIn`, `gapsOut`, `pipSize`, `pipCorner`, `deskSort`.

- **Aplicar** → `hf-ai apply` (`hf-apply set`, `hf-wallpaper`, `hyprctl dispatch`, `qs ipc`).
  Antes guarda el estado en `~/.cache/hyprfrijol/undo/<id>.json` (se guardan los 30 últimos).
- **Deshacer** → `hf-ai undo <id>`: restaura los ajustes tocados, el fondo, «no molestar» y el espacio.
- Los comandos `run` nunca se ejecutan solos: hay que confirmar y se abren en la terminal (`kitty`).

### Voz: solo las órdenes que no se entienden

El **dictado nunca usa IA** (la antigua limpieza `dictationAI` se retiró; `hf-migrate --retired-only` quita la clave con
copia en `settings.json.antes-sin-ia-dictado`). Las órdenes de voz («Distro, …» al dictar, o Super+Alt+V) las entiende
`scripts/hf-voice` sin IA: primero las órdenes propias (`voiceCommands`) y los sinónimos (`voiceAliases`), luego las
de serie. Solo lo que no entiende va al panel (`qs ipc call sidepanel ask`), si `voiceAiFallback` está activo, y lo que
cambie algo pasa por la aprobación de siempre. `voiceCommands`, `voiceAliases` y `voiceAiFallback` están en `DENY_KEYS`:
el asistente no puede crearse órdenes que ejecuten comandos.

### Aprobación

- La tarjeta del plan enseña **qué cambia** en cada paso (`plan[i].preview`: «abajo → arriba», la ventana, la carpeta…).
- Con varios pasos, cada uno tiene su **casilla**: se aplican solo los marcados («Aplicar 2 de 3»). «Rechazar todo» no toca nada.
- **«Aprobar siempre esta acción»** guarda la clave del paso (`plan[i].kind`: `set:barPos`, `download`, `device:mount`…) en
  `aiAlwaysApprove`. Si todos los pasos de un plan están ahí, `hf-ai` devuelve `auto: true` y el panel lo aplica solo (con
  Deshacer). Lo que no tiene vuelta atrás (cerrar ventanas, borrar avisos, expulsar, cancelar descargas, comandos) pregunta
  siempre. Se revoca en Ajustes › IA › «Aprobadas siempre» (`hf-ai approvals` da los nombres).
- La primera vez, el panel enseña qué puede hacer el asistente y 6 ejemplos (`aiOnboarded`; «Volver a verla» en Ajustes › IA).
- Consultas de solo lectura nuevas: `devices` (unidades y espacio), `downloads` (la cola) y `wallhaven` (buscar fondos).

## «Continuar en Claude ↗»

`hf-ai handoff` copia la conversación y el contexto elegido al portapapeles (Markdown) y:

1. abre **Claude Desktop** si está instalado (`claude-desktop`) → pega con `Ctrl+V`;
2. si no, abre `kitty -e claude "<conversación>"` (Claude Code con la conversación como primer mensaje);
3. si no hay ninguno, solo la copia.

El panel muestra el aviso «Abierta en Claude Desktop / Se envió la conversación y el contexto que elegiste».

## PiP de los navegadores

`Pip.qml` reconoce las ventanas «Picture-in-Picture» / «Imagen en imagen» de Firefox y Chromium, las
coloca con `pipSize` (`minimo` 192×108, `pequeno` 256×144, `mediano` 320×180) y `pipCorner`
(`sup-der`, `sup-izq`, `inf-der`, `inf-izq`), se aparta si el panel lateral está abierto y les pone encima
cerrar, pausa (MPRIS) y volver. `pip: false` lo desactiva.

## IPC

```sh
qs -p "$HF_ROOT/config/quickshell" ipc call shell openWith ia wa      # pestaña
qs -p "$HF_ROOT/config/quickshell" ipc call sidepanel ask "Resume el portapapeles"
qs -p "$HF_ROOT/config/quickshell" ipc call sidepanel askImage "¿Qué pone aquí?" /ruta/captura.png
```

`Shell.open("ia", { ask: "…" })` (o el texto `{"ask":"…"}` por IPC) abre la pestaña IA y pregunta directamente.

## Servidor MCP (`scripts/hf-mcp`)

Para que Claude Code (u otro cliente MCP) maneje el escritorio con la misma API validada:

```sh
claude mcp add hyprfrijol -- /ruta/a/hyprfrijol/scripts/hf-mcp
```

Herramientas: `get_state`, `set_settings`, `apply_actions`, `undo`, `wallpaper`, `profile`, `open_view`,
`workspace`, `notify`, las del asistente (`hf-ai tools`) y, para dispositivos, descargas y Wallhaven: `list_devices`,
`device_action`, `list_downloads`, `download`, `download_control`, `wallhaven_search`, `wallhaven_wallpaper`.
Cada una lleva **anotaciones MCP** con su nivel de aprobación: `readOnlyHint: true` en las consultas (el cliente puede
dejarlas pasar sin preguntar) y `false` en las que cambian algo (el cliente pide permiso); `destructiveHint: true` en
las que no se pueden deshacer (`window_action`, `clear_notifications`, `device_action`, `download_control`). Stdio JSON-RPC 2.0, solo biblioteca estándar de Python. Las acciones `run` no se
ejecutan por MCP (el cliente tiene su propia terminal). Cada cambio devuelve un `undo` id.

Prueba rápida:

```sh
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
              '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | scripts/hf-mcp
```
