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
    signal clicked()
    signal rightClicked()
    implicitWidth: 26
    implicitHeight: 22
    property string preload: ""          // vista que abre: al pasar el cursor se va cargando (Shell.preload)
    radius: Theme.pill ? Math.min(width, height) / 2 + 2 : Theme.r(7)
    Behavior on scale { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    color: active ? activeBg : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.light ? "#000000" : "#FFFFFF"
        opacity: mouse.containsMouse ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }
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
