// Interruptor grande de Ajustes (44×26). Activo: pista c.p + bola 20 c.onP. Inactivo: c.s4 + borde 2 c.o + bola 12 c.o.
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property bool checked: false
    // enabled: el de Item (antes se redeclaraba y tapaba al de Qt; mismo valor por defecto)
    signal toggled(bool value)
    property bool focusable: true
    activeFocusOnTab: focusable
    Keys.onPressed: e => { if (root.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.toggled(!root.checked); e.accepted = true; } }
    implicitWidth: 44
    implicitHeight: 26
    radius: 13
    opacity: enabled ? 1 : Theme.stDisabled
    color: checked ? Theme.p : Theme.s4
    border.width: checked ? 0 : 2
    border.color: Theme.o
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    StateLayer { radius: root.radius; hovered: swMa.containsMouse && root.enabled; pressed: swMa.pressed && root.enabled; focused: root.activeFocus }
    Rectangle {
        readonly property real d: root.checked ? 20 : 12
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - d - 3 : 7
        color: root.checked ? Theme.pText : Theme.o
        Behavior on x { NumberAnimation { duration: Theme.dur + 60; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        Behavior on height { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }
    MouseArea {
        id: swMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.toggled(!root.checked)
    }
}
