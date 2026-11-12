// Botón de icono (barra, cabeceras de panel). Como los botones 26×22 / 24×24 del diseño.
//   IconBtn { icon: "x"; onClicked: … }
import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string svg: ""
    property real iconSize: 14
    property bool active: false
    property color activeBg: Theme.p
    property color activeFg: Theme.pText
    property color fg: Theme.t
    property string tooltip: ""
    property bool focusable: true
    signal clicked()
    signal rightClicked()
    // Teclado: se llega con Tab (anillo de foco) y se pulsa con Intro o Espacio
    activeFocusOnTab: focusable
    Keys.onPressed: e => { if (root.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.clicked(); e.accepted = true; } }
    implicitWidth: 26
    implicitHeight: 22
    property string preload: ""          // vista que abre: al pasar el cursor se va cargando (Shell.preload)
    radius: Theme.pill ? Math.min(width, height) / 2 + 2 : Theme.r(7)
    Behavior on scale { NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    color: active ? activeBg : "transparent"
    opacity: enabled ? 1 : Theme.stDisabled
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    StateLayer { radius: root.radius; hovered: mouse.containsMouse; pressed: mouse.pressed; focused: root.activeFocus }
    Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: root.active ? root.activeFg : root.fg }
    Icon { anchors.centerIn: parent; name: root.icon; svg: root.svg; size: root.iconSize; color: root.active ? root.activeFg : root.fg }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.preload) Shell.preload(root.preload)
        onPressed: m => rip.burst(m.x, m.y)
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
