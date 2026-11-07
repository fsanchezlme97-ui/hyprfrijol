// Insignia de la fuente de una app («Repos oficiales» / «AUR» / «Flatpak» / «AppImage» / «Web app»…), cada una con
// su color (Pkg.hue), un tooltip que explica qué significa y, si hay varias, un menú para cambiarla. Centro de aplicaciones.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: sb
    property var tool: null             // app del catálogo (con menú) …
    property string key: ""             // … o fuente fija (resultado de búsqueda)
    property bool big: false            // ficha de la app: algo más grande
    property bool tip: true
    readonly property var srcs: tool ? Pkg.sources(tool) : []
    readonly property var cur: tool ? Pkg.source(tool) : null
    readonly property string k: tool ? (cur?.key ?? "none") : key
    readonly property bool menu: srcs.length > 1
    readonly property color hue: Pkg.hue(k)
    readonly property color fg: k === "none" ? Theme.tv : Theme.light ? Qt.darker(hue, 1.55) : Qt.lighter(hue, 1.5)
    visible: k !== ""
    implicitWidth: bl.implicitWidth + (menu ? 24 : 14)
    implicitHeight: big ? 24 : 18
    radius: Theme.r(4)
    color: k === "none" ? "transparent" : Qt.alpha(hue, Theme.light ? 0.15 : 0.22)
    border.width: 1
    border.color: k === "none" ? Theme.o : Qt.alpha(hue, 0.55)
    Row {
        anchors.centerIn: parent
        spacing: 3
        Txt { id: bl; text: Pkg.longLabels[sb.k] ?? sb.k; size: sb.big ? 12 : 10; weight: Font.Bold; color: sb.fg }
        Txt { visible: sb.menu; text: "▾"; size: sb.big ? 10.5 : 9; color: sb.fg; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: bm
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: sb.menu ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (sb.menu) pop.open()
    }
    ToolTip {
        visible: sb.tip && bm.containsMouse && !pop.opened && !!Pkg.explain[sb.k]
        delay: 450
        y: sb.height + 6
        x: Math.min(0, sb.width - width)
        padding: 9
        width: Math.min(320, tipTxt.implicitWidth + 18)
        background: Rectangle { color: Theme.s1; radius: Theme.r(6); border.width: 1; border.color: Theme.ov }
        contentItem: Txt {
            id: tipTxt
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap; elide: Text.ElideNone
            size: 11.5
            text: "<b>" + (Pkg.longLabels[sb.k] ?? sb.k) + "</b> · " + (Pkg.explain[sb.k] ?? "") + (sb.menu ? "<br><font color='" + Theme.tv + "'>Pulsa para elegir otra fuente</font>" : "")
        }
    }
    Popup {
        id: pop
        y: sb.height + 4
        x: Math.min(0, sb.width - width)
        width: 320
        padding: 5
        background: Rectangle { color: Theme.s1; radius: Theme.r(8); border.width: 1; border.color: Theme.ov }
        contentItem: ColumnLayout {
            spacing: 2
            Txt { Layout.leftMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 2; text: "Instalar desde"; muted: true; size: 11 }
            Repeater {
                model: sb.srcs
                StoreSourceRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    src: modelData
                    first: index === 0
                    tool: sb.tool
                    compact: true
                    onPicked: { Pkg.setSource(sb.tool.id, modelData.key); pop.close(); }
                }
            }
        }
    }
}
