// Miniatura de la tira del selector de fondos (delegado reutilizable del ListView).
// Tamaño fijo: la elegida crece con `scale` y las demás se apartan con un Translate; solo se animan
// transformaciones y opacidad (nada de width/height/x, que obligarían a recolocar la fila en cada fotograma).
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"

Item {
    id: tile
    required property int index
    required property string path
    required property string thumb
    required property bool video
    required property int rev
    required property string res       // vacío = la miniatura aún no está (se está generando)
    property int sel: 0
    property real tileW: 224
    property real tileH: 140
    property real big: 1.35            // escala de la elegida
    property bool isCurrent: false     // es el fondo puesto ahora
    signal picked(int index)
    signal activated(int index)
    signal created()

    readonly property int d: index - sel
    readonly property int ad: Math.abs(d)
    readonly property bool on: d === 0
    // Cuánto se apartan las vecinas para dejar sitio a la elegida, que crece
    readonly property real shift: tileW * (big - 1) / 2 + 6

    width: tileW
    height: tileH * big
    z: on ? 50 : 40 - Math.min(ad, 30)
    Component.onCompleted: created()
    ListView.onReused: created()

    Item {
        id: card
        width: tile.tileW; height: tile.tileH
        anchors.centerIn: parent
        scale: tile.on ? tile.big : hover.hovered ? 1.04 : 1
        opacity: tile.ad === 0 ? 1 : Math.max(0.28, 0.9 - (tile.ad - 1) * 0.14)
        transform: Translate {
            id: tr
            x: tile.d < 0 ? -tile.shift : tile.d > 0 ? tile.shift : 0
            Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

        // Sombra barata: un rectángulo desplazado y translúcido (sin desenfoque por miniatura)
        Rectangle {
            anchors { fill: parent; topMargin: 6; leftMargin: 2; rightMargin: 2; bottomMargin: -6 }
            radius: clipR.radius
            color: "#000000"
            opacity: tile.on ? 0.30 : 0.16
        }
        ClippingRectangle {
            id: clipR
            anchors.fill: parent
            radius: Theme.r(12)
            color: Theme.s3                       // mientras carga
            Image {
                id: img
                anchors.fill: parent
                source: tile.thumb && tile.res !== "" ? "file://" + tile.thumb + (tile.rev ? "?" + tile.rev : "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true                        // la vista previa usa la misma entrada (tamaño natural, 854×480)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            }
            Icon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                name: tile.video ? "play" : "image"; size: 18; color: Theme.tv
            }
        }
        // Filo fino: que las miniaturas oscuras no se pierdan sobre el velo
        Rectangle {
            anchors.fill: parent
            radius: clipR.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.t, 0.14)
        }
        // Anillo de la elegida
        Rectangle {
            anchors { fill: parent; margins: -3 }
            radius: clipR.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.p
            opacity: tile.on ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
        }
        // Vídeo / puesto ahora: insignias pequeñas
        Row {
            anchors { top: parent.top; right: parent.right; margins: 6 }
            spacing: 4
            Rectangle {
                visible: tile.isCurrent
                width: 18; height: 18; radius: 9
                color: Theme.p
                Icon { anchors.centerIn: parent; name: "check"; size: 11; color: Theme.pText; stroke: 2.4 }
            }
            Rectangle {
                visible: tile.video
                width: 18; height: 18; radius: 9
                color: Qt.rgba(0, 0, 0, 0.55)
                Icon { anchors.centerIn: parent; name: "play"; size: 10; color: "white" }
            }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: tile.on ? tile.activated(tile.index) : tile.picked(tile.index)
            onDoubleTapped: tile.activated(tile.index)
        }
    }
}
