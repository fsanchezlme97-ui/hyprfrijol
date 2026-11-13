// Muestra de las ventanas (Ajustes › Apariencia › Ventanas): una inactiva detrás y la activa delante, con la
// sombra (shadows) y el resaltado (activeBorder) elegidos. Imita lo que genera config/apply/10-look.py.
import QtQuick
import QtQuick.Effects
import "../../.."
import "../../../components"

Rectangle {
    id: root
    readonly property string shadows: Settings.get("shadows", "suaves")
    readonly property string mode: Settings.get("activeBorder", "sutil")
    readonly property real rad: Math.min(Settings.get("rounding", null) ?? Theme.winRadius, 12)
    readonly property real shA: shadows === "ninguna" ? 0 : shadows === "marcadas" ? (Theme.light ? 0.30 : 0.55) : (Theme.light ? 0.13 : 0.30)
    readonly property real shR: shadows === "marcadas" ? 12 : 26
    readonly property real shY: shadows === "marcadas" ? 4 : 7
    readonly property color shCol: Qt.rgba(Theme.p.r * (Theme.light ? 0.18 : 0.06), Theme.p.g * (Theme.light ? 0.18 : 0.06), Theme.p.b * (Theme.light ? 0.18 : 0.06), 1)
    implicitHeight: 120
    radius: Theme.r(8)
    color: Theme.bg
    clip: true

    // Ventana inactiva
    RectangularShadow {
        anchors.fill: back; radius: back.radius
        visible: root.shA > 0
        blur: root.shR; offset.y: root.shY
        color: Qt.alpha(root.shCol, root.shA * 0.7)
    }
    Rectangle {
        id: back
        x: parent.width * 0.08; y: 16
        width: parent.width * 0.5; height: parent.height - 34
        radius: root.rad
        color: Theme.s3
        border.width: root.mode === "ninguno" ? 0 : root.mode === "color" ? 2 : 1
        border.color: Qt.alpha(Theme.ov, root.mode === "color" ? 0.7 : Theme.light ? 0.45 : 0.35)
        Txt { anchors { left: parent.left; top: parent.top; margins: 8 } text: "Inactiva"; size: 10.5; muted: true }
    }
    // Ventana activa
    RectangularShadow {
        anchors.fill: front; radius: front.radius
        visible: root.mode === "brillo" || root.shA > 0
        blur: root.mode === "brillo" ? Math.max(root.shR, 22) : root.shR
        offset.y: root.mode === "brillo" ? 0 : root.shY
        color: root.mode === "brillo" ? Qt.alpha(Theme.p, Theme.light ? 0.30 : 0.26) : Qt.alpha(root.shCol, root.shA)
    }
    Rectangle {
        id: front
        x: parent.width * 0.38; y: 30
        width: parent.width * 0.52; height: parent.height - 44
        radius: root.rad
        color: Theme.s1
        border.width: root.mode === "ninguno" ? 0 : root.mode === "color" ? 2 : 1
        border.color: root.mode === "color" ? Theme.p : Qt.alpha(Qt.tint(Theme.p, Qt.alpha(Theme.ov, 0.25)), Theme.light ? 0.55 : 0.45)
        Column {
            anchors { left: parent.left; top: parent.top; margins: 8 }
            spacing: 4
            Txt { text: "Activa"; size: 10.5; weight: Font.DemiBold }
            Rectangle { width: front.width * 0.6; height: 5; radius: 2.5; color: Theme.tv; opacity: 0.45 }
            Rectangle { width: front.width * 0.4; height: 5; radius: 2.5; color: Theme.tv; opacity: 0.45 }
        }
    }
}
