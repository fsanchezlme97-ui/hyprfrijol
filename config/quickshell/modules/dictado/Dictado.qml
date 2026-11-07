// Dictado (voz a texto local, como SuperWhisper): atajo global hf:dictado (Super + Alt + D por defecto).
// Mantener pulsado = hablar mientras se mantiene (un toque corto deja la grabación abierta hasta volver a pulsar);
// en modo «toggle» cada pulsación empieza/termina. La lógica está en scripts/hf-dictate (graba, transcribe con
// whisper.cpp y escribe con wtype); aquí solo la píldora con el nivel del micrófono y el estado.
// IPC:  qs -p <repo>/config/quickshell ipc call dictado toggle|start|stop|cancel|state
// Ajustes › Dictado (sections/Dictado.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"

Scope {
    id: root
    // idle | rec | trans | clean | done | error
    property string phase: "idle"
    property string msg: ""
    property string code: ""
    property real secs: 0
    property var levels: Array(28).fill(0)
    property double pressedAt: 0
    property bool latched: false            // toque corto en modo ptt: sigue grabando hasta la próxima pulsación
    readonly property string mode: Settings.get("dictationMode", "ptt")
    readonly property bool busy: proc.running

    function start(): void {
        if (proc.running) return;
        levels = Array(28).fill(0); secs = 0; msg = ""; code = ""; latched = false;
        phase = "rec";
        hider.stop();
        proc.running = true;
    }
    function stop(): void { if (proc.running && phase === "rec") proc.signal(10); }      // SIGUSR1: termina y transcribe
    function cancel(): void { if (proc.running) proc.signal(12); else phase = "idle"; }   // SIGUSR2: descarta
    function toggle(): void { if (proc.running) stop(); else start(); }

    function onEvent(j): void {
        switch (j.ev) {
        case "rec": phase = "rec"; break;
        case "level":
            levels = levels.slice(1).concat([j.v]);
            secs = j.t ?? secs;
            break;
        case "transcribing": phase = "trans"; break;
        case "cleaning": phase = "clean"; break;
        case "text": msg = j.text; break;
        case "done":
            phase = "done";
            msg = j.how === "copiado" ? "Copiado: pégalo con Ctrl + V" : (msg || "Listo");
            hider.interval = j.how === "copiado" ? 3200 : 1600; hider.restart();
            break;
        case "cancelled": phase = "idle"; break;
        case "error":
            phase = "error"; msg = j.msg ?? "Error"; code = j.code ?? "";
            hider.interval = 4500; hider.restart();
            break;
        }
    }

    Process {
        id: proc
        command: [Paths.script("hf-dictate"), "record"]
        stdout: SplitParser { onRead: l => { try { root.onEvent(JSON.parse(l)); } catch (e) {} } }
        onExited: if (root.phase === "rec" || root.phase === "trans" || root.phase === "clean") { root.phase = "idle"; }
    }
    Timer { id: hider; interval: 1600; onTriggered: root.phase = "idle" }

    GlobalShortcut {
        appid: "hf"; name: "dictado"; description: "HyprFrijol: dictado por voz"
        onPressed: {
            if (root.mode === "toggle" || root.latched || root.phase === "rec") { if (root.busy) root.stop(); else root.start(); return; }
            root.pressedAt = Date.now();
            root.start();
        }
        onReleased: {
            if (root.mode === "toggle" || root.phase !== "rec") return;
            if (Date.now() - root.pressedAt < 350) root.latched = true;     // toque corto: manos libres
            else root.stop();
        }
    }
    IpcHandler {
        target: "dictado"
        function toggle(): void { root.toggle(); }
        function start(): void { root.start(); }
        function stop(): void { root.stop(); }
        function cancel(): void { root.cancel(); }
        function state(): string { return root.phase + (root.msg ? " · " + root.msg : ""); }
    }

    // ---------- píldora ----------
    PanelWindow {
        id: win
        readonly property bool shown: root.phase !== "idle"
        screen: Shell.screen
        visible: shown || fade.running
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-dictado"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        readonly property bool top: Settings.get("osdPos", "abajo") === "arriba"
        anchors { bottom: !top; top: top }
        margins { bottom: top ? 0 : (Settings.barReserves && Settings.barPos === "abajo" ? Settings.barEdge : 4) + 50; top: top ? (Settings.barReserves && Settings.barPos === "arriba" ? Settings.barEdge : 4) + 50 : 0 }
        implicitWidth: 520
        implicitHeight: 48 + 40
        mask: Region { item: pill }

        readonly property color accent: root.phase === "rec" ? Theme.danger : root.phase === "error" ? Theme.danger : Theme.p

        Glass {
            id: pill
            kind: "panel"
            radius: Theme.panelRadius
            anchors.centerIn: parent
            width: Math.min(500, Math.max(250, row.implicitWidth + 28))
            height: 48
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn : 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                width: pill.width - 28
                spacing: 12

                // icono con pulso mientras graba
                Item {
                    implicitWidth: 28; implicitHeight: 28
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28; radius: 14
                        color: Qt.alpha(win.accent, 0.18)
                        scale: root.phase === "rec" ? 1 + Math.min(0.35, (root.levels[root.levels.length - 1] ?? 0) * 0.45) : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    Icon {
                        anchors.centerIn: parent
                        size: 15
                        name: root.phase === "done" ? "check" : root.phase === "error" ? "alert" : root.phase === "clean" ? "sparkle" : "mic"
                        color: win.accent
                    }
                }

                // medidor de nivel (últimos 1,4 s)
                Row {
                    visible: root.phase === "rec"
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: root.levels.length
                        Rectangle {
                            required property int index
                            readonly property real v: root.levels[index] ?? 0
                            width: 3; radius: 1.5
                            height: 4 + v * 22
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.t
                            opacity: 0.35 + v * 0.65
                            Behavior on height { NumberAnimation { duration: 70 } }
                        }
                    }
                }
                // puntos mientras transcribe
                Row {
                    visible: root.phase === "trans" || root.phase === "clean"
                    spacing: 5
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 6; height: 6; radius: 3
                            color: Theme.p
                            SequentialAnimation on opacity {
                                running: root.phase === "trans" || root.phase === "clean"
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 160 }
                                NumberAnimation { from: 0.25; to: 1; duration: 320 }
                                NumberAnimation { from: 1; to: 0.25; duration: 320 }
                                PauseAnimation { duration: (2 - index) * 160 }
                            }
                        }
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 360
                    weight: Font.Medium
                    tabular: root.phase === "rec"
                    color: root.phase === "error" ? Theme.danger : Theme.t
                    text: root.phase === "rec" ? Math.floor(root.secs / 60) + ":" + String(Math.floor(root.secs % 60)).padStart(2, "0")
                              + (root.latched || root.mode === "toggle" ? "  ·  pulsa otra vez para terminar" : "")
                        : root.phase === "trans" ? "Transcribiendo…"
                        : root.phase === "clean" ? "Mejorando con IA…"
                        : root.msg
                }
                // Configurar (si falta algo) / cancelar
                Rectangle {
                    visible: root.phase === "error" && ["engine", "model", "recorder", "typer"].includes(root.code)
                    implicitWidth: cfg.implicitWidth + 20; implicitHeight: 26; radius: 13
                    color: Theme.p
                    Txt { id: cfg; anchors.centerIn: parent; text: "Configurar"; size: 12; weight: Font.DemiBold; color: Theme.pText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.phase = "idle"; Shell.open("ajustesapp", "dictado"); } }
                }
                Rectangle {
                    visible: root.phase === "rec" || root.phase === "trans" || root.phase === "clean"
                    implicitWidth: 26; implicitHeight: 26; radius: 13
                    color: xma.containsMouse ? Theme.fill2 : "transparent"
                    Icon { anchors.centerIn: parent; name: "x"; size: 13; color: Theme.tv }
                    MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                }
                // terminar (modo manos libres)
                Rectangle {
                    visible: root.phase === "rec"
                    implicitWidth: 26; implicitHeight: 26; radius: 13
                    color: Qt.alpha(Theme.danger, sma.containsMouse ? 0.3 : 0.18)
                    Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 2; color: Theme.danger }
                    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stop() }
                }
            }
        }
    }
}
