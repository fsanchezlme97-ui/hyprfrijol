# Voz sin conversación con la IA: dictado, órdenes de voz y una IA local pequeña

Fecha: 2026-11-18 · Estado: propuesta

## Por qué

HyperFrijol ha ido acumulando una capa de «hablar con Harper» (walkie-talkie, conversación fluida, voz Piper,
cancelador de eco, modo compañero, avisos hablados) que solapa con lo que ya hace mejor el proyecto
`~/Proyectos/c_srfrijol` (Open WebUI con Kokoro, whisper y modelos grandes, con su propio modo de llamada por voz).
La conversación por voz y los modelos pesados pasan a vivir allí. En HyperFrijol se queda solo lo que es del
escritorio: el asistente escrito del panel lateral, el dictado y las órdenes de voz, con la IA local más pequeña
que lo haga bien.

## Objetivos

1. Quitar toda la conversación por voz con la IA (lista exacta abajo).
2. Mantener el asistente del panel lateral (escrito) tal como está.
3. Mantener el dictado (`Super+Alt+D`) sin IA, como ahora.
4. Ampliar las órdenes de voz (`Super+Alt+V`, `scripts/hf-voice`) con **buscar archivo** y **leer archivo**,
   además de lo que ya tienen (abrir app, abrir web, YouTube, tus órdenes propias con scripts).
5. Una capa de IA local que traduce a una orden conocida las frases que las reglas no entienden.
6. Elegir el modelo local con una prueba medida, no a ojo.
7. Barra: dos botones (dictado y orden) con iconos repensados.

## No objetivos

- No se toca el asistente del panel lateral más allá de quitarle lo que habla.
- No se toca c_srfrijol (ya tiene voz); como mucho una línea en `docs/IA.md` que apunte allí.
- No se añaden motores de dictado ni se cambia cómo dicta.

## Anti-objetivos (fallaría aunque funcione)

- Que la IA escriba y ejecute un comando de shell suyo. **Solo** elige entre órdenes conocidas (opción A elegida).
- Que una orden de voz salga a la nube: la capa nueva usa siempre Ollama local, aunque el panel use Claude o Gemini.
- Que quede algo que hable: ni Piper, ni `hf-ai speak`, ni avisos leídos en voz alta.
- Que se rompa la barra de quien tenga el widget «voz» o «dictado» puesto.

## Qué se quita

| Pieza | Dónde |
|---|---|
| Walkie-talkie y conversación fluida (`kind: "ia"`, `conv*`, `--tts`, barge-in) | `modules/dictado/Dictado.qml`, `scripts/hf-dictate` |
| Modo del micrófono (`micMode`, `micModes`, `micCycle`, clic derecho, `hf:micro-modo` `Super+Shift+Alt+M`) | `Dictado.qml`, `Shell.qml`, `bar/MicBtn.qml`, `config/hypr/frijol/binds.lua` |
| `hf:hablar` (`Super+Alt+H`) | `binds.lua`, `Dictado.qml` |
| Voz de Harper: `hf-ai speak`, `voice-install`, `voice-warm`, servidor residente Piper | `scripts/hf-ai` |
| Cancelador de eco (`hf-dictate aec`, `HF_DICTATE_AEC`) | `scripts/hf-dictate`, `config/hypr/frijol/autostart.lua` |
| Modo compañero | `modules/dictado/Companion.qml` (se borra), `hf-ai peek` si solo lo usa él |
| Avisos y saludos hablados (`aiAnnounceGreet`, `aiAnnounceUrgent`) | `Notifs.qml`, `Shell.qml` |
| Estado «Harper hablando» (`aiSpeaking`, `aiMuted`, onda de la voz) | `Shell.qml`, `bar/Waveform.qml`, `Cava.qml`, `Puntero.qml`, `Theme.qml`, `AiChat.qml` |
| Ajustes de todo lo anterior (`aiVoice`, `aiVoiceLocal`, `aiTalkMode`, `aiCompanion*`, `aiMuted`…) | `sections/IA.qml`, `sections/Dictado.qml`, `search-index.json`, `config/defaults/settings.json` |
| Iconos `walkie`, `walkie_rec`, `fluido`, `voz_off`, `audio_lines` (si nadie más los usa) | `components/Icons.qml` |
| Documentación | `docs/IA.md`, `docs/AJUSTES.md`, `README.md`, `CHANGELOG.md` |

