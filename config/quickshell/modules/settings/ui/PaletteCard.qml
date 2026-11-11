// Tarjeta de una paleta (Ajustes › Apariencia › Paleta de colores): una ventanita con sus colores (superficie,
// texto, acento, terciario y los colores del terminal) y el nombre. Las paletas con pareja clara/oscura
// (palettes.json "pair") muestran la del modo actual; las de un solo modo llevan un sol o una luna.
//   PaletteCard { key: "nord"; pals: …; current: "nord"; onPicked: (k, mode) => … }   (mode "" = no tocar el modo)
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: card
    property string key: ""
    property var pals: ({})
    property string current: ""
    property string themeMode: "oscuro"
    readonly property var base: pals[key] ?? ({})
    readonly property var pal: base.pair && pals[base.pair] && !!pals[base.pair].light === Theme.light ? pals[base.pair] : base
    readonly property bool on: current === key || (base.pair !== undefined && current === base.pair)
    readonly property var ansi: pal.ansi ?? [pal.s4, "#E06C75", "#98C379", "#E5C07B", pal.p, pal.ter, "#56B6C2"]
    signal picked(string key, string mode)

    implicitWidth: 150
    implicitHeight: 66
    radius: Theme.r(8)
    color: pal.s1 ?? Theme.s4
    border.width: on ? 2 : 1
    border.color: on ? Theme.p : ma.containsMouse ? Qt.alpha(Theme.t, 0.35) : Qt.alpha(Theme.t, 0.12)
    clip: true
    Behavior on border.color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    // Barra lateral de la «ventana» con el fondo más oscuro (o claro)
    Rectangle {
        x: card.border.width; y: card.border.width
        width: 16; height: parent.height - card.border.width * 2
        color: card.pal.bg ?? "transparent"
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8; spacing: 4
            Repeater {
                model: 3
                Rectangle { width: 6; height: 6; radius: 3; color: index === 0 ? card.pal.p : card.pal.ov ?? "transparent" }
            }
        }
    }
    ColumnLayout {
        anchors { fill: parent; leftMargin: 24; rightMargin: 8; topMargin: 7; bottomMargin: 7 }
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: (card.base.name ?? card.key).replace(" · claro", "")
                color: card.pal.t ?? Theme.t
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Icon {
                visible: !card.base.pair
                name: card.base.light ? "sun" : "moon"
                size: 11
                color: card.pal.tv ?? Theme.tv
            }
        }
        // acento + terciario como «botones»
        RowLayout {
            spacing: 4
            Rectangle { implicitWidth: 30; implicitHeight: 9; radius: 4.5; color: card.pal.p ?? "transparent" }
            Rectangle { implicitWidth: 16; implicitHeight: 9; radius: 4.5; color: card.pal.ter ?? "transparent" }
            Rectangle { implicitWidth: 20; implicitHeight: 9; radius: 4.5; color: card.pal.s4 ?? "transparent" }
            Item { Layout.fillWidth: true }
        }
        // colores del terminal
        Row {
            spacing: 0
            Layout.fillWidth: true
            Repeater {
                model: [1, 2, 3, 4, 5, 6]
                Rectangle {
                    required property int modelData
                    width: 13; height: 6
                    color: card.ansi[modelData] ?? "transparent"
                    radius: modelData === 1 || modelData === 6 ? 2 : 0
                }
            }
        }
    }
    Rectangle {
        visible: card.on
        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
        width: 16; height: 16; radius: 8
        color: Theme.p
        Icon { anchors.centerIn: parent; name: "check"; size: 10; color: Theme.pText }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.picked(card.key, card.themeMode === "auto" || !!card.base.pair ? "" : card.base.light ? "claro" : "oscuro")
    }
}
