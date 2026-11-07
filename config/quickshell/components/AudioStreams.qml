// Volumen por aplicación: cada app que reproduce sonido (stream de PipeWire) con su icono, nombre, deslizador
// y silencio. La usan los ajustes rápidos y Ajustes › Sonido.
//   AudioStreams { compact: true }
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."
import "../services"

ColumnLayout {
    id: root
    property bool compact: false
    property string emptyText: "Ninguna app está reproduciendo sonido ahora."
    readonly property var model: Audio.streams
    spacing: compact ? 2 : 4
    PwObjectTracker { objects: Audio.nodes }      // las propiedades (media.class, application.*) llegan al enlazarlos

    Txt {
        visible: root.model.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Layout.leftMargin: root.compact ? 8 : 0
        muted: true; size: root.compact ? 11.5 : 12.5
        text: root.emptyText
    }
    Repeater {
        model: root.model
        RowLayout {
            id: st
            required property var modelData
            readonly property string app: Audio.appName(modelData)
            readonly property string media: String(modelData.properties?.["media.name"] ?? "")
            readonly property string icon: Audio.appIcon(modelData)
            readonly property real vol: modelData.audio?.volume ?? 0
            readonly property bool muted: modelData.audio?.muted ?? false
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 8 : 0
            Layout.rightMargin: root.compact ? 2 : 0
            implicitHeight: root.compact ? 34 : 42
            spacing: root.compact ? 8 : 12
            Rectangle {
                implicitWidth: root.compact ? 22 : 28; implicitHeight: implicitWidth
                radius: Theme.r(6)
                color: img.status === Image.Ready ? "transparent" : Theme.s4
                Image {
                    id: img
                    anchors.fill: parent
                    source: st.icon
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                    asynchronous: true
                }
                Txt { anchors.centerIn: parent; visible: img.status !== Image.Ready; text: st.app.charAt(0).toUpperCase() || "?"; weight: Font.DemiBold; size: 11.5 }
            }
            ColumnLayout {
                Layout.preferredWidth: root.compact ? 90 : 130
                Layout.maximumWidth: Layout.preferredWidth
                spacing: 0
                Txt { Layout.fillWidth: true; text: st.app; size: root.compact ? 12 : 12.5; weight: root.compact ? Font.Medium : Font.Normal }
                Txt { Layout.fillWidth: true; text: st.media; muted: true; size: 10.5; visible: text !== "" && text !== st.app }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 18
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: Theme.ctl(6); color: Theme.s4 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(6, parent.width * Math.min(1, st.vol)); height: 6; radius: Theme.ctl(6)
                    color: st.muted ? Theme.o : Theme.p
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.min(1, st.vol) * (parent.width - width)
                    width: 12; height: 12; radius: 6
                    color: st.muted ? Theme.o : Theme.p
                    border.width: 2; border.color: Theme.s1
                }
                MouseArea {
                    anchors { fill: parent; topMargin: -4; bottomMargin: -4 }
                    cursorShape: Qt.PointingHandCursor
                    function upd(x) { if (st.modelData.audio) { st.modelData.audio.muted = false; st.modelData.audio.volume = Math.max(0, Math.min(1, x / width)); } }
                    onPressed: m => upd(m.x)
                    onPositionChanged: m => { if (pressed) upd(m.x); }
                    onWheel: w => { if (st.modelData.audio) st.modelData.audio.volume = Math.max(0, Math.min(1, st.vol + (w.angleDelta.y > 0 ? 0.05 : -0.05))); }
                }
            }
            Txt { Layout.preferredWidth: root.compact ? 40 : 44; horizontalAlignment: Text.AlignRight; text: Math.round(st.vol * 100) + " %"; muted: true; tabular: true; size: root.compact ? 11 : 12.5 }
            IconBtn {
                implicitWidth: root.compact ? 24 : 26
                icon: st.muted ? "volume_low" : "volume"
                active: st.muted
                activeBg: Theme.fill2; activeFg: Theme.tv
                tooltip: st.muted ? "Activar el sonido" : "Silenciar"
                onClicked: if (st.modelData.audio) st.modelData.audio.muted = !st.modelData.audio.muted
            }
        }
    }
}
