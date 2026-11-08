// Pantalla de carga al entrar en la sesión: el logo de HyprFrijol y una barrita sobre el color del tema, mientras
// el fondo (imagen o primer fotograma del vídeo) y la barra terminan de cargar. Se va con un fundido en cuanto el
// fondo está listo (como mucho 3 s). Solo al iniciar sesión, no al reiniciar el shell (marca en XDG_RUNTIME_DIR por
// sesión de Hyprland). Se quita con «startSplash»: false (Ajustes › Energía y rendimiento).
// No coge el teclado ni el ratón: si algo tarda, se puede trabajar debajo.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

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
    // mínimo para que no sea un parpadeo; máximo por si el fondo no llega nunca
    // HF_SPLASH_HOLD=<ms> la deja más tiempo (para verla en dev/try.sh)
    readonly property int hold: Number(Quickshell.env("HF_SPLASH_HOLD") || 0)
    Timer { id: minT; interval: Math.max(450, win.hold); running: win.firstStart }
    Timer { interval: Math.max(3000, win.hold); running: win.firstStart; onTriggered: win.done = true }
    readonly property bool canGo: ready && !minT.running
    onCanGoChanged: if (canGo && firstStart) fade.restart()
    Timer { id: fade; interval: 120; onTriggered: win.done = true }

    Rectangle {
        id: body
        anchors.fill: parent
        color: Theme.bg
        opacity: win.want ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.done ? 520 : 160; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            spacing: 22
            scale: win.want ? 1 : 1.04
            Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(460, win.width * 0.42)
                height: width * (Theme.light ? 500 / 1400 : 256 / 920)
                fillMode: Image.PreserveAspectFit
                // letras blancas en oscuro; en claro, la tarjeta oscura del README
                source: win.visible ? "file://" + Paths.assets + "/brand/" + (Theme.light ? "logo-card.png" : "logo-wide.png") : ""
                sourceSize.width: 920
                smooth: true; mipmap: true
            }
            // barrita indeterminada (quieta con «Reducir movimiento»)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160; height: 3
                Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.t; opacity: 0.12 }
                Rectangle {
                    id: run
                    height: parent.height; radius: 1.5
                    width: 56
                    color: Theme.p
                    x: Theme.reduceMotion ? (parent.width - width) / 2 : 0
                    SequentialAnimation on x {
                        running: win.visible && !Theme.reduceMotion
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 160 - 56; duration: 700; easing.type: Easing.InOutCubic }
                        NumberAnimation { from: 160 - 56; to: 0; duration: 700; easing.type: Easing.InOutCubic }
                    }
                }
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Preparando tu escritorio…"
                muted: true; size: 12.5
            }
        }
    }
}
