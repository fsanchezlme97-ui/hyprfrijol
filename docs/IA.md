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
| `config/quickshell/modules/sidepanel/AiChat.qml` | Conversación, contexto, tarjetas Aplicar / Descartar / Deshacer, «Seguir en … ↗» |
| `config/quickshell/modules/pip/Pip.qml` | Coloca y controla las ventanas de imagen en imagen |
| `scripts/hf-ai` | Habla con el modelo, valida acciones, las aplica y las deshace |
| `scripts/hf-mcp` | Servidor MCP: la misma API del shell para Claude Code u otros clientes |
| `scripts/hf-screen` | Usar la pantalla: análisis con OCR y elementos numerados, cursor fantasma, clic, teclas y rueda |
| `config/quickshell/modules/puntero/Puntero.qml` | Superposición del cursor fantasma, el resaltado y las marcas numeradas |

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

### IA local con Ollama (respaldo y órdenes de voz)

Ollama con `ollama-vulkan` usa la gráfica (AMD, Intel o NVIDIA). Con respaldo Ollama (`aiFallbackProvider`), si la
nube falla o tarda contesta el modelo local. **Saltar al respaldo** (`aiFallbackWait`, 8 s de serie) se multiplica
por tres al principal (las CLI, Claude Code y las demás, tienen el doble en total); con el principal mirando la
pantalla (la consulta `ui`), el doble. Las órdenes de voz que las reglas no entienden usan ese mismo modelo local
(`voiceLocalModel` vacío: el de Ollama del panel o del respaldo; si no, gemma4:e4b), así solo hay uno cargado.

### IA que ya tienes instalada

`hf-ai clis` busca en el `PATH` las IA de terminal (Ajustes › Asistente de IA › Proveedor y permisos › **IA ya
instalada en este equipo**): `claude` (proveedor `claude-code`, con `--tools ""`), `ollama` (proveedor `ollama`) y
`llm` (proveedor `cli`, `aiCli` = `llm`). Cada una se elige de principal o de respaldo con un clic. `llm` recibe la
conversación por la entrada estándar (nunca en los argumentos, que se ven en `/proc`) en una carpeta temporal vacía.
Solo entran IA que no pueden leer archivos, ejecutar órdenes ni salir a la web por su cuenta, porque el contexto puede
traer texto de fuera (portapapeles, OCR). Fuera, según su documentación: Codex CLI (en solo lectura lee archivos y
busca en la web de serie), Gemini CLI (lee archivos sin preguntar y no tiene cómo apagar todas sus herramientas), Qwen
Code (su modo por defecto sin interacción no está claro) y opencode y Cursor Agent (ejecutan órdenes y editan).

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

**Sin gráfica dedicada** (portátiles de oficina): el 2026-11-17, en la CPU con 4 hilos, 8 órdenes reales con el prompt de
`hf-ai`. La primera orden carga el modelo y lee las ~2.400 instrucciones; las siguientes las tiene en caché.

| Modelo (solo CPU) | Órdenes bien | Primera | Siguientes | RAM |
|---|---|---|---|---|
| **gemma4:e4b** (16 GB de RAM o más) | 7/8 | ~1 min | 2–4,5 s | 6,8 GB |
| **gemma4:e2b** (menos de 16 GB) | 6/8 | 17 s | 1,6–2,4 s | 4,7 GB |
| qwen3:4b-instruct | 6/8 | 94 s | 5–17 s | 5,1 GB |

La orden que falla a los tres («Cambia el estilo a flat») también la falla gemma4:e4b en la gráfica: es del modelo, no
de la CPU. `./install.sh --equipo=cpu` deja Parakeet de dictado (0,7 s por orden corta con 4 núcleos) y el modelo según la
RAM (`perfil/equipo-cpu.json` o `perfil/equipo-cpu-poca-ram.json`); `--equipo=gpu`, gemma4:e4b en la gráfica y el
dictado híbrido con whisper turbo (`perfil/equipo-gpu.json`).

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
| `file` | `{"type":"file","op":"reveal","path":"/home/…/informe.pdf"}` (`open`) | Abrir la carpeta de informe.pdf |

Claves de `set`: `estilo`, `colorMode`, `palette`, `themeMode`, `barPos`, `barMode`, `animado`,
`reduceTransparency`, `reduceMotion`, `gapsIn`, `gapsOut`, `pipSize`, `pipCorner`, `deskSort`.

