// Capa de estado común de los controles (estilo Math): hover y presionado con la misma opacidad en todos, y el anillo
// de foco cuando se llega con el teclado (Tab). Va dentro del control, encima del fondo y debajo del contenido.
//   StateLayer { radius: parent.radius; hovered: ma.containsMouse; pressed: ma.pressed; focused: root.activeFocus }
import QtQuick
import ".."

Item {
    id: root
    property real radius: 0
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property color tone: Theme.stateTone
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tone
        opacity: root.pressed ? Theme.stPress : root.hovered ? Theme.stHover : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }
    // Anillo de foco: por fuera del control, separado 2 px, para que se vea sobre cualquier fondo
    Rectangle {
        visible: root.focused
        anchors.fill: parent
        anchors.margins: -(Theme.focusWidth + 1)
        radius: root.radius + Theme.focusWidth + 1
        color: "transparent"
        border.width: Theme.focusWidth
        border.color: Theme.focusRing
    }
}
