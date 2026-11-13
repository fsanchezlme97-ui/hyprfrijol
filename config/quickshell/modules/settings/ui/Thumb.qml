// Miniatura de fondo (imagen, o el primer cuadro si es un vídeo/GIF) con anillo c.p si está elegida.
//   Thumb { file: "/ruta/fondo.jpg"; label: "fondo"; selected: …; onClicked: … }
// Los vídeos usan la miniatura de hf-wallpaper (~/.cache/hyprfrijol/thumbs/<md5 de la ruta>.jpg, la generan
// «hf-wallpaper vthumbs» / Wallpapers.qml); `tick` la vuelve a cargar cuando aparece.
// El nombre va abajo, dentro de la tarjeta, sobre un degradado y cortado con «…» si no cabe.
import QtQuick
import QtQuick.Effects
import "../../.."
import "../../../components"

Item {
    id: root
    property string file: ""
    property bool selected: false
    readonly property bool video: /\.(mp4|webm|mkv|mov|gif)$/i.test(file)
    property string label: ""
    property real r: Theme.r(6)
    property int tick: 0
    readonly property string preview: !file ? "" : !video ? "file://" + file
        : "file://" + Paths.cache + "/thumbs/" + Qt.md5(file).slice(0, 16) + ".jpg?" + tick
    signal clicked()
    implicitHeight: 82
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.r
        color: Theme.s4
        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            name: root.video ? "play" : "image"
            size: 18
            color: Theme.tv
        }
        Item {
            id: mask
            anchors.fill: pic
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; radius: root.selected ? Math.max(0, root.r - 2) : root.r }
        }
        Item {
            id: pic
            anchors.fill: parent
            anchors.margins: root.selected ? 3 : 0
            visible: img.status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
            Image {
                id: img
                anchors.fill: parent
                source: root.preview
                sourceSize.width: 360
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: !root.video
            }
            // Degradado para que el nombre se lea sobre cualquier imagen
            Rectangle {
                visible: root.label !== ""
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.min(parent.height, 32)
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: root.r
            color: "transparent"
            border.width: root.selected ? 3 : 0
            border.color: Theme.p
        }
        // Insignia «animado» arriba a la izquierda (no choca con el nombre)
        Rectangle {
            visible: root.video
            anchors { left: parent.left; top: parent.top; margins: 8 }
            width: vt.implicitWidth + 12; height: 18; radius: Theme.ctl(18)
            color: Qt.alpha("#000000", 0.55)
            Txt { id: vt; anchors.centerIn: parent; text: /\.gif$/i.test(root.file) ? "▶ GIF" : "▶ animado"; size: 10; color: "#FFFFFF" }
        }
        Txt {
            visible: root.label !== ""
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; bottomMargin: 8 }
            text: root.label
            elide: Text.ElideRight
            maximumLineCount: 1
            size: 11; color: "#FFFFFF"; weight: Font.DemiBold
            style: Text.Raised; styleColor: Qt.alpha("#000000", 0.45)
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    }
}
