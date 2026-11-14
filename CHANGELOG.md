# Cambios de HyprFrijol

Cada versión es una etiqueta de git `vX.Y.Z`. `hf-update` muestra esta lista (o la anotación de la etiqueta)
antes de actualizar. Formato: la versión más nueva arriba, una sección `## [X.Y.Z] — AAAA-MM-DD` por versión.

## [0.9.90] — 2026-11-13

### Cambiado
- **Conversación por voz con Helpert mucho más rápida.** Después de una visita de Helpert, con capturas de pantalla en
  la conversación, cada turno tardaba unos 5,5 s en responder. Ahora tarda alrededor de 1 s, medido con la misma
  conversación antes y después.
  - La causa: la hora al minuto, la ventana y el portapapeles iban dentro de las instrucciones del sistema. Cada vez
    que cambiaban, el modelo local tenía que volver a leer las ~2.700 palabras de instrucciones y a mirar todas las
    capturas del historial.
  - Ahora ese contexto va con tu último mensaje, y el historial se recorta por bloques, así que el modelo reaprovecha
    lo ya leído. Vale para Ollama, para los servidores compatibles con OpenAI y para Gemini.
  - Además, el portapapeles y el título de la ventana dejan de tratarse como instrucciones del sistema: ahora son datos
    junto a tu mensaje.
- **La voz de Helpert empieza a sonar en ~0,2 s en vez de ~1,3 s.** La voz (Piper) se queda cargada en memoria
  mientras conversas, unos 150 MB, y se cierra sola tras 10 minutos sin hablar. Se precarga al empezar una
  conversación o una visita. Interrumpir a Helpert hablando funciona igual que antes.

### Corregido
- Dictado con Nemotron: una pregunta o exclamación que no cerraba el propio modelo («¿qué tiempo hará mañana») ya no
  termina en punto, sino con su «?» o su «!».

## [0.9.89] — 2026-11-13

### Seguridad
- Al terminar de dictar ya no se vuelve a copiar una contraseña:
  - Si lo que tenías copiado venía de un gestor de contraseñas (marcado como tal), no se guarda ni se devuelve, porque
    antes volvía sin esa marca, entraba en el historial del portapapeles y reaparecía aunque el gestor ya la hubiera
    borrado.
  - Lo que se devuelve va marcado como sensible, porque ya estaba en el historial.
  - Solo se devuelve si el portapapeles sigue teniendo lo último que pegó el dictado: si copias algo tú mientras
    dictas, se queda lo tuyo.

## [0.9.88] — 2026-11-13

### Corregido
- El dictado ya no se come espacios, signos ni tildes en los editores de texto enriquecido. En la caja de T3 Code,
  WhatsApp web, Notion y otros editores de ese tipo (ProseMirror/tiptap, Lexical), el texto salía a ratos todo
  junto: «pasasidictoalgomuy». La causa es que `wtype` asigna a cada carácter un código de tecla inventado, y según el
  que le toque, esos editores lo pierden; teclear más despacio no lo evitaba. Ahora:
  - Fuera de las terminales, el texto se **pega**.
  - Lo pegado va marcado como sensible, así que no entra en el historial del portapapeles.
  - Al terminar de dictar, el portapapeles vuelve a tener lo que habías copiado.
  - En las terminales, donde Ctrl+V no pega, se sigue tecleando como antes.
- Con Nemotron, el dictado vuelve a escribir **en directo**: cada palabra aparece en la ventana en cuanto el modelo la
  da por segura, y al acabar la frase solo se corrige lo que haya cambiado al final, normalmente nada. Antes la frase
  solo se veía arriba, en el aviso, y no llegaba a la ventana hasta la pausa.
- Dictar desde un archivo (`hf-dictate record --file`) con un motor en streaming (Vosk, Nemotron) ya no da «No
  entendí nada» cuando el audio se acababa antes de que cargase el motor.

## [0.9.87] — 2026-11-13

### Añadido
- Motor de dictado **Nemotron 3.5** (NVIDIA, en streaming), el nuevo recomendado: botón en Ajustes › Dictado o
  `hf-dictate install-nemotron`. Ocupa unos 750 MB: el runtime NeMo-Speech.cpp y el modelo, fijados por versión y
  comprobados con su suma. En «Automático» se usa en cuanto está instalado.
  - **Entiende mejor:** reconoce en el idioma elegido (con «Español + inglés», lo detecta él). Parakeet no deja fijar
    el idioma y, con frases largas o un micrófono flojo, se pasaba al inglés o al portugués: «Confirm the reunion
    delivers at the 10…», «vendas», «suporte». Con una lectura de prueba de 45 s, Nemotron la escribió entera en
    español.
  - **Sin parpadeo:** lo provisional se ve en el aviso del dictado mientras hablas. En la ventana, cada frase se
    escribe entera al hacer una pausa, sin borrar ni reescribir nada. En la prueba no hubo ni un retroceso; antes
    hubo 133.
  - **Sin frases partidas a mitad:** el propio modelo decide dónde acaba la frase, no un detector de volumen. Si una
    pausa corta la frase, lo siguiente sigue en minúscula y sin punto.
  - **Consumo:** usa como máximo 4 núcleos, alrededor de 1,3 núcleos ocupados mientras dictas.

### Corregido
- Órdenes de voz con un motor en streaming (Vosk, Nemotron): lo que se seguía diciendo tras la orden ya no se manda
  como una segunda orden.

## [0.9.86] — 2026-11-13

### Corregido
- Al cambiar los tiempos de inactividad, `hf-apply` relanza hypridle a través de Hyprland (como el arranque de la
  sesión) y no desde quien lo ejecuta: lanzado desde una terminal o una herramienta que luego se cerraba entera,
  hypridle moría con ella y dejaba de haber bloqueo y apagado por inactividad hasta volver a entrar.

## [0.9.85] — 2026-11-13

### Corregido
- El fondo en vídeo ya no desaparece tras apagarse la pantalla con el equipo bloqueado: si al desconectarse el monitor
  no quedaba ninguna pantalla para el vídeo (las demás con fondo propio), el vigilante intentaba pausar un reproductor
  que no existía, fallaba y se cerraba, y al volver la pantalla nadie relanzaba el vídeo (escritorio sin fondo).

## [0.9.84] — 2026-11-13

### Corregido
- El escritorio remoto ya no se corta por inactividad: con alguien dentro por RDP (hypr-rdp) o VNC (wayvnc), la
  pantalla no se apaga ni el equipo se suspende. Al apagarse, el monitor sin señal se desconectaba, la salida que se
  estaba capturando desaparecía y la conexión se caía. El bloqueo por inactividad sigue haciéndose.

## [0.9.83] — 2026-11-13

### Añadido
- Botón de cerrar en la cabecera de Ajustes, junto a maximizar.

## [0.9.82] — 2026-11-13

### Corregido
- Al desbloquear, la pantalla de bloqueo no avisaba de que se había soltado: la marca de «bloqueado» se quedaba puesta
  (el siguiente arranque del shell volvía a bloquear la pantalla) y el shell seguía creyéndose bloqueado, con el
  clima, los chips propios, los contadores de uso y el fondo en vídeo parados hasta reiniciarlo. Ahora el desbloqueo
  lo refleja él mismo.

## [0.9.81] — 2026-11-13

### Añadido
- Ajustes › Sistema y recuperación › **Respaldo**: «Crear…» guarda el respaldo completo (`hf-perfil respaldo`) donde
  elijas, para llevarlo fuera (USB, tu nube); «Cargar…», en el equipo nuevo tras instalar HyprFrijol desde GitHub,
  lo repone en una terminal (pide tu contraseña) y al terminar basta con cerrar sesión y volver a entrar. La sección
  muestra también la orden para instalar y cargar el respaldo de una vez.

### Cambiado
- Acerca › «Respaldo completo…» lleva a esa sección en vez de exportar solo los ajustes.
- La sincronización de ajustes por git deja fuera la carpeta `secrets/`.

## [0.9.80] — 2026-11-13

### Añadido
- `hf-perfil respaldo`: un solo archivo para reinstalar y quedar igual. Lleva el perfil (paquetes, apps, servicios,
  acceso remoto, voz, dictado, modelos, login y ajustes) y además tus datos (notas, tareas, calendario local,
  conversaciones del asistente, historial de avisos, firmas, fijados del portapapeles, apps por defecto y de inicio,
  la configuración del escritorio remoto sin su contraseña), tus fondos, los grupos de hardware, el servicio
  `ydotool` y el idioma, teclado y hora del sistema (no el nombre del equipo). `./install.sh --perfil=RESPALDO.tar.gz`
  (también por `bootstrap.sh`, en una distro con escritorio o sin él) lo repone; las rutas del equipo de origen pasan
  a las del nuevo (otro usuario u otro idioma de carpetas). Sin contraseñas ni claves, ni el historial del
  portapapeles. Al restaurar solo se aceptan archivos normales de la lista de datos, nunca enlaces ni rutas que se
  salgan, y lo del sistema solo con valores de forma válida.
- El cursor Bibata Modern Classic entra en el instalador (AUR en Arch, Debian/Ubuntu); antes solo estaba si otro
  paquete lo traía.
- `install.sh --acceso-remoto` y `--yes` llegan a la restauración del perfil (sin `--yes`, el gestor de paquetes
  preguntaba aunque la instalación fuera desatendida).

### Corregido
- `./install.sh --perfil` (sin archivo) fallaba al empezar (usaba la carpeta del repo antes de calcularla). Un perfil
  que no existe se detecta antes de instalar nada, no al final.
- Las claves de los ajustes (`printerApiKey`) podían ir al perfil público del repo y al tuyo; ahora no van en ninguno.

## [0.9.79] — 2026-11-13

### Corregido
- La marca de «pantalla bloqueada» de la 0.9.76 podía quedarse puesta con la sesión ya desbloqueada, y entonces
  cada arranque del shell bloqueaba la pantalla (y reproducía el vídeo del bloqueo, que dejaba ~400 MB retenidos).
  Se escribía de forma asíncrona y se borraba con un `rm` aparte: un bloqueo que se soltaba al momento la dejaba
  escrita después del borrado. Ahora se escribe y se vacía por el mismo `FileView` sin esperar, y solo «1» cuenta
  como bloqueado. Probado en sesión anidada: marca vacía no bloquea; bloquear, matar el shell y relanzarlo sí
  retoma el bloqueo.

## [0.9.78] — 2026-11-13

### Mejorado
- Menos trabajo en segundo plano sin cambiar nada de lo que se ve. Medido en reposo (`dev/perf.sh`): el hilo
  principal del shell pasa del 4,4 % al 2,3 % de un núcleo.
  - El historial de avisos ya no se rehace cada minuto con el panel cerrado (hasta 150 filas): sus cabeceras «Hoy»
    y «Ayer» dependen del día (`Time.day`), no de la hora.
  - El icono animado del clima se para con la sesión bloqueada o la barra escondida (seguía 12 veces por segundo
    bajo el bloqueo toda la noche).
  - Cambiar de ventana con el foco ya no lanza `hyprctl` ni relee todas las ventanas: el evento trae la ventana y el
    orden de uso (Alt + Tab) se lleva como Hyprland. Con el foco siguiendo al ratón eran hasta ~8 por segundo.
  - La barra de título de las ventanas flotantes pregunta su posición por el socket de Hyprland desde el shell, no
    con un `hyprctl` cada 100 ms.
  - Las páginas de Ajustes que se actualizan solas (Red, Escritorio remoto, Privacidad, Impresoras, Máquinas
    virtuales, Almacenamiento) solo consultan con Ajustes a la vista; al volver a verlo, refrescan al momento.
  - Con wifi, la señal se lee cada 30 s con un solo `nmcli` y sin pedir una búsqueda de redes (antes sh y cuatro
    `nmcli`).
  - Ordenar los iconos del escritorio u ocultar iconos de la bandeja ya no recarga Hyprland.

## [0.9.77] — 2026-11-13

### Cambiado
- Pendientes recortados a tres: idiomas, otras distros y la comparación de rendimiento con otros shells. El resto
  (motor único de paquetes, plugins, otros compositores, Howdy, pruebas con uso real abiertas y avisos sin arreglo
  de nouveau) queda como descartado en `docs/PENDIENTES.md`.

## [0.9.76] — 2026-11-13

### Corregido
- Si Quickshell se caía con la pantalla bloqueada, Hyprland dejaba su pantalla de error («oopsie daisy») en vez del
  bloqueo. Dos causas: `hf-shell` dejaba Quickshell en el grupo de procesos de quien lo lanzaba (una terminal, una
  sesión de un asistente…) y systemd lo mataba al cerrarse ese grupo; ahora va en su propio scope. Y si aun así se
  cae, el Quickshell que relanza `hf-shell` retoma el bloqueo (`allow_session_lock_restore` y una marca en
  `$XDG_RUNTIME_DIR`), así que la sesión sigue protegida y se desbloquea con la contraseña de siempre.

## [0.9.75] — 2026-11-13

### Corregido
- El fondo en vídeo se quedaba en negro: al relanzarse el reproductor (una recarga de Hyprland, una pantalla que
  vuelve), el shell podía pausarlo antes de que creara su superficie, y no se veía nada hasta la siguiente
  reanudación. Ahora el reproductor se anuncia cuando ya tiene su capa y, si el fondo está en pausa, nace pausado.
- El fondo en vídeo también desaparecía tras el bloqueo por inactividad: el monitor HDMI, al apagarse, se desconecta
  y se reconecta varias veces, y el vigilante del vídeo se cerraba en medio (comprobaba la sesión con `hyprctl`, que
  llegaba a tardar más de 3 s). Ahora mira el socket de Hyprland, un reproductor que se cierra porque su pantalla se
  fue no cuenta como fallo, y cada salida del vigilante queda en `$XDG_RUNTIME_DIR/hf-motion-*/motion.log`.
- La pantalla de bloqueo reproducía el vídeo original (4K a 60 fps, decodificado por CPU, uno por pantalla) y el
  shell pasaba de 200 MB a más de 1 GB al bloquear. Usa la copia a la altura de la pantalla que ya reproduce el
  escritorio (`wallpaper-play`).
- `hf-wallpaper -o` aceptaba cualquier nombre de pantalla, y el shell llegó a guardar un fondo para «undefined».
  Ahora solo las conectadas (quitar el fondo propio vale también con una desconectada).

## [0.9.74] — 2026-11-13

### Corregido
- RustDesk seguía colgando canales de la gráfica de nouveau al arrancar su servidor: la opción que apaga el códec
  por hardware se escribía en tu configuración (`~/.config/rustdesk/RustDesk2.toml`) y el servicio de root la
  borraba al sincronizar la suya. `hf-remote rustdesk gpu` y `hf-remote rustdesk hwcodec-off` la ponen ahora en
  el servicio (`sudo rustdesk --option enable-hwcodec N`). Se quita el paso automático de 0.9.72, que no servía
  (sin sudo no llega al servicio): con nouveau y RustDesk ya instalado, lanza una vez
  `hf-remote rustdesk hwcodec-off`.

## [0.9.73] — 2026-11-13

### Cambiado
- Estilo Math, fase 3: todos los huecos y márgenes del shell siguen la escala 4 / 8 / 12 / 16 / 24 (668 valores
  sueltos de 3, 5, 6, 10, 14, 18… llevados al más cercano). `dev/spacing.py` los revisa y `dev/lint.sh` avisa si
  vuelve a colarse uno. Los radios de lo que va dentro de un panel (baldosas del centro de control, rellenos,
  resumen de avisos, tarjetas del asistente) son concéntricos: el del panel menos el margen (`Theme.inner`).
- Ajustes, por dentro: Escritorio y gestos va en tres grupos (Ventanas · Escritorio · Ratón y touchpad) con lo
  de ventanas junto; en IA, «Personalidad» se separa en Personalidad, Voz y conversación y Modo compañero; en Barra,
  el comportamiento va tras la posición y «Avisos emergentes» pasa a llamarse «Indicadores de volumen y brillo»
  (no son las notificaciones).

### Corregido
- Ajustes › Acerca: el bloque «Ajustes» (Detalles técnicos, 0.9.70) se ponía como tercera columna encima de las otras
  dos; ahora va debajo de «Sincronizar tu escritorio».
- Spotlight: con la escala nueva el pie de atajos se salía del panel en el modo portapapeles, y en el Centro de
  aplicaciones la descripción de cada app perdía su segunda línea; los dos caben de nuevo.

### Añadido
- Dos pantallas (Ajustes › Pantallas › Con varias pantallas): apps que se abren siempre en la secundaria (chat,
  música, correo…; la regla sigue a la secundaria al conectar o quitar pantallas), el PiP en la otra pantalla, y el
  modo sin distracciones oscurece las demás pantallas (Ajustes › Enfoque).
- Transiciones: preset de animaciones «Cinemático» (más largo y amplio, rebote marcado); al minimizar, la ventana
  vuela y se encoge hasta su icono del dock; los avisos se deslizan a su sitio cuando llega o se va uno; inercia en
  el gesto de 3 dedos (un deslizamiento rápido cambia de espacio aunque sea corto).

## [0.9.72] — 2026-11-13

### Corregido
- Con el modelo local, «Abre YouTube» o «abre Spotify» no hacían nada y el asistente decía «Estos son los pasos:»
  sin pasos: pedía abrir una app que no está instalada. Si no la hay y es una web conocida (YouTube, Spotify, Gmail,
  WhatsApp, Netflix…) se abre su web; si no, dice que no la encuentra.
- Las miniaturas de la vista previa de Spotlight (`~/.cache/hyprfrijol/preview`) no se borraban nunca: las que nadie
  mira en 30 días se borran (se revisa como mucho una vez al día).
