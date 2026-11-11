// Fondo de pantalla dibujado por el propio shell (sustituye a swww).
// hf-wallpaper escribe ~/.local/state/hyprfrijol/wallpaper.json y aquí se hace el fundido:
//   { image, video, fadeMs, monitors: { "DP-1": "/ruta.jpg" } }   (monitors = fondo propio por pantalla)
//   motions: { "DP-1": "/vídeo.mp4" } + motionOn: { "DP-1": true } = esa pantalla tiene vídeo propio y ya pinta
// - Modo de color «mono» + ajuste monoFondo (por defecto sí) → el fondo se ve en blanco y negro.
// - Rotación: wallpaperRotateMin > 0 cambia el fondo cada N minutos (wallpaperRandom = al azar);
//   wallpaperHora = true pone el fondo de la hora del día (amanecer, bruma, lago, noche).
// Si el fondo es un vídeo que reproduce mpvpaper, esta capa se oculta.
// Ajustes › Fondos: wallpaperTransition ("fundido" | "ninguna"), wallpaperNoFullscreen (la rotación espera a que no
// haya nada en pantalla completa), wallpaperPauseOn (pausa el fondo en movimiento: fullscreen | bateria | maximizada |
// cubierto (las ventanas tapan ≥ 85 % de cada pantalla, en mosaico o flotantes) | juego | foco). wallpaperMotion / wallpaperMotionKind / wallpaperFps los aplica hf-wallpaper.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"

