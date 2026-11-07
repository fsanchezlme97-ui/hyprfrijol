// Atajos de «no molestar» (Notifs.dndPreset): 1 h · hasta esta noche (20:00) · hasta mañana (08:00) ·
// hasta que lo desactive, con el tiempo que queda. La usan los ajustes rápidos y el centro de notificaciones.
//   DndPresets { }
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

Rectangle {
    id: root
    signal picked(string key)
    radius: Theme.r(6)
    color: Theme.fill2
    implicitHeight: col.implicitHeight + 8
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
        spacing: 1
        Txt {
            Layout.fillWidth: true; Layout.preferredHeight: 26; Layout.leftMargin: 8
            size: 11.5; muted: true
            text: Notifs.dnd ? "No molestar · " + Notifs.dndLeft : "Silenciar los avisos…"
        }
        Repeater {
            model: Notifs.dndPresets
            Rectangle {
                id: row
                required property var modelData
                readonly property bool on: Notifs.dnd && Notifs.dndKind === modelData.key
                Layout.fillWidth: true
                implicitHeight: 30; radius: Theme.r(5)
                color: ma.containsMouse ? Theme.s1 : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8
                    Icon { name: row.modelData.key === "siempre" ? "dnd" : row.modelData.key === "1h" ? "clock" : "moon"; size: 13; color: row.on ? Theme.p : Theme.tv }
                    Txt { Layout.fillWidth: true; text: row.modelData.label; weight: row.on ? Font.DemiBold : Font.Normal }
                    Txt { visible: !!row.modelData.hint; text: Time.fmtHM(row.modelData.hint ?? ""); size: 11; muted: true; tabular: true }
                    Icon { visible: row.on; name: "check"; size: 13; color: Theme.p }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Notifs.dndPreset(row.modelData.key); root.picked(row.modelData.key); }
                }
            }
        }
        Rectangle {
            visible: Notifs.dnd
            Layout.fillWidth: true
            implicitHeight: 30; radius: Theme.r(5)
            color: offMa.containsMouse ? Theme.s1 : "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8
                Icon { name: "bell"; size: 13; color: Theme.tv }
                Txt { Layout.fillWidth: true; text: "Desactivar ahora"; color: Theme.p }
            }
            MouseArea {
                id: offMa
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { Notifs.setDnd(false); root.picked("off"); }
            }
        }
    }
}