- Las instalaciones con una gráfica en nouveau que ya tenían RustDesk reciben una vez el códec por hardware apagado
  (`hf-remote rustdesk hwcodec-off`, sin sudo); antes solo se apagaba al volver a lanzar `hf-remote rustdesk gpu`.

## [0.9.71] — 2026-11-13

### Corregido
- Al iniciar sesión, la barra a veces arrancaba dibujando en la gráfica de nouveau, se caía y el vigilante la
  reabría 20 s después. `hf-shell` elige ya la otra gráfica (y sin vídeo por hardware) antes de lanzar Quickshell,
  aunque el entorno de Hyprland aún no lo traiga.
- RustDesk colgaba un canal de la gráfica de nouveau cada vez que arrancaba su servidor (al bloquear, al conectar):
  probaba el códec por hardware con VA-API en esa gráfica. `hf-remote rustdesk gpu` también apaga ese códec
  (`enable-hwcodec`); por CPU (VP9/AV1) va de sobra para el escritorio remoto.

## [0.9.70] — 2026-11-13

### Corregido
- El equipo se podía congelar al iniciar sesión (cursor enorme, había que reiniciar). Con una gráfica NVIDIA en
  nouveau (sin firmware de vídeo) el login dibujaba en ella y el fondo en vídeo se decodificaba en ella; el canal
  de la GPU se colgaba («nouveau … SCHED_ERROR / gr: TRAP»). Ahora el login dibuja en la otra gráfica
  (`greeter/hyprland-greeter.lua`, se instala en /etc/greetd con la actualización) y el fondo animado decodifica
  por hardware en la otra gráfica, o por CPU si solo hay nouveau (`hf-wallpaper`).
- El clima de la barra apenas se movía con el cielo cubierto (la nube iba y venía 1 px): ahora dos nubes se cruzan,
  y con cielo parcial el sol o la luna asoman tras una nube que pasa.

### Cambiado
- Ajustes más ordenado: la lista va por grupos (Personalización, Escritorio, Herramientas, Dispositivos,
  Conexiones, Aplicaciones, Sistema) y «Widgets de la barra» es una pestaña de Barra. Los detalles técnicos
  (comandos, servicios y claves de configuración junto a cada título) se ocultan; se ven con Ajustes › Acerca ›
  «Detalles técnicos» (`settingsTech`).
- «Barra viva» se puede apagar: Ajustes › Barra › Comportamiento (`barLive`).

## [0.9.69] — 2026-11-13

### Cambiado
- Conversación por voz sin clics: lo que se puede deshacer (abrir apps y webs, música, volumen, ajustes, fondos…) se
  hace al momento, sin preguntar. Lo que no tiene vuelta atrás (cerrar una ventana, borrar avisos, un comando)
  pregunta «¿Lo hago?» y se contesta hablando; el panel ya no se abre para aprobarlo. Solo lo que lleva sudo va al
  panel, porque pide tu contraseña.
- El «sí» se entiende mejor: sin tildes, con muletillas delante («Mm, de acuerdo») y como lo transcribe a veces el
  reconocedor («Proceed», «A probar y aplicar»). Antes esas respuestas iban al asistente como una pregunta nueva y
  volvía a proponer el plan.
- «Abre el navegador» abre tu navegador predeterminado (antes podía elegir Firefox teniendo Chrome por defecto), y
  «cierra el navegador» encuentra su ventana.

## [0.9.68] — 2026-11-12

### Seguridad
- Vista previa de Word, Excel y LibreOffice: un documento con párrafos o celdas metidos unos dentro de otros a
  propósito hacía que el texto se recorriera una vez por nivel (cuadrático). Ahora solo cuentan los de fuera, el XML
  se lee por trozos y cada elemento se suelta al usarlo: 200 000 niveles se leen en 0,3 s.

## [0.9.67] — 2026-11-12

### Seguridad
- El resumen automático de avisos (al abrir el centro) solo usa el modelo local: si falla, no pasa a la nube; eso
  solo con «Resumir» (`hf-ai digest --local`). Los avisos de las apps privadas (Ajustes › Asistente de IA ›
  Privacidad) no entran en el resumen, y los avisos le llegan por la entrada estándar, no en la línea de órdenes
  (donde cualquier proceso los podría leer).
- Vista previa de Spotlight: ImageMagick solo abre la imagen con el decodificador de su extensión (un «.png» que en
  realidad es PostScript ya no llega a Ghostscript), y Word, Excel y LibreOffice se leen con un analizador XML en
  vez de expresiones regulares (un archivo preparado podía dejarlas minutos calculando). Además, tope de 15 s.

### Corregido
- La vista previa de texto en Spotlight enseñaba solo la primera línea.

## [0.9.66] — 2026-11-12

### Nuevo
- Spotlight con vista previa de archivos (`/nombre`): miniatura de imágenes, PDF (1.ª página) y vídeos, el principio
  de textos, código, CSV, Word, Excel y LibreOffice, o lo que contiene una carpeta; con sus datos (medidas, páginas,
  duración, líneas, tamaño, fecha). Debajo, acciones rápidas según el tipo: Resumir (al asistente), convertir a otro
  formato, sacar el texto (OCR), firmar, enviar por correo y copiar el archivo para pegarlo en otra app; también en
  Ctrl K. Lo hace `hf-fileact preview` (miniaturas en `~/.cache/hyprfrijol/preview`).
- Resumen de avisos en el centro de control: con 3 avisos o más, una tarjeta los resume en una o dos frases, primero
  lo que pide atención. Si Ollama es tu proveedor o tu respaldo lo hace el modelo local y nada sale del equipo, y se
  rehace solo al abrir el centro (Ajustes › Notificaciones › «Resumen automático», `notifDigestAuto`); si no, con el
  botón «Resumir». `hf-ai digest` desde la terminal.
- Barra viva: el icono del clima se mueve según el tiempo (el sol gira despacio, la nube va y viene, cae lluvia o
  nieve, el rayo destella, la estrella de la luna titila) y el anillo del pomodoro se vacía con el tiempo que queda y
  late en los 2 últimos minutos. Quietos en pantalla completa, en modo juego y sin animaciones; a ~12 fotogramas por
  segundo para no repintar la barra a 60.

### Corregido
- «Preguntar a la IA» sobre un Word, Excel o LibreOffice (menú de Nautilus y Spotlight) enviaba solo el nombre del
  archivo; ahora manda su texto.

## [0.9.65] — 2026-11-12

### Nuevo
- Conversación por voz: puedes interrumpir a Helpert. Mientras contesta te sigue escuchando y, si le hablas, se calla
  y lo que dices es tu siguiente turno (también la frase con la que le cortaste). Durante la conversación su voz y el
  micrófono pasan por el cancelador de eco de PipeWire (`hf-dictate aec`), para que no se oiga a sí mismo por los
  altavoces; sin él, hay que hablarle claramente más alto que lo que el micrófono oye de los altavoces. Se puede
  apagar en Ajustes › Asistente de IA › «Interrumpir hablando» (`aiConvInterrupt`).

### Corregido
- Al callarte en la conversación, el turno tardaba ~4 s en llegar a Helpert: cada frase pasaba antes por la
  corrección de nombres con IA (`dictationAiFix`, hasta 3 s). En la conversación ya no (el asistente entiende un
  nombre mal oído); ahora llega 1,2 s después de que te calles (`aiConvSilence`).
- La X del panel del asistente no se podía pulsar con el panel a la izquierda: la zona que recibe el ratón se quedaba
  desplazada 24 px por la animación de entrada.

## [0.9.64] — 2026-11-12

### Nuevo
- Separadores en la barra: Ajustes › Widgets de la barra › «Añadir separador» pone una raya fina en la isla del
  widget elegido; se mueve como cualquier widget y se quita con «Quitar» o Supr. Junto a uno puesto a mano no se
  dibuja el separador automático entre información y utilidades.
- Panel del asistente renovado: cabecera con avatar y el proveedor debajo («Gemini · respaldo Ollama»), burbujas
  más limpias, campo de texto más alto con botón de dictado y sugerencias en una sola fila que se desplaza con la
  rueda. «Seguir en …» pasa a ser un botón con borde.
- `hf-remote rustdesk gpu`: el servicio de RustDesk usa la gráfica buena (lo hace también `hf-remote rustdesk instalar`).

### Corregido
- El clima no salía en la barra en una instalación nueva (desde la 0.9.62): sin datos el widget estaba oculto y,
  oculto, no pedía los datos.
- Iconos de la bandeja que salían como una tuerca o borrosos (RustDesk, Epic Games Launcher): si la app manda una
  imagen suelta de `/run` o `/tmp`, o un nombre de icono que el tema no tiene, se busca el del tema por el nombre o el
  título de la app (`RustDesk` → `rustdesk`, `Epic Games Launcher` → `epic-games`).
- Cambiar de fondo ya no reinicia el shell: `hf-apply` solo lo reinicia si cambió el código de `config/quickshell`
  en git (antes miraba la fecha de los archivos y cualquier edición sin guardar en git contaba).
- Con una gráfica `nouveau` además de la buena (p. ej. GT 710 + RX 6600), las apps abiertas desde la sesión usan la
  buena (`DRI_PRIME`): la ventana de conexión de RustDesk se cerraba al pintar con `nouveau`.
- Los pids del fondo en movimiento van en una carpeta privada (`$XDG_RUNTIME_DIR`, permisos 700).

## [0.9.63] — 2026-11-12

### Mejorado
- El shell ya no se va volviendo lento: en tu sesión no se recarga en caliente al actualizar (cada recarga dejaba
  ~20 MB sin liberar; tras muchas, 1,2 GB y medio segundo en abrir las notificaciones). Ahora `hf-apply` lo reinicia
  limpio cuando cambia su código, pero no con la pantalla bloqueada ni con un panel abierto: espera a que lo cierres.
  Medido: abrir las notificaciones pasa de ~500 ms a ~85 ms y la memoria de 1,2 GB a ~340 MB.
- La pantalla de bloqueo deja quieto el fondo en vídeo tras 2 minutos sin tocar nada (vuelve al mover el ratón o
  escribir). Con una gráfica `nouveau` en el equipo, el vídeo se decodifica por CPU: un 4K a 60 fps costaba ~1,4
  núcleos por pantalla toda la noche, también con las pantallas apagadas.

### Corregido
- El fondo en movimiento no se paraba al taparlo con ventanas si había una segunda pantalla con imagen fija propia:
  la regla «cubierto» pedía tapar también esa. Ahora solo cuentan las pantallas donde se ve el vídeo.
- Una sesión de prueba (`dev/try.sh`) ya no deja tu fondo en vídeo sin pausa: los pids del reproductor van por sesión
  (`$XDG_RUNTIME_DIR/hf-motion-<sesión>/`), y antes la de prueba sobrescribía los tuyos.

## [0.9.62] — 2026-11-12

### Nuevo
- Ajustes › Widgets de la barra: una sección propia para los widgets. Se ven las dos islas y se arrastra cada widget
  para cambiarlo de orden o pasarlo de la isla derecha a la izquierda (tras los espacios y el título). Con el teclado:
  ← → lo mueven y ↑ ↓ lo cambian de isla; también hay botones. «Orden de fábrica» lo deja como estaba.
- Cada widget con su interruptor y sus opciones (estilo y medidas del sistema, estado del cielo del clima).
- Clic derecho y rueda propios para cualquier widget: una orden por botón (p. ej. «playerctl next»).
- Widgets propios: una orden que se repite cada N segundos y enseña lo que escribe (texto, o JSON con texto, icono y
  ayuda), con su orden para el clic y para el clic derecho. Sin salida no ocupa sitio y con la pantalla bloqueada no corre.

### Cambiado
- Ajustes › Barra deja los widgets a la nueva sección; en «Módulos visibles» quedan espacios, título, música, red,
  batería, avisos y reloj.
- Las órdenes de los widgets propios y de los clics no salen al perfil público ni las puede cambiar el asistente.

## [0.9.61] — 2026-11-12

### Nuevo
- Registro del asistente: un botón en la cabecera del panel muestra cada petición (hora, panel/voz/terminal, quién
  respondió y con qué modelo, cuánto tardó, si contestó el respaldo, el error, lo que propuso) y cada acción aplicada.
  Se puede actualizar, copiar y vaciar; también `hf-ai activity` y `qs ipc call sidepanel log`.

### Mejorado
- Con un respaldo configurado, el panel ya no espera hasta 2 minutos a Gemini cuando se atasca: a los 30 s responde el
  respaldo (en la voz, a los 10).
- El icono «Seguir en …» de la cabecera se oculta también cuando no hay ninguna herramienta.

## [0.9.60] — 2026-11-12

### Mejorado
- El botón del panel del asistente ya no es solo «Continuar en Claude»: «Seguir en … ↗» lleva la conversación y el
  contexto elegido a la herramienta de IA que uses. Reconoce T3 Code, Claude Desktop, Cursor y Zed (se abren con la
  conversación en el portapapeles) y Claude Code, Codex, Gemini CLI, Qwen Code y opencode (la reciben como primer
  mensaje en la terminal); para cualquier otra se escribe su orden con `{prompt}` o `{file}`. Se elige en Ajustes ›
  Asistente de IA › Integraciones; en «Automática» usa la de tu proveedor o la primera instalada, y sin ninguna no hay
  botón. La copia en archivo queda en `$XDG_RUNTIME_DIR`, solo legible por ti.

## [0.9.59] — 2026-11-12

### Mejorado
- Ajustes con un solo selector: las «pastillas» sueltas (Escala, Margen, Esquinas, Distancia…) son ahora el mismo
  control segmentado que el resto, con los segmentos igual de anchos; antes convivían dos estilos, a veces en la misma
  tarjeta.
- Las acciones que parecían texto («Actualizar», «Probar», «Vaciar historial», «Olvidar», «Abrir»…) llevan borde de
  botón; los enlaces que solo llevan a otra sección siguen como enlace, sin la flecha repetida.

### Corregido
- Panel del asistente: un aviso de QML al quitar mensajes (texto sin definir durante un instante).

## [0.9.58] — 2026-11-12

### Rendimiento (sin cambiar cómo se ve)
- El fondo en vídeo se pausa detrás del bloqueo (que ya reproduce su propia copia) y de Energía, Bienvenida y la
  vista general: Hyprland ya no rehace el desenfoque en cada fotograma de algo que no se ve moverse.
- Con fondo en vídeo se suelta la imagen fija que quedaba cargada debajo (unos 9 MB por pantalla, más su textura).
- Juegos y vídeo a pantalla completa van directos a la pantalla, sin componer (`render:direct_scanout = 2`).
- El tiempo no se vuelve a pedir al abrir el panel si la previsión tiene menos de 15 minutos.
- La isla de recursos de la barra tiene ancho fijo para sus cifras: no cambia de tamaño (ni recoloca la barra)
  cada vez que la CPU pasa de 9 % a 10 %.

### Corregido
- Relojes del mundo en «--:--» durante los primeros 10 minutos: el proceso salía con la lista vieja.
- Atajos con nombres en inglés («APOSTROPHE», «SEMICOLON») en Teclado: ahora «'» y «;».
- Textos cortados en Ajustes: las explicaciones de cada fila pasan a dos líneas en vez de acabar en «…», y las
  órdenes largas (Acerca, regla de PiP) ya no se parten a mitad de palabra.
- La barra lateral de Ajustes se funde en los bordes en vez de cortar el primer y el último elemento.
- Zonas horarias en español («Lima · Perú» en vez de «America · Lima») en la Bienvenida y en Fecha y hora.
- Contradicciones: el interruptor de plugins de Omarchy, la dirección del buscador web (solo con «Otro»), las
  acciones de Wi-Fi con el Wi-Fi apagado, OBS repetido en «Siempre opacas» y la ubicación por IP con ciudad fija.
- Sin emojis en los títulos de Descargas; «punto de restauración» en vez de «snapshot» en Energía.
- Fuera de las cabeceras los nombres internos (claves de ajustes y rutas del proyecto).

### Cambiado
- «Apps de HyprFrijol» (los niveles con instalar y quitar) pasa de Ajustes › Aplicaciones a una categoría propia
  del Centro de aplicaciones: Ajustes es solo para ajustes.
- Instalaciones nuevas: el portapapeles y el historial del asistente se borran a los 30 días (antes, nunca). Quien
  ya tenía ajustes guardados conserva «nunca» y «siempre» (`hf-apply` los escribe una vez); se puede cambiar en Portapapeles y en Asistente de IA › Privacidad.

## [0.9.57] — 2026-11-12

### Documentación
- Pendientes al día: cerrados rendimiento, dictado, productividad (los recorridos del plan en tres pasos o menos) y
  las animaciones entre paneles. Quedan tus pruebas con uso real y, en los planes, el espaciado de Math.

## [0.9.56] — 2026-11-12

### Mejorado
- Dictado: «¿» y «¡» de apertura en las preguntas y exclamaciones en español (los motores solo ponían el de cierre);
  en inglés no se tocan. Medidos los motores con 10 frases, 4 voces y ruido de fondo: Parakeet, el de serie, se
  equivoca en el 9 % de las palabras y tarda 0,13 s por frase (Whisper small: 12 % y 1 s; Vosk: 17 % y 0,3 s).

## [0.9.55] — 2026-11-12

### Mejorado
- Paneles que se transforman unos en otros: al saltar de uno a otro sin cerrar (de Spotlight a energía, del centro
  de control a actualizaciones, de la música al centro de control…) se ve una sola tarjeta que cambia de forma. Antes
  solo lo hacían los paneles de la barra y el centro de control; ahora también Spotlight, energía, actualizaciones,
  fondos, widgets, música y atajos. Con «Reducir movimiento» no se anima.

