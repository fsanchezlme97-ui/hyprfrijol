// Fila de muestras de color para elegir uno. Cada color es un token del tema ("p", "ter", "sc", "danger"…)
// o "#RRGGBB" (se resuelve con Events.tint).
//   ColorSwatches { colors: ["p", "ter", "#4F8EF7"]; current: "p"; onPicked: c => … }
import QtQuick
import "../../.."
import "../../../components"
import "../../../services"

Row {
    id: root
    property var colors: []
    property string current: ""
    property real size: 18
    signal picked(string color)
    spacing: 6
    Repeater {
        model: root.colors
        Rectangle {
            required property string modelData
            readonly property bool on: root.current === modelData
            width: root.size; height: root.size; radius: root.size / 2
            color: Events.tint(modelData)
            border.width: on ? 2 : 0
            border.color: Theme.t
            Icon { anchors.centerIn: parent; visible: parent.on; name: "check"; size: 11; color: Theme.bg }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(parent.modelData) }
        }
    }
}
