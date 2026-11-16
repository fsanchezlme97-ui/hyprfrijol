# Harper: el asistente del panel, con gemma4 y más capaz

Fecha: 2026-11-16 · Estado: diseño pendiente de aprobación

## Por qué

El asistente del panel lateral debe rendir bien en local (gemma4:e4b en la RX 6600 XT) sin depender de la nube ni
de EcoFlow AI, que queda como proyecto aparte. Se le cambia el nombre a **Harper** y se le dan tres capacidades que
hoy le faltan o fallan: encontrar y abrir archivos, no equivocarse de sitio al usar la pantalla, y dibujar para
explicar.

## Objetivos

1. **Nombre e icono.** Helpert pasa a llamarse Harper. Por voz se entiende aunque whisper escriba «Jarper» o
   parecido. Icono nuevo: unas gafas redondas con cejas, `>` en una lente y `_` en la otra.
2. **Archivos.** «¿Dónde está X?» → Harper lo busca, da la ruta y, si se le pide, lo abre o abre su carpeta.
   También puede leerlo para resumirlo o contestar preguntas sobre él.
3. **Pantalla.** Cuando hay más de un sitio que encaja con lo que se pide (varios correos de la misma persona),
   Harper no elige a ciegas: los numera en pantalla y pregunta cuál, salvo que el mensaje ya lo deje claro.
4. **Imágenes con código.** Cuando se le pide un dibujo, o cuando un dibujo ayuda a explicar algo, Harper responde
   con un SVG (estático o animado) que el panel muestra en la conversación. No en cada respuesta.

## Fuera de alcance

- Unirlo con EcoFlow AI (llama-swap, Qwen 35B, FLUX, Kokoro, ComfyUI).
- Imágenes por difusión, p5.js, Three.js, Zdog, Spline, HyperFrames y Remotion. Con gemma4, p5 y Zdog salieron
  rotos en la prueba (ver «Enfoques»); SVG salió bien. Las librerías se pueden añadir más tarde para proveedores
  grandes sin rehacer esto.
- Indexar los archivos (RAG) o buscar por contenido. La búsqueda es por nombre.
- Cambiar la voz (sigue Piper «sharvard») o la palabra de activación del dictado (sigue «Distro»).

## Lo que haría que fracase aunque funcione

- Que Harper haga clic en el sitio equivocado sin preguntar.
- Que meta dibujos en respuestas que no los necesitan.
- Que las respuestas vayan más lentas: el prompt de gemma4 crece lo mínimo (unas pocas líneas por capacidad).
- Que pueda ejecutar algo al «abrir un archivo».

## Restricciones

- El proveedor sigue siendo elegible por el usuario (Ajustes › IA). En este equipo: `aiProvider: ollama`,
  `aiModel: gemma4:e4b`, sin respaldo en la nube (`aiFallbackProvider: off`).
- Sin emojis en la interfaz.
- Toda dependencia nueva entra en `install/packages.tsv` para todas las distros. Este diseño no añade ninguna:
  `fd` ya es opcional y hay respaldo con `find`, y el SVG lo dibuja Qt.
- Cada parte es una versión propia: commit + tag + push + release + `hf-perfil publicar`, y se aplica en la sesión
  (`hf-shell refresh` vía `hyprctl exec_cmd`).

## Enfoques considerados (imágenes)

Prueba del 2026-11-16 con gemma4:e4b (temperatura 0,4): SVG de un gato bajo la luna, 14 s, reconocible; p5.js de
estrellas fugaces, 11 s, no hizo lo pedido; Zdog de una casita, 9 s, pantalla en blanco.

- **A. Solo SVG (elegido).** Es lo que gemma4 hace bien, es ligero y no necesita librerías ni red.
- B. SVG + p5/Zdog/Three según el modelo. Más código y mantenimiento para algo que con gemma4 no se usaría.
- C. Plantillas que el modelo rellena. Quedan bonitas y no fallan, pero solo hacen lo que traen.

El usuario eligió A, con la condición de que dibuje solo cuando haga falta para explicar o se le pida.

## Diseño

### 1. Harper (nombre, voz, icono)

- `config/defaults/settings.json`: `aiName: "Harper"` y `aiPersona` igual que ahora, pero empezando por «Eres Harper».
- `scripts/hf-migrate`: igual que la migración Samantha → Helpert (0.8.20). Si `aiName == "Helpert"`, pasa a
  «Harper», y la personalidad solo cambia si es la de fábrica (huella sha256). Copia en
  `settings.json.antes-de-harper`.
- Textos de la interfaz, prompts, docs y comentarios: Helpert → Harper. Donde se muestra el nombre del asistente se
  usa `aiName` si ya se hace así. Las entradas antiguas del CHANGELOG no se tocan.
- Voz: antes de mandar al modelo lo transcrito, se normalizan las variantes a «Harper» (jarper, járper, harpe,
  jarpe, arper, «har per», «jar per»). Además, una línea en el prompt: «por voz tu nombre puede llegar mal escrito
  (Jarper…)».
- **Mi decisión:** «Distro» sigue siendo la palabra de activación. Se añade `harper` con sus variantes a `WAKE_ALTS`
  para que funcione si el usuario la pone en Ajustes › Dictado.
