// Una fuente de instalación de una app (menú de la insignia y selector de la ficha): nombre claro con su color,
// paquete, versión si se sabe y, en la ficha, qué significa esa fuente. Centro de aplicaciones.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: so
    property var src: ({})
    property var tool: null
    property bool first: false
    property bool compact: false
    property string version: ""
    signal picked()
    readonly property bool on: Pkg.source(tool)?.key === src.key
    readonly property bool inst: Pkg.isInst(src.key, src.pkg, tool)
    implicitHeight: col.implicitHeight + (compact ? 14 : 18)
    radius: Theme.r(5)
    color: on ? Theme.selBg : om.containsMouse ? Qt.alpha(Theme.t, 0.06) : "transparent"
    border.width: compact ? 0 : 1
    border.color: on ? "transparent" : Theme.ov
    MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: so.picked() }
    ColumnLayout {
        id: col
        x: 10; width: parent.width - 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: Pkg.hue(so.src.key) }
            Txt { text: Pkg.longLabels[so.src.key] ?? so.src.label; weight: Font.DemiBold; color: so.on ? Theme.selText : Theme.t }
            Txt { visible: so.first; text: "recomendada"; size: 10.5; color: so.on ? Theme.selText : Theme.tv }
            Item { Layout.fillWidth: true }
            Txt { visible: so.inst; text: "instalada"; size: 10.5; weight: Font.DemiBold; color: so.on ? Theme.selText : Theme.p }
            Txt { visible: !so.inst && so.on && !so.compact; text: "elegida"; size: 10.5; weight: Font.DemiBold; color: Theme.selText }
        }
        Mono {
            Layout.fillWidth: true
            text: so.src.pkg + (so.src.repo ? "  ·  " + so.src.repo : "") + (so.version ? "  ·  " + so.version : "")
            size: 10.5; color: so.on ? Theme.selText : Theme.tv
        }
        Txt {
            visible: !so.compact && !!Pkg.explain[so.src.key]
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: Pkg.explain[so.src.key] ?? ""
            size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
            color: so.on ? Theme.selText : Theme.tv
            opacity: so.on ? 0.85 : 1
        }
    }
}