## [0.9.54] — 2026-11-12

### Mejorado
- Chat del asistente: cada mensaje nuevo (o cada cambio de estado, como aplicar un paso) destruía y volvía a crear
  todas las burbujas de la conversación, con su Markdown e imágenes. Ahora solo se crea la nueva: menos CPU al
  responder y un 40 % menos de memoria retenida en conversaciones largas.
- `dev/perf.sh -c N`: prueba de fugas (abre y cierra todas las vistas y secciones N veces y da la memoria tras cada
  vuelta y al descargarse).

## [0.9.53] — 2026-11-12

### Seguridad
- `hf-perfil aplicar` (y `./install.sh --perfil`) pregunta antes de abrir el acceso remoto (SSH, Tailscale,
  RustDesk); sin terminal solo lo hace con `--acceso-remoto`. El perfil del repo es público: abrir el equipo a la red
  no puede ir solo por venir en él. Los paquetes sí se instalan (instalarlos no abre nada).

### Corregido
- Las pruebas en un Hyprland anidado (`dev/try.sh`, `dev/check.sh`, `dev/perf.sh`) tumbaban el portal de documentos
  de tu sesión al cerrarse (`xdg-document-portal.service` fallido, código 21): desmontaban `/run/user/…/doc`, que
  es compartido. Ahora la prueba no arranca un portal de documentos propio.

## [0.9.52] — 2026-11-12

### Añadido
- El asistente busca fotos en Unsplash y las pone de fondo o las añade a los tuyos, como con Wallhaven (también por
  MCP: `unsplash_search`, `unsplash_wallpaper`). Nombra al autor, como pide Unsplash.
- `perfil/perfil.json` en el proyecto: el equipo de referencia sin datos personales (paquetes, apps, servicios,
  acceso remoto, voz, dictado, modelos locales, login y ajustes de aspecto). `./install.sh --perfil` lo aplica; los
  ajustes se suman a los tuyos con copia de los de antes. `hf-perfil publicar` lo rehace.

## [0.9.50] — 2026-11-12

### Seguridad
- `hf-remote acceso on`: el cortafuegos se pone antes de arrancar sshd y, sin cortafuegos, no se arranca (antes SSH
  quedaba abierto a cualquier red). Con firewalld se quita `ssh` de la zona por defecto (en Fedora venía abierto a
  todas las redes): solo Tailscale y, si quieres, tu red local. Con ufw avisa si ya había una regla que abre SSH a
  cualquier red.
- Asistente: un bloque ```json``` de ejemplo en la respuesta ya no se convierte en un plan; las formas sueltas (un
  objeto, uno por línea) solo valen en un bloque `hf-actions`.

## [0.9.49] — 2026-11-12

### Añadido
- **IA local de respaldo**: Ollama en la gráfica (`ollama-vulkan`, nuevo en el instalador) con gemma4:e4b, el mejor
  de 7 modelos probados (18/18 órdenes de voz, 0,5 s; la tabla está en `docs/IA.md`). Si Gemini falla o tarda,
  contesta el local; en la voz la espera a Gemini es de 10 s.
- **Voz con el modelo local primero** (Ajustes › Asistente de IA › Modelos, `aiVoiceLocal`): la voz pregunta a Ollama
  (menos de 1 s) y Gemini o Claude quedan de respaldo.
- **`hf-perfil`**: guarda lo que tiene tu equipo (paquetes, apps, servicios, acceso remoto, voz, dictado, modelos
  locales, login y ajustes) y lo deja igual en otro con `./install.sh --perfil=perfil.json`. `hf-update` lo guarda
  antes de cada actualización. Sin claves ni contraseñas.
- `hf-remote acceso on|off|status`: SSH, cortafuegos (ufw o firewalld) y Tailscale de una vez;
  `hf-remote rustdesk instalar`. En el instalador: servidor SSH y AnyDesk (solo saliente).

### Corregido
- Modelos pequeños: entienden más órdenes. Las instrucciones llevan ejemplos del formato, se arregla
  `{"type":"barPos",…}` (sin «set»), se aceptan acciones sueltas o una por línea y la fecha de los próximos 7 días
  va en el contexto («el viernes» caía en la semana siguiente).
- Ollama: contexto de 16.384 tokens (con 4.096 se cortaban las instrucciones), cargado 30 min y sin «pensar»
  (los modelos que piensan tardaban más de 30 s).
- Si un servidor de IA dejaba de responder a mitad de la respuesta, la petición fallaba sin pasar al respaldo.

## [0.9.48] — 2026-11-12

### Corregido
- Conversación por voz:
  - «Sí, hazlo» no aprobaba el plan: la «í» no contaba como letra al buscar el «sí».
  - Si el asistente proponía cambios sin texto, Helpert solo decía «¿Lo hago?»; ahora lee los pasos.
  - Con ruido de fondo el turno no terminaba nunca: ahora dura 40 s como mucho.
  - Lo que Whisper «oye» en el ruido («Mm-hmm», «Gracias.», «Subtítulos…») cuenta como silencio y no se le
    pregunta al asistente.

## [0.9.47] — 2026-11-12

### Corregido
- El asistente se inventaba la hora («¿qué hora es?» por voz): ahora siempre sabe la fecha y la hora local.
- Voz y Spotlight con Gemini usan el modelo ligero (Flash-Lite) si no eliges otro en «Modelo rápido»: el Flash
  del plan gratuito tardaba 30-40 s o fallaba por saturación.

### Añadido
- Pruebas de la conversación por voz sin micrófono: `qs ipc call dictado conversationFiles "a.wav,b.wav"` (cada
  audio es un turno tuyo; al acabarse, termina).

## [0.9.46] — 2026-11-12

### Corregido
- `hf-greeter-sync` avisaba de que faltaba QtMultimedia (fondo en vídeo del login) aunque estuviera instalado.

## [0.9.45] — 2026-11-12

### Seguridad
- Las capturas del asistente (modo compañero, «+ Captura», leer la ventana) ya no se hacen si Hyprland no responde:
  antes, sin poder comprobar si había un gestor de contraseñas a la vista, se daba por bueno. El modo compañero
  captura solo la pantalla activa (si no se sabe cuál, no captura), crea el archivo ya privado y lo borra si
  aparece una app privada mientras tanto.

## [0.9.44] — 2026-11-12

### Añadido
- **Modo compañero** (Ajustes › Asistente de IA, apagado por defecto): de vez en cuando Helpert mira la pantalla
  activa y empieza él la conversación por voz: ofrece ayuda, pregunta cómo vas o comenta lo que ve. Si no ve nada
  que decir, calla. Cuándo:
  - cada 20, 45 o 90 minutos (a elegir, con algo de azar), o 1,5 veces más si tienes mucho abierto o el equipo
    trabajando;
  - antes, si el equipo va muy cargado 3 minutos seguidos, o tras una hora seguida sin descanso;
  - nunca en pantalla completa, en llamadas, en «no molestar», con el pomodoro de foco, en modo sin distracciones,
    si no estás o en los primeros 15 minutos.
  Las capturas van a `~/.cache/hyprfrijol/capturas_tmp_ai` (solo tuya; las 20 últimas, un día como mucho) y nunca
  se hacen con un gestor de contraseñas a la vista. Si no contestas, se va sin insistir.
- **Aprobar por voz**: cuando en una conversación el asistente propone cambios (sus herramientas: ventanas, apps,
  ajustes, música, temporizadores…), pregunta «¿Lo hago?» y basta con decir «sí» o «no».

## [0.9.42] — 2026-11-12

### Añadido
- **Ajustes › Bloqueo e inicio de sesión**: personaliza la pantalla de bloqueo y el login con los temas de
  Apariencia (las paletas del sistema y las tuyas) y con tus fondos (de la colección o cualquier imagen).
  - Bloqueo, con vista previa en vivo: tema, fondo (imagen, desenfocada, paisaje o color liso), oscurecido,
    disposición (izquierda, centro, derecha), estilo del reloj y qué mostrar (fecha, tiempo, música, batería,
    no molestar).
  - Login: tema, fondo (imagen o vídeo, o paisaje), pantalla de reposo, movimiento y qué mostrar (reloj, fecha,
    nombre del equipo, batería, red, distribución del teclado, apagar y reiniciar; la accesibilidad siempre).
    «Ver el login» lo abre en vista previa (Esc sale). Los cambios se copian solos al login (`hf-greeter-sync --auto`).

## [0.9.41] — 2026-11-12

### Añadido
- **Conversación por voz con el asistente**: Super + Alt + H (o el micrófono en modo «asistente») la activa y
  la desactiva. Escucha, al callarte (≈1,2 s, ajustable) le pasa lo dicho al asistente, Helpert contesta en voz
  alta con frases cortas y vuelve a escuchar. Mientras Helpert habla no escucha (no se oye a sí mismo); si tarda,
  dice «Un momento.». Termina pulsando otra vez, con el botón de la píldora, diciendo «adiós» / «eso es todo» o
  tras un rato en silencio. «Una pregunta» en Ajustes › Asistente de IA vuelve al modo de antes.

### Cambiado
- **Solo Helpert para la voz**: se quita la voz de Gemini; respuestas, avisos y saludos los lee siempre Helpert
  (Piper, local, sin internet y sin esperas). Sin la voz instalada, `hf-ai speak` lo dice y ofrece instalarla.

## [0.9.40] — 2026-11-12

### Cambiado
- **Entrar con RustDesk** en lugar de AnyDesk (Ajustes › Escritorio remoto). AnyDesk no acepta conexiones
  entrantes en Wayland ni con el portal (lo dicho en 0.9.37 era un error: corta con «servidor de pantalla no
  admitido» sin llegar a pedir nada). RustDesk sí usa el portal RemoteDesktop que instala `hf-remote rustdesk portal`;
  la primera conexión se acepta en el equipo marcando «recordar». Se quita la aprobación automática de AnyDesk
  (`hf-remote picker`, `remoteUnattended`): ya no tenía uso.

## [0.9.39] — 2026-11-12

### Seguridad
- AnyDesk sin nadie delante: la aprobación de una vez por conexión se reclama de forma atómica (dos peticiones a la
  vez ya no pasan las dos) y solo en la carpeta privada de la sesión (sin ella no se aprueba nada); los id de app
  admitidos son exactos (`com.anydesk.Anydesk`, `com.rustdesk.RustDesk`), no prefijos.

## [0.9.38] — 2026-11-12

### Cambiado
- AnyDesk sin nadie delante (`remoteUnattended`): ahora es opcional (desactivado por defecto), aprueba una sola
  vez por conexión entrante y nunca a una app aislada (Flatpak/Snap, que el portal identifica por su id), para que
  otra app que pida controlar el equipo justo después no aproveche el permiso.

## [0.9.37] — 2026-11-12

### Añadido
- **Entrar a esta sesión con AnyDesk** (Ajustes › Escritorio remoto › Entrar con AnyDesk o RustDesk). AnyDesk 8
  necesita en Wayland el portal RemoteDesktop, que el portal de Hyprland (xdph 1.5.0) aún no trae: sin él caía a
  X11 y no veía nada. `hf-remote anydesk portal` instala xdph con la parte de control remoto (PR #448, fijada a un
  commit revisado; `install/pkgbuilds/xdg-desktop-portal-hyprland-rd`, Arch). Como nadie puede aceptar en pantalla
  cuando entras desde otro equipo, `remoteUnattended` (activado) aprueba solo las peticiones que llegan justo
  después de que AnyDesk acepte una conexión entrante, y comparte la pantalla elegida para RDP; el resto (Meet,
  otras apps) sigue preguntando. Se prepara solo al iniciar sesión (`hf-remote anydesk boot`).

### Corregido
- `hf-remote`: un ajuste puesto a `false` en tus ajustes se ignoraba y ganaba el valor por defecto.

## [0.9.36] — 2026-11-12

### Añadido
- **Fondos de Unsplash** (Ajustes › Fondos › Unsplash), como los de Wallhaven: buscar fotos (sin texto, el tema
  «Wallpapers»; populares o recientes), «Añadir a mis fondos» o «Poner», y usarlo como origen del cambio automático
  y de «Al azar» (`wallpaperSource = "unsplash"`). El selector de fondos (Super + W) trae una foto nueva con «Traer de
  Unsplash» y nombra a su autor. Unsplash no tiene API sin clave: pide una «Access Key» gratuita
  (unsplash.com/developers), que va al llavero, nunca a settings.json. Las fotos se bajan a la medida de tu pantalla,
  con caché limitada (`unsplashCacheMB`). `hf-unsplash` / `hf-wallpaper unsplash …`.

## [0.9.35] — 2026-11-12

### Corregido
- Escritorio remoto (RDP): el servicio vuelve a comprobar que hay contraseña justo antes de arrancar `hypr-rdp`
  (se reintenta solo y el archivo pudo borrarse o vaciarse entre medias); sin ella se para y no se reintenta.

## [0.9.34] — 2026-11-12

### Añadido
- **Entrar desde Windows con «Conexión a Escritorio remoto» (mstsc)** a esta misma sesión: Ajustes › Escritorio
  remoto › «Entrar desde Windows (RDP)», con hypr-rdp (AUR). Por defecto solo escucha en la IP de Tailscale; pide tu
  usuario y una contraseña propia de RDP (sin ella no arranca), se activa al iniciar sesión y deja elegir la
  pantalla que se ve (o una pantalla nueva solo para la conexión). `hf-remote rdp status|start|stop|password`.

### Cambiado
- Ajustes › Escritorio remoto ya no dice que en Hyprland no hay servidor RDP.

## [0.9.33] — 2026-11-11

### Cambiado
- **Paneles más rápidos al abrir**: los botones de la barra (chips, música, centro de control, aplicaciones) abren
  al pulsar, no al soltar, y la animación de entrada arranca un fotograma antes. Pulsar fuera de un panel lo cierra
  también al pulsar.
- **El centro de control ya no se atasca la primera vez**: al abrirse preguntaba enseguida a `adb` por el móvil, y
  la primera vez tras arrancar eso paraba la interfaz 120-170 ms en plena animación. Ahora esas comprobaciones van
  cuando ya ha aparecido, y el panel se dibuja una vez, invisible, al cargarse. Primera apertura: de unos 100 ms con
  un parón de 160 ms a unos 50 ms sin parón (medido en una sesión anidada).

### Añadido
- **Paneles que se transforman uno en otro** (prueba): con el panel de un chip de la barra abierto (música, clima,
  sistema, impresora, pomodoro, unidades, descargas) o el centro de control, un clic en otro botón de la barra no
  cierra uno y abre el otro: la tarjeta se estira hasta el sitio y el tamaño del nuevo mientras cambia el contenido.
  Con el panel abierto la barra sigue funcionando; pulsar su fondo lo cierra. «Reducir movimiento» lo quita.

## [0.9.32] — 2026-11-11

### Corregido
- La lista de conversaciones del asistente vuelve a enseñar la fecha de cada una («Hoy · 22:15», «Ayer»…): le
  faltaba un import y daba «Time is not defined».
- `dev/lint.sh` (`dev/coherencia.py`) avisa de cualquier .qml que use un singleton sin importar su carpeta.

## [0.9.31] — 2026-11-11

### Añadido
- **Letras de canciones** en el panel de música (Super + M): la línea que suena, grande, y la siguiente; si la
  letra no está sincronizada, el texto entero. Las da lrclib.net (gratis y sin cuenta); como eso es mandar a un
  servicio de fuera el artista y el título de lo que escuchas, se activa a mano con «Ver la letra» en el propio
  panel y se quita con «Ocultar letras» (`musicLyrics`, apagado por defecto).

## [0.9.30] — 2026-11-11

### Añadido
- **Puntos de restauración es una app** (lanzador propio): la lista de snapper con «Crear ahora», «Ver cambios» y
  «Restaurar archivos». En Ajustes › Sistema queda un resumen con el botón para abrirla.
- **Perfil de energía al enchufar y al desenchufar** (Ajustes › Energía, solo con batería): ahorro, equilibrado o
  rendimiento para cada caso (`powerProfileAC`, `powerProfileBattery`); si lo cambias a mano, se respeta hasta el
  siguiente cambio.

### Cambiado
- Ajustes › Almacenamiento ya no repite la lista de unidades extraíbles del icono de la barra: dice cuántas hay y
  «Ver las unidades» abre ese menú.
- Los lanzadores de las apps del shell llevan la ruta entre comillas (carpetas con espacios).

## [0.9.29] — 2026-11-11

### Añadido
- **Super + Ctrl + Tab salta a la otra pantalla** (Super + Tab sigue siendo la vista general).
- **Elegir en qué pantalla salen los avisos** (Ajustes › Notificaciones › Avisos emergentes › Pantalla: la que tiene
  el foco, la principal o una concreta; `notifyScreen`). Solo aparece con más de una pantalla.
- **Reloj en la barra sencilla** de las otras pantallas (Ajustes › Barra, `barSecondaryClock`).
- **Cerrar un proceso desde el monitor del sistema**: la «x» de cada fila (dos clics; se le pide que se cierre,
  así puede guardar antes).

### Nota
- En la 0.9.28, el ahorro de CPU con dos pantallas no se pudo medir en una sesión real: con música sonando, la onda
  de audio de la barra es lo que más gasta.

## [0.9.28] — 2026-11-11

### Añadido
- **La barra en cada pantalla** (Ajustes › Barra › Comportamiento): una fila por monitor para elegir barra
  completa, sencilla (sus espacios y lo que gasta cada programa) o ninguna (`barScreens`). Antes solo se podía
  elegir entre todas las pantallas o solo la principal, y la completa era siempre la de la principal.
