// Tarjeta pequeña (icono, nombre, fuente) para las alternativas de la ficha de una app. Centro de aplicaciones.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: mi
    property var tool: ({})
    property var store: null
    signal picked()
    readonly property bool inst: Pkg.isToolInstalled(tool)
    implicitWidth: 236
    implicitHeight: 58
    radius: Theme.r(6)
    color: mm.containsMouse ? Qt.tint(Theme.s3, Qt.alpha(Theme.t, 0.04)) : Theme.s3
    border.width: 1
    border.color: mm.containsMouse ? Theme.o : Theme.ov
    MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mi.picked() }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 12
        StoreIcon { tool: mi.tool; store: mi.store; size: 32 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Txt { Layout.fillWidth: true; text: mi.tool.name; weight: Font.DemiBold; size: 12.5 }
            RowLayout {
                spacing: 4
                StoreBadge { tool: mi.tool; tip: false; enabled: false }
                Txt { visible: mi.inst; text: "instalada"; size: 10.5; weight: Font.DemiBold; color: Theme.p }
            }
        }
    }
}
