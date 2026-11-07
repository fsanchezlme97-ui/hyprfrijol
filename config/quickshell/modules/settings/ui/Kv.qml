// Fila clave/valor con separador (Acerca, permisos, resumen).
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Item {
    id: root
    property string k: ""
    property string v: ""
    property bool bold: true
    property bool mono: false
    property real h: 41
    signal clicked()
    property bool clickable: false
    Layout.fillWidth: true
    implicitHeight: h
    Rectangle { width: parent.width; height: 1; color: Theme.ov }
    RowLayout {
        anchors.fill: parent
        spacing: 12
        Txt { text: root.k; muted: true }
        Txt {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.v
            weight: root.bold ? Font.DemiBold : Font.Normal
            font.family: root.mono ? Theme.mono : Theme.font
            color: root.clickable ? Theme.t : Theme.t
        }
    }
    MouseArea { anchors.fill: parent; enabled: root.clickable; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
