// Fila de estado: insignia (icono o siglas) a la izquierda, título + estado y controles a la derecha.
//   InfoRow { label: "Tailscale"; sub: "Conectado"; glyph: "TS"; lit: true; Button { … } }   (o icon: "shield")
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Item {
    id: mr
    property string label: ""
    property string sub: ""
    property string glyph: ""
    property string icon: ""
    property bool lit: false
    property bool separator: true
    default property alias trailing: tr.data
    Layout.fillWidth: true
    implicitHeight: 54
    Rectangle { visible: mr.separator; width: parent.width; height: 1; color: Theme.ov }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 1
        spacing: 12
        Rectangle {
            implicitWidth: 34; implicitHeight: 34
            radius: Theme.r(8)
            color: mr.lit ? Theme.pc : Theme.s4
            Txt { visible: mr.icon === ""; anchors.centerIn: parent; text: mr.glyph; weight: Font.Bold; size: mr.glyph.length > 2 ? 11 : 12.5; color: mr.lit ? Theme.pcText : Theme.tv }
            Icon { visible: mr.icon !== ""; anchors.centerIn: parent; name: mr.icon; size: 16; color: mr.lit ? Theme.pcText : Theme.tv }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: mr.label; weight: Font.DemiBold }
            Txt { Layout.fillWidth: true; text: mr.sub; muted: true; size: 11.5 }
        }
        Row { id: tr; spacing: 8; Layout.alignment: Qt.AlignVCenter }
    }
}
