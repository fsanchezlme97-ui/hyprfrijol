# Harper: plan de implementación

> Para quien lo ejecute: superpowers:executing-plans, tarea a tarea. Los pasos llevan casillas (`- [ ]`).

**Objetivo:** el asistente del panel pasa a llamarse Harper (nombre, voz, icono) y aprende cuatro cosas: abrir y
leer archivos, no elegir a ciegas en pantalla, y dibujar esquemas SVG con estilo y escenas 3D.

**Arquitectura:** todo pasa por `scripts/hf-ai`. Allí se validan las acciones, consultas y bloques nuevos con
esquema cerrado, y `AiChat.qml`/`AiRich.qml` solo pintan lo validado. La desambiguación vive en
`scripts/hf-screen resolve`, que ya tiene los elementos numerados del último análisis.

**Tecnología:** Python 3 (sin dependencias nuevas), QML de Quickshell 0.3.2, Qt SVG, Qt Quick 3D (fase 4b,
pendiente de verificar).

**Diseño:** `docs/planes/harper.md`.

## Restricciones globales

- Sin emojis en la interfaz. Todo en español.
- Proveedor elegible por el usuario. En este equipo: `aiProvider: ollama`, `aiModel: gemma4:e4b`,
  `aiFallbackProvider: off`.
- Una dependencia nueva va a `install/packages.tsv` en todas las distros (solo `qt6-quick3d`, en la fase 4b, y
  solo si se aprueba).
- Pruebas: autopruebas con `assert` (`scripts/hf-ai selftest`, `scripts/hf-screen selftest`), `dev/lint.sh` y
  `dev/check.sh`.
- Al acabar cada fase:
  - versión propia en `CHANGELOG.md` (v0.10.28, v0.10.29…);
  - commit + tag + push + release de GitHub + `scripts/hf-perfil publicar`;
  - `hf-shell refresh` vía `hyprctl exec_cmd`, comprobando que `qs` arranca sin errores.
- Pruebas de pantalla solo en la sesión anidada (`dev/try.sh`). Después se limpian el historial, la actividad y
  los deshacer.

## Puntos a vigilar

1. Voz: «Jarper, pon la barra arriba» tiene que llegar al modelo como «Harper, …». Pero «harpa» o «arpegio» no se
   tocan (solo palabras completas).
2. `file open` sobre un enlace simbólico que apunta fuera de `$HOME` o a un ejecutable: se valida la ruta ya
   resuelta (`realpath`).
3. Dos correos del mismo remitente, con el asunto de uno en el mensaje: no se pregunta, se elige ese.
4. SVG con `<style>` propio, `@import` o `url(http…)`: se quita entero.
5. JSON de escena con 500 objetos o números enormes: se recorta a 40 y los valores se limitan.

---

## Fase 1: Harper (v0.10.28)

### Tarea 1.1: nombre por defecto, migración y voz

**Archivos:**
- Modificar: `config/defaults/settings.json` (`aiName`, `aiPersona`)
- Modificar: `scripts/hf-migrate` (paso nuevo, igual que Samantha → Helpert)
- Modificar: `scripts/hf-apply:40`
- Modificar: `scripts/hf-ai` (`norm_name`, prompt de personalidad, `do_chat`)
- Modificar: `scripts/hf-voice` (`WAKE_ALTS`, `WAKE_LOOSE`)

**Interfaces:**
- Produce: `norm_name(text: str) -> str` en `hf-ai`.

- [ ] Prueba `_selftest_name` en `hf-ai`:
  ```python
  assert norm_name("Jarper, pon la barra arriba") == "Harper, pon la barra arriba"
  assert norm_name("oye járper qué hora es") == "oye Harper qué hora es"
  assert norm_name("jar per abre ajustes") == "Harper abre ajustes"
  assert norm_name("toca la harpa") == "toca la harpa"
  assert norm_name("un arpegio") == "un arpegio"
  ```
  Se llama desde `selftest`. Ejecutar `scripts/hf-ai selftest`: tiene que fallar porque `norm_name` no existe.