- **Paquete para el AUR** (`hyprfrijol-git`) en `packaging/aur/`, generado desde `install/packages.tsv`
  (`dev/gen-pkgbuild.py`): instala en `/opt/hyprfrijol` con las entradas de sesión. `install.sh` respeta la
  sesión que pone el paquete y `hf-update` (y Ajustes › Sistema) dicen que se actualiza con el ayudante del AUR.

### Mejorado
- Menos CPU en reposo con dos pantallas: el consumo por programa de la barra sencilla lee los procesos cada 4 s y
  el análisis de cada lectura se salta el trabajo que no hace falta.

## [0.9.27] — 2026-11-11

### Añadido
- **Deshacer al borrar una conversación del asistente** (8 s, «Deshacer» bajo la lista de conversaciones).
- **Las descargas a medias se reanudan al iniciar sesión** (Ajustes › Almacenamiento › «Reanudar al iniciar
  sesión», `downloadsResume`).
- **El buscador de Ajustes encuentra también las tarjetas propias**: Wallhaven, Calendarios (.ics), Mis temas,
  Nombres de los espacios, VPN de empresa, Diagnóstico, Modo seguro, Actualizaciones de HyprFrijol… y «Restaurar
  valores por defecto» de esas secciones restaura también sus claves.
- `hf-apps` comprueba la suma sha256 de las AppImage y paquetes Flatpak que baja de GitHub (la que publica GitHub o
  el SHA256SUMS de la release); si no coincide, no instala nada.
- `dev/lint.sh` comprueba que cada clave de ajustes tiene valor por defecto, que cada programa que usa el código está
  en `install/packages.tsv` (`dev/coherencia.py`) y que el índice de búsqueda de Ajustes está al día.

### Corregido
- El pomodoro y el temporizador cuentan por reloj: tras suspender el equipo siguen donde toca.
- Los eventos diarios o semanales que empezaron hace muchos años vuelven a salir en la agenda.
- Convertir un PDF a PNG ya no pisa las páginas de otra conversión; el OCR de un PDF va página a página en
  `~/.cache` (antes un PDF grande llenaba `/tmp`).
- Un tema propio llamado «Rosa claro» ya no pisa la variante clara de «Rosa».
- El shell arranca aunque la carpeta del proyecto tenga espacios o paréntesis (`hf-shell` y las órdenes de
  Hyprland escapan la ruta).
- Valores por defecto que faltaban (`dimInactive`, `workspaceAnim`, `dragSnap`, `floatRemember`, `lazyModules`,
  `startSplash`, `timerMin`…); fuera las claves sin uso `widgetsOnDesktop` y `dictation`.

## [0.9.26] — 2026-11-11

### Añadido
- **Comandos por voz nuevos** (antes iban a la IA):
  - «apaga / reinicia / suspende el equipo», «cierra sesión»: abren el menú de Energía con esa opción marcada, y
    no se hace nada hasta que pulsas Intro o haces clic;
  - «silencia el micro» / «activa el micrófono»;
  - «qué hora es», «qué día es hoy»: lo contesta la píldora sin preguntar a la IA;
  - «recuérdame llamar a mamá mañana», «añade una tarea comprar leche», «apunta …»: tarea en la agenda, con fecha si
    dices hoy, mañana o pasado mañana (con una hora concreta sigue yendo al asistente);
  - «pon el volumen a tope», «vete al escritorio dos», «enciende el modo oscuro», «me pones …».
- Se entienden las frases con cortesía delante: «¿puedes subir un poco el volumen?», «me podrías…», «quiero que…».

## [0.9.25] — 2026-11-11

### Añadido
- **Deshacer** unos segundos después de borrar:
  - en **Tareas**, al borrar una tarea o «Borrar las hechas» (botón abajo y Ctrl + Z);
  - en la **agenda**, al borrar una tarea («Deshacer» bajo la lista);
  - en el **historial de avisos**, al pulsar «Vaciar historial» (el mismo botón pasa a «Deshacer»).
- Historial de avisos: al copiar un aviso con un clic, pone «Copiado».
- Spotlight: si no hay nada (con la IA y la web apagadas), una fila «Nada coincide» con los prefijos.
- Alt + Tab: el pie recuerda que Q cierra la ventana elegida y Esc cancela.

### Arreglado
- Los botones que solo aparecen al pasar el cursor (papelera de tareas, quitar un aviso) ya no reciben clics ni el
  foco del teclado mientras están invisibles.
- Botones pequeños más fáciles de acertar: los de menos de 24 px aceptan el clic en un margen alrededor (quitar
  adjuntos en el asistente, flechas del pomodoro, cerrar avisos), igual que cerrar en la vista de espacios y las
  flechas del editor de widgets, que además enseñan la mano.

## [0.9.24] — 2026-11-11

### Cambiado
- **Más apps fuera de Ajustes** (Ajustes es para ajustes): tres partes de uso diario pasan a su propia ventana, con
  lanzador en el menú de apps y en Spotlight. En Ajustes queda lo que se configura y un botón para abrirlas.
  - **Conexiones remotas**: conectarse, añadir y editar las conexiones guardadas (RDP, VNC, SSH, SPICE). Los clientes y
    compartir este escritorio siguen en Ajustes › Escritorio remoto.
  - **Máquinas virtuales**: encender, apagar y abrir tus máquinas, y tus contenedores de Distrobox. Lo que hay que
    instalar, Cockpit y las otras apps siguen en Ajustes › Máquinas virtuales.
  - **Cola de impresión**: los trabajos pendientes, para cancelarlos. Las impresoras y los escáneres siguen en
    Ajustes › Impresoras y escáneres, que cuenta los trabajos y tiene «Ver la cola».
  - Se abren también con `qs -p <repo>/config/quickshell ipc call remoto|maquinas|impresion open`.
  - Hace falta `hf-apply` una vez para los lanzadores y para que sus ventanas floten centradas.

## [0.9.23] — 2026-11-11

### Cambiado
- **Menos trabajo en reposo**: el shell ya no lanza ningún programa mientras no haces nada (medido en una sesión de
  prueba: de 0,13 % a 0 % de un núcleo en procesos lanzados).
  - Con ventanas flotantes, el dock inteligente o un PiP, las posiciones se preguntan a Hyprland por su socket en vez
    de lanzar `hyprctl` cada 600 ms.
  - El modo cafeína ya no se comprueba cada 30 s: `hf-caffeine` avisa al shell cuando cambia.
  - Con cable, la red ya no se sondea cada 30 s (los cambios llegan por `nmcli monitor`).
  - `nvidia-smi` pasa de cada 2 s a cada 10 s, salvo con el monitor del sistema abierto (en portátiles dejaba la
    gráfica despierta).
  - La pastilla de recursos, el clima, la impresora y la onda de sonido dejan de leer datos con la barra escondida
    (Super + J) o la sesión bloqueada.
  - La cola de descargas sin nada activo ya no se relee cada 8 s.
- **Consumo por programa** (barra de la pantalla secundaria y monitor del sistema): la memoria es la propia de cada
  programa, sin las bibliotecas y la memoria compartida que antes contaban una vez por proceso (Chrome salía con
  gigas de más). Un programa que tira de la CPU (10 % o más) se ve siempre, aunque gaste poca memoria y haya muchos.

## [0.9.22] — 2026-11-11

Revisión completa del proyecto: unos 70 fallos corregidos. Lo que se nota:

### Arreglado
- **Tus ajustes ya no se pueden perder**: si `settings.json` queda roto (una coma de más al editarlo a mano), ni el shell ni `hf-apply set` lo pisan con un archivo casi vacío; se guarda una copia en `settings.json.roto`. Si otro programa (el asistente, `hf-apply set`) escribe a la vez que tú cambias algo, se conservan los dos cambios. Los archivos enlazados desde tus dotfiles siguen siendo enlaces.
- **«Ciudad del clima» funciona**: al escribir una ciudad en Ajustes › Escritorio se busca y el pronóstico pasa a ser el suyo (antes no hacía nada). Vacía, vuelve a la ubicación por IP. Si no hay red al arrancar, el clima reintenta al minuto.
- **Tareas**: Esc cancela la edición en vez de cerrar la ventana; los filtros van con Alt + 1, 2, 3; las hechas salen con la última arriba; y la fecha se escribe como quieras: «hoy», «mañana», «vie», «12 nov», «12/11» (una fecha imposible ya no se guarda). En Spotlight, `+tarea hoy`.
- **Asistente**: las conversaciones largas ya no fallan al enviarse ni dejan de guardarse; abrir una conversación antigua no la sube a «Hoy»; no se pueden aplicar dos planes a la vez (el segundo salía como hecho sin haberse ejecutado).
- **Contraseña de administrador**: si pulsaste el ojo una vez, las siguientes peticiones vuelven a ocultarla.
- **Descargas**: tras reiniciar, pausar o cancelar una descarga antigua ya no puede cerrar otro programa; los enlaces de dropbox.com o linux.com no se confunden con x.com.
- **Unidades**: «Expulsar todo» no toca discos internos en puertos con conexión en caliente; expulsar sin nombre no expulsa la primera unidad sin etiqueta.
- **Modo seguro**: restaurar la copia más antigua con 12 guardadas ya no la borra a mitad (dejaba la carpeta de ajustes vacía).
- **Fondo en vídeo por pantalla**: al activar «Reducir movimiento» se paran de verdad los reproductores.
- **Otras distros**: el centro de actualizaciones funciona con dnf, apt, zypper y xbps (antes solo pacman); `hf-vm` y `hf-vpn` detectan bien Debian y Fedora; el login visual se instala también con doas y copia el fondo en vídeo.
- **Terminal elegida**: «> comando» de Spotlight y las instalaciones usan la terminal de Ajustes › Predeterminadas; GNOME Console funciona (su programa es `kgx`); si la terminal elegida ya no está, se usa kitty.
- **Ajustes**: quitados tres interruptores que no hacían nada (botón PiP, PiP automático, sincronizar automáticamente) y el segundo interruptor del título de ventana; «Restaurar valores por defecto» ya no borra tus datos (conexiones remotas, servidores MCP, órdenes de voz, atajos); la velocidad de repetición del teclado marca la opción real; enlaces que abrían la sección equivocada; «Restablecer» la personalidad del asistente vuelve a la de fábrica; la búsqueda encuentra las filas de Usuarios.
- **Textos**: «1 activa», «1 archivo», «Sin conectar»; la hora respeta el formato de 12 h en el bloqueo, la impresora y el historial del asistente; sin emojis en los avisos de alarma y temporizador.
- **Temas propios** sin matugen (Debian, Ubuntu) y **Wallhaven** con el servidor caído ya no fallan sin explicación; **Firmar** detecta PyMuPDF antiguo.

### Cambiado
- **Menos trabajo en segundo plano**: guardar una alarma, un reloj o una orden de voz ya no relanza `hf-apply`; cambiar cualquier ajuste ya no vuelve a bajar los calendarios ni recalcula los relojes del mundo; el reloj de alarmas solo corre si hay alguna; la cola de descargas no se recalcula si no cambió.
- «Reducir movimiento» y el preajuste «Ninguno» se respetan en más sitios (dock, agenda, bloqueo, barra).
- Dependencias nuevas en el instalador: PyMuPDF y PyGObject (Firmar, enviar al móvil), `pacman-contrib` (Arch) y QtMultimedia pasa a instalarse por defecto (vídeo en el bloqueo y el selector de fondos).

## [0.9.21] — 2026-11-11

### Cambiado
- **Ajustes es para ajustes**: lo que eran apps dentro de Ajustes ahora va por fuera.
  - **Tareas es una app propia**: su ventana (flotante, centrada), en el menú de apps y en Spotlight («Tareas»), con `hf-tareas` y su atajo global `hf:tareas`. Agrupa vencidas, hoy, mañana, más adelante, sin fecha y hechas; fecha rápida al añadir (sin fecha, hoy, mañana u otro día), editar con doble clic o el lápiz, y filtros Pendientes · Hechas · Todas (1, 2, 3). La agenda tiene «Todas las tareas ›».
  - **Alarmas**: se gestionan en su ventana (la del pomodoro); Ajustes › Productividad › Agenda solo tiene el botón para abrirla.
  - **Apps instaladas**: la lista con «Desinstalar» pasa al Centro de aplicaciones, categoría «Instaladas». Ajustes › Aplicaciones se queda con las fuentes de software, los niveles de HyprFrijol y los botones para abrir el Centro.
  - Ajustes › Productividad tiene un apartado «Apps» para abrir Tareas, Alarmas y el Pomodoro.
- **Barras de progreso sin parones**: los datos llegan a saltos (las descargas cada 1,5 s, la instalación por pasos, el pomodoro cada segundo) y la barra llegaba al valor y se quedaba quieta hasta el siguiente. Ahora avanza sin pararse durante ese rato, un brillo recorre lo hecho mientras trabaja, en los pasos largos sigue avanzando despacio, y sin tamaño conocido un tramo va y viene. Descargas (lista y anillo de la barra), modelos del dictado, instalación de apps, pomodoro, impresora 3D y la cuenta atrás de «¿Se ve bien?».


### Añadido
- **Dictado: nombres bien escritos**. El reconocedor oye bien el español pero confunde nombres propios, grupos, creadores, marcas y términos de internet con palabras que suenan parecido («mi dev», «Fo Fitters»). Ahora se corrigen al acabar cada frase:
  - **Vocabulario con cualquier motor**: lo que suene como una palabra de tu vocabulario (Ajustes › Dictado, separadas por comas) se escribe así, también con Parakeet y Vosk, que antes lo ignoraban. Sin conexión y al momento: «midu dev» → midudev, «fu faiters» → Foo Fighters, «iper land» → Hyprland.
  - **Corregir con la IA** (Nunca · Al hablar con el asistente · Siempre): cada frase pasa por el modelo rápido de tu asistente, que sabe de grupos, streamers, programas e internet («Busca en Show to el último y tetro de Guy en The Witch» → «Busca en YouTube el último directo de Ibai en Twitch»). Con Gemini usa Flash-Lite (~1–2 s). No responde ni traduce lo que dictas, y si tarda más de 3 s se escribe lo que se oyó. Por defecto solo al hablar con el asistente, porque al dictar en otras apps el texto saldría de tu equipo.
- `hf-ai dictfix` para probar la corrección desde la terminal.


### Seguridad
- **Servidores MCP: la conversación no olvida lo que ya leyó**. «Consultar sin preguntar» deja de valer en toda la conversación (no solo en esa respuesta) si alguna respuesta anterior consultó algo o si hay imágenes o documentos adjuntos: a partir de ahí también esas consultas te piden confirmación.

### Corregido
- `hf-ai chat -` leía la entrada dos veces y llegaba vacía.

## [0.9.18] — 2026-11-11

### Seguridad
- **Servidores MCP: todo se confirma por defecto**. Que una herramienta sea «de solo lectura» lo dice el propio servidor, así que ya no basta para usarla sin preguntar: el asistente te enseña lo que va a mandar y esperas a confirmarlo, y lo que responda aparece en el chat. Para que consulte sin preguntar hay una opción nueva por servidor, «Consultar sin preguntar», y aun con ella no lo hace después de haber leído datos en la misma respuesta (resultados de consultas, capturas o imágenes) ni si no le dejas consultar el escritorio.
- **Las claves no salen de su servidor**: con dirección, el servidor tiene que ser https (http solo para uno en este equipo) y no se siguen redirecciones, así la clave nunca va a otra dirección.
- **Herramientas al día**: si cambias el comando, la dirección o la variable de la clave de un servidor, sus herramientas guardadas dejan de valer hasta que lo compruebes otra vez.
- **Descripciones como datos**: lo que cuenta cada servidor de sus herramientas se limpia (sin bloques ni marcas) y va en un apartado marcado como datos, no como instrucciones.

## [0.9.17] — 2026-11-11

### Añadido
- **Servidores MCP para el asistente** (Ajustes › Asistente de IA › Integraciones): conecta herramientas de fuera (calendario, GitHub, notas…) con un comando o una dirección. Cada servidor se aprueba con su interruptor después de ver qué herramientas trae; las de solo lectura las usa cuando le hacen falta y las que cambian algo te piden confirmación cada vez, con lo que va a enviar a la vista. Las claves se leen de una variable de entorno y nunca se guardan en los ajustes. Con «Solo en este equipo» no se usa ninguno.
- La misma pestaña explica cómo **usar HyprFrijol desde Claude** (el comando para añadir su servidor MCP, con botón de copiar) y qué herramientas expone.
- El Inicio del asistente dice cuántos servidores MCP tienes aprobados.
- `hf-ai mcp list | check | call` para manejarlos desde la terminal.

## [0.9.16] — 2026-11-11

### Cambiado
- **Estados iguales en todos los controles** (estilo Math): botones, botones de icono, mosaicos, interruptores y segmentos se iluminan igual al pasar el cursor y al pulsarlos, y lo desactivado se atenúa igual en todos.
- **Se puede usar con el teclado**: Tab recorre los botones, interruptores y segmentos de los paneles y de Ajustes con un anillo del color de acento; Intro o Espacio los pulsa, y las flechas cambian la opción de un segmento. Spotlight, la vista de ventanas y las demás vistas que ya usaban Tab siguen igual.
- **Más profundidad sin transparencia**: los paneles llevan una sombra en dos capas (una cercana y nítida y otra amplia) y un filo de luz muy fino arriba.

## [0.9.15] — 2026-11-11

