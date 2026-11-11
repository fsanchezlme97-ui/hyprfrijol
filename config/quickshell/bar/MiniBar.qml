// Barrita vertical de nivel (0–1) para el chip «Sistema» de la barra.
import QtQuick
import ".."

Rectangle {
    id: root
    property real value: 0
    property color barColor: Theme.p
    implicitWidth: 4
    implicitHeight: 14
    radius: Theme.r(2)
    color: Theme.fill2
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(1.5, parent.height * Math.max(0, Math.min(1, root.value)))
        radius: parent.radius
        color: root.value > 0.9 ? Theme.danger : root.barColor
        Behavior on height { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutCubic } }
    }
}
