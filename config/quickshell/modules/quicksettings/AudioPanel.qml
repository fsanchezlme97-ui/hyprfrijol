// Ajustes rápidos › desplegable del volumen: salida y entrada predeterminadas y volumen por app.
// Piezas compartidas con Ajustes › Sonido: components/AudioDevices.qml y AudioStreams.qml.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

Rectangle {
    id: root
    radius: Theme.r(6)
    color: Theme.fill2
    implicitHeight: col.implicitHeight + 8
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
        spacing: 2
        Txt { Layout.fillWidth: true; Layout.preferredHeight: 24; Layout.leftMargin: 8; text: "Salida"; size: 11; muted: true; weight: Font.DemiBold }
        AudioDevices { Layout.fillWidth: true; output: true; compact: true }
        Txt { Layout.fillWidth: true; Layout.preferredHeight: 24; Layout.leftMargin: 8; text: "Entrada"; size: 11; muted: true; weight: Font.DemiBold }
        AudioDevices { Layout.fillWidth: true; output: false; compact: true; maxItems: 4 }
        Txt { Layout.fillWidth: true; Layout.preferredHeight: 24; Layout.leftMargin: 8; text: "Aplicaciones"; size: 11; muted: true; weight: Font.DemiBold }
        AudioStreams { Layout.fillWidth: true; compact: true; emptyText: "Ninguna app suena ahora" }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28; radius: Theme.r(5)
            color: more.containsMouse ? Theme.s1 : "transparent"
            Txt { anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } text: "Ajustes de sonido…"; color: Theme.p; size: 12 }
            MouseArea { id: more; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("ajustesapp", "sonido") }
        }
    }
}
