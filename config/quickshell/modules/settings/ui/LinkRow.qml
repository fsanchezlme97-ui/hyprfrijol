// Fila que remite a otra sección de Ajustes (un ajuste tiene una sola sección dueña):
// título + «Se configura en <Sección> ›»; al pulsarla abre esa sección y resalta la fila.
//   LinkRow { label: "Bloquear la pantalla"; section: "privacidad"; sectionLabel: "Privacidad"; target: "Bloquear tras" }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Item {
    id: root
    property string label: ""
    property string section: ""          // clave de la sección (nav de SettingsApp)
    property string sectionLabel: ""
    property string target: label        // etiqueta de la fila en la otra sección
    property string value: ""            // valor actual (opcional), a la derecha
    property bool separator: true
    Layout.fillWidth: true
    implicitHeight: 48
    Rectangle { visible: root.separator; width: parent.width; height: 1; color: Theme.ov }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        radius: Theme.r(5)
        color: Theme.t
        opacity: ma.containsMouse ? 0.04 : 0
    }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 1
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: root.label; weight: Font.DemiBold }
            Txt { Layout.fillWidth: true; text: "Se configura en " + root.sectionLabel + " ›"; size: 11.5; color: Theme.p; font.underline: ma.containsMouse }
        }
        Txt { visible: root.value !== ""; text: root.value; muted: true }
        Txt { text: "›"; size: 18; color: Theme.tv }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.open("ajustesapp", root.section + "#" + root.target)
    }
}
