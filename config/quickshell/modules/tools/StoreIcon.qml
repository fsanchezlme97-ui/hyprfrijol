// Icono de una app del Centro de aplicaciones: el del tema (o el de la app instalada); si no hay, el de Flathub
// (fallback, p. ej. en la ficha) y si tampoco, la inicial sobre un cuadrado de color.
import QtQuick
import "../.."
import "../../components"
import "../../services"

Item {
    id: ic
    property var tool: ({})
    property var store: null
    property real size: 40
    property string fallback: ""        // URL de un icono remoto (Flathub) si el tema no tiene ninguno
    readonly property string src: store ? store.iconOf(tool) : ""
    readonly property var tile: ({ print: [Theme.sc, Theme.scText], files: [Theme.pc, Theme.pcText], crea: [Theme.pc, Theme.pcText], ofi: [Theme.sc, Theme.scText], ia: [Theme.p, Theme.pText], game: [Theme.sc, Theme.scText], com: [Theme.pc, Theme.pcText] })[tool?.cat] ?? [Theme.s4, Theme.t]
    implicitWidth: size; implicitHeight: size
    Image {
        id: img
        anchors.fill: parent
        source: ic.src || ic.fallback
        sourceSize: Qt.size(ic.size * 2, ic.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true; mipmap: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: !img.visible
        radius: Theme.r(ic.size * 0.22)
        color: ic.tile[0]
        Txt { anchors.centerIn: parent; text: (ic.tool?.name ?? "?")[0]; weight: Font.DemiBold; size: ic.size * 0.4; color: ic.tile[1] }
    }
}