- **Aplicar** → `hf-ai apply` (`hf-apply set`, `hf-wallpaper`, `hyprctl dispatch`, `qs ipc`).
  Antes guarda el estado en `~/.cache/hyprfrijol/undo/<id>.json` (se guardan los 30 últimos).
- **Deshacer** → `hf-ai undo <id>`: restaura los ajustes tocados, el fondo, «no molestar» y el espacio.
- Los comandos `run` nunca se ejecutan solos: hay que confirmar y se abren en la terminal (`kitty`).

### Voz: órdenes, sin conversación

No se conversa por voz con Harper (desde 0.11.0): la conversación por voz y los modelos grandes viven en otro
proyecto (Open WebUI con su modo de llamada). Aquí se quedan el dictado, las órdenes de voz y la voz de Harper como
**lectora** opcional (`aiVoice`, apagada por defecto: avisos urgentes y el saludo con lo pendiente del día).

El **dictado nunca usa IA** (la antigua limpieza `dictationAI` se retiró; `hf-migrate --retired-only` quita la clave con
copia en `settings.json.antes-sin-ia-dictado`). Las órdenes de voz («Distro, …» al dictar, o Super+Alt+V) las entiende
`scripts/hf-voice`: primero las órdenes propias (`voiceCommands`) y los sinónimos (`voiceAliases`), luego las de serie
(con **buscar archivo**, que abre Spotlight en `/`, y **leer archivo**, que lo abre en kitty con `bat`). Si nada
encaja, una **IA local** (Ollama, nunca la nube) elige entre las órdenes conocidas: devuelve `{"orden", "valor"}` con
salida JSON limitada, la orden pasa otra vez por las reglas y nunca escribe un comando suyo (`voiceLocalAI`,
`voiceLocalModel`). Si tampoco, la frase va escrita al panel (`qs ipc call sidepanel ask`) si `voiceAiFallback` está
activo, y lo que cambie algo pasa por la aprobación de siempre. `voiceCommands`, `voiceAliases` y `voiceAiFallback`
están en `DENY_KEYS`: el asistente no puede crearse órdenes que ejecuten comandos.

**Qué modelo** (`dev/voz-modelos.py`, 2026-11-19, RX 6600 XT): 40 frases que las reglas no entienden, 3 de ellas
trampas destructivas («borra la carpeta de descargas») que deben dar `ninguna`. Gana el más pequeño que no sea peor
que gemma4:e4b (mismos aciertos o más, ninguna trampa) y conteste en menos de 1,5 s; si no, gemma4:e4b.

| Modelo | Aciertos | Trampas falladas | Mediana | p90 | En disco |
|---|---|---|---|---|---|
| **gemma4:e4b** (se queda) | 37/40 | 0 | 504 ms | 540 ms | 6,1 GB |
| gemma4:e2b | 35/40 | 0 | 260 ms | 281 ms | 4,3 GB |
| qwen3.5:2b | 31/40 | 2 | 500 ms | 549 ms | 2,5 GB |
| qwen3.5:4b | 38/40 | 0 | 3919 ms | 5803 ms | 3,1 GB |

qwen3.5:4b acierta una más pero tarda casi 4 s; gemma4:e2b es el doble de rápido pero falla más. Un solo modelo para
el panel y la voz: gemma4:e4b.

### Aprobación

- La tarjeta del plan enseña **qué cambia** en cada paso (`plan[i].preview`: «abajo → arriba», la ventana, la carpeta…).
- Con varios pasos, cada uno tiene su **casilla**: se aplican solo los marcados («Aplicar 2 de 3»). «Rechazar todo» no toca nada.
- **«Aprobar siempre esta acción»** guarda la clave del paso (`plan[i].kind`: `set:barPos`, `download`, `device:mount`…) en
  `aiAlwaysApprove`. Si todos los pasos de un plan están ahí, `hf-ai` devuelve `auto: true` y el panel lo aplica solo (con
  Deshacer). Lo que no tiene vuelta atrás (cerrar ventanas, borrar avisos, expulsar, cancelar descargas, comandos) pregunta
  siempre. Se revoca en Ajustes › IA › «Aprobadas siempre» (`hf-ai approvals` da los nombres).