- [ ] Implementar `norm_name`:
  - una regex con límites de palabra y sin tildes para `harper|jarper|harpe|jarpe|arper|har per|jar per`;
  - devuelve «Harper» con mayúscula.
- [ ] Aplicar `norm_name` a todos los mensajes `role == "user"` de `req["messages"]` al principio de `do_chat`.
  Añadir al prompt de personalidad: «Te llamas Harper; por voz tu nombre puede llegar mal escrito».
- [ ] Ejecutar `scripts/hf-ai selftest` → `ok`.
- [ ] `settings.json` de fábrica:
  - `aiName: "Harper"`;
  - `aiPersona`: igual que ahora, pero empezando por «Eres Harper:».
- [ ] `hf-migrate`, paso nuevo:
  - si `aiName == "Helpert"` → «Harper»;
  - la personalidad solo cambia si su sha256 es el de la de fábrica de Helpert, y se calcula sobre el texto actual
    antes de cambiarlo;
  - copia en `settings.json.antes-de-harper`.

  Comprobar con un `settings.json` falso en un directorio temporal:
  `HOME=$tmp scripts/hf-migrate --dry-run` lo anuncia, y sin `--dry-run` lo cambia.
- [ ] `hf-apply:40`: «Samantha» y «Helpert» pasan los dos a «Harper».
- [ ] `hf-voice`: añadir `"harper": {"harper", "jarper", "járper", "harpe", "jarpe", "arper", "har per", "jar per"}`
  a `WAKE_ALTS` (y `WAKE_LOOSE` vacío).
- [ ] Commit `feat: Harper (nombre, voz y migración desde Helpert)`.

### Tarea 1.2: icono de gafas y textos

**Archivos:**
- Modificar: `config/quickshell/components/Icons.qml` (clave `"ai"`)
- Modificar: «Helpert» → «Harper» en los textos visibles, prompts, comentarios y docs de los 26 archivos de
  `grep -rli helpert`, salvo las entradas antiguas de `CHANGELOG.md` y la migración.
- Regenerar: `dev/gen-settings-index.py`

- [ ] Trazo del icono `"ai"` (24×24, trazo 1.8, `currentColor`):
  - dos círculos de radio ~4,2 en (7,13) y (17,13);
  - puente: un arco corto entre los dos;
  - cejas: dos arcos encima;
  - `>` dentro de la izquierda (`M5.6 11.4l1.9 1.6-1.9 1.6`);
  - `_` dentro de la derecha (`M15.4 15h3.2`).

  Comprobación: renderizarlo a 14 px y a 48 px (con `magick` desde un SVG de prueba) y mirarlo. A 14 px se tienen
  que leer gafas, y `>` `_` al menos como marcas.
- [ ] Sustituir los textos. `grep -rn Helpert` solo debe quedar en el CHANGELOG antiguo, en `hf-migrate` y en
  `hf-apply`.
- [ ] `python3 dev/gen-settings-index.py`, `dev/lint.sh` y `dev/check.sh` → todo bien.
- [ ] Commit `feat: icono de Harper (gafas con prompt) y textos`.

### Tarea 1.3: publicar la v0.10.28 y aplicarla en este equipo

- [ ] En este equipo:
  - ejecutar `scripts/hf-migrate`;
  - poner `aiProvider: ollama`, `aiModel: gemma4:e4b`, `aiFallbackProvider: off` con `scripts/hf-apply set`;
  - `hf-shell refresh` vía `hyprctl exec_cmd` y comprobar el log de `qs`.
- [ ] Probar `scripts/hf-ai ask "¿cómo te llamas?"` → responde Harper, con gemma4.
- [ ] CHANGELOG, tag, push, release y `hf-perfil publicar`.

## Fase 2: archivos (v0.10.29)

### Tarea 2.1: `files` con fecha, `read_file` y acción `file`

**Archivos:**
- Modificar: `scripts/hf-ai`:
  - consulta `files` en `run_query`;
  - consulta nueva `read_file`;
  - `QUERY_LABELS`;
  - `SCHEMA_DOC` y la línea de consultas del prompt;
  - `validate`, `meta` y `apply` para la acción `file`.

