// Fila de música del centro de control: carátula, título, artista y anterior / reproducir / siguiente del reproductor
// activo (services/Media.qml). Se oculta si no hay ninguno; pulsar la carátula o el título abre el reproductor completo.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

Rectangle {
    id: row
    readonly property var p: Media.active
    visible: !!p && Media.players.length > 0
    Layout.fillWidth: true
    implicitHeight: 56
    radius: Theme.r(12)
    color: Theme.fill2

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 12
        Item {
            implicitWidth: 40; implicitHeight: 40
            Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: Theme.r(8) } }
            Rectangle { anchors.fill: parent; radius: Theme.r(8); color: Theme.s4 }
            Icon { anchors.centerIn: parent; visible: art.status !== Image.Ready; name: "music"; size: 16; color: Theme.tv }
            Item {
                anchors.fill: parent
                visible: art.status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                Image { id: art; anchors.fill: parent; source: row.p?.trackArtUrl ?? ""; sourceSize.width: 96; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: row.p?.trackTitle || "Sin título"; weight: Font.DemiBold; elide: Text.ElideRight }
            Txt { Layout.fillWidth: true; text: row.p?.trackArtist ?? ""; muted: true; size: 11.5; elide: Text.ElideRight }
        }
        IconBtn {
            icon: (row.p?.isPlaying ?? false) ? "pause" : "play"; iconSize: 16; implicitWidth: 32; implicitHeight: 32
            tooltip: (row.p?.isPlaying ?? false) ? "Pausar" : "Reproducir"
            onClicked: if (row.p?.canTogglePlaying) row.p.togglePlaying()
        }
        IconBtn {
            icon: "next"; iconSize: 16; implicitWidth: 32; implicitHeight: 32
            opacity: (row.p?.canGoNext ?? false) ? 1 : 0.35
            tooltip: "Siguiente"
            onClicked: if (row.p?.canGoNext) row.p.next()
        }
    }
    MouseArea { anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: 80 } cursorShape: Qt.PointingHandCursor; onClicked: { Shell.close(); Shell.open("musica"); } }
}