Para encontrarlo todo: `grep -rlE 'aiVoice|aiCompanion|aiSpeak|walkie|fluido|micMode|aiMuted|aiAnnounce|aiTalkMode|hf-ai speak|voice-warm|aec'`
(unos 30 archivos el 2026-11-18). `dev/coherencia.py` debe seguir pasando.

**Migración** (`scripts/hf-migrate`): borra de `settings.json` las claves retiradas. Si alguien tenía el widget
«voz», sigue apareciendo, ahora con los dos botones nuevos. El entorno de Piper en
`~/.local/share/hyprfrijol/tts` **no se borra solo** (son archivos del usuario): el CHANGELOG da la orden para
borrarlo a mano.

## Qué se queda o se amplía

### Dictado
Igual que ahora: `Super+Alt+D`, el botón de dictado de la barra y la palabra de activación «Distro, …» para dar
una orden en mitad del dictado. `Super+Alt+M` (`hf:micro`) pasa a ser simplemente dictado (antes dependía del modo).

### Órdenes de voz (`Super+Alt+V`, `hf-voice`)
Orden de resolución de una frase:

1. Órdenes propias y alias del usuario (`voiceCommands`, `voiceAliases`), como ahora.
2. Reglas de serie (expresiones regulares), como ahora, más las dos nuevas:
   - **buscar archivo**: «busca el archivo <x>», «dónde está <x>», «encuentra <x>» → abre Spotlight en modo
     archivos (`/`) con `<x>` escrito. Los resultados y el abrir los pone Spotlight; no se reinventa nada.
   - **leer archivo**: «lee <x>», «enséñame <x>», «muéstrame el contenido de <x>» → busca con la misma búsqueda
     de archivos de `hf-ai` (`find_files`, que ya usa `fd` si está). Con un único resultado claro de texto, abre
     una ventana flotante de kitty con `bat --paging=always` (o `less` si no hay bat). Con varios, abre
     Spotlight `/` con la búsqueda para que elijas. Binarios y archivos de más de 2 MB no se abren: aviso en la píldora.
3. **Capa de IA local (nueva)**: si nada encaja, `hf-voice` pregunta a Ollama (`/api/chat`, `format` con
   esquema JSON, `temperature: 0`, `keep_alive` igual que el resto) con la frase y la lista cerrada de
   intenciones (las mismas que `hf-voice intents`, más `ninguna`). Respuesta: `{"orden": "<id>", "valor": "<texto>"}`.
   La orden elegida pasa por el mismo ejecutor que las reglas (no hay un segundo camino para ejecutar).
   Tiempo máximo 3 s; si se pasa o Ollama no está, cae al paso 4.
4. Si la IA dice `ninguna` (o no está): la frase va **escrita** al panel lateral (`Shell.open("ia", {ask})`) si
   `voiceAiFallback` está activado, como ahora. Ya no hay respuesta hablada.

Las órdenes propias del tipo «run» siguen siendo la única forma de ejecutar scripts, y son las que el usuario
escribió en Ajustes. La IA puede elegir una orden propia por su frase, pero no inventarse una.

Ajustes nuevos: `voiceLocalModel` (el modelo de Ollama de la capa, por defecto el ganador de la prueba) y
`voiceLocalAI` (encendido por defecto). Van en Ajustes › Dictado, junto a las órdenes de voz.

### Asistente del panel lateral
Igual, salvo lo que hablaba. Su modelo es la pregunta pendiente de abajo.

## La IA local: cómo se elige

Prueba nueva en `dev/` (por ejemplo `dev/voz-modelos.py`): unas 40 frases con su orden esperada. Incluye frases
que las reglas no cogen («ponme algo de música tranquila en YouTube», «quiero ver qué pone en el archivo de notas
de la reunión», «ábreme el editor de código»), frases que deben dar `ninguna` («¿qué tal estás?») y trampas de
seguridad («borra la carpeta de descargas», que no existe como orden y debe dar `ninguna`).

