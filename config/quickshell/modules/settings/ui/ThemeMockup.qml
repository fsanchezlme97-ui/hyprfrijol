// Maqueta de un tema que aún no está puesto (creador de Mis temas): la barra y el centro de control dibujados con
// los colores de `pal` (bg s1 s3 s4 p onP pc onPc sc onSc ter t tv o ov), no con los del tema activo.
//   ThemeMockup { pal: preview.dark; label: "Oscuro" }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property var pal: ({})
    property string label: ""
    readonly property color bg: pal.bg ?? "#000000"
    function c(k) { return pal[k] ?? "transparent"; }

    implicitWidth: 300
    implicitHeight: 196
    radius: Theme.r(8)
    clip: true
    border.width: 1
    border.color: Qt.alpha(Theme.t, 0.12)
    // «Escritorio»: el fondo del tema con un velo del acento
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.tint(root.bg, Qt.alpha(root.c("p"), 0.22)) }
        GradientStop { position: 1; color: Qt.tint(root.bg, Qt.alpha(root.c("ter"), 0.16)) }
    }

    // Barra
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        height: 22
        radius: Theme.r(6)
        color: root.c("s1")
        border.width: 1; border.color: root.c("ov")
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 6; spacing: 3
            Rectangle { width: 12; height: 12; radius: Theme.r(3); color: root.c("p") }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 14; height: 14; radius: Theme.r(4)
                    color: index === 0 ? root.c("sc") : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: index === 0 ? root.c("onSc") : root.c("tv")
                        font.family: Theme.font; font.pixelSize: Theme.px(8); font.weight: Font.DemiBold
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: "Navegador — inicio"
            color: root.c("tv")
            font.family: Theme.font; font.pixelSize: Theme.px(8.5)
        }
        Row {
            anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
            spacing: 5
            Repeater { model: 3; Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: root.c("tv") } }
            Text { text: "19:22"; color: root.c("t"); font.family: Theme.font; font.pixelSize: Theme.px(9); font.weight: Font.DemiBold }
        }
    }

    // Centro de control
    Rectangle {
        id: cc
        anchors { right: parent.right; top: bar.bottom; bottom: parent.bottom; margins: 6 }
        width: parent.width * 0.6
        radius: Theme.r(8)
        color: root.c("bg")
        border.width: 1; border.color: root.c("ov")
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 7
            spacing: 5
            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 4; columnSpacing: 4
                Repeater {
                    model: [["Wi-Fi", true], ["Bluetooth", true], ["No molestar", false], ["Cafeína", false]]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: Theme.r(6)
                        color: modelData[1] ? root.c("p") : root.c("s3")
                        Text {
                            anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                            text: modelData[0]
                            color: modelData[1] ? root.c("onP") : root.c("t")
                            font.family: Theme.font; font.pixelSize: Theme.px(8.5); font.weight: Font.DemiBold
                        }
                    }
                }
            }
            // volumen
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6; radius: 3
                color: root.c("s4")
                Rectangle { width: parent.width * 0.62; height: parent.height; radius: 3; color: root.c("p") }
            }
            // un aviso
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.r(6)
                color: root.c("s1")
                border.width: 1; border.color: root.c("o")
                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 2
                    Text { text: "Descarga terminada"; color: root.c("t"); font.family: Theme.font; font.pixelSize: Theme.px(8.5); font.weight: Font.DemiBold }
                    Text { text: "informe.pdf · 2,4 MB"; color: root.c("tv"); font.family: Theme.font; font.pixelSize: Theme.px(8) }
                }
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                    spacing: 4
                    Rectangle {
                        width: abrir.implicitWidth + 12; height: 15; radius: Theme.r(5); color: root.c("pc")
                        Text { id: abrir; anchors.centerIn: parent; text: "Abrir"; color: root.c("onPc"); font.family: Theme.font; font.pixelSize: Theme.px(8); font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: root.c("ter")
                    }
                }
            }
        }
    }

    // Una ventana detrás
    Rectangle {
        anchors { left: parent.left; top: bar.bottom; bottom: parent.bottom; right: cc.left; margins: 6 }
        radius: Theme.r(7)
        color: root.c("s1")
        opacity: 0.92
        border.width: 1; border.color: root.c("ov")
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 5
            Rectangle { width: parent.width * 0.6; height: 6; radius: 3; color: root.c("t"); opacity: 0.85 }
            Rectangle { width: parent.width; height: 4; radius: 2; color: root.c("tv"); opacity: 0.6 }
            Rectangle { width: parent.width * 0.8; height: 4; radius: 2; color: root.c("tv"); opacity: 0.6 }
        }
    }

    Rectangle {
        visible: root.label !== ""
        anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
        width: lab.implicitWidth + 12; height: 17; radius: 8.5
        color: Qt.alpha(root.c("bg"), 0.85)
        Text { id: lab; anchors.centerIn: parent; text: root.label; color: root.c("t"); font.family: Theme.font; font.pixelSize: Theme.px(9); font.weight: Font.DemiBold }
    }
}
