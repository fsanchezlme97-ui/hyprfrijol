// Pantalla de carga al entrar en la sesión, como la de KDE: el frijolito (assets/brand/bean.png) y una barrita fina
// que se va llenando, sobre el color del tema, mientras el fondo (imagen o primer fotograma del vídeo) y la barra
// terminan de cargar. Solo cuando hace falta: si el fondo está en menos de un cuarto de segundo, el logo ni aparece
// (solo un fundido del color del tema). Se va con un fundido en cuanto el fondo está listo (como mucho 3 s). Solo al iniciar sesión, no al reiniciar el shell (marca en XDG_RUNTIME_DIR por
// sesión de Hyprland). Se quita con «startSplash»: false (Ajustes › Energía y rendimiento).
// No coge el teclado ni el ratón: si algo tarda, se puede trabajar debajo.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: win
    property bool ready: false            // el fondo de esta pantalla ya se ve
    property bool firstStart: false       // primera vez en esta sesión (lo decide `seen`)
    property bool done: false
    readonly property bool want: firstStart && !done && Settings.get("startSplash", true) !== false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-splash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}
    visible: want || body.opacity > 0.01

    // ¿Primera vez del shell en esta sesión de Hyprland? (el shell puede reiniciarse: entonces no se enseña)
    Process {
        running: true
        command: ["sh", "-c", 'd="${XDG_RUNTIME_DIR:-/tmp}/hyprfrijol"; f="$d/splash-${HYPRLAND_INSTANCE_SIGNATURE:-x}-$0"; '
            + '[ -e "$f" ] && echo seen; mkdir -p "$d"; : > "$f"', win.screen?.name ?? "pantalla"]
        stdout: StdioCollector { onStreamFinished: win.firstStart = text.trim() !== "seen" }
    }
    // El logo aparece solo si la carga pasa de 250 ms; si aparece, se queda al menos 600 ms (sin parpadeos).
    // Máximo 3 s por si el fondo no llega nunca. HF_SPLASH_HOLD=<ms> la deja más tiempo (para verla en dev/try.sh).
    readonly property int hold: Number(Quickshell.env("HF_SPLASH_HOLD") || 0)
    property bool logo: false
    Timer { interval: 250; running: win.firstStart && !win.done; onTriggered: { win.logo = true; minT.restart(); } }
    Timer { id: minT; interval: Math.max(600, win.hold) }
    Timer { interval: Math.max(3000, win.hold + 400); running: win.firstStart; onTriggered: win.finish() }
    Timer { id: holdT; interval: Math.max(1, win.hold); running: win.firstStart && win.hold > 0 }
    readonly property bool canGo: firstStart && ready && !minT.running && !holdT.running
    onCanGoChanged: if (canGo) finish()
    function finish(): void {
        if (done || !firstStart) return;
        if (!logo) { done = true; return; }
        progress = 1;                 // la barrita termina y luego se va
        fade.restart();
    }
    Timer { id: fade; interval: 260; onTriggered: win.done = true }
    // avance de la barrita: crece rápido al principio y se frena (nunca llega sola al final)
    property real progress: 0
    NumberAnimation on progress { running: win.logo && !win.done && win.progress < 1; to: 0.9; duration: 2600; easing.type: Easing.OutCubic }

    Rectangle {
        id: body
        anchors.fill: parent
        color: Theme.bg
        opacity: win.want ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.done ? 450 : 120; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16
            spacing: 26
            opacity: win.logo ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 112; height: 112
                fillMode: Image.PreserveAspectFit
                source: win.visible ? "file://" + Paths.assets + "/brand/bean.png" : ""
                sourceSize: Qt.size(256, 256)
                smooth: true; mipmap: true
            }
            // barrita de carga, fina como la de KDE
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 128; height: 3; radius: 1.5
                color: Qt.alpha(Theme.t, 0.14)
                Rectangle {
                    height: parent.height; radius: 1.5
                    width: parent.width * win.progress
                    color: Theme.p
                    Behavior on width { enabled: win.progress >= 1; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