**Interfaces:**
- Produce:
  - `file_ok(path: str, op: str) -> str | None`: devuelve la ruta real si se permite, `None` si no;
  - acción `{"type":"file","op":"reveal"|"open","path":…}`, con `kind` `file:reveal` y `file:open`.

- [ ] Prueba `_selftest_files` con un `HOME` temporal y `settings()` simulados:
  - `file_ok` de un `$HOME/doc.pdf` que existe da la ruta real; con un archivo que no existe da `None`;
  - `/etc/passwd`, `$HOME/.ssh/id_ed25519` y `$HOME/.gnupg/x` dan `None`;
  - un enlace `$HOME/l → /etc/passwd` da `None`;
  - un script con +x da `None` con `open` y la ruta con `reveal`;
  - `x.desktop`, `x.sh` y `x.AppImage` con `open` dan `None`;
  - `validate([{"type":"file","op":"open","path":…pdf}])` da una acción, y `op: "rm"` da `[]`.
- [ ] Ejecutarla → falla.
- [ ] Implementar `file_ok`:
  - `realpath` primero;
  - permitido bajo `$HOME` o `/run/media/$USER`;
  - fuera: `.ssh`, `.gnupg`, `~/.config/hyprfrijol/secrets` y `.local/share/keyrings`;
  - con `open`, fuera el +x y las extensiones `.desktop .sh .bash .zsh .fish .py .AppImage .run .bin .exe .bat
    .jar .deb .rpm`.
- [ ] Implementar la acción `file`. `apply`:
  - `reveal` → `nautilus --select <ruta>` si existe; si no, `xdg-open` de la carpeta;
  - `open` → `xdg-open <ruta>`;
  - los dos desligados (`start_new_session`).

  `meta`: etiqueta «Abrir la carpeta de <nombre>» / «Abrir <nombre>», `confirm` false y sin deshacer.
- [ ] `files`:
  - con `fd` se añade `--type f -l`… o se lee `os.stat` de cada resultado;
  - salida `ruta · AAAA-MM-DD HH:MM · tamaño legible`, ordenada por fecha, la más reciente primero, hasta 30.
- [ ] `read_file {"path"}`:
  - `file_ok(path, "reveal")`, después `read_doc`, recortado a `DOC_MAX`;
  - pasa por el filtro de secretos (`redact`) como el resto del contexto;
  - permiso `query_allowed` (el mismo que leer el escritorio).
- [ ] Prompt: una línea para la acción `file` y la consulta `read_file`, más «si te preguntan dónde está un archivo,
  usa files y da la ruta; ábrelo solo si te lo piden».
- [ ] `scripts/hf-ai selftest` → `ok`. Probar con gemma4:
  - `scripts/hf-ai chat '{"messages":[{"role":"user","text":"¿dónde está el README de hyprfrijol?"}]}'` → da la
    ruta;
  - «ábreme su carpeta» → plan con `file reveal`.
- [ ] Commit, docs (`docs/IA.md`: la tabla de acciones y las consultas), CHANGELOG v0.10.29 y publicar.

## Fase 3: pantalla sin elegir a ciegas (v0.10.30)

### Tarea 3.1: detección de duplicados en `hf-screen resolve`

**Archivos:**
- Modificar: `scripts/hf-screen` (`resolve`, `selftest`, función nueva `twins`)

**Interfaces:**
- Produce: `twins(d: dict, e: dict) -> list[dict]`. Son los elementos legibles con el mismo texto normalizado que
  `e` (incluido `e`), cada uno con `row`: el texto de su fila, es decir los elementos cuyo centro vertical está a
  ±0,6·h, unidos con « · » y de izquierda a derecha.
- `resolve(a, hint="")` añade `a["choices"] = [{"n", "row", "box"}]` cuando hay más de uno y ninguno queda
  elegido por `hint`.
- Se elige por `hint` si el texto normalizado de `hint` contiene una palabra de 4 letras o más que está en la fila
  de un solo candidato. «el último» / «el primero» eligen por posición vertical.