### Añadido
- **Mis temas: vista previa de verdad**. Al crear un tema se ve la barra y el centro de control (con un aviso y una ventana detrás) pintados con sus colores, en oscuro y en claro, en vez de dos tarjetas pequeñas.
- **Editar colores uno a uno**: fondo, superficie, acento, botones, selección, texto, bordes… cada uno con su código. Si un texto no se leería bien se ajusta solo y la nota lo dice; lo que ves es lo que se guarda.
- **Editar un tema guardado**: «Editar» bajo cada tema propio lo abre en el creador. Si lo guardas con otro nombre, sustituye al anterior.
- `hf-theme check`: valida un tema editado a mano sin guardarlo.

## [0.9.14] — 2026-11-11

### Añadido
- **Inicio del asistente** (Ajustes › Asistente de IA): la primera pestaña dice en una línea qué proveedor y modelo responden y si están listos, con «Probar conexión»; un resumen de lo que más importa (respaldo, solo en este equipo, confirmación, datos sensibles, apps privadas, historial y recetas) que lleva a donde se cambia, y los atajos del asistente.

### Cambiado
- Lo que antes era la pestaña «Asistente» se llama **Proveedor y permisos**.

## [0.9.13] — 2026-11-11

### Añadido
- **El asistente responde en directo**: en el panel lateral la respuesta se va escribiendo mientras llega, con Claude Code, Gemini, Ollama y los servidores compatibles con OpenAI. Las consultas que hace antes de responder («Miró las ventanas») salen en cuanto las hace.
- **Detener**: mientras responde, el botón de enviar pasa a ser un cuadrado que corta la respuesta y deja lo que ya había llegado.
- **Repetir con otro modelo**: bajo la última respuesta, junto a Copiar y Regenerar, un botón abre los modelos del proveedor y repite la pregunta con el que elijas. Debajo de cada respuesta se ve qué modelo respondió.

## [0.9.12] — 2026-11-11

### Corregido
- La apertura de los paneles (centro de control, Spotlight, agenda, ventanas de los widgets de la barra…) es **una sola animación**: el fundido, la escala y el deslizamiento van a la vez, sin rebote. Antes el panel se quedaba un instante quieto como un bloque gris desenfocado y luego entraba, y el fundido acababa antes que el movimiento.
- Se abren siempre igual, con el ratón o con el teclado (antes, con el ratón nacían del punto pulsado y con el teclado desde su borde).

## [0.9.11] — 2026-11-11

### Corregido
- Al abrir el centro de control, Spotlight u otro panel ya no se ven dos animaciones seguidas (un fundido de Hyprland y luego la entrada del panel): ahora solo se anima el panel. Los avisos que estaban en pantalla ya no salen deslizándose a la vez que se abre el centro de control.

## [0.9.10] — 2026-11-11

### Seguridad
- Un tema creado por el asistente ya no puede sobrescribir uno tuyo con el mismo nombre (se guarda como «Nombre 2»), así que Deshacer solo borra el que creó el asistente.

## [0.9.9] — 2026-11-11

### Añadido
- **Recetas del asistente** (Ajustes › Asistente de IA › Recetas): instrucciones guardadas que se aplican de un golpe a la selección, lo copiado, la pantalla o una imagen copiada. Vienen Resumir, Traducir al español y al inglés, Corregir redacción, Explicar el error, Crear tarea, Crear evento y Crear tema desde imagen, y puedes guardar las tuyas. El resultado va al panel lateral, se copia o reemplaza la selección. Salen en **Spotlight** por su nombre.
- El asistente puede **crear eventos en la agenda** y **temas de colores** (con su tarjeta para confirmar y Deshacer).

### Seguridad
- En el modo **Solo en este equipo** el asistente solo habla con un Ollama de esta máquina: si la dirección configurada es de otra, no envía nada.

## [0.9.8] — 2026-11-11

### Añadido
- **Modelos del asistente** (Ajustes › Asistente de IA › Modelos): un modelo para las respuestas rápidas (lo que llega de Spotlight y de la voz) y otro para las imágenes; un **respaldo** que responde si el proveedor falla o no hay red (la respuesta lo dice), y el modo **Solo en este equipo**, que usa Ollama y apaga las voces en la nube.

### Seguridad
- El asistente ya no puede cambiar la lista de apps privadas.

## [0.9.7] — 2026-11-11

