// Botón de Ajustes: "primary" (c.p), "outline" (borde c.ov) o "link" (texto c.p).
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string text: ""
    property string kind: "outline"
    // enabled: el de Item (antes se redeclaraba y tapaba al de Qt; mismo valor por defecto)
    property real h: 30
    signal clicked()
    implicitHeight: h
    implicitWidth: kind === "link" ? t.implicitWidth : t.implicitWidth + 26
    radius: Theme.ctl(h)
    scale: Theme.estilo !== "flat" && ma.pressed && enabled ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    opacity: enabled ? 1 : 0.45
    color: kind === "primary" ? Theme.p : "transparent"
    border.width: kind === "outline" ? 1 : 0
    border.color: Theme.ov
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.t; opacity: ma.containsMouse && root.enabled && root.kind !== "link" ? 0.07 : 0 }
    Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: t.color }
    Txt {
        id: t
        anchors.centerIn: parent
        text: root.text
        size: 12.5
        weight: root.kind === "primary" ? Font.DemiBold : Font.Medium
        color: root.kind === "primary" ? Theme.pText : root.kind === "link" ? Theme.p : Theme.t
        font.underline: root.kind === "link" && ma.containsMouse
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onPressed: m => { if (root.enabled && root.kind !== "link") rip.burst(m.x, m.y); } onClicked: if (root.enabled) root.clicked() }
}
