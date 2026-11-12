.pragma library
// Catálogo fijo del Spotlight: acciones del shell (design/Main.dc.html, ITEMS).
// act: lo ejecuta Spotlight.runAct(). top: aparece con la búsqueda vacía.

var ACTIONS = [
    { key: "act:pomo", cat: "Acciones", g: "◷", name: "Iniciar pomodoro", sub: "25 min de foco", kw: "pomodoro tiempo foco timer temporizador", top: true, act: "pomo",
      det: [["Foco / descanso", "25 / 5 min"], ["En la barra", "Clic para pausar · clic derecho reinicia"]] },
    { key: "act:snap", cat: "Acciones", g: "▥", name: "Organizar ventanas", sub: "diseños de acople", kw: "snap layouts mosaico zonas organizar", hint: "Super Alt W", top: true, act: "view:snap",
      det: [["Diseños", "6 + personalizados"], ["Grupos", "Restaura combinaciones recientes"]] },
    { key: "act:clip", cat: "Acciones", g: "⎘", name: "Historial del portapapeles", sub: "fijados y recientes", kw: "clipboard copiado pegar portapapeles", hint: "Super V", top: true, act: "prefix::",
      det: [["Historial", "cliphist"], ["Se borra", "Al cerrar sesión (configurable)"]] },
    { key: "act:emoji", cat: "Acciones", g: "☺", icon: "smile", name: "Emojis", sub: "busca y escribe un emoji", kw: "emoji emoticono caritas simbolos smiley", hint: "Super .", act: "prefix:;",
      det: [["Prefijo", "; y lo que buscas"], ["Intro", "Lo escribe en la ventana (o lo copia)"]] },
    { key: "act:snapshot", cat: "Acciones", g: "◷", name: "Crear punto de restauración", sub: "snapper · btrfs", kw: "snapshot restaurar backup copia snapper rollback restauracion", top: true, act: "snapshot",
      det: [["Herramienta", "Snapper"], ["Arranque", "Aparece en el menú si usas limine-snapper o grub-btrfs"], ["Ojo", "No reemplaza una copia de seguridad"]] },
    { key: "act:focus", cat: "Acciones", g: "◎", name: "Modo sin distracciones", sub: "oculta barra y huecos", kw: "zen foco concentracion enfoque distracciones", act: "focus",
      det: [["Salir", "Super + Z o desde ajustes rápidos"]] },
    { key: "act:agenda", cat: "Acciones", g: "▦", name: "Agenda", sub: "calendario y reuniones", kw: "calendario reunion eventos agenda", act: "view:agenda",
      det: [["También", "Clic en la hora de la barra"]] },
    { key: "act:updates", cat: "Acciones", g: "↻", name: "Actualizar sistema", sub: "paquetes, AUR, Flatpak y firmware", kw: "update upgrade pacman aur flatpak firmware actualizar actualizaciones", act: "view:actualizaciones",
      det: [["Antes", "Punto de restauración automático"]] },
    { key: "act:game", cat: "Acciones", g: "◈", name: "Modo juego (Steam)", sub: "Steam a pantalla completa", kw: "steam juego gaming consola gamescope big picture", act: "game",
      det: [["Sesión", "gamescope si está instalado"], ["Volver", "Steam › Salir de Big Picture"]] },
    { key: "act:capture", cat: "Acciones", g: "◉", name: "Captura o grabación de pantalla", sub: "región, ventana o pantalla · anotar", kw: "screenshot captura grabar video pantalla recortar ocr", hint: "Impr Pant", top: true, act: "view:captura",
      det: [["Herramientas", "grim, slurp, wf-recorder"], ["Guarda en", "~/Imágenes/Capturas"]] },
    { key: "act:color", cat: "Acciones", g: "◍", icon: "drop", name: "Selector de color", sub: "elige un color de la pantalla · HEX, RGB, HSL, OKLCH", kw: "color picker cuentagotas pipeta hex rgb hsl oklch selector colores muestra", hint: "Super Mayús C", act: "view:color",
      det: [["Copia", "En tu formato preferido"], ["Historial", "Los últimos 30 colores"]] },
    { key: "act:widgets", cat: "Acciones", g: "▦", name: "Mostrar escritorio y widgets", sub: "clima, impresora 3D, sistema", kw: "widgets escritorio clima impresora cpu", hint: "Super G", act: "view:widgets",
      det: [["Widgets", "QML · se editan en el sitio"]] },
    { key: "act:downloads", cat: "Acciones", g: "↓", icon: "download", name: "Descargas", sub: "cola de vídeo, música, imágenes y archivos · «descargar <dirección>»", kw: "descargar bajar download yt-dlp youtube mp3 video musica galeria aria2 cola",
      act: "view:w-descargas", det: [["También", "Escribe «descargar» y pega la dirección"]] },
    { key: "act:devices", cat: "Acciones", g: "⏏", name: "Expulsar memorias USB", sub: "unidades extraíbles conectadas", kw: "usb pendrive memoria tarjeta sd expulsar desmontar dispositivos disco extraible",
      act: "view:w-dispositivos", det: [["Ajustes", "Almacenamiento"]] },
    { key: "act:power", cat: "Acciones", g: "⏻", name: "Menú de energía", sub: "bloquear, suspender, apagar", kw: "apagar reiniciar suspender power energia cerrar sesion", hint: "Super Esc", act: "view:energia",
      det: [["Atajo", "Super + Escape"]] },
    { key: "act:lock", cat: "Acciones", g: "⊡", name: "Bloquear pantalla", sub: "pide la contraseña al volver", kw: "bloquear lock pantalla", hint: "Super L", act: "lock",
      det: [["Atajo", "Super + L"]] },
    { key: "act:wall", cat: "Acciones", g: "▨", name: "Cambiar fondo de pantalla", sub: "selector con vista previa", kw: "wallpaper fondo cambiar siguiente animado selector", hint: "Super Mayús W", act: "view:fondos",
      det: [["Colores", "Se adaptan al fondo (modo Automático)"], ["Siguiente", "Super + Shift + W"]] },
    { key: "act:qs", cat: "Acciones", g: "◐", name: "Ajustes rápidos", sub: "Wi‑Fi, Bluetooth, sonido, energía", kw: "wifi bluetooth volumen brillo red ajustes rapidos", act: "view:ajustes",
      det: [["También", "Clic en wifi · altavoz · batería de la barra"]] },
    { key: "act:allapps", cat: "Apps", g: "▦", icon: "grid", name: "Todas las apps", sub: "cuadrícula por categoría", kw: "todas apps aplicaciones programas instaladas launchpad cajon cuadricula lista menu", act: "allapps",
      det: [["Teclas", "←↑↓→ · Tab categoría · Alt + letra"], ["Clic derecho", "Dock, archivo .desktop, desinstalar"], ["También", "El botón ⌘ de la barra"]] },
    { key: "act:settings", cat: "Apps", g: "⚙", name: "Ajustes", sub: "apariencia, barra, fondos, IA…", kw: "ajustes configuracion settings preferencias apariencia tema", act: "view:ajustesapp",
      det: [["Secciones", "18 · desde apariencia hasta accesibilidad"]] },
    { key: "act:tools", cat: "Apps", g: "⬡", name: "Centro de aplicaciones", sub: "instala apps recomendadas", kw: "instalar apps aplicaciones programas herramientas tienda software centro", hint: "Super Mayús I", act: "view:herramientas",
      det: [["Fuentes", "Repositorios, AUR, Flathub y AppImage"], ["Selección", "Por categoría o por perfil"]] },
    { key: "act:firmar", cat: "Apps", g: "✍", name: "Firmar documentos", sub: "pon tu firma en un PDF", kw: "firmar firma pdf documento contrato rubrica signature sign escanear foto", act: "view:firmar",
      det: [["Firmas", "De una foto (sin fondo) o dibujada"], ["Resultado", "nombre-firmado.pdf junto al original"]] },
    { key: "act:welcome", cat: "Apps", g: "✺", name: "Bienvenida / asistente inicial", sub: "idioma, estilo, fondo, barra y apps", kw: "bienvenida asistente inicial primer arranque configurar tutorial wizard empezar", act: "view:bienvenida",
      det: [["Pasos", "Idioma · estilo · fondo · barra · apps · listo"], ["También", "Ajustes › Aplicaciones"]] },
    { key: "act:ia", cat: "IA", icon: "ai", g: "", name: "Preguntar al asistente", sub: "o escribe ? y tu pregunta", kw: "ia ai asistente chat pregunta claude", hint: "Super A", top: true, act: "view:ia",
      det: [["Modelo", "El de Ajustes › IA"], ["Contexto", "Ventana activa + portapapeles"]] }
];

