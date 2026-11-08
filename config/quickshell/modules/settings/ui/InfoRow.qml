// Fila de estado: insignia (icono o siglas) a la izquierda, título + estado y controles a la derecha.
//   InfoRow { label: "Tailscale"; sub: "Conectado"; glyph: "TS"; lit: true; Button { … } }   (o icon: "shield")
//   badge: "Recomendado" pone una etiqueta junto al título (badgeStrong: true la pinta con el acento)
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
    property string badge: ""
    property bool badgeStrong: false
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
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { text: mr.label; weight: Font.DemiBold; Layout.fillWidth: mr.badge === "" }
                Rectangle {
                    visible: mr.badge !== ""
                    implicitWidth: bt.implicitWidth + 14; implicitHeight: 18
                    radius: 9
                    color: mr.badgeStrong ? Theme.selBg : "transparent"
                    border.width: mr.badgeStrong ? 0 : 1
                    border.color: Theme.ov
                    Txt { id: bt; anchors.centerIn: parent; text: mr.badge; size: 10.5; weight: Font.DemiBold; color: mr.badgeStrong ? Theme.selText : Theme.tv }
                }
                Item { visible: mr.badge !== ""; Layout.fillWidth: true }
            }
            Txt { Layout.fillWidth: true; text: mr.sub; muted: true; size: 11.5 }
        }
        Row { id: tr; spacing: 8; Layout.alignment: Qt.AlignVCenter }
    }
}
