// Pantalla de bloqueo (diseño «Bloqueo»): ext-session-lock de Wayland + PAM.
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
    // El reloj grande usa peso 300: si Inter no está instalada, una familia con «Light» real
    readonly property string clockFont: Qt.fontFamilies().includes(Theme.font) ? Theme.font : "Noto Sans"
    readonly property bool forceScene: tryMode === "scene" || tryMode === "error"

    property string password: ""
    property string state: ""          // "" | "checking" | "error" | "ok"
    property string message: ""        // aviso de PAM (huella, error…)
    property date lockedAt: new Date()
    signal shake()
    signal clearInput()

    function lock(): void {
        if (sessionLock.locked) return;
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
    Timer { id: unlockTimer; interval: Theme.reduceMotion ? 0 : 260; onTriggered: { sessionLock.locked = false; root.password = ""; root.state = ""; root.message = ""; } }

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
        command: ["sh", "-c", 'test -f /etc/pam.d/hyprlock && echo hyprlock || echo login; getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; command -v fprintd-verify >/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q "#" && echo fp || echo nofp; test -s "$HOME/.face" && echo face || echo noface']
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

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            Item {
                id: page
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : 320; easing.type: Easing.OutCubic } }

                // Fondo: el fondo actual (enlace que mantiene hf-wallpaper) o el paisaje del diseño
                Landscape { anchors.fill: parent; visible: wall.status !== Image.Ready; animated: !Theme.reduceMotion }
                Image {
                    id: wall
                    anchors.fill: parent
                    source: root.forceScene ? "" : "file://" + Paths.state + "/current-wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize: Qt.size(surface.width, surface.height)
                    visible: status === Image.Ready
                }
                // Fondo en movimiento: el mismo vídeo que en el escritorio (mpvpaper queda debajo del bloqueo)
                Loader {
                    anchors.fill: parent
                    active: root.wallVideo !== "" && wall.visible
                    source: Qt.resolvedUrl("../../components/VideoLoop.qml")
                    onLoaded: item.source = Qt.binding(() => root.wallVideo)
                }
                // Velo suave para que el texto se lea sobre cualquier fondo
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, wall.visible ? 0.28 : 0.06) }
                        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, wall.visible ? 0.08 : 0) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, wall.visible ? 0.32 : 0.05) }
                    }
                }
                // Al desbloquear, el contenido se desvanece
                Item {
                    anchors.fill: parent
                    opacity: root.state === "ok" ? 0 : 1
                    scale: root.state === "ok" ? 1.02 : 1
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // ---- Reloj, fecha y avisos (arriba a la izquierda) ----
                    ColumnLayout {
                        layer.enabled: wall.visible
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.6; shadowVerticalOffset: 1 }
                        x: 110 * Math.min(1, surface.width / 1440)
                        y: 72 * Math.min(1, surface.height / 900)
                        spacing: 0
                        Text {
                            text: Time.hhmm
                            color: "#F2F2F4"
                            font.family: root.clockFont
                            font.pixelSize: 132
                            font.weight: Font.Light
                            font.letterSpacing: -0.04 * 132
                            font.features: { "tnum": 1 }
                            renderType: Text.QtRendering
                            Layout.leftMargin: -6
                        }
                        Text {
                            Layout.topMargin: -16
                            text: Time.longDate
                            color: "#E6E6EA"
                            font.family: Theme.font
                            font.pixelSize: 20
                            renderType: Text.QtRendering
                        }
                        Flow {
                            Layout.topMargin: 30
                            Layout.preferredWidth: 700
                            spacing: 10
                            Repeater {
                                model: {
                                    const a = [];
                                    const n = Notifs.count;
                                    if (n > 0 && Settings.get("notifyLock", true)) a.push({ icon: "bell", text: n + (n === 1 ? " notificación" : " notificaciones") + " (contenido oculto)" });
                                    if (Battery.present) a.push({ icon: Battery.percent < 0.2 && !Battery.charging ? "battery_low" : "battery",
                                                                  text: "Batería " + Math.round(Battery.percent * 100) + " %" + (Battery.charging ? " · cargando" : "") });
                                    if (Notifs.dnd) a.push({ icon: "dnd", text: "No molestar" });
                                    return a;
                                }
                                Rectangle {
                                    required property var modelData
                                    height: 32; radius: Theme.r(6)
                                    width: chipRow.implicitWidth + 28
                                    color: Theme.glassPanel
                                    border.width: 1; border.color: Theme.border
                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        Icon { name: modelData.icon; size: 13; color: Theme.tv }
                                        Txt { text: modelData.text; size: 12.5 }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Contraseña (abajo, centrada) ----
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 70
                        spacing: 12

                        Rectangle {
                            id: field
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 360; implicitHeight: 48
                            radius: Theme.r(7)
                            color: Theme.glassPanel
                            border.width: 1
                            border.color: root.state === "error" ? Qt.alpha(Theme.ter, 0.8) : input.activeFocus ? Qt.alpha(Theme.p, 0.55) : Theme.border
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            transform: Translate { id: shakeT }
                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 50 }
                                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 70 }
                                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 70 }
                                NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
                                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                            }
                            Connections {
                                target: root
                                function onShake() { if (!Theme.reduceMotion) shakeAnim.restart(); }
                                function onClearInput() { input.text = ""; }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 5; anchors.rightMargin: 5
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 38; implicitHeight: 38; radius: Theme.r(6)
                                    color: Theme.pc
                                    clip: true
                                    Icon { anchors.centerIn: parent; name: root.hasFprint ? "fingerprint" : "user"; size: 17; color: Theme.pcText; visible: face.status !== Image.Ready }
                                    Image {
                                        id: face
                                        anchors.fill: parent
                                        source: root.hasFace ? "file://" + Paths.home + "/.face" : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                        asynchronous: true
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: input.text === ""
                                        text: root.state === "checking" ? "Comprobando…" : root.hasFprint ? "Contraseña o huella" : "Contraseña"
                                        size: 14
                                        color: Theme.t
                                        opacity: 0.85
                                    }
                                    TextInput {
                                        id: input
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        echoMode: TextInput.Password
                                        passwordCharacter: "●"
                                        color: Theme.t
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.letterSpacing: 2
                                        selectionColor: Theme.p
                                        clip: true
                                        focus: true
                                        enabled: root.state !== "checking" && root.state !== "ok"
                                        cursorVisible: activeFocus
                                        onTextChanged: { root.password = text; if (root.state === "error" && text !== "") { root.state = ""; root.message = ""; } }
                                        onAccepted: root.submit()
                                        Keys.onPressed: event => { capsProc.running = true; if (event.key === Qt.Key_Escape) { text = ""; event.accepted = true; } }
                                        Component.onCompleted: forceActiveFocus()
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 38; implicitHeight: 38; radius: Theme.r(6)
                                    color: goMa.containsMouse ? Qt.lighter(Theme.p, 1.08) : Theme.p
                                    Icon { anchors.centerIn: parent; name: "arrow_right"; size: 16; color: Theme.pText; visible: root.state !== "checking" }
                                    // Indicador de comprobación
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 16; height: 16; radius: 8
                                        color: "transparent"
                                        border.width: 2; border.color: Theme.pText
                                        visible: root.state === "checking"
                                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.p; x: 8; y: -2 }
                                        RotationAnimation on rotation { running: root.state === "checking"; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                                    }
                                    MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                                }
                            }
                        }
                        Txt {
                            layer.enabled: wall.visible
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.5; shadowBlur: 0.5 }
                            Layout.alignment: Qt.AlignHCenter
                            size: 11.5
                            color: root.state === "error" ? Theme.ter : Theme.tv
                            textFormat: Text.PlainText
                            text: {
                                const who = root.realName || root.userName;
                                if (root.message) return root.message;
                                if (root.caps) return who + " · Bloq Mayús activado";
                                return who + " · Bloqueado desde las " + Qt.formatDateTime(root.lockedAt, "HH:mm");
                            }
                        }
                    }
                }
                // Clic en cualquier parte → foco al campo
                MouseArea { anchors.fill: parent; z: -1; onClicked: input.forceActiveFocus() }
            }
        }
    }
}
