// Tarjeta seleccionable (modo de energía, calidad del vidrio…): título + subtítulo, anillo c.p si está elegida.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string title: ""
    property string sub: ""
    property bool selected: false
    property real h: 64
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: h
    implicitWidth: 140
    radius: Theme.r(7)
    color: selected ? Theme.selBg : ma.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.p : Theme.ov
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 1
        Item { Layout.fillHeight: true }
        Txt { Layout.fillWidth: true; text: root.title; weight: Font.DemiBold; color: root.selected ? Theme.selText : Theme.t }
        Txt { Layout.fillWidth: true; text: root.sub; size: 11.5; muted: true; visible: text !== "" }
        Item { Layout.fillHeight: true }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
