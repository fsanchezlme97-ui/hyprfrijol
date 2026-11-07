// Lista de dispositivos de audio (salidas o entradas) para elegir el predeterminado, con icono según el tipo
// (altavoces, auriculares, HDMI, Bluetooth, USB, micrófono). La usan los ajustes rápidos y Ajustes › Sonido.
//   AudioDevices { output: true; compact: true }
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import ".."
import "../services"

ColumnLayout {
    id: root
    property bool output: true          // true → salidas (sinks); false → entradas (micrófonos)
    property bool compact: false        // filas de 30 px (ajustes rápidos) o de 44 px con subtítulo (Ajustes)
    property int maxItems: 8
    readonly property var model: (output ? Audio.sinks : Audio.sources).slice(0, maxItems)
    readonly property var current: output ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    spacing: compact ? 1 : 2
    PwObjectTracker { objects: Audio.nodes }      // las propiedades (media.class, application.*) llegan al enlazarlos
    Component.onCompleted: if (output) Audio.refreshPorts()

    Txt {
        visible: root.model.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Layout.leftMargin: root.compact ? 8 : 0
        muted: true; size: 11.5
        text: root.output ? "No hay salidas de audio" : "No hay micrófonos"
    }
    Repeater {
        model: root.model
        Rectangle {
            id: row
            required property var modelData
            readonly property bool on: root.current === modelData
            Layout.fillWidth: true
            implicitHeight: root.compact ? 30 : 44
            radius: root.compact ? Theme.r(5) : Theme.r(6)
            color: on && !root.compact ? Theme.selBg : ma.containsMouse ? (root.compact ? Theme.s1 : Qt.alpha(Theme.t, 0.05)) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur } }
            RowLayout {
                anchors { fill: parent; leftMargin: root.compact ? 8 : 10; rightMargin: root.compact ? 8 : 10 }
                spacing: root.compact ? 8 : 12
                Rectangle {
                    visible: !root.compact
                    implicitWidth: 28; implicitHeight: 28; radius: Theme.r(6)
                    color: row.on ? Theme.p : Theme.fill2
                    Icon { anchors.centerIn: parent; name: Audio.kindIcon(row.modelData); size: 15; color: row.on ? Theme.pText : Theme.t }
                }
                Icon { visible: root.compact; name: Audio.kindIcon(row.modelData); size: 13; color: row.on ? Theme.p : Theme.tv }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt {
                        Layout.fillWidth: true
                        text: Audio.nodeName(row.modelData)
                        weight: row.on ? Font.DemiBold : Font.Normal
                        color: row.on && !root.compact ? Theme.selText : Theme.t
                    }
                    Txt {
                        visible: !root.compact
                        Layout.fillWidth: true
                        text: Audio.kindLabel(row.modelData)
                        size: 11.5; color: row.on ? Theme.selText : Theme.tv; opacity: row.on ? 0.8 : 1
                    }
                }
                Txt {
                    visible: root.compact && row.on && (row.modelData.audio?.muted ?? false)
                    text: "silenciado"; size: 11; muted: true
                }
                Icon { visible: row.on; name: "check"; size: 13; color: root.compact ? Theme.p : Theme.selText }
            }
            MouseArea {
                id: ma
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setDefault(row.modelData)
            }
        }
    }
}
