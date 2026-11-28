// Isla desplegada: una fila por actividad con sus controles (o la hora y la fecha si no hay nada). La usan la isla
// suelta (Island.qml) y la muesca de la barra (bar/Bar.qml).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

ColumnLayout {
    anchors { fill: parent; margins: 12 }
    spacing: 8
    opacity: Isla.expanded ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.durMedium } }
    ColumnLayout {
        visible: Isla.keys.length === 0
        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
        spacing: 0
        Txt { text: Time.hhmm; size: 24; weight: Font.Medium; tabular: true }
        Txt { text: Time.longDate.charAt(0).toUpperCase() + Time.longDate.slice(1); muted: true; size: 12 }
    }
    Repeater {
        model: Isla.keys.slice(0, 3)
        Item {
            id: row
            required property string modelData
            readonly property var d: Isla.info(modelData)
            Layout.fillWidth: true
            implicitHeight: 52
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Isla.pinned = false; Shell.open(row.d.view); } }
            RowLayout {
                anchors.fill: parent
                spacing: 12
                Item {
                    implicitWidth: 44; implicitHeight: 44
                    Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: Theme.r(10) } }
                    Rectangle { anchors.fill: parent; radius: Theme.r(10); color: Theme.s4 }
                    Icon { anchors.centerIn: parent; visible: art.status !== Image.Ready; name: row.d.icon ?? "clock"; size: 18; color: Theme.p }
                    Item {
                        anchors.fill: parent
                        visible: art.status === Image.Ready
                        layer.enabled: visible
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        Image { id: art; anchors.fill: parent; source: row.d.art ?? ""; sourceSize.width: 96; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Txt { Layout.fillWidth: true; text: row.d.title; weight: Font.DemiBold; elide: Text.ElideRight }
                    Txt { Layout.fillWidth: true; text: row.d.sub; muted: true; size: 11.5; tabular: true; elide: Text.ElideRight }
                    Rectangle {
                        visible: row.d.progress >= 0
                        Layout.fillWidth: true; implicitHeight: 3; radius: 1.5; color: Theme.fill2
                        Rectangle { width: parent.width * row.d.progress; height: parent.height; radius: 1.5; color: Theme.p }
                    }
                }
                // Controles de cada actividad
                IconBtn { visible: row.modelData === "musica"; icon: "prev"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Anterior"; opacity: Media.active?.canGoPrevious ? 1 : 0.35; onClicked: if (Media.active?.canGoPrevious) Media.active.previous() }
                IconBtn { visible: row.modelData === "musica"; icon: Media.active?.isPlaying ? "pause" : "play"; iconSize: 16; implicitWidth: 30; implicitHeight: 30; tooltip: "Pausar"; onClicked: if (Media.active?.canTogglePlaying) Media.active.togglePlaying() }
                IconBtn { visible: row.modelData === "musica"; icon: "next"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Siguiente"; opacity: Media.active?.canGoNext ? 1 : 0.35; onClicked: if (Media.active?.canGoNext) Media.active.next() }
                IconBtn { visible: row.modelData === "pomodoro"; icon: Pomodoro.running ? "pause" : "play"; iconSize: 16; implicitWidth: 30; implicitHeight: 30; tooltip: Pomodoro.running ? "Pausar" : "Seguir"; onClicked: Pomodoro.toggle() }
                IconBtn { visible: row.modelData === "pomodoro"; icon: "next"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Saltar al siguiente bloque"; onClicked: Pomodoro.skip() }
                Btn { visible: row.modelData === "reunion" && !!row.d.link; kind: "primary"; h: 28; padX: 12; text: "Unirse"; onClicked: { Qt.openUrlExternally(row.d.link); Isla.pinned = false; } }
            }
        }
    }
}