- Icono `"ai"` de `config/quickshell/components/Icons.qml` (caja 24×24, trazo 1.8): dos lentes redondas, puente,
  cejas en arco, `>` dentro de la lente izquierda y `_` dentro de la derecha. Se revisa a 12-14 px, que es el
  tamaño de la barra y el panel. Si `>_` no se distingue a ese tamaño, se engruesa o se simplifica solo ahí.

### 2. Archivos

- Consulta `files` (existe): devuelve también la fecha de modificación y el tamaño, con lo más reciente primero,
  para que «el que bajé ayer» se pueda resolver. Igual que hoy: `fd`, con respaldo `find`, en `$HOME`, 30 resultados.
- Consulta nueva `read_file {"path"}`: el texto del archivo con `read_doc` (los mismos límites que los adjuntos).
  Permiso: el mismo que leer el escritorio (`can_read`).
- Acción nueva `file {"op": "reveal"|"open", "path"}`:
  - `reveal` abre la carpeta en Nautilus con el archivo seleccionado (`nautilus --select`; `xdg-open` de la carpeta
    si no hay Nautilus).
  - `open` lo abre con su aplicación (`xdg-open`).
  - Validación: la ruta existe y está bajo `$HOME` o `/run/media/$USER`. Fuera: `.ssh`, `.gnupg`, la carpeta de
    secretos de hyprfrijol y lo que esté en las apps privadas.
  - `open` rechaza ejecutables (bit +x), `.desktop`, `.sh`, `.AppImage` y similares. Esos solo se pueden `reveal`.
  - Etiqueta: «Abrir la carpeta de informe.pdf» / «Abrir informe.pdf». No cambia nada del estado, así que no tiene
    Deshacer y se puede marcar como «Aprobar siempre».
- Prompt: una línea por cada una (la consulta `read_file` y la acción `file`).

### 3. Pantalla: no elegir a ciegas

- En `hf-ai`, al validar un `pointer` con `mark`: si el texto clave de ese elemento (normalizado: minúsculas, sin
  tildes) aparece en otro elemento de la misma captura, el paso no se aplica. En su lugar, el plan devuelve una
  pregunta de desambiguación:
  - candidatos: cada elemento coincidente con el resto de su fila (los elementos a la misma altura, ± media línea),
    por ejemplo «Juan Pérez · Factura noviembre · 10:32»;
  - en pantalla, `Puntero.qml` resalta y numera solo esos candidatos;
  - en el panel, una tarjeta «¿Cuál?» con un botón por candidato. Elegir uno sigue el plan con ese `mark`.
    Responder «el 2» o «el de la factura» también vale.
- No pregunta si el mensaje del usuario contiene texto que solo está en la fila de un candidato (el asunto, la hora),
  o si dice «el último» o «el primero». En ese caso elige ese y lo dice en la etiqueta del paso.
- El prompt se queda como está: la decisión la toma `hf-ai`, no gemma4.

### 4. Imágenes con código (SVG)

- Prompt (unas 3 líneas): dibujar solo si se pide un dibujo, esquema o ilustración, o si un dibujo explica algo
  mucho mejor que el texto. Formato: un bloque de código `svg` con un SVG completo, `viewBox`, sin texto largo
  dentro, animación con CSS o SMIL si aporta.
- `hf-ai` limpia el SVG antes de que llegue al panel: quita `<script>`, `<foreignObject>`, atributos `on*`, y
  `href`/`xlink:href`/`url()` que no sean `#ancla` o `data:`. Máximo 100 KB. Si no es un SVG válido, se queda como
  bloque de código normal.
- `AiRich.qml`: un tipo nuevo `svg`, que se dibuja a lo ancho del panel con su proporción. Debajo, tres botones:
  - «Guardar», a `$(xdg-user-dir PICTURES)/Harper/AAAAMMDD-HHMMSS.svg` (en español, `~/Imágenes`);
  - «Copiar», el código;
  - «Abrir en grande», con el visor predeterminado.
- Render: con Qt (`Image` con el SVG como `data:`), que no tiene red ni JavaScript. Si las animaciones no se mueven
  ahí, el que construye prueba Qt SVG animado (6.7+). Si tampoco, se muestra estático y la animación se ve en
  «Abrir en grande». No se mete WebEngine solo para esto.

## Pruebas

- `dev/` (asserts, como el resto):
  - normalización del nombre por voz;
  - validación de rutas de `file` (fuera de `$HOME`, `.ssh`, ejecutables);
  - limpieza del SVG (script, `on*`, href externo);
  - desambiguación con una lista de elementos de prueba (duplicados → pregunta; con asunto en el mensaje → sin
    pregunta).
- A mano, en la sesión anidada (`dev/try.sh`):
  - icono a 12-14 px;
  - «¿dónde está…?» y «ábrelo»;
  - responder a un correo con dos del mismo remitente;
  - «dibújame cómo funciona un…».

## Orden

1. Harper (nombre, voz, icono, migración). En este equipo: gemma4 de principal y sin respaldo.
2. Archivos.
3. Pantalla.
4. Imágenes.

## Lo que queda al que construye

- El trazo exacto del icono.
- La tolerancia de «misma fila» (en coordenadas 0-1000).
- La frase de cada etiqueta y de la tarjeta «¿Cuál?».
- Si `read_file` comparte código con los adjuntos o los llama directamente.