- [ ] Ampliar `selftest` de `hf-screen`. Marcas de prueba:
  - 1 «Juan Pérez» y 2 «Factura noviembre», en la fila y=100;
  - 3 «Juan Pérez» y 4 «Cena viernes», en y=200;
  - 5 «Responder».

  Casos:
  ```python
  r = resolve({"op": "click", "mark": 1})
  assert [c["n"] for c in r["choices"]] == [1, 3] and "Factura noviembre" in r["choices"][0]["row"]
  assert "choices" not in resolve({"op": "click", "mark": 1}, hint="responde a juan lo de la cena")  # → la 3
  assert resolve({"op": "click", "mark": 1}, hint="el de la cena")["label"] == "Juan Pérez"
  assert resolve({"op": "click", "mark": 1}, hint="el último")["at"] == centro de la 3
  assert "choices" not in resolve({"op": "click", "mark": 5})
  ```
- [ ] `scripts/hf-screen selftest` → falla.
- [ ] Implementar `twins`, la elección por `hint` y `choices` en `resolve`. `main` pasa `hint` por la CLI
  (`resolve '<json>' '<hint>'`).
- [ ] `scripts/hf-screen selftest` → `ok`. Commit.

### Tarea 3.2: «¿Cuál?» en hf-ai y en el panel

**Archivos:**
- Modificar: `scripts/hf-ai`:
  - en `validate`, el pointer pasa el último mensaje del usuario como `hint`;
  - en `parse_reply`, si un pointer trae `choices`, el plan se para ahí.
- Modificar: `config/quickshell/modules/sidepanel/AiChat.qml` (botones de `choices`)
- Caché: `~/.cache/hyprfrijol/ai-choice.json` (`{"t", "action", "rest", "choices"}`, caduca a los 300 s)

**Interfaces:**
- La respuesta de `do_chat` gana `choices: [{"n": int, "label": str}]` y un texto «Hay varios: ¿cuál?».
- Mensaje siguiente del usuario «el 2», «2» o texto que encaja con una fila → `hf-ai` recupera la caché y rehace
  la acción con ese `mark`, más los pasos que quedaban, sin llamar al modelo.

- [ ] Prueba `_selftest_choice` en `hf-ai`, con un `ultima.json` de prueba y `hf-screen` real:
  - un plan `[pointer mark 1, pointer type …]` con dos «Juan Pérez» devuelve `choices` de 2 y `actions == []`;
  - después `pick_choice("el 2")` devuelve las dos acciones con `at` de la marca 3.
- [ ] Implementar `pick_choice(text: str) -> list | None` y el corte del plan.
- [ ] Puntero: con `choices`, `hf-ai` llama a `qs ipc call puntero marks '<json de los candidatos>' 8000`, para que
  se vean numerados en pantalla.
- [ ] `AiChat.qml`: si la respuesta trae `choices`, una fila de botones `outline` «1 · Juan Pérez · Factura…»
  (elidido). Al pulsar, `root.ask("el " + n)`.
- [ ] `selftest` → `ok`, más `dev/check.sh`. Prueba en la sesión anidada con dos ventanas de texto con el mismo
  nombre. Commit, docs, CHANGELOG v0.10.30 y publicar.

## Fase 4: imágenes (v0.10.31 y v0.10.32)

### Tarea 4a.1: esquemas `hf-diagram` (SVG con estilo)

**Archivos:**
- Modificar: `scripts/hf-ai` (`clean_svg`, `DIAGRAM_CSS`, prompt, `parse_reply` sustituye el bloque por el SVG final)
- Modificar: `config/quickshell/modules/sidepanel/AiRich.qml` (tipo `svg`: `Image` con `data:image/svg+xml`, ancho
  del panel, proporción del `viewBox`, botones Guardar / Copiar / Abrir en grande)
- Modificar: `scripts/hf-ai` (subórdenes `save-svg <archivo>` y `open-svg`, que escriben en
  `$(xdg-user-dir PICTURES)/Harper/`)

