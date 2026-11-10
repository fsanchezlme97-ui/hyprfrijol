// Interruptor grande de Ajustes (44×26). Activo: pista c.p + bola 20 c.onP. Inactivo: c.s4 + borde 2 c.o + bola 12 c.o.
import QtQuick
import "../../.."

Rectangle {
    id: root
    property bool checked: false
    // enabled: el de Item (antes se redeclaraba y tapaba al de Qt; mismo valor por defecto)
    signal toggled(bool value)
    implicitWidth: 44
    implicitHeight: 26
    radius: 13
    opacity: enabled ? 1 : 0.4
    color: checked ? Theme.p : Theme.s4
    border.width: checked ? 0 : 2
    border.color: Theme.o
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    Rectangle {
        readonly property real d: root.checked ? 20 : 12
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - d - 3 : 7
        color: root.checked ? Theme.pText : Theme.o
        Behavior on x { NumberAnimation { duration: Theme.dur + 60; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Behavior on width { NumberAnimation { duration: Theme.dur } }
        Behavior on height { NumberAnimation { duration: Theme.dur } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.toggled(!root.checked)
    }
}