PanelWindow {
    id: win
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "hf-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    // Con vídeo (mpvpaper, también en la capa Background) esta ventana debe ser transparente: al reiniciar el shell
    // se crea por encima de mpvpaper y, con color opaco, taparía el fondo en movimiento.
    color: win.showVideo ? "transparent" : Theme.bg
    // Sin esto, una ventana que nace opaca (al arrancar, antes de leer wallpaper.json) ya no puede volverse
    // transparente: el escritorio se quedaba negro con el vídeo detrás.
    surfaceFormat.opaque: false

    property bool showA: true
    // Ya se ve algo (Splash.qml espera a esto): la imagen cargada o, con vídeo, el fotograma/mpvpaper detrás
    readonly property bool ready: wpLoaded && (wp.video || a.status === Image.Ready || b.status === Image.Ready || win.image === "")
    property bool wpLoaded: false
    readonly property string outName: screen?.name ?? ""
    // Fondo propio de esta pantalla, si lo tiene
    readonly property string ownImage: (wp.monitors ?? {})[outName] ?? ""
    readonly property string image: ownImage || wp.image
    // Se ve un vídeo detrás: el propio de la pantalla (cuando ya pinta) o, sin fondo propio, el global
    readonly property bool showVideo: ownImage !== "" ? !!(wp.motionOn ?? {})[outName] : wp.video
    readonly property bool mono: Settings.get("colorMode", "auto") === "mono"
                                 && Settings.get("monoFondo", true) !== false && Settings.get("monoFondo", true) !== "false"
    // Solo la primera pantalla se encarga de rotar (hay una instancia de esto por pantalla)
    readonly property bool primary: Quickshell.screens.length === 0 || screen === Shell.primaryScreen

    function apply() {
        if (!image) return;
        const url = "file://" + image;
        const cur = showA ? a : b;
        if (cur.source.toString() === url && cur.status === Image.Ready && !changedSinceShown) return;
        changedSinceShown = false;
        const target = showA ? b : a;
        if (target.source.toString() === url) target.source = "";   // forzar recarga si es el mismo archivo
        target.source = url;
    }
    property bool changedSinceShown: false
    readonly property int fadeMs: Settings.get("wallpaperTransition", "fundido") === "ninguna" ? 0 : wp.fadeMs
    onImageChanged: apply()

    FileView {
        path: Paths.state + "/wallpaper.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { win.changedSinceShown = true; reload(); }
        onLoaded: { win.wpLoaded = true; win.apply(); if (win.primary) { win.sentPause = false; pauseRe.restart(); } }
        onLoadFailed: win.wpLoaded = true
        JsonAdapter {
            id: wp
            property string image: ""
            property bool video: false
            property int fadeMs: 1200
            property var monitors: ({})
            property var motionOn: ({})
            property real changed: 0
        }
    }

    component Layer: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(win.width * (win.screen?.devicePixelRatio ?? 1), win.height * (win.screen?.devicePixelRatio ?? 1))
        Behavior on opacity { NumberAnimation { duration: win.fadeMs; easing.type: Easing.InOutQuad } }
    }

    Item {
        id: stack
        anchors.fill: parent
        visible: !win.showVideo
        // Fundido sin huecos: la imagen nueva aparece ENCIMA y la anterior sigue opaca debajo hasta que la nueva está
        // entera. Antes las dos se cruzaban (1→0 y 0→1) y a medio camino se veía lo de detrás: negro, o el vídeo viejo.
        Layer {
            id: a
            z: win.showA ? 1 : 0
            opacity: win.showA ? 1 : (b.opacity >= 1 ? 0 : 1)
            onStatusChanged: if (status === Image.Ready && !win.showA) win.showA = true
            // ya tapada del todo: se suelta la imagen anterior (≈ 9 MB a 1920×1200, más su textura)
            onOpacityChanged: if (opacity === 0 && !win.showA) source = ""
        }
        Layer {
            id: b
            z: win.showA ? 0 : 1
            opacity: win.showA ? (a.opacity >= 1 ? 0 : 1) : 1
            onStatusChanged: if (status === Image.Ready && win.showA) win.showA = false
            onOpacityChanged: if (opacity === 0 && win.showA) source = ""
        }
        // Blanco y negro (modo mono), con transición suave
        layer.enabled: win.mono || satAnim.running
        layer.effect: MultiEffect {
            saturation: stack.sat
            contrast: -stack.sat * 0.05
        }
        property real sat: win.mono ? -1 : 0
        Behavior on sat { NumberAnimation { id: satAnim; duration: 600 } }
    }

    // ── Estado de las ventanas (pantalla completa / maximizada en algún espacio visible) ──
    readonly property var visibleWs: HyprClients.monitors.map(m => m.activeWorkspace?.id)
    readonly property var shownClients: HyprClients.clients.filter(c => visibleWs.includes(c.workspace?.id))
    readonly property bool anyFullscreen: shownClients.some(c => ((c.fullscreen ?? 0) & 2) !== 0)
    readonly property bool anyMaximized: shownClients.some(c => ((c.fullscreen ?? 0) & 1) !== 0)
    // Cubierto: en TODAS las pantallas (mpvpaper es uno para todas) las ventanas del espacio visible tapan al menos el
    // 85 % de la zona útil, sean en mosaico o flotantes (el escritorio flotante también cuenta). Se mide con una rejilla
    // de 16×10 puntos: barato y no cuenta dos veces lo que se solapa. Antes bastaba una ventana en mosaico, y en el
    // modo flotante nunca se pausaba.
    readonly property bool covered: {
        const mons = HyprClients.monitors;
        if (!mons.length) return false;
        return mons.every(m => {
            const r = HyprClients.usableRect(m), ws = m.activeWorkspace?.id;
            const cs = HyprClients.clients.filter(c => c.workspace?.id === ws || (c.pinned && c.monitor === m.id));
            if (!cs.length || !(r.w > 0 && r.h > 0)) return false;
            if (cs.some(c => (c.fullscreen ?? 0) !== 0)) return true;
            const N = 16, M = 10;
            let hit = 0;
            for (let i = 0; i < N; i++) for (let j = 0; j < M; j++) {
                const x = r.x + (i + 0.5) * r.w / N, y = r.y + (j + 0.5) * r.h / M;
                if (cs.some(c => x >= c.at[0] && x < c.at[0] + c.size[0] && y >= c.at[1] && y < c.at[1] + c.size[1])) hit++;
            }
            return hit >= N * M * 0.85;
        });
    }

    // ── Pausar el fondo en movimiento (lo manda la primera pantalla, para todos los reproductores) ──
    readonly property var pauseOn: {
        const l = Settings.get("wallpaperPauseOn", ["fullscreen", "bateria", "juego"]);
        return (Array.isArray(l) ? l : []).map(x => x === "pantalla-completa" ? "fullscreen" : x);
    }
    // Un juego en un espacio visible (Steam, gamescope: las mismas clases que rules.lua y Focus.qml)
    readonly property bool anyGame: shownClients.some(c => /^(steam_app_\d+|gamescope)$/i.test(c.class ?? ""))
    readonly property bool paused: (wp.video || Object.keys(wp.motionOn ?? {}).length > 0) && (
        (pauseOn.includes("fullscreen") && anyFullscreen) ||
        (pauseOn.includes("maximizada") && anyMaximized) ||
        (pauseOn.includes("cubierto") && covered) ||
        (pauseOn.includes("bateria") && Battery.onBattery) ||
        (pauseOn.includes("juego") && anyGame) ||
        (pauseOn.includes("foco") && Shell.focusMode))
    property bool sentPause: false
    onPausedChanged: if (primary) syncPause()
    function syncPause() {
        if (paused === sentPause) return;
        sentPause = paused;
        // Solo los reproductores de esta sesión (hf-wallpaper guarda sus pids: el global y los propios de cada
        // pantalla): ni otras sesiones ni otros usuarios
        Quickshell.execDetached(["sh", "-c", 'for p in $(cat "$1"/motion*.pid 2>/dev/null); do kill "$2" "$p" 2>/dev/null; done',
                                 "sh", Paths.state, paused ? "-STOP" : "-CONT"]);
    }
    // Un fondo nuevo arranca otro reproductor: volver a aplicar la pausa
    Timer { id: pauseRe; interval: 1500; onTriggered: if (win.paused) win.syncPause() }

    // ── Rotación automática ───────────────────────────────────────────────
    // wallpaperNoFullscreen: si toca cambiar con algo en pantalla completa, se espera a que salga
    readonly property bool holdRotation: Settings.get("wallpaperNoFullscreen", true) !== false && anyFullscreen
    property string pendingCmd: ""
    function rotate(cmd) {
        if (holdRotation) { pendingCmd = cmd; return; }
        pendingCmd = "";
        Quickshell.execDetached(cmd === "hora" ? [Paths.script("hf-wallpaper"), "hora"]
                                               : ["env", "HF_QUIET=1", Paths.script("hf-wallpaper"), cmd]);
    }
    onHoldRotationChanged: if (!holdRotation && pendingCmd !== "") rotate(pendingCmd)
    readonly property int rotateMin: Number(Settings.get("wallpaperRotateMin", 0)) || 0
    readonly property bool byHour: Settings.get("wallpaperHora", false) === true
    Timer {
        running: win.primary && win.rotateMin > 0 && !win.byHour
        repeat: true
        interval: Math.max(1, win.rotateMin) * 60000
        onTriggered: win.rotate(Settings.get("wallpaperRandom", false) ? "random" : "next")
    }
    Timer {
        running: win.primary && win.byHour
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: win.rotate("hora")
    }
}
