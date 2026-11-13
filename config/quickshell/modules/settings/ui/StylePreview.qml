// Vista previa del estilo: el fondo actual con una ventana y la barra dibujadas con el tema activo.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"

Rectangle {
    id: root
    property string wallpaper: ""
    property bool video: false
    radius: Theme.r(6)
    color: Theme.bg
    clip: true
    Image {
        id: bgImg
        anchors.fill: parent
        source: root.wallpaper && !root.video ? "file://" + root.wallpaper : ""
        sourceSize.width: 600
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {   // el «desenfoque» del cristal detrás de la ventana
        anchors.fill: parent
        source: bgImg
        saturation: Settings.get("colorMode", "auto") === "mono" && Settings.get("monoFondo", true) ? -1 : 0
    }
    // ventana (con la sombra de Ajustes › Ventanas › Sombras)
    RectangularShadow {
        x: parent.width * 0.08; y: 14
        width: parent.width * 0.56; height: parent.height - 52
        radius: Settings.get("rounding", null) ?? Theme.winRadius
        visible: Theme.shadow.a > 0
        blur: Theme.shBlur * 0.8; offset.y: Theme.shY * 0.6
        color: Theme.shadow
    }
    Item {
        x: parent.width * 0.08; y: 14
        width: parent.width * 0.56; height: parent.height - 52
        Rectangle {
            id: winBg
            anchors.fill: parent
            radius: Settings.get("rounding", null) ?? Theme.winRadius
            color: "transparent"
            clip: true
            MultiEffect {
                anchors.fill: parent
                visible: Theme.blur
                source: ShaderEffectSource { sourceItem: bgImg; sourceRect: Qt.rect(winBg.parent.x, winBg.parent.y, winBg.width, winBg.height) }
                blurEnabled: true; blur: 1.0; blurMax: 32
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Settings.get("rounding", null) ?? Theme.winRadius
            color: Theme.win
            border.width: 1
            border.color: Theme.st.winBorder ?? Theme.ov
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                spacing: 8
                Rectangle { implicitWidth: 70; implicitHeight: 7; radius: Theme.r(3); color: Theme.t; opacity: 0.8 }
                Rectangle { Layout.fillWidth: true; implicitHeight: 5; radius: 2; color: Theme.tv; opacity: 0.5 }
                Rectangle { implicitWidth: 90; implicitHeight: 5; radius: 2; color: Theme.tv; opacity: 0.5 }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 8
                    Rectangle { implicitWidth: 46; implicitHeight: 16; radius: Theme.r(5); color: Theme.p }
                    Rectangle { implicitWidth: 46; implicitHeight: 16; radius: Theme.r(5); color: Theme.fill2 }
                }
            }
        }
    }
    // panel lateral
    Glass {
        kind: "panel"
        x: parent.width * 0.68; y: 14
        width: parent.width * 0.26; height: parent.height - 52
        shadow: false
        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 8
            Repeater { model: 3; Rectangle { width: parent.width; height: 16; radius: Theme.r(5); color: Theme.fill2 } }
        }
    }
    // barra
    Glass {
        kind: "bar"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
        height: 22
        shadow: false
        Row {
            anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 4
            Rectangle { width: 14; height: 14; radius: Theme.r(4); color: Theme.p }
            Repeater { model: 4; Rectangle { width: 10; height: 10; radius: Theme.r(3); anchors.verticalCenter: parent.verticalCenter; color: index === 0 ? Theme.sc : "transparent"; Txt { anchors.centerIn: parent; text: index + 1; size: 8 } } }
        }
        Txt { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: Time.hhmm; size: 10; weight: Font.DemiBold }
    }
    Rectangle {
        anchors { top: parent.top; right: parent.right; margins: 8 }
        width: pn.implicitWidth + 12; height: 20; radius: Theme.ctl(20)
        color: Qt.alpha(Theme.s1, 0.8)
        Txt { id: pn; anchors.centerIn: parent; text: Theme.paletteName + (Theme.glassy ? " · Transparente" : ""); size: 10.5 }
    }
}
