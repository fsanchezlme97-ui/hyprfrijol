// Fila de medidor: etiqueta · barra · valor
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

RowLayout {
    id: m
    property string label: ""
    property real value: 0          // 0–1
    property string text: ""
    property color barColor: Theme.p
    property real labelWidth: 38
    property real textWidth: 92
    Layout.fillWidth: true
    spacing: 10
    Txt { text: m.label; muted: true; size: 12; Layout.preferredWidth: m.labelWidth; visible: m.labelWidth > 0 }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 5
        radius: Theme.r(3)
        color: Theme.fill2
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, m.value))
            height: parent.height
            radius: Theme.r(3)
            color: m.value > 0.92 ? Theme.danger : m.barColor
            Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutCubic } }
        }
    }
    Txt { text: m.text; size: 12; tabular: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: m.textWidth; visible: m.textWidth > 0 }
}
