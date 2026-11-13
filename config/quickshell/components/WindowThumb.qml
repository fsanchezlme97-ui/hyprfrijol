// Miniatura en vivo de una ventana de Hyprland (ScreencopyView) con respaldo: baldosa con icono y nombre.
// La usan la vista general (Super + Tab) y Alt + Tab.
//   WindowThumb { address: "0x…"; cls: "kitty"; title: "…"; live: true; radius: Theme.r(5) }
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

Item {
    id: root
    property string address: ""
    property string cls: ""
    property string title: ""
    property bool live: true
    property real radius: Theme.r(5)
    property color fill: Theme.s3
    property bool showLabel: true          // nombre de la app en el centro cuando no hay imagen o la miniatura es pequeña
    property bool forceLabel: false
    property real labelSize: 12.5
    readonly property var toplevel: { HyprClients.refreshes; return HyprClients.toplevelFor(address); }
    readonly property bool hasImage: shot.hasContent && shot.visible

    Rectangle {
        id: base
        anchors.fill: parent
        radius: root.radius
        color: root.fill
    }

    ScreencopyView {
        id: shot
        anchors.fill: parent
        visible: false
        captureSource: root.live && root.width > 8 ? (root.toplevel?.wayland ?? null) : null
        live: root.live
        paintCursor: false
        constraintSize: Qt.size(Math.ceil(root.width * 1.5), Math.ceil(root.height * 1.5))
    }
    // Esquinas redondeadas sobre la captura
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: shot.hasContent
        source: shot
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // Etiqueta pequeña con icono + app sobre la captura (si cabe)
    Rectangle {
        visible: root.showLabel && shot.hasContent && !root.forceLabel && root.width > 90 && root.height > 50
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
        width: Math.min(root.width - 12, chipRow.implicitWidth + 14)
        height: 20
        radius: Theme.r(10)
        color: Qt.alpha("#000000", 0.55)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Image {
                width: 12; height: 12
                anchors.verticalCenter: parent.verticalCenter
                sourceSize: Qt.size(24, 24)
                source: root.cls ? HyprClients.iconFor(root.cls) : ""
                visible: status === Image.Ready
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - 44)
                text: HyprClients.appName(root.cls)
                size: 11
                weight: Font.Medium
                color: "white"
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: root.showLabel && (!shot.hasContent || root.forceLabel)
        width: parent.width - 12
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real s: Math.min(32, root.height * 0.32)
            visible: !shot.hasContent && status === Image.Ready && root.height > 46
            width: s; height: s
            sourceSize: Qt.size(64, 64)
            source: root.cls ? HyprClients.iconFor(root.cls) : ""
            asynchronous: true
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: HyprClients.appName(root.cls)
            size: root.labelSize
            color: shot.hasContent ? "white" : Theme.t
            style: shot.hasContent ? Text.Outline : Text.Normal
            styleColor: "#80000000"
        }
    }
}