// Color de la baldosa por categoría (CAT_TILE del diseño)
var CAT_TILE = { "Apps": "s4", "Web apps": "pc", "Ventanas": "s4", "Archivos": "s4", "Acciones": "s4", "IA": "p",
                 "Calculadora": "p", "Web": "s4", "Comandos": "s4", "Fijados": "s4", "Recientes": "s4" };

// Orden de categorías en los resultados
var CAT_ORDER = ["Fijados", "Calculadora", "Apps", "Ventanas", "Web apps", "Acciones", "Archivos", "Comandos", "IA", "Web"];

// Puntuación difusa: prefijo > inicio de palabra > subcadena > subsecuencia. 0 = no coincide.
function score(hay, q, noFuzzy) {
    if (!q) return 1;
    hay = hay.toLowerCase();
    var i = hay.indexOf(q);
    if (i === 0) return 100 - Math.min(20, hay.length / 4);
    if (i > 0) {
        var prev = hay.charAt(i - 1);
        return (/[\s\-_.\/·(]/.test(prev) ? 80 : 60) - Math.min(15, i / 3);
    }
    // subsecuencia compacta (solo en el nombre): «vsc» → «Visual Studio Code»
    if (noFuzzy || q.length < 3) return 0;
    var j = 0, gaps = 0, last = -1;
    for (var k = 0; k < hay.length && j < q.length; k++) {
        if (hay.charAt(k) === q.charAt(j)) { if (last >= 0) gaps += k - last - 1; last = k; j++; }
    }
    if (j < q.length || gaps > q.length * 3) return 0;
    return Math.max(8, 40 - gaps * 2);
}

// Todas las palabras de la consulta deben aparecer (como el diseño); la nota es la media
function multiScore(fields, q) {
    var words = q.toLowerCase().split(/\s+/).filter(function (w) { return w.length; });
    if (!words.length) return 1;
    var total = 0;
    for (var w = 0; w < words.length; w++) {
        var best = 0;
        for (var f = 0; f < fields.length; f++) {
            if (!fields[f]) continue;
            var s = score(String(fields[f]), words[w], f > 0) * (f === 0 ? 1 : 0.7);
            if (s > best) best = s;
        }
        if (best === 0) return 0;
        total += best;
    }
    return total / words.length;
}

// Expresión aritmética simple (como el diseño): solo números y operadores
function isArithmetic(q) {
    return /^[\d\s+\-*\/().,%^]+$/.test(q) && /[+\-*\/%^]/.test(q) && /\d/.test(q);
}