- La primera vez, el panel enseña qué puede hacer el asistente y 6 ejemplos (`aiOnboarded`; «Volver a verla» en Ajustes › IA).
- Consultas de solo lectura nuevas: `devices` (unidades y espacio), `downloads` (la cola) y `wallhaven` (buscar fondos).

### Conversación

- **Permiso para mirar la pantalla** (Ajustes › Asistente de IA › Privacidad › «Mirar la pantalla»):
  - antes de capturar (consultas `screen`/`ui`, la ventana activa sin captura guardada), Harper pregunta «¿Puedo hacer
    una captura?» con los botones Sí / No, y espera;
  - `aiScreenAsk`: `siempre` (por defecto) pregunta antes de cada captura; `sensible` solo con una ventana sensible a
    la vista;
  - **ventanas sensibles** (`aiSensitiveWindows`: correo, banca, pagos, mensajería, inicios de sesión…, por la clase o
    el título): con una a la vista pregunta siempre y dice por qué, en los dos modos y aunque se lo pidas tú;
  - pedirlo tú («mira mi pantalla», «¿qué ves?», «+ Captura», el atajo de la ventana actual) ya es el permiso;
  - si al contestar «sí» hay una ventana sensible que la pregunta no nombraba (apareció después), no captura: vuelve a
    preguntar nombrándola;
  - la pregunta espera 5 minutos (`~/.cache/hyprfrijol/ai-screen-ask.json`); cualquier otro mensaje la descarta;
  - también vale para lo que se pide por MCP: sin permiso, la herramienta de pantalla no captura.
- **«No, gracias»** («estoy bien», «ahora no», «no hace falta»…) se entiende siempre como una negativa; un «no» o un
  «nada» a secas, solo justo después de una oferta. Harper contesta «Vale, aquí estoy si me necesitas.», sin llamar al
  modelo.
- **«Repite»** («¿qué dijiste?», «otra vez», «¿cómo?») vuelve a decir la última respuesta sin llamar al modelo.
- **Seguir el hilo:** una respuesta corta (hasta 4 palabras) a un mensaje que acababa en pregunta le llega al modelo con
  esa pregunta al lado. Así un «no» a «¿Te ha quedado claro?» se entiende como «explícamelo de otra forma». El prompt
  lleva además unas reglas de conversación: no volver a presentarse, contestar con una frase corta a las gracias y no
  cerrar siempre con una pregunta.

### Esquemas (dibujos con código)

Harper dibuja **solo si se lo pides** (un dibujo, esquema o diagrama) o si un esquema explica algo mucho mejor que el
texto. El modelo no elige colores: escribe un SVG sencillo con piezas con clase y el estilo lo pone HyprFrijol.

