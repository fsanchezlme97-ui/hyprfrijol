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
            // Parlante / auricular de la misma tarjeta: switch bajo la salida activa
            readonly property var portSet: root.output && on ? (Audio.portSets[modelData.name] ?? null) : null
            readonly property real baseH: root.compact ? 30 : 44
            Layout.fillWidth: true
            implicitHeight: baseH + (portSet ? (root.compact ? 30 : 36) : 0)
            radius: root.compact ? Theme.r(5) : Theme.r(6)
            color: on && !root.compact ? Theme.selBg : ma.containsMouse ? (root.compact ? Theme.s1 : Qt.alpha(Theme.t, 0.05)) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.compact ? 8 : 10; rightMargin: root.compact ? 8 : 10 }
                height: row.baseH
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
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: row.baseH
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setDefault(row.modelData)
            }
            Row {
                visible: !!row.portSet
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: root.compact ? 4 : 6
                          leftMargin: root.compact ? 28 : 50; rightMargin: root.compact ? 8 : 10 }
                spacing: 4
                Repeater {
                    model: row.portSet?.list ?? []
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool act: row.portSet?.active === modelData.name
                        width: chipTxt.implicitWidth + 30; height: 22; radius: Theme.ctl(22)
                        color: act ? Theme.p : chipMa.containsMouse ? Qt.alpha(Theme.t, 0.10) : Theme.fill2
                        Row {
                            anchors.centerIn: parent; spacing: 4
                            Icon { anchors.verticalCenter: parent.verticalCenter; size: 12; color: chip.act ? Theme.pText : Theme.tv
                                   name: chip.modelData.type === "Headphones" ? "headphones" : "speaker" }
                            Txt { id: chipTxt; anchors.verticalCenter: parent.verticalCenter; text: chip.modelData.label; size: 11
                                  color: chip.act ? Theme.pText : Theme.t }
                        }
                        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!chip.act) Audio.setPort(row.modelData.name, chip.modelData.name) }
                    }
                }
            }
        }
    }
}
