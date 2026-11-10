// Dictado y comandos de voz (local, como SuperWhisper): atajos globales hf:dictado (Super + Alt + D), hf:comando
// (Super + Alt + V) y hf:hablar (Super + Alt + H: lo dicho va al asistente, que contesta con voz si aiVoice). Modo «ptt»: hablar mientras se mantiene (un toque corto deja el micrófono abierto hasta volver a
// pulsar); «toggle»: cada pulsación empieza/termina; «continuo»: empieza al pulsar y para solo tras unos segundos
// callado. Mientras hablas el texto se va escribiendo en la ventana y lo provisional se corrige al terminar cada frase
// (scripts/hf-dictate: VAD + whisper-server residente). Al dictar, «Distro, …» al principio de una frase es una orden (dictationWake);
// las órdenes las entiende scripts/hf-voice (sin IA) y lo demás va al asistente.
// La píldora va donde el OSD y con su estilo (services/OsdStack.qml): pegada al borde y el OSD se aparta.
// IPC:  qs -p <repo>/config/quickshell ipc call dictado toggle|start|stop|cancel|state|command
//       … dictado file <clip.wav> [dictado|comando]  (pruebas: el audio sale del archivo, a tiempo real)
// Ajustes › Dictado (sections/Dictado.qml).
// Botón de la barra: módulo «dictado» de barModules (Shell.dictToggle / Shell.dictPhase).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    // idle | rec | trans | cmd | done | error  (el dictado no usa IA: sin fase de «mejorar»)
    property string phase: "idle"
    property string kind: "dictado"         // dictado | comando | ia (lo dicho va al asistente, no se escribe)
    property string msg: ""
    property string code: ""
    property string partial: ""             // lo provisional de la frase en curso
    property string committed: ""           // lo ya escrito en esta sesión
    property string cmdText: ""             // orden reconocida
    property string cmdMsg: ""              // resultado («Hecho», error…)
    property bool cmdOk: true
    property bool ready: false              // el modelo ya está cargado
    property bool speaking: false
    property real secs: 0
    property var levels: Array(12).fill(0)
    property double pressedAt: 0
    property bool latched: false            // toque corto en modo ptt: sigue grabando hasta la próxima pulsación
    property string pendingKind: ""
    property var args: []
    readonly property string mode: Settings.get("dictationMode", "ptt")
    readonly property bool busy: proc.running

    function start(k, extra, fromKey): void {
        if (proc.running) return;
        kind = k || "dictado";
        levels = Array(12).fill(0); secs = 0; msg = ""; code = ""; latched = !fromKey && mode === "ptt";   // sin atajo: manos libres
        partial = ""; committed = ""; cmdText = ""; cmdMsg = ""; cmdOk = true; ready = false; speaking = false;
        phase = "rec";
        hider.stop(); cmdHider.stop();
        const a = [Paths.script("hf-dictate"), "record", "--mode", fromKey || mode !== "ptt" ? mode : "toggle"];
        if (kind === "comando") a.push("--command");
        if (fromKey) a.push("--hold");     // no escribir con las teclas del atajo aún pulsadas (released() lo suelta)
        args = a.concat(extra ?? []);
        proc.running = true;
    }
    function send(c): void { if (proc.running) proc.write(c + "\n"); }
    function stop(): void { if (proc.running && phase === "rec") { send("release"); send("stop"); } }
    function cancel(): void { if (proc.running) send("cancel"); else phase = "idle"; }
    function toggle(k): void { if (proc.running) stop(); else start(k); }
    function testFile(path, k): void { if (!proc.running) start(k || "dictado", ["--file", path, "--simulate-live"]); }

    function onEvent(j): void {
        switch (j.ev) {
        case "rec": phase = "rec"; break;
        case "ready": ready = true; break;
        case "level":
            levels = levels.slice(1).concat([j.v]);
            secs = j.t ?? secs;
            break;
        case "speech": speaking = j.on; break;
        case "partial": partial = j.text; break;
        case "phrase":
            partial = "";
            if (j.text) committed = (committed + j.text).slice(-400);
            break;
        case "cmd":
            cmdText = "«" + j.text + "»"; cmdMsg = ""; partial = "";
            if (kind === "comando") phase = "cmd";
            cmdHider.stop();
            break;
        case "cmdresult":
            cmdOk = !!j.ok; cmdText = j.intent === "unknown" || !j.label ? (j.text ? "«" + j.text + "»" : cmdText) : j.label;
            cmdMsg = j.fallback === "ai" && j.ok ? "Se lo pregunté al asistente" : (j.msg || (j.ok ? "Hecho" : "No pude hacerlo"));
            if (kind === "comando") { phase = "done"; msg = cmdMsg; hider.interval = j.ok ? 2200 : 4000; hider.restart(); }
            else cmdHider.restart();
            break;
        case "transcribing": phase = "trans"; break;
        case "text": committed = j.text; break;
        case "done":
            if (kind === "ia") {                // hablar con el asistente: la pregunta va al panel lateral
                phase = "done"; msg = committed.trim() ? "Se lo dije a " + (Settings.get("aiName", "") || "el asistente") : "No te oí";
                if (committed.trim()) Shell.open("ia", { ask: committed.trim() });
                hider.interval = 1800; hider.restart();
                break;
            }
            if (j.how === "comando") {          // solo hubo órdenes: se queda el resultado un momento
                if (kind !== "comando") { phase = "done"; msg = cmdMsg; hider.interval = 2400; hider.restart(); }
                break;
            }
            phase = "done";
            msg = j.how === "copiado" ? "Copiado: pégalo con Ctrl + V" : "Escrito";
            hider.interval = j.how === "copiado" ? 3200 : 1600; hider.restart();
            break;
        case "cancelled": phase = "idle"; break;
        case "error":
            if (j.fatal === false) break;
            phase = "error"; msg = j.msg ?? "Error"; code = j.code ?? "";
            hider.interval = 4500; hider.restart();
            break;
        }
    }

    Process {
        id: proc
        command: root.args
        environment: root.kind === "ia" ? { HF_DICTATE_OUTPUT: "ninguna" } : ({})   // «ia»: no escribir en la ventana
        stdinEnabled: true
        stdout: SplitParser { onRead: l => { try { root.onEvent(JSON.parse(l)); } catch (e) {} } }
        onExited: if (["rec", "trans", "cmd"].includes(root.phase)) { root.phase = "idle"; }
    }
    Binding { target: Shell; property: "dictPhase"; value: root.phase }
    Connections { target: Shell; function onDictToggle() { root.toggle("dictado"); } }   // botón de la barra
    Timer { id: hider; interval: 1600; onTriggered: root.phase = "idle" }
    Timer { id: cmdHider; interval: 3000; onTriggered: { root.cmdText = ""; root.cmdMsg = ""; } }

    function pressed(k): void {
        if (proc.running) {
            // Con Super + Alt pulsados, lo que se teclease serían atajos de Hyprland (Super + Alt + S manda la ventana al
            // espacio oculto…): hf-dictate no escribe hasta que released() mande «release»
            root.send("hold");
            if (root.phase === "rec") root.send("stop");
            return;
        }
        root.pressedAt = Date.now();
        root.start(k, null, true);
    }
    function released(): void {
        root.send("release");                                          // ya se puede escribir (en todos los modos)
        if (root.mode !== "ptt" || root.phase !== "rec" || root.latched) return;
        if (Date.now() - root.pressedAt < 350) root.latched = true;    // toque corto: manos libres
        else root.stop();
    }
    GlobalShortcut {
        appid: "hf"; name: "dictado"; description: "HyprFrijol: dictado por voz"
        onPressed: root.pressed("dictado")
        onReleased: root.released()
    }
    GlobalShortcut {
        appid: "hf"; name: "comando"; description: "HyprFrijol: comando de voz"
        onPressed: root.pressed("comando")
        onReleased: root.released()
    }
    GlobalShortcut {
        appid: "hf"; name: "hablar"; description: "HyprFrijol: hablar con el asistente"
        onPressed: root.pressed("ia")
        onReleased: root.released()
    }
    IpcHandler {
        target: "dictado"
        function toggle(): void { root.toggle("dictado"); }
        function talk(): void { root.toggle("ia"); }          // hablar con el asistente (hf-ai talk)
        function command(): void { root.toggle("comando"); }
        function start(): void { root.start("dictado", null); }
        function stop(): void { root.stop(); }
        function cancel(): void { root.cancel(); }
        function file(path: string, kind: string): void { root.testFile(path, kind); }
        function state(): string {
            return root.phase + " · " + root.kind + (root.partial ? " · …" + root.partial : "") + (root.committed ? " · " + root.committed : "")
                + (root.cmdText ? " · orden: " + root.cmdText + (root.cmdMsg ? " → " + root.cmdMsg : "") : "") + (root.msg ? " · " + root.msg : "");
        }
    }

    // ---------- píldora (sitio y estilo del OSD) ----------
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
        anchors { bottom: OsdStack.atB; top: OsdStack.atT; left: OsdStack.atL; right: OsdStack.atR }
        margins {
            bottom: OsdStack.atB ? OsdStack.edge("abajo") : 0; top: OsdStack.atT ? OsdStack.edge("arriba") : 0
            left: OsdStack.atL ? OsdStack.edge("izquierda") : 0; right: OsdStack.atR ? OsdStack.edge("derecha") : 0
        }
        implicitWidth: 680
        implicitHeight: 42 + 40
        mask: Region { item: pill }
        Binding { target: OsdStack; property: "dictation"; value: win.shown ? pill.height : 0 }

        readonly property bool isCmd: root.kind === "comando" || root.cmdText !== ""
        readonly property color accent: root.phase === "error" || (root.cmdText && root.cmdMsg && !root.cmdOk) ? Theme.danger
                                      : root.phase === "rec" && !isCmd ? Theme.danger : Theme.p
        readonly property string iconName: root.cmdMsg ? (root.cmdOk ? "check" : "alert")
                                         : root.phase === "done" ? "check" : root.phase === "error" ? "alert"
                                         : isCmd ? "command" : "mic"
        readonly property string mmss: Math.floor(root.secs / 60) + ":" + String(Math.floor(root.secs % 60)).padStart(2, "0")
        // texto principal y secundario de la píldora
        readonly property string mainText: root.cmdText !== "" && root.phase !== "error" ? root.cmdText
            : root.phase === "rec" ? (root.partial || (root.committed ? root.committed.trim().slice(-120) : ""))
            : root.phase === "trans" ? (root.partial || "Transcribiendo…")
            : root.phase === "cmd" ? root.cmdText
            : root.msg
        readonly property string hint: root.phase !== "rec" ? ""
            : !root.ready ? "Preparando el micrófono…"
            : root.kind === "comando" ? "Di una orden: «pon Walk de Foo Fighters en YouTube»"
            : Settings.get("dictationWake", true) ? "Habla… · «" + (String(Settings.get("dictationWakeWord", "Distro")).trim() || "Distro") + ", …» para una orden"
            : "Habla…"
        readonly property string sub: root.cmdMsg !== "" ? root.cmdMsg
            : root.phase === "cmd" ? "Haciéndolo…"
            : root.phase === "rec" && !root.partial && !root.committed && (root.latched || root.mode !== "ptt") ? (root.mode === "continuo" ? "para solo al callarte" : "pulsa otra vez para terminar")
            : ""

        Glass {
            id: pill
            kind: "panel"
            radius: Theme.panelRadius
            anchors.horizontalCenter: parent.horizontalCenter
            y: OsdStack.pillY(win.height, height, 0)
            width: Math.min(640, Math.max(260, row.implicitWidth + 32))
            height: 42
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn : 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                width: pill.width - 32
                spacing: 10

                // icono (micrófono = dictado · ⌘ = orden) con pulso mientras habla
                Item {
                    implicitWidth: 24; implicitHeight: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 24; radius: 12
                        color: Qt.alpha(win.accent, 0.18)
                        scale: root.phase === "rec" ? 1 + Math.min(0.35, (root.levels[root.levels.length - 1] ?? 0) * 0.45) : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    Icon { anchors.centerIn: parent; size: 14; name: win.iconName; color: win.accent }
                }
                // medidor de nivel
                Row {
                    visible: root.phase === "rec" && root.cmdText === ""
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: root.levels.length
                        Rectangle {
                            required property int index
                            readonly property real v: root.levels[index] ?? 0
                            width: 3; radius: 1.5
                            height: 3 + v * 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.t
                            opacity: 0.35 + v * 0.65
                            Behavior on height { NumberAnimation { duration: 70 } }
                        }
                    }
                }
                // puntos mientras transcribe o ejecuta
                Row {
                    visible: root.phase === "trans" || root.phase === "cmd" || (root.cmdText !== "" && root.cmdMsg === "")
                    spacing: 4
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 5; height: 5; radius: 2.5
                            color: Theme.p
                            SequentialAnimation on opacity {
                                running: parent.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 160 }
                                NumberAnimation { from: 0.25; to: 1; duration: 320 }
                                NumberAnimation { from: 1; to: 0.25; duration: 320 }
                                PauseAnimation { duration: (2 - index) * 160 }
                            }
                        }
                    }
                }
                // texto: lo provisional en tenue, lo ya escrito y las órdenes en normal
                Txt {
                    id: mainTxt
                    Layout.fillWidth: true
                    Layout.maximumWidth: 460
                    weight: Font.Medium
                    elide: root.phase === "rec" || root.phase === "trans" ? Text.ElideLeft : Text.ElideRight
                    text: win.mainText || win.hint
                    color: root.phase === "error" ? Theme.danger
                         : !win.mainText || (root.partial && win.mainText === root.partial) ? Theme.tv : Theme.t
                }
                Txt {
                    visible: win.sub !== ""
                    size: 11.5; elide: Text.ElideRight
                    Layout.maximumWidth: 200
                    text: win.sub
                    color: root.cmdMsg !== "" ? (root.cmdOk ? Theme.p : Theme.danger) : Theme.tv
                }
                Txt {
                    visible: root.phase === "rec" && root.cmdText === ""
                    text: win.mmss; size: 11.5; muted: true; tabular: true
                }
                // Configurar (si falta algo)
                Rectangle {
                    visible: root.phase === "error" && ["engine", "model", "recorder", "typer"].includes(root.code)
                    implicitWidth: cfg.implicitWidth + 20; implicitHeight: 26; radius: 13
                    color: Theme.p
                    Txt { id: cfg; anchors.centerIn: parent; text: "Configurar"; size: 12; weight: Font.DemiBold; color: Theme.pText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.phase = "idle"; Shell.open("ajustesapp", "dictado"); } }
                }
                // terminar (manos libres)
                Rectangle {
                    visible: root.phase === "rec" && (root.latched || root.mode !== "ptt")
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: Qt.alpha(Theme.danger, sma.containsMouse ? 0.3 : 0.18)
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 2; color: Theme.danger }
                    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stop() }
                }
                // cancelar
                Rectangle {
                    visible: root.phase === "rec" || root.phase === "trans"
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: xma.containsMouse ? Theme.fill2 : "transparent"
                    Icon { anchors.centerIn: parent; name: "x"; size: 12; color: Theme.tv }
                    MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                }
            }
        }
    }
}
