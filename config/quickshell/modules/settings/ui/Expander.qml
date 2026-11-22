// Acordeón simple: cabecera clickeable con título/subtítulo e icono, y contenido colapsable.
//   Expander { title: "Título"; subtitle: "subtítulo"; open: true; …contenido… }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

ColumnLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool open: false
    property real pad: 10
    default property alias content: body.data
    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + root.pad * 2
        radius: Theme.r(6)
        color: mouse.containsPress ? Theme.alpha(Theme.stateTone, Theme.stPress * 0.6)
              : mouse.containsMouse ? Theme.alpha(Theme.stateTone, Theme.stHover * 0.5) : "transparent"
        border.width: 0

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }

        RowLayout {
            id: headerRow
            anchors { fill: parent; margins: root.pad }
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt { text: root.title; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt { visible: root.subtitle !== ""; text: root.subtitle; muted: true; size: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            }
            Icon {
                name: root.open ? "chevron_up" : "chevron_down"
                size: 16
                color: Theme.tv
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: root.open ? body.implicitHeight + 10 : 0
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: Theme.durShort; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            id: body
            width: parent.width
            spacing: 8
            enabled: root.open
        }
    }
}
