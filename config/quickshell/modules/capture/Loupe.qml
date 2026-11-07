// Lupa sobre la pantalla congelada (Captura y Selector de color): amplía los píxeles alrededor del cursor,
// sin suavizado, con el píxel central enmarcado y, si se quiere, la rejilla de píxeles.
//   Loupe { source: "file://…png"; screenW: 1440; screenH: 900; px: mouse.x; py: mouse.y }
import QtQuick
import "../.."

Item {
    id: root
    property url source
    property real screenW: 0            // tamaño lógico de la pantalla (lo que ocupa la imagen sin ampliar)
    property real screenH: 0
    property real px: 0                 // punto lógico bajo el cursor
    property real py: 0
    property real zoom: 8
    property int cells: 17              // píxeles lógicos que se ven por lado
    property bool grid: false
    property color frame: "white"
    readonly property real side: cells * zoom
    width: side; height: side

    Rectangle {
        id: clipBox
        anchors.fill: parent
        radius: Theme.r(12)
        color: "black"
        clip: true
        border.width: 0
        Image {
            source: root.source
            asynchronous: false
            cache: true
            smooth: false
            mipmap: false
            width: root.screenW * root.zoom
            height: root.screenH * root.zoom
            x: root.side / 2 - (Math.floor(root.px) + 0.5) * root.zoom
            y: root.side / 2 - (Math.floor(root.py) + 0.5) * root.zoom
        }
        // Rejilla de píxeles
        Repeater {
            model: root.grid ? root.cells + 1 : 0
            Rectangle { required property int index; x: index * root.zoom; width: 1; height: root.side; color: Qt.rgba(0, 0, 0, 0.18) }
        }
        Repeater {
            model: root.grid ? root.cells + 1 : 0
            Rectangle { required property int index; y: index * root.zoom; height: 1; width: root.side; color: Qt.rgba(0, 0, 0, 0.18) }
        }
        // Píxel central
        Rectangle {
            x: Math.floor(root.cells / 2) * root.zoom - 1; y: x
            width: root.zoom + 2; height: width
            color: "transparent"; border.width: 1.5; border.color: root.frame
            Rectangle { anchors.fill: parent; anchors.margins: 1.5; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.7) }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: clipBox.radius
        color: "transparent"
        border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.85)
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.45) }
    }
}
