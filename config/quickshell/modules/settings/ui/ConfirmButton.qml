// Botón con confirmación en dos pasos para acciones destructivas: el primer clic cambia el texto
// a «¿Seguro? …» (en c.danger) durante 4 s; el segundo emite confirmed().
//   ConfirmButton { text: "Olvidar"; confirmText: "¿Olvidar? Sí"; onConfirmed: … }
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string text: ""
    property string confirmText: "¿Seguro? Sí"
    property bool enabled: true
    property real h: 30
    property bool armed: false
    signal confirmed()
    implicitHeight: h
    implicitWidth: t.implicitWidth + 26
    radius: Theme.ctl(h)
    opacity: enabled ? 1 : 0.45
    color: armed ? Theme.danger : "transparent"
    border.width: armed ? 0 : 1
    border.color: Qt.alpha(Theme.danger, 0.6)
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.danger; opacity: ma.containsMouse && root.enabled && !root.armed ? 0.1 : 0 }
    Txt {
        id: t
        anchors.centerIn: parent
        text: root.armed ? root.confirmText : root.text
        size: 12.5
        weight: root.armed ? Font.DemiBold : Font.Medium
        color: root.armed ? Theme.bg : Theme.danger
    }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = false }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!root.enabled) return;
            if (root.armed) { root.armed = false; disarm.stop(); root.confirmed(); }
            else { root.armed = true; disarm.restart(); }
        }
    }
}