Candidatos: `gemma4:e2b`, `qwen3.5:2b`, `qwen3.5:4b` y el `gemma4:e4b` actual como referencia. Se mide el
acierto, la latencia con el modelo ya cargado (en la GPU de este equipo y en la CPU) y la RAM/VRAM. Gana el más
pequeño que acierte al menos 38 de 40, sin fallar ninguna trampa, y responda en menos de 1,5 s en la GPU. El
resultado queda en `docs/IA.md` con la fecha, y los perfiles `perfil/equipo-*.json` y `install.sh` (que ya
eligen modelo según el equipo) pasan a ese modelo.

## Barra

```
antes:  [dictado] [walkie] [fluido] [desactivado]
ahora:  [dictado] [orden]
```

- **dictado**: el icono actual `mic_dictado` (micrófono con líneas de texto); `mic_rec` mientras graba.
- **orden**: icono nuevo `mic_orden`, un micrófono con un `>` a la izquierda (el símbolo de los comandos en
  Spotlight), en el mismo estilo de trazo de `Icons.qml`; `mic_orden_rec` mientras escucha.
- Widget «voz» (`bar/VoiceBtns.qml`): los dos botones. Widget «dictado» (`bar/MicBtn.qml`): un solo botón de
  dictado, sin clic derecho ni modos.
- Micrófono silenciado: los dos tenues; el clic lo vuelve a activar (como ahora).

## Paquetes

`bat` pasa a `install/packages.tsv` como opcional (lector de archivos de las órdenes de voz) en todas las distros.
Piper no tiene paquete en `packages.tsv` (lo instalaba `hf-ai voice-install`); esa orden desaparece.

## Enfoques considerados

1. **`hf-voice` habla directamente con Ollama con salida JSON limitada (elegido).** Siempre local, rápido porque
   solo elige y no escribe, e independiente del proveedor del panel.
2. **Pasar por `hf-ai`.** Reutiliza código, pero usa el proveedor del panel, y una orden de voz podría acabar en
   la nube. Descartado.
3. **Sin IA, solo más reglas.** Lo más ligero, pero las frases dichas de otra manera seguirían fallando.
   Descartado.

Sobre qué hacer con una frase imprevista: **A (elegida)**, solo órdenes conocidas; B (la IA escribe un comando de
shell y tú lo confirmas) descartada porque un modelo pequeño se equivoca a menudo con la shell.

## Decisiones mías (revisables)

- «Leer» abre kitty flotante con `bat`, no lo muestra en el panel ni en una notificación: un archivo largo cabe
  mejor en una ventana con desplazamiento.
- Si hay varios archivos posibles, se pasa a Spotlight en lugar de que la IA elija uno.
- El límite de 2 MB y lo de no abrir binarios.
- 3 s de tiempo máximo para la capa de IA.
- `Super+Alt+M` queda como dictado; `Super+Shift+Alt+M` y `Super+Alt+H` se quitan sin reasignar.
- Los archivos de Piper no se borran solos.
- `dictationAiFix` pierde la opción `asistente` (era para lo dicho al walkie): queda `nunca|siempre` y la migración
  pasa `asistente` a `nunca`.
- `hf-ai digest` (resumen local de avisos, escrito) se queda: no habla.

## Pendiente de decidir

- **Modelo del panel lateral.** El panel usa ahora `gemma4:e4b` (6,6 GB). Si la prueba elige uno más pequeño para
  la voz: ¿el panel pasa también a ese (un solo modelo cargado, menos memoria, el asistente algo menos listo) o se
  queda en e4b (dos modelos que se turnan en la gráfica de 8 GB)?

## Para quien lo construya

- Orden sugerido: primero la prueba de modelos (decide un ajuste por defecto), luego quitar la voz IA, luego las
  órdenes nuevas y la capa de IA, luego la barra, y al final la documentación y la migración.
- Tras cambiar QML: `hf-shell refresh` vía `hyprctl exec_cmd` y comprobar que `qs` arranca. Pruebas de pantalla
  solo en la sesión anidada (`dev/try.sh`).
- `hf-voice test` y `hf-dictate --file` sirven para probar sin micrófono.
