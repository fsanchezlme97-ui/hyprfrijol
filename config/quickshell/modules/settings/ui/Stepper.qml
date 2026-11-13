// − valor + (botones redondos) para el pomodoro.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

RowLayout {
    id: root
    property string label: ""
    property int value: 0
    property int from: 1
    property int to: 99
    property int step: 1
    property string unit: "min"
    signal stepped(int value)
    Layout.fillWidth: true
    spacing: 12
    Txt { text: root.label; Layout.fillWidth: true; weight: Font.Medium }
    component RoundBtn: Rectangle {
        id: rb
        property string glyph: ""
        signal hit()
        implicitWidth: 28; implicitHeight: 28; radius: 14
        color: m.containsMouse ? Theme.sc : Theme.s4
        Txt { anchors.centerIn: parent; text: rb.glyph; size: 15; weight: Font.DemiBold }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.hit() }
    }
    RoundBtn { glyph: "−"; onHit: root.stepped(Math.max(root.from, root.value - root.step)) }
    Txt { Layout.preferredWidth: 58; horizontalAlignment: Text.AlignHCenter; text: root.value + (root.unit ? " " + root.unit : ""); tabular: true; weight: Font.DemiBold; size: 13 }
    RoundBtn { glyph: "+"; onHit: root.stepped(Math.min(root.to, root.value + root.step)) }
}
