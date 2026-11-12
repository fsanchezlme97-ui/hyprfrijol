// Pantalla de bloqueo (diseño «Bloqueo»): ext-session-lock de Wayland + PAM. Lo que se ve está en LockFace.qml
// (lo que muestra se elige en Ajustes › Bloqueo e inicio de sesión).
//   qs -p <repo>/config/quickshell ipc call lock lock        (lo usa scripts/hf-lock; Super + L; hypridle)
//   qs -p <repo>/config/quickshell ipc call lock isLocked
// Es un bloqueo seguro: si Quickshell se cae, Hyprland mantiene la sesión bloqueada.
// PAM: usa /etc/pam.d/hyprlock si existe (como hyprlock); si no, «login». Con pam_fprintd en la pila, la huella
// funciona igual que en hyprlock (el aviso del lector aparece debajo del campo).
// Pruebas (solo con HF_TRY=1, dev/try.sh):  HF_TRY_LOCK=1 bloquea al arrancar · HF_TRY_LOCK=error muestra el error.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../.."
import "../../components"
import "../../services"


Scope {
    id: root
    readonly property bool dry: Quickshell.env("HF_TRY") === "1"
    readonly property string tryMode: dry ? (Quickshell.env("HF_TRY_LOCK") ?? "") : ""
    readonly property string userName: Quickshell.env("USER") ?? ""
    property string realName: ""
    property string pamConfig: "login"
    property bool hasFprint: false
    property bool caps: false
    property bool hasFace: false
    // Fondo en vídeo puesto ahora (hf-wallpaper: wallpaper.json «video» + wallpaper-path). Quieto con «Reducir
    // movimiento» y, si así se pidió en Ajustes › Fondos, con batería (como en el escritorio)
    readonly property string wallVideo: {
        const p = (wallPath.text() || "").trim();
        if (!wallJson.video || !/\.(mp4|webm|mkv|mov|gif)$/i.test(p) || Theme.still) return "";
        const on = Settings.get("wallpaperPauseOn", ["fullscreen", "bateria", "juego"]);
        if (Battery.onBattery && Array.isArray(on) && on.includes("bateria")) return "";
        return p;
    }
    FileView { id: wallPath; path: Paths.state + "/wallpaper-path"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    FileView {
        path: Paths.state + "/wallpaper.json"; watchChanges: true; printErrors: false; onFileChanged: reload()
        JsonAdapter { id: wallJson; property bool video: false }
    }
    readonly property bool forceScene: tryMode === "scene" || tryMode === "error"

    property string password: ""
    property string state: ""          // "" | "checking" | "error" | "ok"
    property string message: ""        // aviso de PAM (huella, error…)
    property date lockedAt: new Date()
    signal shake()
    signal clearInput()
    function checkCaps(): void { capsProc.running = true; }

    // El vídeo de fondo se queda quieto tras 2 min sin tocar nada: decodificarlo (por CPU con nouveau, 4K a 60 fps)
    // costaba ~1,4 núcleos por pantalla toda la noche, también con las pantallas apagadas. Ratón o tecla: sigue.
    property bool videoAwake: true
    function wake(): void { videoAwake = true; videoNap.restart(); }
    onPasswordChanged: wake()
    Timer { id: videoNap; interval: 120000; running: sessionLock.locked && root.videoAwake; onTriggered: root.videoAwake = false }

    function lock(): void {
        if (sessionLock.locked) return;
        videoAwake = true;
        password = ""; state = ""; message = ""; lockedAt = new Date();
        Shell.close();
        sessionLock.locked = true;
    }
    function submit(): void {
        if (state === "checking" || state === "ok") return;
        if (password === "" && !hasFprint) { fail("Escribe tu contraseña"); return; }
        state = "checking"; message = "";
        if (pam.active) pam.abort();
        pam.start();
    }
    function fail(msg: string): void {
        state = "error";
        message = msg;
        password = "";
        clearInput();
        shake();
    }
    function succeed(): void {
        state = "ok";
        unlockTimer.restart();
    }
    Timer { id: unlockTimer; interval: Theme.still ? 0 : 260; onTriggered: { sessionLock.locked = false; root.password = ""; root.state = ""; root.message = ""; } }

    PamContext {
        id: pam
        config: root.pamConfig
        user: root.userName
        onPamMessage: {
            if (responseRequired) respond(root.password);
            else if (message) root.message = message;     // p. ej. «Coloca el dedo en el lector»
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.succeed();
            else if (result === PamResult.MaxTries) root.fail("Demasiados intentos. Espera un momento");
            else root.fail("Contraseña incorrecta");
        }
        onError: err => root.fail("No se pudo comprobar la contraseña")
    }

    // Detección: pila PAM, nombre completo, huella, Bloq Mayús
    Process {
        running: true
        command: ["sh", "-c", 'test -f /etc/pam.d/hyprlock && echo hyprlock || echo login; echo "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"; command -v fprintd-verify >/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q "#" && echo fp || echo nofp; test -s "$HOME/.face" && echo face || echo noface']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.pamConfig = l[0] || "login";
                root.realName = (l[1] || "").trim();
                root.hasFprint = (l[2] || "") === "fp";
                root.hasFace = (l[3] || "") === "face";
            }
        }
    }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.trim() !== "" && text.trim() !== "0" }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
    }

    Component.onCompleted: {
        if (tryMode !== "") {
            lock();
            if (tryMode === "error") Qt.callLater(() => { password = "x"; fail("Contraseña incorrecta"); });
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        onLockedChanged: Shell.locked = locked

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            LockFace {
                anchors.fill: parent
                ctl: root
                video: root.wallVideo
                videoPaused: !root.videoAwake
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.still ? 0 : 320; easing.type: Easing.OutCubic } }
            }
            // Mover el ratón despierta el vídeo (pasivo: los botones del bloqueo siguen recibiendo el cursor)
            // (Qt manda eventos de cursor sintéticos en cada fotograma del vídeo: solo cuenta si el cursor se movió)
            HoverHandler {
                property point last: Qt.point(-1, -1)
                onPointChanged: {
                    const q = point.position;
                    if (Math.abs(q.x - last.x) + Math.abs(q.y - last.y) < 3) return;
                    last = q;
                    root.wake();
                }
            }
        }
    }
}
