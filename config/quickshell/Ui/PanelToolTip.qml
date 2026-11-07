// Compatibilidad con Omarchy · qs.Ui.PanelToolTip: globo de ayuda (QtQuick.Controls ToolTip) con el tema.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

ToolTip {
    id: root
    property color panelForeground: Commons.Color.tooltip.text
    property color panelBackground: Commons.Color.tooltip.background
    property color panelBorder: Commons.Color.tooltip.border
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.bodySmall
    readonly property var panelBorderSpec: Border.flat(panelBorder, 1)
    delay: 400
    padding: 0
    background: BorderSurface { color: root.panelBackground; borderSpec: root.panelBorderSpec; radius: Style.cornerRadius }
    contentItem: Text {
        textFormat: Text.PlainText
        text: root.text
        color: root.panelForeground
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        wrapMode: Text.WordWrap
        leftPadding: Style.spacing.controlPaddingX
        rightPadding: Style.spacing.controlPaddingX
        topPadding: Style.spacing.controlPaddingY
        bottomPadding: Style.spacing.controlPaddingY
    }
}