- **Piezas** (bloque ```` ```hf-diagram ````): `box`, `pill`, `node`, `accent` (lo importante), `arrow`, `line`,
  `dashed`, `dot`, `label`, `title`, `small`, `muted`.
- **Limpieza** (`clean_svg`, lista blanca):
  - fuera `<script>`, `<foreignObject>`, `on*`, `style`, colores propios, enlaces y `url()`;
  - sin DTD ni entidades;
  - 100 KB y 400 piezas como mucho;
  - un ```` ```svg ```` escrito a mano pasa por la misma limpieza.
- **Arreglos para gemma4:**
  - etiquetas inventadas (`<label>`, `<arrow>`, `<box>`, `<node>`, `<pill>`) se convierten en lo que querían decir;
  - atributos repetidos: vale el primero, y un `x1`/`y1` repetido sin `x2`/`y2` pasa a ser el final de la línea;
  - el SVG metido en una imagen markdown se rescata.
- **Marco y tamaño:** el marco se recalcula con lo que hay dibujado (los modelos se salen o dejan medio vacío). La
  letra, los trazos y la sombra crecen con el ancho, para que un esquema ancho se lea en el panel (~360 px).
- **Estilo** (aspecto tipo Spline): degradado suave del color de contenedor del tema, sombra difusa teñida, esquinas
  redondas, flechas con punta y borde del color principal en `accent`. Los colores van como marcadores (`__P__`…)
  que `AiRich.qml` cambia por los del tema al dibujarlo: si cambias de tema, el esquema cambia con él.
- **En el panel:** Qt SVG (sin red ni JavaScript; las animaciones se ven quietas). Debajo, «Guardar» (en
  `Imágenes/Harper`), «Copiar» y «Abrir en grande» (`hf-ai save-svg` / `open-svg`). El panel les pasa el esquema
  con marcadores y los colores aparte: hf-ai lo vuelve a limpiar con la lista blanca y solo acepta colores `#rrggbb`,
  porque el archivo puede acabar en un navegador. Las vallas se reconocen igual que en `AiRich.qml` (sin distinguir
  mayúsculas), así que todo lo que el panel dibuja como esquema ha pasado por `clean_svg`.

### Archivos

- **Buscar** (`files {"query","ext"}`): por nombre en la carpeta personal (`fd`, o `find` sin él). Con varias palabras
  («README hyprfrijol») busca las que estén todas en la ruta; si no hay, cada una en el nombre, por coincidencias. Da
  ruta, fecha y tamaño, lo más nuevo primero (30 como mucho).
- **Leer** (`read_file {"path"}`): el texto (como un adjunto: PDF, DOCX, ODT, texto; 24 000 caracteres) para resumirlo
  o contestar sobre él, con el filtro de secretos.
- **Abrir** (acción `file`): `reveal` enseña el archivo en su carpeta (Nautilus `--select`; una carpeta se abre ella
  misma) y `open` lo abre con su app. Sin deshacer (no cambia nada) y sin confirmación; se puede «aprobar siempre».
- Límites (`file_ok`): la ruta real (sin enlaces) dentro de `$HOME` o `/run/media/$USER`; fuera `.ssh`, `.gnupg`,
  `.password-store`, los llaveros y los secretos de hyprfrijol. `open` nunca ejecuta: ejecutables, `.desktop`, `.sh`,
  `.AppImage` y similares solo se enseñan en su carpeta.
- Con modelos pequeños (gemma4), si el mensaje habla de un archivo («¿dónde está…?», «búscame…», «resúmeme el…»),
  `hf-ai` le añade una nota con los dos pasos (`FILE_NUDGE`, no se ve ni se guarda en el registro); si aun así no
  busca, busca él con las palabras del mensaje; si propone abrir algo que se pidió resumir, se lo lee; y acepta las
  consultas escritas sin comillas o dentro del bloque de acciones.

## Usar la pantalla (Computer Use)

Harper puede señalar y usar lo que se ve en la pantalla, siempre con tu permiso (Ajustes › IA › «Usar la pantalla»,
`aiScreenControl`):

1. **Análisis de la pantalla** (Screen Parsing, consulta `ui`). `hf-screen parse`:
   - hace la captura con `hf-ai peek`, que se niega si hay una app privada a la vista o las capturas están desactivadas;
   - pasa la captura por tesseract en gris, al doble a escala 1, para no perder el texto claro sobre fondo oscuro;
   - agrupa las palabras en elementos (dos botones en una misma fila son dos).

   Si tu mensaje pide actuar en la pantalla («haz clic en…», «pulsa…», «escribe en…», `screen_intent`), se analiza antes
   de la primera ronda. Si no, el modelo la pide.
2. **Elementos numerados** (Set-of-Mark). El modelo con visión recibe la captura con cada elemento recuadrado y
   numerado, y la lista con «número: texto (x,y)». Responde con el número (`"mark"`). Para lo que no tiene texto (iconos)
   da `"x","y"` de 0 a 1000 sobre la captura.
   - Solo valen números de un análisis hecho en esa misma petición (`UI_SEEN`).
   - **Sin elegir a ciegas.** Si el elemento tiene gemelos (el mismo texto en otra fila: dos correos de «Juan Pérez»),
     `hf-screen resolve` mira lo que pediste (`HINT`, tu último mensaje). Si una palabra tuya está en la fila de uno solo
     («lo de la cena»), o dices «el último» o «el primero», elige ese, y la tarjeta enseña su fila entera («Juan Pérez ·
     Cena viernes»). Si no, el plan se para: los candidatos salen numerados en la pantalla y en el panel («¿Cuál?», un
     botón por cada uno). Lo decide el código, no el modelo. El pendiente se guarda 5 min en
     `~/.cache/hyprfrijol/ai-choice.json`. «el 2», «el segundo», «el de la factura» o el botón lo completan sin volver a
     preguntar al modelo; cualquier otro mensaje lo descarta. El modelo no puede marcar un paso como ya elegido
     (`picked` y `choices` se quitan de lo que escribe), y `do_apply` nunca aplica un paso que espera elección.
   - Si el modelo propone un clic sin haber mirado, se le enseña la pantalla y vuelve a proponer.
3. **Cursor fantasma y resaltado** (Ghost Cursor, Visual Overlay). En cuanto se propone el plan, una flecha morada sale
   de tu cursor hasta el sitio, con el elemento resaltado y un bocadillo («Clic: Guardar»). La dibuja
   `modules/puntero/Puntero.qml`, que no recibe clics ni teclado. `hf-screen show` enseña todas las marcas del último
   análisis.
4. **La acción** (`{"type":"pointer","op":"click"|"double"|"right"|"type"|"key"|"scroll"|"point", …}`) pide confirmación
   siempre: en el panel con la tarjeta, o en la conversación con «¿Lo hago?».
   - El nombre de cada paso sale de lo que se lee en ese sitio, nunca del modelo. Una o dos letras sueltas (la «U» que
     el OCR ve en una papelera) no son un nombre: el paso se llama «un icono sin texto».
   - En la conversación se oyen los pasos tal cual antes de «¿Lo hago?», no solo lo que el modelo dice que hará. El sí
     tiene que ser la frase entera («sí», «vale, hazlo»): «sí, pero ese no es» no aprueba.
   - Un icono sin texto o un punto sin texto no se aprueba de oído: va al panel, para ver antes dónde señala el cursor.
   - En cuanto hay que entender la pantalla, Gemini pasa a un Flash completo (`GEMINI_SCREEN`, ~3-5 s) aunque la voz
     use el Lite; si falla o está saturado, se repite con el Lite. Con `aiModelVision` puesto, manda ese.
   - Al aprobarla se cierra el panel, el cursor se coloca con `hl.dsp.cursor.move` y el clic va por el protocolo de
     puntero virtual de Wayland (`zwlr_virtual_pointer_v1`, un cliente mínimo en Python dentro de `hf-screen`), sin
     ydotool.
   - Escribir pega fuera de las terminales, como el dictado; las teclas van con wtype.
   - Por MCP no se ejecutan.

Lo que se lee en la pantalla son datos, no instrucciones. Por eso nada se hace sin tu «sí»: una web no puede pedirle a
Harper que haga clic por ti.

## «Seguir en … ↗» (cualquier herramienta de IA)

`hf-ai handoff` copia la conversación y el contexto elegido al portapapeles (Markdown, sin secretos), la deja también en
`$XDG_RUNTIME_DIR/hf-handoff.md` (solo legible por ti) y la lleva a la herramienta de `aiHandoff`
(Ajustes › Asistente de IA › Integraciones):

| Destino | Cómo se lleva |
|---|---|
| T3 Code, Claude Desktop, Cursor, Zed | se abre la app; la conversación queda en el portapapeles (`Ctrl+V`) |
| Claude Code (`claude`), Codex (`codex`), Gemini CLI (`gemini -i`), Qwen Code (`qwen -i`), opencode (`--prompt`) | en la terminal, con la conversación como primer mensaje |
| `custom` | `aiHandoffCmd`, cualquier orden: `{prompt}` = el texto, `{file}` = el .md; sin marcador, portapapeles. Nombre del botón: `aiHandoffLabel` |

`auto` (por defecto) usa la del proveedor si está instalada (Claude Code con `claude-code`, Gemini CLI con `gemini`,
Codex con `openai`) y si no, la primera instalada en el orden de la tabla; `off` quita el botón. Sin ninguna, el botón
no aparece. `hf-ai handoff-targets` lista lo instalado y el destino elegido. Con más de 120 KB se pasa el archivo en vez
del texto (un argumento no puede pasar de 128 KB).

## Registro del asistente

El botón de la terminal en la cabecera del panel (o `qs ipc call sidepanel log`) abre el registro: cada petición con
la hora, de dónde vino (panel, voz o terminal), quién respondió y con qué modelo, cuánto tardó, si contestó el
respaldo, el error si lo hubo, las consultas que hizo y lo que propuso; y cada acción aplicada (las de Deshacer).
Lo guarda `hf-ai` en `~/.local/state/hyprfrijol/ai-activity.jsonl` (modo 600, las 500 últimas); la pregunta va recortada,
sin secretos y solo si el historial (`aiHistory`) está activo. `hf-ai activity [n]` lo imprime en JSON y
`hf-ai activity clear` lo vacía; el panel tiene Actualizar, Copiar y Vaciar.

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