### Añadido
- **Mis temas** en Ajustes › Apariencia: crea un tema con tus colores pegando de 1 a 8 códigos (#RRGGBB) o eligiendo una imagen. De una paleta con los códigos escritos se leen tal cual; de una foto se sacan sus colores. Cada tema sale en oscuro y en claro, con el contraste corregido para que todo se lea, y se ve antes de guardarlo.
- Los temas propios se **exportan** a un .json (en Descargas) y se **importan** desde otro equipo. También desde la terminal con `hf-theme`.

## [0.9.6] — 2026-11-11

### Añadido
- **Opacidad de las ventanas sin foco** en Ajustes › Animaciones y efectos › Ventanas: automática (como antes), opacas, 92 % o 85 %, con una lista de **apps siempre opacas** (vídeo, videollamadas y OBS por defecto) para que se sigan viendo bien mientras trabajas en otra ventana.
- **Onda al pulsar**: se puede apagar el efecto de onda de botones y mosaicos.

## [0.9.5] — 2026-11-11

### Añadido
- **Ajustes › Productividad › Spotlight**: qué grupos salen al buscar sin prefijo (apps, acciones, ventanas, calculadora, IA y web), su orden (por relevancia o el que elijas) y el buscador web de «!» (DuckDuckGo, Google, Brave, Kagi, Startpage u otro con una dirección con %s). También la lista de prefijos.

## [0.9.4] — 2026-11-11

### Añadido
- **Tareas**: una lista sencilla con fecha opcional. Se ven en la agenda (Super + C) bajo los eventos del día, con casilla para marcarlas; las vencidas salen arriba en rojo. Se crean con el «+» de la agenda (Evento o Tarea), escribiendo `+texto` en Spotlight («+llamar al banco mañana») o pidiéndoselo al asistente (con Deshacer), y se gestionan en Ajustes › Productividad › Tareas.
- **Portapapeles**: tamaño del historial (100 a 2000) y borrar lo copiado tras 1, 7 o 30 días. Lo que copias con una app privada delante (gestores de contraseñas y las que añadas) no se guarda.
- **Alarmas en Ajustes** (Productividad › Agenda y alarmas), además de en la ventana del pomodoro.

### Cambiado
- **Productividad es una sola entrada en Ajustes** con pestañas: Enfoque y pomodoro, Portapapeles, Agenda y alarmas y Tareas. Los calendarios .ics pasan de Fecha a Agenda y los ajustes del portapapeles de Teclado a Portapapeles (con enlaces desde donde estaban).

### Seguridad
- El asistente no lee la pantalla si una app privada se ve en cualquier monitor (antes solo miraba la ventana activa), ni el portapapeles si lo último se copió desde una app privada o el gestor lo marcó como contraseña.

### Nota
- El portapapeles nuevo arranca al iniciar sesión; hasta entonces sigue el de antes.

## [0.9.3] — 2026-11-11

### Añadido
- **El asistente oculta datos sensibles** antes de enviarlos al proveedor: claves de API, tokens, claves privadas, contraseñas en URLs y números de tarjeta que vengan del portapapeles, la pantalla, los títulos o las consultas. El panel avisa («Se ocultó 1 dato sensible del contexto»). Lo que escribes tú no se toca. Se apaga en Ajustes › Asistente de IA › Privacidad.
- **Apps privadas**: con un gestor de contraseñas (u otra app que añadas) delante, el asistente no lee su ventana ni su título, no mira la pantalla y no toca el portapapeles.
- **Registro de acciones** con Deshacer en Ajustes › Asistente de IA › Privacidad (`hf-ai log`), y **días que se guarda el historial** (7, 30, 90 o siempre) con «Borrar todo».

### Cambiado
- **Asistente de IA es una sola entrada en Ajustes** con pestañas: Asistente, Privacidad, Dictado y Panel lateral y PiP (Dictado y Panel ya no salen sueltos en la lista; sus enlaces siguen funcionando). Privacidad y seguridad enlaza a la privacidad del asistente.

## [0.9.2] — 2026-11-11

### Cambiado
- **12 temas, cada uno con su variante oscura y clara** ajustada a mano (antes 66 paletas, muchas de un solo modo): Grafito, Oxocarbon, Ciruela, Rosa pastel, Catppuccin, Rosé Pine, Nord, Tokyo Night, Gruvbox, Everforest, Kanagawa y Lila pastel; Monocromo sigue en «Color». Al cambiar entre claro y oscuro se usa siempre la pareja del tema, no una variante calculada.
- Nuevos: **Ciruela** (oscuro y claro) y **Oxocarbon claro** (IBM Carbon). Grafito y Claro pasan a ser el mismo tema.

### Migración
- Si tenías una paleta retirada, pasa a la más parecida (p. ej. Lavanda → Lila pastel, Vino → Ciruela, Carbón → Oxocarbon). Copia antes en `settings.json.antes-de-temas`. Los temas importados de Omarchy no se tocan.

## [0.9.1] — 2026-11-11

### Añadido
- **Ajustes › Animaciones y efectos**: una sección con el movimiento, las sombras, el resaltado de la ventana activa y el desenfoque (antes repartidos entre Apariencia y Energía, que ahora enlazan aquí).
- **Modo juego** (Super + Mayús + G): quita al momento animaciones, desenfoque, sombras, redondeo, huecos y bordes; otra vez, y vuelven.
- **Atenuar ventanas inactivas** (oscurece un poco las que no tienen el foco).
- **Estilo del cambio de espacio**: según el preset, deslizar, con fundido, fundido o vertical.

### Cambiado
- Los detalles del shell (hover, cambios de color, chips, menús, la onda al pulsar) siguen ahora al preset de movimiento: Rápido los acorta y Fluido los alarga. Antes solo seguían a la velocidad.

## [0.9.0] — 2026-11-11

### Cambiado
- Un solo estilo, **Math** (Material 3). Lo que antes era el estilo SkySoul es ahora el interruptor **Transparencia** de Ajustes › Apariencia (y de la bienvenida): paneles de cristal desenfocados sobre cualquier paleta. Con «Reducir transparencia» o «Alto contraste» siguen siendo sólidos.
- Los controles se comportan igual con o sin transparencia: onda al pulsar, interruptores y campos de Material.
- El rebote al abrir lo decide el preset de movimiento (Fluido), ya no el estilo.

### Quitado
- El estilo **Chroma** (negro, puntos y rojo) y su fuente Doto.

### Migración
- `hf-migrate` (lo lanza `hf-update`) pasa tu ajuste: SkySoul → Math con transparencia; Material y Chroma → Math sólido. Copia antes en `settings.json.antes-de-math`.
- El login (greetd) entiende el tema nuevo; para que use su versión nueva, `hf-greeter-sync`.

## [0.8.50] — 2026-11-11

### Arreglado
- Con una gráfica NVIDIA con `nouveau` (aquí la GT 710), el vídeo de fondo de la pantalla de bloqueo, del selector de fondos y del login tiraba Quickshell (SIGBUS): VA-API decodificaba en la primera gráfica, la de nouveau, que no tiene firmware de vídeo. Al caerse con la pantalla bloqueada, Hyprland mostraba su pantalla de «Oops» del bloqueo caído. Ahora, si `nouveau` está cargado, Qt decodifica el vídeo por CPU (`QT_FFMPEG_DECODING_HW_DEVICE_TYPES=none`, en `env.lua` y en `greeter/hyprland-greeter.lua`).

## [0.8.49] — 2026-11-11

### Cambiado
- Los paneles que abres con el ratón desde la barra (centro de control, tiempo, red, Spotlight…) nacen del punto que pulsaste y vuelven a él al cerrarse, en vez de aparecer en su sitio. Con el teclado siguen saliendo de su borde; con «Reducir movimiento», sin animación. Va en la base de todos los paneles (`components/Overlay.qml`), así que vale para todos.

## [0.8.48] — 2026-11-11

### Rendimiento
- El shell en reposo gasta ~1 % de un núcleo en lugar de ~4,7 % (medido en una sesión real con dos pantallas). Las dos causas, encontradas con `qmlprofiler`:
  - El monitor del sistema (`SysStats`) llamaba a JS una vez por línea: ~380 líneas cada 2 s con el consumo por programa. Ahora es una llamada por bloque.
  - El reloj compartido (`Time.now`) cambiaba cada segundo, y con él se rehacía cada segundo la lista del centro de notificaciones, aunque estuviera cerrado (el «hace X min» de cada aviso). Ahora cambia al cambiar de minuto; nada muestra segundos.
- Nuevo `dev/perf.sh`: mide la CPU y la memoria del shell en reposo en una sesión anidada (ver `dev/DESARROLLO.md`, que explica también cómo perfilar la sesión real).

## [0.8.47] — 2026-11-11

### Arreglado
- Icono de Tailscale en la bandeja de la barra: la sesión arranca `tailscale systray` si Tailscale está instalado (el servicio `tailscaled` no pone icono por sí solo). Para manejarlo sin sudo hace falta ser operador: `sudo tailscale set --operator=$USER` (lo hace «Activar servicio» en Ajustes › Red).

## [0.8.46] — 2026-11-11

### Arreglado
- Micrófono de la barra: silenciado ya no deja cambiar de modo (clic derecho, Super + Shift + Alt + M o `hf:micro-modo`), porque ningún modo funcionaría; avisa «actívalo para cambiar de modo». El clic y Super + Alt + M, silenciado, solo lo vuelven a activar, aunque el modo sea dictado o asistente (por si se silenció desde otro sitio).

## [0.8.45] — 2026-11-11

### Arreglado
- Con el login de HyprFrijol (greetd), Chrome ya no pide la contraseña del llavero al abrirse: `./install.sh --greeter` añade `pam_gnome_keyring` a `/etc/pam.d/greetd`, así la contraseña con la que entras desbloquea el llavero. Nuevo paquete en el nivel `greeter` (`gnome-keyring-pam` en Fedora/openSUSE, `libpam-gnome-keyring` en Debian/Ubuntu).

## [0.8.44] — 2026-11-11

### Cambiado
- Iconos del micrófono por modo: dictado (micrófono con líneas de texto, relleno mientras escucha), asistente (con chispas), silenciar (el micrófono solo) y silenciado (tachado con el trazo cortado, en rojo).
- Orden de las utilidades de la barra (horizontal y vertical): lo que acompaña (gato bongo · pomodoro · cafeína), lo que escribe y habla (portapapeles · micrófono · asistente) y ajustes.
- Iconos de estado: la red por cable ya no es una pantalla (tres equipos unidos); el wifi tiene punto y atenúa los arcos según la señal; sin conexión se tacha. Volumen silenciado con aspa y nivel bajo con una onda (barra, OSD, centro de control y música, desde `Audio.icon`); batería con rayo al cargar; campana más redonda y tachada en no molestar.

## [0.8.43] — 2026-11-11

### Cambiado
- El gato bongo vuelve a la derecha de la barra principal, justo antes del pomodoro: ya no salta de pantalla con el foco.

## [0.8.42] — 2026-11-11

### Cambiado
- El botón del micrófono de la barra tiene tres modos (`micMode`): dictado, hablar con el asistente y silenciar. Clic: lo del modo; clic derecho: el siguiente. Silenciado se ve tachado en rojo en cualquier modo. También en Ajustes › Dictado.
- Super + Alt + M hace lo del modo del micrófono (antes solo silenciaba) y Super + Shift + Alt + M cambia de modo (atajos globales `hf:micro` y `hf:micro-modo`; IPC `dictado micro` / `microModo`). La tecla de silenciar el micrófono sigue igual.
- El gato bongo se queda en la pantalla de la última ventana con el foco: pasar a una pantalla vacía ya no lo mueve.

## [0.8.41] — 2026-11-11

- Gato bongo: va justo después del título de la ventana activa, en la barra de la pantalla con el foco (donde
  escribes); con dos pantallas se pasa a la otra al cambiar el foco. Antes iba entre las utilidades de la derecha.

## [0.8.40] — 2026-11-11

- Espacios por pantalla arreglados con una principal guardada que ya no existe (HDMI-A-1 → HDMI-A-2 al añadir una
  gráfica): esa ya no se queda con el 1–10, hace de principal la más grande conectada. La barra marcaba mal el
  espacio activo y al hacer clic saltaba a un espacio de la otra pantalla.
- El orden y las reglas de los espacios los calcula la configuración de Hyprland (`frijol/workspaces.lua`) con las
  pantallas conectadas de verdad, igual que la barra (`WsLabel`). Al cargar y al conectar o quitar una pantalla,
  los espacios que tenían un número de otra pantalla se renumeran sin mover sus ventanas.
- La barra se entera cuando un espacio cambia de número (Quickshell no atendía `changeworkspaceid`).
- Espacios de la barra: el del espacio activo es una sola píldora que se desliza de un espacio a otro (antes se
  apagaba en uno y se encendía en el otro).

## [0.8.39] — 2026-11-11

- Ajustes › Fondos de pantalla: con varias pantallas, «Pantalla: Todas · HDMI-A-2 (principal) · VGA-1». Con una
  elegida, el fondo (también en movimiento) y «Al azar» van solo a ella, se marca el suyo y «Usar el general» se lo
  quita. Antes solo se podía desde el selector de fondos.

## [0.8.38] — 2026-11-11

- Animaciones más fluidas:
  - Hyprland: el fundido de las capas del shell (paneles, avisos, menús), el de los menús emergentes de las apps,
    el zoom del cursor, la llegada de una pantalla y el encendido de pantalla heredaban el valor por defecto de
    Hyprland (0,8 s con la curva genérica). Ahora siguen el preajuste de movimiento (p. ej. 0,24 s en Fluido) con
    su curva. «global» se fija en los cuatro preajustes para que nada vuelva a quedarse lento.
  - Shell: unas 100 transiciones (hover, pulsación, cambios de color y de tamaño) iban en línea recta; ahora usan
    la curva del preajuste. Las de duración fija siguen la velocidad elegida y se anulan con «Reducir movimiento»
    (`Theme.ms()`).
- Barra secundaria: el consumo se agrupa por programa, no por proceso (dos kitty abiertos por separado salen como
  uno, «×2», sumando los dos). Con varias ventanas, el clic va de una en una.

## [0.8.37] — 2026-11-11

- El consumo de la barra secundaria ya no es por espacio: muestra todos los programas abiertos, en cualquier espacio
  y pantalla, con lo que gasta cada uno (orden fijo; con más de 8, los que más gastan y «+N»). Con una sola pantalla
  no aparece: ahí ya está el chip de sistema.

## [0.8.36] — 2026-11-10

- La barra de las pantallas secundarias vuelve a estar siempre visible.
- Barra de las pantallas secundarias, a la derecha: los programas de su espacio visible con lo que gastan. Icono,
  CPU (% de todo el equipo) y memoria, sumando todos sus procesos (pestañas de Chrome, apps Electron, lo que corre
  en una terminal). En rojo si pasan del 25 % de CPU o de 2 GB. Clic: ir a la ventana · clic central: cerrarla.

## [0.8.35] — 2026-11-10

- Pantallas secundarias: su barra se esconde sola (vuelve al llevar el cursor al borde) y muestra el título de su
  ventana.
- El título de la barra es el de la ventana activa de esa pantalla (la última enfocada en su espacio visible), no
  el de la que tiene el foco en otra.
- Dock: nuevo ajuste de posición (Ajustes › Escritorio y gestos › Dock › Posición: Automática · Izquierda · Abajo,
  `dockPos`). Abajo va en horizontal. Automática: a la izquierda, salvo en una pantalla con otra pegada a su
  izquierda, donde el cursor se pasaría a la otra sin tocar el borde: ahí va abajo.

## [0.8.34] — 2026-11-10

- Pantallas secundarias: su barra solo muestra sus espacios (sin aplicaciones, título, onda de audio, chips,
  bandeja ni grupo de estado). Todo eso queda en la principal.
- Fondos en movimiento por pantalla: el selector de fondos, con una pantalla elegida, pone un vídeo propio en ella
  (su propio mpvpaper). El vídeo general solo se reproduce en las pantallas sin fondo propio (antes se decodificaba
  también debajo de las que lo tenían) y se reparte de nuevo al conectar o quitar pantallas. La pausa (batería,
  pantalla completa, juego…) para todos los reproductores.
- Pantalla principal: si la guardada ya no está conectada (el conector cambia de nombre, p. ej. HDMI-A-1 → HDMI-A-2
  al añadir una gráfica), se usa la más grande en vez de la primera de la lista.
- `hf-wallpaper` ya no se corta a medias si un reproductor recién cerrado sigue en la lista de procesos.

## [0.8.33] — 2026-11-10

- Pantallas en dos tarjetas gráficas: el cursor ya no sale como un cuadrado negro en la segunda (cursor por software
  cuando hay salidas conectadas en más de una tarjeta; se revisa al conectar o quitar pantallas).
- Al iniciar ya no aparece «[hyprpm] Failed to load plugins: Outdated headers» si no tienes plugins de Hyprland instalados.

## [0.8.32] — 2026-11-10

- Nueva lista de trabajo en `docs/PENDIENTES.md`.

## [0.8.31] — 2026-11-10

- README: el resumen ya no anuncia el panel con WhatsApp, YouTube y Pinterest (retirado en 0.8.28).

## [0.8.30] — 2026-11-10

- **Modo de ventanas por espacio, guardado**: Super + Ctrl + Espacio (o clic en el icono nuevo junto a los espacios
  de la barra) cambia el modo (mosaico, desplazamiento, flotante) solo del espacio activo. El icono muestra el modo
  del espacio, de color si tiene el suyo. Estas excepciones ya no se pierden al reiniciar el shell.
- **Mover una ventana a otra pantalla**: Super + Ctrl + Shift + flechas.
- **Consola desplegable**: Super + º abre una terminal que baja desde arriba sobre el escritorio atenuado; la misma
  tecla la esconde y vuelve con lo que tenías.
- **Avisos repetidos juntos**: el mismo aviso varias veces (misma app, título y texto) se queda en uno con «×N».
- **Portal cautivo**: si la red pide iniciar sesión (hoteles, aeropuertos), avisa con un botón para abrir la página
  de acceso; el icono de red de la barra se pone en rojo y el botón de Wi-Fi de los ajustes rápidos la abre.

## [0.8.29] — 2026-11-10

- **Espacios por pantalla**: con varias pantallas, cada una tiene sus propios espacios del 1 al 10. Super + número,
  Super + Shift/Alt + número, Super + Ctrl + flechas y Super + rueda se quedan en la pantalla donde estás, y la barra
  de cada pantalla muestra solo los suyos. Por dentro, la principal usa del 1 al 10 y la siguiente del 11 al 20 (la
  vista general las marca con el nombre de la pantalla). Se apaga en Ajustes › Escritorio y gestos › Espacios de
  trabajo (`wsPerMonitor`). Con una sola pantalla no cambia nada.

## [0.8.28] — 2026-11-10

- **El menú de los iconos de la bandeja se cierra** al hacer clic fuera o al volver a pulsar el icono. Antes se
  quedaba abierto y no había forma de quitarlo. Lo mismo con el desplegable de iconos ocultos.
- **Se retiran las web apps**: la sección de Ajustes, el panel lateral web, sus entradas en Spotlight, el PiP de
  YouTube, sus atajos y `hf-webapp`. El panel lateral queda solo para el asistente de IA. Al actualizar se borran sus
  lanzadores, el enlace `~/.local/bin/hf-webapp` y sus claves de `settings.json` (copia en
  `settings.json.antes-sin-webapps`). Las sesiones guardadas en `~/.local/share/hyprfrijol/webapps` no se tocan: se
  pueden borrar a mano.

## [0.8.27] — 2026-11-10

- **Botones de ventana dentro de la ventana**: la barra de título del shell pasa a ser una pastilla pequeña arriba a
  la derecha de la ventana activa (asa para moverla, minimizar, maximizar y cerrar). Al arrastrar el asa la ventana
  sigue al cursor sin retraso: se quita la animación de movimiento mientras dura. Doble clic en el asa: maximizar.
- Enfocar una ventana (desde el dock, Alt + Tab o al restaurarla) ya no lleva el cursor a su centro
  (`cursor:no_warps`).
- Las ventanas flotantes pueden maximizarse y restaurarse con sus propios botones también en mosaico; las de mosaico
  siguen sin poder hacerlo por su cuenta.
- Límite conocido: Hyprland ignora el botón de minimizar de las apps que dibujan su propia barra (Chrome, apps de
  GNOME…). Para minimizarlas: su icono del dock, o Alt + Espacio › Minimizar.

## [0.8.26] — 2026-11-10

- **Barras de título sin plugins**: en el modo flotante, la ventana activa que no trae su propia barra (terminales,
  apps Qt…) lleva una barra dibujada por el shell. Tiene icono, título, menú, minimizar, maximizar o restaurar y
  cerrar. Arrastrarla mueve la ventana, el doble clic maximiza y el clic derecho abre el menú. Si la ventana está
  maximizada, la barra aparece al llevar el cursor al borde de arriba. Se apaga en Ajustes › Escritorio y gestos.
  Si algo falla, como mucho la barra no aparece: el shell va aparte y no puede cerrar la sesión.
- En el modo flotante funciona el botón de maximizar de las apps que traen su propia barra (Chrome, Firefox, GNOME…).
  En mosaico siguen sin poder maximizarse por su cuenta.
- Para redimensionar sin Super basta con arrastrar el borde de la ventana.
- Hyprbars ya no se ofrece en Ajustes › Plugins y el instalador ya no descarga la fuente Nerd Font: ninguno hace falta.

## [0.8.25] — 2026-11-10

- **El instalador trae la fuente de iconos en todas las distros**: en Arch la instala pacman
  (`ttf-jetbrains-mono-nerd`). En Fedora, openSUSE, Debian/Ubuntu y Void, que no la empaquetan, descarga Symbols
  Nerd Font en `~/.local/share/fonts`. En NixOS se añade `nerd-fonts.symbols-only` a la lista de fuentes que
  propone. Si ya tienes una Nerd Font, no descarga nada.

## [0.8.24] — 2026-11-10

- Los botones de las barras de título usan iconos de Nerd Font (cerrar, maximizar, minimizar, chincheta y menú)
  en vez de símbolos de texto. Sin una Nerd Font instalada siguen los símbolos de texto. El instalador añade
  JetBrains Mono Nerd Font en Arch.

## [0.8.23] — 2026-11-10

- Sin emojis en Ajustes ni en la barra de título: el botón de mostrar en todos los espacios es ahora ⊙.

## [0.8.22] — 2026-11-10

- **El modo flotante se comporta como un escritorio clásico** (Openbox, GNOME):
  - **Barras de título** en las ventanas que no traen la suya, con el estilo de la ventana PiP: menú ⋮,
    mostrar en todos los espacios ⊙, minimizar, maximizar y cerrar. Usa el plugin Hyprbars; al elegir Flotante en
    Ajustes › Escritorio y gestos se ofrece instalarlo (se compila una vez).
  - Chrome, Firefox, las apps de GNOME, VS Code, Discord, Spotify… ya dibujan su barra y no se les pone otra.
    La lista se puede cambiar en **Apps con su propia barra**.
  - **Menú de ventana** con **Alt + Espacio** o el botón ⋮: minimizar, maximizar o restaurar, mostrar en todos los
    espacios, organizar, mover a otro espacio y cerrar.
  - **Se enfoca con clic**, no al pasar el cursor.

## [0.8.21] — 2026-11-10

- **El portapapeles muestra las imágenes copiadas desde el gestor de archivos**: Nautilus, Thunar o Dolphin solo
  copian la ruta del archivo y se veía `file:///…/foto.png`. Ahora sale la miniatura y el nombre, y al copiarla desde
  el historial se pega la imagen, no la ruta. Si la fijas, se guarda una copia, así que sigue aunque borres o muevas
  el original. Si copias varias a la vez, siguen saliendo como texto.
- Las miniaturas cargan aunque el nombre del archivo lleve `#`, `?`, `%`, espacios o tildes.

## [0.8.20] — 2026-11-10

- **Dos voces: Helpert y Sophia.** El asistente se llama ahora **Helpert** (antes Samantha), con una personalidad
  nueva, sobria y directa, como un buen mayordomo. Habla con la voz local. **Sophia** pone la voz de Google a los
  avisos puntuales. Se cubren entre sí: sin clave de Google, o si Google falla, los avisos los dice Helpert.
  Tus ajustes se actualizan solos (copia en `settings.json.antes-de-helpert`). Si habías escrito tu propia
  personalidad, se respeta.
- **Sophia te saluda al entrar** con la hora y el tiempo, una sola vez por sesión (Ajustes › Asistente de IA ›
  «Sophia: saludo al entrar»).
- **Sophia lee los avisos importantes**: los recordatorios del asistente y las notificaciones urgentes. Calla en
  «no molestar» y con las apps que hayas silenciado, y no repite el mismo aviso en menos de un minuto («Sophia:
  avisos importantes»). Las dos opciones vienen apagadas.
- `hf-ai announce "texto"` (Sophia) sustituye a `hf-ai speak --google`.

## [0.8.19] — 2026-11-10

- **Samantha habla con una voz local**: Piper con la voz «sharvard» (español de España). Empieza a sonar en ~1 s
  (antes ~4,6 s con Gemini), no necesita internet ni gasta la cuota gratuita de Google, así que ya no se calla al
  llegar al límite. Ocupa ~250 MB y ~150 MB de RAM solo mientras habla. Se instala desde Ajustes › Asistente de IA
  («Instalar la voz local») o con `hf-ai voice-install`. Sin ella, la voz sigue siendo la de Gemini.
- `hf-ai speak --google "texto"` usa la voz de Gemini a propósito, para avisos puntuales.

## [0.8.18] — 2026-11-10

- **Samantha empieza a hablar antes**: la respuesta se lee en dos trozos. Suena la primera frase en unos 4 s y el
  resto se genera mientras tanto, en vez de esperar a tener todo el audio (con respuestas largas eran 15–30 s de
  silencio). Si Gemini falla a mitad, lo ya generado se oye igual. Cortar la voz o una respuesta nueva siguen
  callando la anterior al momento.

## [0.8.17] — 2026-11-09

- **Hablar con Samantha ya no abre el panel lateral**: con «Hablar con voz» activo, Super + Alt + H (o `hf-ai talk`)
  hace la conversación con el panel cerrado y se oye la respuesta. Queda guardada en el historial de chats como
  siempre. El panel solo se abre si la respuesta propone cambios que hay que aprobar; si algo falla, llega un aviso.
  Sin voz, se sigue abriendo el panel para poder leer la respuesta.

## [0.8.16] — 2026-11-09

- **La voz de Samantha suena limpia**: ya no lee en voz alta «dilo con voz cálida…» antes de cada respuesta, y al
  final ya no suena un ruido como de televisor apagándose (Gemini manda ahora un WAV entero y se envolvía en otro,
  así que sus bloques finales se oían como estática).

## [0.8.15] — 2026-11-09

- **Hablar con Samantha por voz: Super + Alt + H** (mantener: hablar · soltar: se lo pregunta; un toque corto deja el
  micrófono abierto hasta volver a pulsar). Lo dicho no se escribe en la ventana: va al asistente, que contesta con
  voz si «Hablar con voz» está activo. Desde la terminal: `hf-ai talk`. El dictado sigue en Super + Alt + D
  (`hf-dictate toggle` desde la terminal) y todos los atajos se ven con Super + / (nuevo grupo «Voz y asistente»).
- **La voz de Samantha se distingue en la barra**: mientras habla, la onda de audio es siempre una onda rellena en el
  color terciario (con música u otros sonidos sigue el estilo de siempre).
- Las preguntas al asistente desde la voz o desde otras apps (`sidepanel ask`) ya no se pierden cuando el chat aún no
  estaba cargado.
- Gemini: el modelo por defecto pasa a «Gemini Flash» (alias que sigue al más nuevo; gemini-2.5-flash ya no se da a
  cuentas nuevas) y, si está saturado, se reintenta una vez con Flash-Lite.

## [0.8.14] — 2026-11-09

- Voz del asistente más segura: el audio temporal y el registro del reproductor van a una carpeta privada (nunca a
  /tmp), y «parar la voz» solo detiene el reproductor de hf-ai.

## [0.8.13] — 2026-11-09

- **El asistente se llama Samantha** y tiene personalidad propia (cálida, curiosa, cercana). Se cambia en Ajustes ›
  Asistente de IA › Personalidad.
- **Samantha puede hablar**: «Hablar con voz» (Ajustes › Asistente de IA › Personalidad) lee cada respuesta en voz
  alta con Gemini TTS y la clave gratuita de Google AI Studio, aunque el asistente use Claude. No lee el código y
  corta la respuesta anterior si llega otra. A mano: `hf-ai speak "texto"` / `hf-ai speak --stop`.
- Se aceptan las claves nuevas de Google AI Studio (las que empiezan por `AQ.`), y si el proyecto de Google tiene la
  facturación sin saldo se dice claramente (antes parecía el límite del plan gratuito).
- **Clic derecho en un icono del desplegable «›» de la bandeja**: vuelve a abrir su menú (antes se cerraba el
  desplegable y no pasaba nada).

## [0.8.12] — 2026-11-09

- **Las opciones de los iconos de la bandeja que abren una terminal ya funcionan** (p. ej. «Ejecutar Cachy-Update»):
  GLib no reconocía kitty y no abría nada. Nuevo `scripts/xdg-terminal-exec`, que abre la terminal elegida en
  Ajustes › Predeterminadas. Arregla también cualquier app con `Terminal=true` lanzada desde otra app.

## [0.8.11] — 2026-11-09

- **Dictado en tiempo real**: con Super + Alt + D las palabras se van escribiendo en la ventana con foco mientras
  hablas, y lo provisional se corrige solo (con retrocesos) al terminar cada frase. Hace falta `wtype`; con ydotool o
  «Pegar»/«Portapapeles» sigue yendo frase a frase.
  Mientras hablas solo se añaden las palabras en que coinciden dos provisionales seguidos (en dictados largos ya no se
  borra ni se reescribe lo dicho); si una palabra ya escrita cambia, se corrige una vez al cerrar la frase.
- **Super + Alt + D ya no mueve ventanas ni cambia de espacio**: mientras las teclas del atajo están pulsadas no se
  escribe nada (antes las letras se convertían en atajos de Hyprland, como Super + Alt + S).
- **El dictado ya no agranda la pantalla**: nunca escribe con Ctrl, Mayús, Alt o Super pulsados en el teclado (con
  cualquier atajo, no solo el del dictado; lo mira en el teclado físico y escribe a trozos). Antes, pulsar un atajo
  mientras escribía convertía las letras en atajos y el zoom subía hasta 3× (se quita con Super + -).
- **Botón de dictado en la barra** (módulo «Dictado» en Ajustes › Barra; activo por defecto): clic para empezar o
  terminar, resaltado mientras graba.
- El panel del asistente ya no tiene micrófono propio: el dictado es global y escribe también en su caja de texto.

## [0.8.10] — 2026-11-09

- **Cambiar entre fondos en movimiento ya no dispara la CPU**: la copia a la medida de la pantalla y la del login se
  convierten con 2 hilos y la menor prioridad (antes usaban todos los núcleos a la vez). Al cambiar varias veces
  seguidas se corta la conversión del vídeo que ya no está, y las del login en cola ya no convierten cada una su
  fondo viejo.
- **Código con colores en el asistente**: los bloques de código de las respuestas se ven resaltados por lenguaje
  (SQL, terminal bash/zsh/fish, JSON, Python, diff, yaml/toml/ini, HTML/XML, Lua y estilo C: JS/TS/QML/C/Go/Rust…),
  con paleta clara u oscura según el tema. Sin dependencias nuevas (`modules/sidepanel/highlight.js`).
- **Iconos Catppuccin** (catppuccin/vscode-icons, MIT) para todo lo de archivos y código: lenguaje en la cabecera de los
  bloques de código del asistente, documentos adjuntos, resultados de archivos de Spotlight y archivos y carpetas del
  escritorio (con carpetas especiales: src, .config, Descargas, Documentos…). Mocha con tema oscuro, Latte con tema claro.
  Solo se incluyen los 180 iconos usados (`components/CatIcon.qml`; se regeneran con `dev/gen-catppuccin.py`).

## [0.8.9] — 2026-11-09

- **Arranque más ligero**: Quickshell arranca sin páginas enormes transparentes (THP «always» en CachyOS y otras):
  ~165 MB menos de RAM (de ~470 a ~305 MB). `hf-wallpaper restore` ya no vuelve a sacar el fotograma del vídeo ni a
  calcular la paleta si el fondo no cambió (~1 s de CPU y un PNG 4K menos en cada inicio de sesión).
- **Vigilante del shell sin procesos en reposo**: antes lanzaba `sleep`, `flock`, `timeout` y `hyprctl` cada 3 s
  (~115 000 procesos al día); ahora espera con builtins y solo pregunta a Hyprland si el shell no está.
- La búsqueda de actualizaciones en segundo plano corre con la menor prioridad (`nice 19`).
- Ajustes › Notificaciones: las capturas temporales (`/run/user/…`) ya no se guardan como icono de la app (salía un
  icono roto tras reiniciar).
- **Fondo en vídeo, «Tapado por ventanas»** (Ajustes › Fondos › Pausar): ahora mide cuánto tapan de verdad las
  ventanas (≥ 85 % de cada pantalla), también las flotantes. Antes bastaba una ventana en mosaico y, con el escritorio
  flotante, nunca se pausaba.
- **mpvpaper colgado al cerrar sesión**: si la sesión se cerraba con el vídeo pausado, el reproductor (detenido con
  SIGSTOP) no se enteraba y se quedaba para siempre. Ahora se reanuda para que termine solo, y cada cierre del
  reproductor va seguido de SIGCONT. El vigilante del vídeo ya no lo relanza cuando la sesión se ha ido.
- `hf-doctor`: avisa por los volcados de memoria de este arranque; los de días atrás solo se mencionan.
- Para desarrollar: `dev/lint.sh` (revisión estática) y `dev/check.sh` (abre todas las vistas en una sesión anidada y
  falla si hay errores de QML). Ver `dev/DESARROLLO.md`.
- Botones e interruptores de Ajustes usan el `enabled` de Qt en vez de redeclararlo; paletas internas y el arrastre de
  la captura con nombres que no tapan propiedades de Qt.
- Documentación al día con la 0.8.8 (el panel lateral es solo del asistente; las web apps van en ventana o navegador).

## [0.8.8] — 2026-11-09

- **Esquinas de la barra más suaves**: un anillo tenue de 1 px por fuera del contorno ensancha el suavizado (como
  el de las esquinas de Hyprland); a 1x ya no se ven escalones ni un tramo recto a 45°.
- **Paneles a la misma distancia que las ventanas**: el centro de control, las notificaciones, el panel lateral y
  los demás paneles suman al hueco (`gaps_out`) el filo de las ventanas (`border_size`), así su borde visible cae
  donde empieza el contenido de las ventanas, junto a la barra y al borde de la pantalla.
- **Panel lateral solo para el asistente**: las web apps salen del panel (se veían mal y gastaban recursos que el
  navegador ya pone): las que estaban en él se abren en el navegador (en Spotlight y Ajustes › Web apps sigue la
  opción «Ventana propia»). El panel mide **un cuarto de la pantalla** (una columna de un mosaico de 4; también
  «Un tercio» o 400 px en Ajustes › Panel lateral). `hf-migrate` pasa las web apps de modo «panel» a «navegador»
  y cierra sus procesos.
- **Barra: esquinas redondas y suaves**: el contorno de las cápsulas se dibuja con curvas Bézier y suavizado (antes
  tramos rectos que se veían octogonales), +4 px sobre las esquinas de las ventanas por defecto (Ajustes › Barra ›
  Esquinas: +0 / +2 / +4). Sin el contorno gris; en vidrio (Aurora) sin filo, el borde lo da el cristal.
- **Misma distancia que las ventanas**: la barra flotante queda del borde de la pantalla al mismo hueco que las
  ventanas (gaps_out; antes se forzaba a 2–4 px), y con ella el centro de control y los paneles.
- **Ventanas flotantes como en un escritorio clásico** (Ajustes › Escritorio › Ventanas flotantes):
  - **Encajar al soltar**: arrastra una ventana flotante contra un lado y ocupa esa mitad; contra una esquina, ese
    cuarto; arriba (o sobre la barra), toda el área. Soltada lejos de los bordes, una ventana encajada recupera su
    tamaño, centrada bajo el cursor (`config/hypr/frijol/floatsnap.lua` + `snap drop`).
  - **Recordar dónde estaba cada app**: al volver a abrirla flotando, en el mismo sitio y con el mismo tamaño
    (`~/.local/state/hyprfrijol/float-geometry.json`).
  - **Barras de título con botones**: acceso directo a Hyprbars (Ajustes › Plugins), que pone minimizar ·
    maximizar · cerrar en las ventanas flotantes.
  - El antiguo «Acoplar al arrastrar a los bordes» (imán de Hyprland) se llama ahora «Imán al arrastrar».
- **WhatsApp como en la 0.8.6** (si se abre en ventana propia): una columna, la lista o el chat, con «←»; sin la
  línea vertical en medio.

## [0.8.7] — 2026-11-09

- **Personalidad del asistente** (Ajustes › IA › Personalidad): ponle **nombre** (sale en la pestaña del panel y
  en la bienvenida, y sabe que se llama así) y escribe **cómo quieres que sea**: tono, trato, idioma, largo de las
  respuestas… Se suma a sus instrucciones de siempre; no le quita permisos ni la confirmación de cambios, y él no
  puede cambiarla.
- **Pomodoro, temporizador y alarmas** en la ventana del chip, ordenada en tres pestañas:
  - **Pomodoro**: bloque (Foco / Descanso / Largo) y rondas arriba, el anillo, «¿En qué te vas a concentrar?»
    (opcional), y debajo las duraciones y opciones.
  - **Temporizador**: cuenta atrás suelta con minutos rápidos (1 min – 1 h, se recuerdan) o ±1 min, «¿Qué te
    recuerdo?» opcional y alarma con aviso urgente («Repetir») al acabar. Los temporizadores del asistente se ven
    (y se cancelan) ahí. IPC: `pomodoro timer <min> <actividad>`.
  - **Alarmas** (nuevo): a una hora del día, una sola vez o los días que marques (L M X J V S D), con etiqueta.
    Suenan con aviso urgente que trae «Posponer 5 min» y «Detener»; las de una vez se apagan solas. IPC:
    `alarms add <HH:MM> <etiqueta>` · `list` · `remove <id>`.
- **Parlante o auricular, a mano** (Ajustes › Sonido y ajustes rápidos): si tu salida tiene los dos en la misma
  tarjeta (línea trasera + jack frontal), debajo sale un interruptor «Parlante (línea) | Auriculares». Elegir el
  parlante con el auricular enchufado desactiva el silencio automático del chip para que suene igual
  (`scripts/hf-audio`; necesita `amixer` para eso).
- **Web apps**:
  - **Zoom en la cabecera del panel** (− 90 % +; clic en el número: 100 %; rueda encima), el mismo de Ctrl + / Ctrl −.
  - **YouTube (y las demás) ya no se quedan en negro** al volver a su pestaña hasta mover el ratón: se fuerza a
    Chromium a pintar al traerlas.
  - **Avisos con la web app escondida**: la página ahora sabe cuándo está guardada (antes se creía siempre a la
    vista y WhatsApp no avisaba de nada).
  - **Panel lateral más estrecho**: por defecto mide lo mismo que el centro de control (404 px); en Ajustes › Panel
    lateral › Ancho también hay 480 px y un tercio de la pantalla. Las web apps lo siguen salvo que tengan su
    propio ancho («Un tercio», 600 u 800 px en Ajustes › Web apps).
  - **WhatsApp en el panel estrecho**: la lista de chats arriba y el chat abierto abajo, mitad y mitad (con «✕»
    para cerrarlo); sin chat abierto, la lista ocupa todo. Sin encoger el zoom para caber ni la línea vertical que
    quedaba en medio.
  - **Cerrar si no la usas** (Ajustes › Web apps): columna Nunca / 15 / 30 / 60 min en cada fila del panel lateral;
    no aparece en las de mensajería.
- **Fondos en movimiento**:
  - **Sin pantallazo negro al cambiar de vídeo**: el nuevo se pone encima del viejo cuando ya pinta (antes entraba
    con un fundido de capa de Hyprland y a medio camino se veía negro o los dos mezclados). Entre imágenes, la nueva
    aparece encima de la anterior sin dejar ver lo de detrás.
  - **Vídeos a la medida de tu pantalla**: un fondo 4K se convierte una vez, en segundo plano, a la altura de la
    pantalla y a los fps elegidos (caché en `~/.cache/hyprfrijol/wallpapers-scaled`); mpvpaper decodifica hasta 4
    veces menos píxeles. `wallpaperScale: false` lo desactiva.
  - **Pausar cuando está tapado por ventanas** (Ajustes › Fondos): nueva opción, apagada por defecto.
- **Menos CPU**: la onda de audio de la barra pinta sus barras en la GPU y a 30 fps (con música, el shell pasó de
  ~8 % a ~4 %, cava de 1,3 % a 0,7 %).
- **Sin procesos huérfanos al reiniciar el shell**: `nmcli monitor`, `hf-devices watch`, cava y los bucles de la
  barra mueren con él (antes se quedaba una copia por cada reinicio).
- **Avisos de kitty** (y de apps cuyo icono es una ruta): ya no se toman por avisos con imagen.
- **Barra**:
  - La zona de la campana ya no tapa la bandeja: al pulsar un icono de la bandeja (p. ej. actualizaciones) se abre
    su menú y no el centro de notificaciones.
  - **Cápsulas (archipiélago / isla) con las esquinas de las ventanas** y el mismo filo que una ventana sin foco;
    Ajustes › Barra › Esquinas les da +0, +2 (por defecto) o +4 px sobre las de las ventanas.
  - **Bongo Cat junto al pomodoro** y un separador entre los botones propios (asistente, ajustes) y los iconos de
    las apps (bandeja).
- **Ajustes**: «Plugins de Omarchy» pasa a ser una pestaña dentro de Plugins (Hyprland · Omarchy).

## [0.8.6] — 2026-11-08

- **El login recuerda tu usuario y tu sesión**: el usuario del greeter tiene la carpeta personal en `/` y no podía
  guardar nada. Ahora usa `/var/lib/hyprfrijol-greeter` (la crea `hf-greeter-sync` o `install.sh --greeter`).
- **Menos gasto en reposo**: la onda de audio de la barra ya no deja cava funcionando a 60 fps cuando no ha sonado
  nada desde el arranque; Bloq Mayús se vigila sin lanzar procesos (antes ~13 por segundo); la red se entera de los
  cambios por eventos (`nmcli monitor`) en vez de preguntar cada 6 s; el brillo no se sondea en equipos sin
  retroiluminación; la lista de ventanas usa un solo `hyprctl` (antes 7 procesos), los títulos llegan del propio
  evento y una ventana que cambia de título sin parar ya no deja la lista sin actualizar; las estadísticas de la
  barra leen `/proc` y `/sys` sin `cat`/`grep` (la mitad de procesos cada 2 s).
- **Cambiar de fondo dos veces seguidas** ya no deja reproductores de vídeo huérfanos: los cambios van uno detrás de
  otro.
- **Avisos**: los botones de acción ya no dejan el aviso a medio cerrar.
- **hf-doctor**: sin el falso aviso de «nvidia sin modeset» cuando ese parámetro solo lo puede leer root.
- **Web apps: Atrás / Adelante** en la cabecera del panel (y Alt + →), salvo en las de mensajería; se puede cambiar
  en Ajustes › Web apps › Más opciones.
- **Web apps: «Cerrar si no la usas»** (Nunca, 15 min, 30 min o 1 h; por defecto Nunca): libera memoria cerrando las
  del panel que llevan ese tiempo sin abrirse. Nunca cierra la que está a la vista, en PiP o sonando.
- **Bloqueo, ajustes rápidos y polkit**: si tu usuario no tiene nombre completo (o no está en `/etc/passwd`, p. ej.
  LDAP), ya no aparece «nofp» en vez de tu nombre.
- **Ajustes › Plugins de Omarchy** muestra la ruta con `~`.
- **Capturas nuevas** en el README (0.8.6, 1920×1080, configuración por defecto).
- **PiP de YouTube**: al salir, el vídeo recupera su tamaño (antes se quedaba a pantalla completa dentro de la web).
- **Indicador de sesión de prueba** en la barra: solo aparece con una prueba de `dev/try.sh` en marcha; clic para
  verla u ocultarla.
- **La onda de audio** escucha menos en silencio: comprobaciones de 2,5 s cada vez más espaciadas (15 → 60 s).
- **Estadísticas de la barra** con un solo proceso en marcha en vez de uno nuevo cada 2 s.
- **hf-doctor** avisa de los volcados de memoria (cuántos, de qué programa y cuánto ocupan).
- **Pruebas** (`dev/try.sh`): cierra los portales antes que el Hyprland anidado (dejaban cientos de volcados de
  memoria), sin la ventana de novedades de Hyprland (también daba segfault) y con su propia carpeta de web apps (antes
  veía las de la sesión real como abiertas y podía mandarles órdenes).

## [0.8.5] — 2026-11-08

- **Imágenes del portapapeles de vuelta**: si habías copiado texto desde Chrome (que lo guarda en UTF-16), la lista
  del historial tenía bytes nulos y `grep` la tomaba por binaria: no salía ninguna miniatura. Esos textos también se
  ven ya bien (antes «h t t p s : / /…»).
- **Filtros por app también en Recientes**: la misma fila que el historial, con cuántos avisos tiene cada app y
  desplazamiento horizontal si no caben; «Borrar estos» borra solo los de la app elegida.
- **Gato bongo con los dibujos del Bongo Cat de VS Code** ([kitgore/BongoCat](https://github.com/kitgore/BongoCat),
  licencia MIT, en `config/quickshell/assets/bongocat`): el gato de línea tumbado, en el color del texto del tema, que
  baja la pata izquierda o derecha al escribir. Calcado con trazos lisos (`bar/bongo.js`; la fuente original se veía
  ondulada a tamaño de icono) y del tamaño de los iconos de la bandeja.
- **Pantalla de carga como la de KDE**: solo el frijolito y una barrita fina que se va llenando, y solo cuando hace
  falta: si el fondo está listo en menos de un cuarto de segundo, no aparece.
- **Super + flechas respeta el mosaico**: cada pulsación lee el estado real de las ventanas (`hyprctl`) y, si hay
  una vecina en esa dirección, se intercambia con ella; si no, la ventana se recoloca en su hueco (arriba/abajo o
  izquierda/derecha de su vecina), así una ventana a media pantalla pasa a ser un cuarto arriba a la izquierda.
  ↑ ya no maximiza encima de las demás (maximizar sigue en Super + D, y cualquier flecha lo deshace); pulsar hacia
  un lado en el que ya está no hace nada. Las apps que flotan siempre (Nautilus, visores…) entran en el mosaico en
  ese lado con la primera flecha, en vez de quedarse encima de las demás (Super + Alt + Espacio las vuelve a soltar).
  En el modo flotante las flechas recorren mitades y cuartos (← y luego ↑ = cuarto de arriba a la izquierda).
- **Panel lateral en columnas**: las web apps del panel miden un tercio de la pantalla (una columna de un mosaico de 3,
  en vez de 560–800 px) y se abren al 90 % de zoom. Fijado, el panel ocupa siempre ese tercio, también en la pestaña
  del asistente: el mosaico queda en tres columnas y las demás ventanas se reparten y se mueven en los otros dos
  tercios. «Ancho en el panel» de cada web app sigue permitiendo 600/800 px o el del panel.
- **Paneles alineados con las ventanas**: el panel lateral (también fijado), el centro de control, las
  notificaciones y el resto de paneles dejan con el borde de la pantalla y con la barra el mismo hueco que las
  ventanas en mosaico (gaps_out), y entre el panel fijado y la ventana vecina el mismo que entre dos ventanas.
- **Asistente más ancho y con respuestas ricas**: mide lo mismo que las web apps (un tercio; Ajustes › Panel lateral ›
  Ancho). Las respuestas se dibujan con formato: bloques de comandos y código con «Copiar», gráficos de barras, líneas
  o sectores (bloque `hf-chart` que el modelo usa cuando aporta o se lo pides) e imágenes.
- **Centro de control sin desplazar todo**: los avisos ocupan el hueco entre los ajustes rápidos y la agenda; con
  muchos solo se desplazan las listas de Recientes e Historial y la agenda queda a la vista.
- **Dictado más preciso y rápido, en español e inglés**:
  - Motor nuevo **Parakeet v3** (NVIDIA, con onnx-asr; `hf-dictate install-parakeet` o el botón de Ajustes › Dictado):
    entiende español, inglés y 23 idiomas más sin elegir, puntúa solo y en CPU tarda ~0,3 s por frase (whisper small
    ~2 s). En «Automático» se usa si está instalado.
  - Antes el automático usaba Vosk, que fallaba mucho y no entendía inglés: ahora va Parakeet → whisper → Vosk.
  - whisper: idioma «Español + inglés» (por defecto; cada frase en el idioma que oye, sin traducir), contexto de audio
    a la medida de la frase y búsqueda en haz: ~2 s por frase en CPU (antes ~3 s) y menos errores.
  - GPU: con `ggml-vulkan` instalado se mide una vez la GPU frente a la CPU y se usa la más rápida (con algunas
    tarjetas y versiones de ggml-vulkan la GPU va varias veces más lenta). `dictationGpu`: auto | si | no.
- **Centro de control en páginas**: los mosaicos se deslizan en horizontal (rueda, Mayús + rueda o arrastrando, con
  puntitos de página). En la segunda página: claro/oscuro, escritorio remoto, cafeína, selector de color y dos
  mosaicos nuevos, **Teléfono** (Valent: abrir, hacer sonar, enviar archivo) y **Duplicar móvil** (scrcpy: instalar,
  abrir, comprobar). La tarjeta del teléfono ya no ocupa sitio abajo.
- **Super + Mayús + S hace lo mismo que Impr Pant**: abre la herramienta de captura (región, ventana, pantalla o
  grabar) en vez de recortar directamente.
- **Grabar un GIF o un clip corto**: en la barra de grabación se elige Vídeo, Clip (hasta 60 s, MP4 ligero) o GIF
  (hasta 30 s, 15 fps, ≤ 960 px). Al terminar se copia el archivo para pegarlo en un chat y el aviso ofrece abrirlo o
  abrir la carpeta. Para enseñar rápido algo que falla.
- **Desenfoque en todos los estilos**: el desenfoque del fondo de SkySoul (selector de espacios, paneles, barra)
  ahora también en Material y Chroma. Se quita con Calidad del desenfoque › Ahorro, modo concentración o Reducir
  transparencia.
- **Web apps más rápidas y sin pantallazo negro**: nacen escondidas, se precargan las del panel al abrirlo la primera
  vez y Chromium ya no congela las que no se ven (por eso YouTube tardaba y al volver se veía negro un momento).
- **Asistente con historial y documentos**:
  - Botón del reloj en la cabecera: todas las conversaciones guardadas con título, fecha y nº de mensajes, buscador
    (también dentro del texto), abrir para seguirla, borrar y «Nueva».
  - Arrastrar y soltar (o el clip) también documentos: PDF, texto, Markdown, código, CSV, DOCX/ODT… El asistente lee
    su texto (hasta 8 por mensaje); se ven como etiquetas en el mensaje y con un clic se abren.
  - Bajo cada respuesta: Copiar y, en la última, «Otra respuesta». Los gráficos usan marcas redondas en el eje.
- **Instalar gallery-dl ya funciona**: no está en los repos oficiales de Arch y se intentaba con pacman; ahora va por
  AUR (yay/paru). Ajustes › Almacenamiento explica para qué sirve cada herramienta de descarga.

## [0.8.4] — 2026-11-08

- **Entrar es ~2,5 s más rápido**: el login esperaba a que pasaran sus cuatro mensajes («Comprobando…»,
  «Bienvenido»…) antes de arrancar la sesión; ahora arranca en cuanto la contraseña es correcta.
- **Pantalla de carga al entrar**: el logo de HyprFrijol y una barrita mientras el fondo y la barra terminan de
  cargar (un segundo o menos; solo al iniciar sesión, no al reiniciar el shell). Se quita en Ajustes › Energía y
  rendimiento › «Pantalla de carga al entrar».
- **Logo de HyprFrijol en Ajustes › Acerca del sistema**, con la versión instalada.
- **Centro de control más rápido**: Spotlight y el centro de control se precargan en segundo plano poco después de
  entrar y el centro se queda cargado (la primera apertura con el teclado tardaba ~220 ms; ahora ~50 ms).
- **Muchas notificaciones sin salirse de la pantalla**: en el centro de control la lista ocupa el hueco que queda bajo
  los ajustes rápidos y se desplaza por dentro (con barra fina); la pila de avisos emergentes tampoco pasa del alto
  de la pantalla. Los filtros por app del historial van en una sola fila que se desplaza en horizontal.
- **Gato bongo** (Ajustes › Barra › «Gato bongo»): un gatito en la barra que golpea la mesa con la pata izquierda o
  derecha al escribir. `scripts/hf-bongo` solo dice la mano, nunca la tecla, y no guarda nada; necesita estar en el
  grupo `input`. Clic: dormirlo.
- **Iconos en vez de «CPU», «GPU» y «RAM»** en el chip de sistema de la barra (estilo texto).
- **Super + flechas respetan el mosaico**: ← → cambian la ventana de sitio con la vecina sin cambiar su tamaño, ↑ la
  maximiza dentro del mosaico y ↓ lo deshace (antes la sacaban a flotante con media pantalla). Una ventana que flotaba
  por un acople anterior vuelve al mosaico. En los espacios flotantes siguen acoplando a mitades.
- **Islas de la barra más juntas**: la de los chips (clima, sistema, pomodoro, cafeína…) y la del estado.
- **Apps GTK de cristal de verdad en SkySoul**: además del desenfoque, el mismo esmerilado claro arriba y el
  resplandor del acento que los paneles del shell, y menos capas opacas encima (antes se veían solo translúcidas).

## [0.8.3] — 2026-11-08

- **Login arreglado**: la sesión ya no vuelve al login nada más entrar. greetd (con `source_profile`) unía los
  argumentos de `sh -c`; ahora la sesión se lanza en palabras sueltas.
- **Tu foto en el login**: `hf-greeter-sync` copia `~/.face` al login, porque el greeter no puede leer tu carpeta personal.
- **El login con tu mismo fondo, también en movimiento**: si tu fondo es un vídeo, el login lo reproduce en bucle y
  sin sonido (una copia ligera; necesita `qt6-multimedia` y `qt6-multimedia-ffmpeg`; si no están, se ve un fotograma).
  La carpeta `/etc/greetd/quickshell/live` pasa a ser tuya: después de la primera sincronización, el login se pone al
  día solo al cambiar de fondo, de tema o de foto, sin pedir contraseña.
- **Fondo en vídeo más fiable**: un vigilante relanza mpvpaper si se cierra (por ejemplo, cuando una pantalla se
  enciende y se apaga al iniciar sesión) y, si no hay manera, vuelve a la imagen fija en lugar de dejar el escritorio
  en negro. `hf-wallpaper` solo cierra el reproductor de su propia sesión.
- **Movimiento del fondo**: activarlo o quitarlo en Ajustes › Fondos se aplica al momento.
- **Cambiar de un fondo en vídeo a otro sin pantallazo negro**: el reproductor anterior sigue hasta que el nuevo ya
  pinta y, mientras tanto, se ve el primer fotograma del nuevo (antes se cerraba primero y a veces el escritorio se
  quedaba en negro hasta otro clic).
- **El selector de fondos (Super+Mayús+W) enseña los vídeos en movimiento**: al pararte en uno se reproduce en
  grande, en bucle y sin sonido (necesita `qt6-multimedia-ffmpeg`; sin él, la imagen fija de siempre).
- **La pantalla de bloqueo también se mueve** con un fondo en vídeo (quieta con «Reducir movimiento» o, si así está
  en Ajustes › Fondos, con batería).
- **El escritorio ya no se queda en negro con un fondo en vídeo** al iniciar sesión: la capa del fondo nacía opaca y
  Quickshell no la dejaba volverse transparente después.
- **Cambiar de estilo ya no cambia tu redondeo**: el estilo solo cambia el material (colores, transparencia, bordes,
  brillos); los radios, las píldoras y las esquinas los decide Ajustes › Apariencia › Redondeo, igual en todos.
- **Estilos renovados**: ahora hay tres, Material, **SkySoul** y **Chroma**.
  - **SkySoul** (antes *Aurora*): el orden de Material hecho de cristal. Muy transparente sobre un desenfoque muy
    amplio, esmerilado más claro arriba, un resplandor suave del acento que se desliza despacio por los paneles
    abiertos (se para con «Reducir movimiento») y bordes de dos trazos: un filo exterior oscuro casi invisible que lo
    separa de cualquier fondo y un filo interior de luz que da grosor al cristal.
  - **Chroma** (sustituye a *Mica*), como los Nothing Phone: negro puro, gris carbón, títulos y reloj con letra de
    puntos (Doto, incluida en `config/quickshell/assets/fonts`, licencia OFL), espacios de trabajo como puntos Glyph,
    deslizadores y anillos de puntos, lo activo en blanco y el rojo solo para lo importante. Usa su propia paleta.
  - SkySoul de verdad translúcido: Ajustes, Herramientas y Firmar nacían opacos en Material y se quedaban negros
    al pasar a SkySoul; y el desenfoque, más fino y luminoso, deja intuir el fondo en vez de un gris plano.
  - Chroma: el aviso de volumen y brillo es una barra de puntos, en rojo si está silenciado.
  - Bordes de SkySoul suaves: el borde de las ventanas es un filo de luz casi transparente (antes una línea del
    color del acento); los paneles y las islas de la barra ya no tienen contorno oscuro, solo un filo de luz que
    se desvanece hacia abajo, y la sombra es tan tenue que no se transparenta por el cristal.
  - **Las apps GTK cambian con el estilo** (con «Aplicar a las apps»): en SkySoul, Nautilus, Loupe y compañía son
    de cristal desenfocado; en Chroma, negro Nothing con lo activo en blanco, filos de 1 px y títulos con Doto
    (se enlaza en `~/.local/share/fonts/hyprfrijol`). Las apps abiertas lo toman al volver a abrirlas.
  - Se retira *Suave*. Quien tenía Aurora pasa a SkySoul, Mica a Chroma y Suave a Material, sin hacer nada.

## [0.8.2] — 2026-11-07

- **Dictado sin IA y en tiempo real con Vosk**: si está Vosk (`python-vosk` + `vosk-api`, ahora recomendado), cada
  palabra aparece mientras hablas y cada frase se escribe al hacer una pausa; whisper.cpp queda como alternativa más
  precisa, por frases (y es el que se usa mientras Vosk no esté: Ajustes › Dictado lo instala con un clic). Se retira
  «Mejorar el texto con IA» (`dictationAI`; `hf-migrate` la quita con copia). La IA solo recibe las órdenes de voz que
  no se entienden. Con el modelo pequeño en español (40 MB): 7,7 % de palabras erróneas en una lectura de 93 s, 33×
  más rápido que el tiempo real en CPU (whisper «base»: 12 %).
- **«Distro»** es la palabra para dar órdenes al dictar («Distro, sube el volumen», «oye Distro…»), en homenaje a las
  distribuciones de Linux; se puede cambiar en Ajustes › Dictado. Quien tuviera «Frijol» sin tocar pasa a «Distro».
- **Órdenes de voz propias**: frase → comando, app, web u otra orden (con `*` para lo que digas), y otras palabras para
  las de serie («toca» = «reproduce»). Se comprueban escribiéndolas, sin ejecutar nada.

## [0.8.1] — 2026-11-07

- **Dictado en tiempo real** (whisper.cpp residente): el texto aparece mientras hablas, en la misma posición que
  los avisos de volumen y mayúsculas, y se escribe por frases. Modelos gestionables desde Ajustes › Dictado,
  GPU (Vulkan) si está instalada y motores Vosk / faster-whisper opcionales.
- **Órdenes de voz** (Super+Alt+V, o «Frijol, …» mientras dictas; `hf-voice`): música en YouTube, YouTube Music
  o Spotify («Reproduce Walk de los Foo Fighters desde YouTube»), volumen, brillo, controles multimedia, el
  navegador (abrir sitios, buscar, pestañas, desplazarse, zoom), espacios, ventanas, fondos, temporizadores… Lo que
  no entiende pasa al asistente, con su aprobación.
- **VPN de empresa**: FortiGate (FortiClient) y GlobalProtect (Palo Alto) con usuario y contraseña, 2FA,
  certificado o SSO/SAML en el navegador, sin sudo (NetworkManager + OpenConnect / openfortivpn / gpclient);
  confianza en el certificado del servidor e importación de copias de FortiClient. Los clientes oficiales
  aparecen si están instalados.
- **Escritorio remoto**: Remmina por defecto para Windows (RDP), con puerta de enlace, varias pantallas, carpetas
  y sonido; FreeRDP 3 y Conexiones como alternativas.
- **Apps en ventana flotante** (Ajustes › Escritorio y gestos): archivos, imágenes, audio, vídeo, calculadora o
  cualquier app se abren flotantes y centradas en vez de en mosaico.
- **Desinstalar apps** desde Ajustes › Aplicaciones › «Instaladas en este equipo» (paquetes y Flatpak), con las
  esenciales protegidas y aviso de lo que se lleva cada paquete.
- **Panel lateral fijable**: el asistente puede quedarse fijo como parte del mosaico en vez de por encima.
- **Calendario plegable** en el centro de control: una sola fila con la semana actual.
- **Sin KDE**: Valent sustituye a KDE Connect (`hf-phone`), las apps Qt usan qt6ct y los selectores de archivo,
  el portal GTK (`hf-pickfile`). Las apps de KDE siguen como alternativa opcional.
- **Selector de fondos** rediseñado, con animaciones más fluidas.
- **Arreglado**: las apps GTK (Nautilus, Loupe…) tardaban hasta 15 s en abrir porque cada recarga repetía las
  rutas de `XDG_DATA_DIRS`; montaje de discos NTFS/exFAT con mensaje claro si falta el controlador o reiniciar.
- **Se retiran los perfiles de actividad** (Trabajo, Diseño 3D, Juego, Personal; `hf-profile`, Ctrl+Super+P).
  Los avisos siguen solo «no molestar» y el modo sin distracciones; la barra, sus propios ajustes (Super+J la
  esconde en la sesión). `hf-migrate` (y `hf-apply` al arrancar) borra su estado y quita `profiles`,
  `profileRules` y `notifyFavorites` de settings.json, con copia. El modo de energía no se toca.

## [0.8.0] — 2026-11-07

Primera versión publicada con etiqueta.

- **Sesión aparte** «Hyprland (HyprFrijol)»: Hyprland 0.57+ configurado en Lua (`config/hypr/`), sin tocar
  `~/.config/hypr`; tus cambios en `~/.config/hyprfrijol/local.lua`.
- **Shell en Quickshell**: barra (abajo, arriba o izquierda; fija o flotante), Spotlight (apps, archivos,
  calculadora, comandos, ventanas, portapapeles, emojis), centro de control (ajustes rápidos, notificaciones,
  agenda), OSD, vista general, Alt+Tab, Snap, dock, widgets y escritorio.
- **Aspecto**: estilos Aurora, Material, Mica y Suave; colores del fondo (matugen) o 45 paletas; claro/oscuro/auto;
  el tema llega a kitty, GTK, Qt/KDE, btop e iconos.
- **Panel lateral** con el asistente de IA: aprobación paso a paso con vista previa, «aprobar siempre» revocable
  y primeros pasos con ejemplos (`hf-ai`, `hf-mcp`); web apps opcionales.
- **PiP** para vídeos, videollamadas (Meet, Teams, Zoom, Jitsi) y reproductores (Spotify, YouTube Music), con los
  botones por fuera de la ventana, en el lado contrario a su posición.
- **Herramientas**: selector de fondos (por monitor, por hora), captura y grabación con lupa, OCR y anotación,
  selector de color, modo sin distracciones, bloqueo, menú de energía, agente de polkit.
- **Ajustes** completos (Apariencia, Barra, Pantallas, Sonido, Red, Bluetooth, Energía, Plugins, Sistema…)
  con buscador; centro de actualizaciones del sistema con punto de restauración (`hf-updates`).
- **Login** propio con greetd + Quickshell, sincronizado con tu tema (`hf-greeter-sync`).
- **Instalador** para Arch, Fedora, openSUSE, Debian/Ubuntu y Void (`install.sh`, `install/packages.tsv`),
  también en sistemas mínimos sin escritorio.
- **Que no se rompa**: modo seguro en el login (`hf-safe`, `config/hypr/safe.lua`), copias «buenas» de tus
  ajustes, diagnóstico copiable (`hf-doctor`) y actualización por versiones con vuelta atrás (`hf-update`).
- **Plugins de Omarchy**: carga widgets de barra, paneles, menús, superposiciones y servicios de la shell de Omarchy,
  e importa sus temas `colors.toml` (`hf-plugin`, Ajustes › Plugins de Omarchy).
- **Aplicaciones por niveles** (de serie, productividad, destacadas, creativas, experimentales) con `hf-apps` y
  Ajustes › Aplicaciones; extensión de Nautilus (preguntar a la IA, firmar PDF, OCR, convertir, poner de fondo).
- **Día a día**: memorias USB con aviso, «Abrir» y «Expulsar» (`hf-devices`, Ajustes › Almacenamiento); cola de
  descargas de vídeo, audio e imágenes (`hf-download`); fondos de Wallhaven (`hf-wallhaven`); discos NTFS y exFAT.
- **Dependencias por función** (`hf-deps`): qué falta para cada parte del escritorio y cómo instalarlo.
- **Carga diferida**: las vistas se cargan al abrirlas (unos 55 MB menos de RAM en reposo).
- **Aspecto por defecto**: paleta Oxocarbon, estilo Material, barra arriba en archipiélago.