**Interfaces:**
- `clean_svg(src: str, theme: dict) -> str | None`.
- En el texto de la respuesta, el bloque queda como ```` ```svg ```` con el SVG limpio y ya con estilo, y
  `AiRich` lo reconoce por el lenguaje `svg`.

- [ ] Prueba `_selftest_svg`:
  - `<script>` → fuera;
  - `onload=` → fuera;
  - `<foreignObject>` → fuera;
  - `href="http://x"` → fuera, `href="#a"` → se queda;
  - `style="fill:red"` y `fill="red"` → fuera;
  - un `<style>@import…</style>` del modelo → fuera;
  - más de 100 KB → `None`;
  - un texto que no es SVG → `None`;
  - un SVG válido sale con `<style>` y `<defs>` de HyprFrijol, y el color de acento del tema dentro.
- [ ] Implementar con `xml.etree.ElementTree` (lista blanca de etiquetas: `svg g rect circle ellipse line polyline
  polygon path text tspan title desc` más las de animación `animate animateTransform animateMotion set`;
  atributos en lista blanca).
- [ ] `DIAGRAM_CSS`, el aspecto tipo Spline:
  - degradado vertical claro→acento en `.box`, `.pill` y `.node`;
  - esquinas `rx` 14;
  - sombra con un `rect` desplazado y con opacidad (Qt SVG no dibuja `feGaussianBlur`);
  - trazo 2 redondeado en `.arrow` y `.line`, con marcador de punta;
  - `.flow` con `stroke-dasharray` animado;
  - texto en la fuente del tema.

  Comprobarlo dibujando 3 esquemas de gemma4 en el panel de la sesión anidada y ajustar a ojo.
- [ ] Prompt (3 líneas): cuándo dibujar, el bloque `hf-diagram`, las clases disponibles y que no ponga colores.
- [ ] `selftest`, `dev/check.sh`. Commit, docs, CHANGELOG v0.10.31 y publicar.

### Tarea 4b.0: comprobar Qt Quick 3D (antes de construir)

- [ ] Preguntar al usuario si se instala `qt6-quick3d` (dependencia nueva) y que la instale él con
  `! sudo pacman -S qt6-quick3d`.
- [ ] En la sesión anidada, un `View3D` mínimo con una esfera dentro del panel. Si Quickshell no lo carga, parar y
  consultar el respaldo (Three.js en una ventana `qml6` aparte).

### Tarea 4b.1: escenas `hf-scene` (JSON → Qt Quick 3D)

**Archivos:**
- Modificar: `scripts/hf-ai` (`clean_scene`, prompt)
- Crear: `config/quickshell/modules/sidepanel/AiScene.qml` (`View3D`: luz de estudio, sombras,
  `PrincipledMaterial` mate, suelo con sombra, giro con el ratón, `anim`)
- Modificar: `AiRich.qml` (tipo `scene` → `AiScene`; Guardar PNG con `grabToImage`)
- Modificar: `install/packages.tsv` (`qt6-quick3d`, las distros, `recommended`, «dibujos 3D del asistente») y
  `dev/gen-pkgbuild.py`

**Interfaces:**
- `clean_scene(src: str) -> dict | None`:
  - `{"camera": "front"|"iso"|"top", "background": "theme"|"soft"|"none", "objects": [...]}`;
  - cada objeto: `{"shape", "pos": [x,y,z], "rot": [x,y,z], "scale": [x,y,z], "color", "anim"}`;
  - números limitados a ±50 (`scale` de 0,05 a 20), hasta 40 objetos.

- [ ] Prueba `_selftest_scene`:
  - 500 objetos → se queda en 40;
  - `shape: "teapot"` → fuera;
  - `pos: [1e9,0,0]` → `[50,0,0]`;
  - `color: "#ff0000"` → se queda (un color hex vale) y `color: "url(x)"` → `soft`;
  - lo que no es JSON → `None`.
- [ ] Implementar `clean_scene` y el visor. Comprobar 3 escenas de gemma4 en la sesión anidada («planeta con
  anillos», «átomo», «escritorio con un portátil»).
- [ ] `selftest`, `dev/lint.sh`, `dev/check.sh`. Commit, docs, CHANGELOG v0.10.32 y publicar.
