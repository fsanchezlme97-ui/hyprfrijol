// Compatibilidad con Omarchy · qs.Ui.BarIconButton: botón de icono de la barra (glifo, iconComponent o hijos propios).
import QtQuick
import qs.Commons

WidgetButton {
    id: root
    property Component iconComponent: null
    property real slotSize: Style.bar.iconSlot
    property real opticalSize: Style.bar.iconCanvas
    property real iconSize: Math.min(Style.bar.iconSize, opticalSize)
    readonly property real visualIconSize: Style.bar.iconSize
    readonly property real canvasSize: Math.max(visualIconSize, opticalSize)
    property string labelText: ""
    property bool debugOpticalBounds: false
    readonly property real glyphPaintedWidth: glyph.visible ? glyph.paintedWidth : 0
    readonly property real glyphPaintedHeight: glyph.visible ? glyph.paintedHeight : 0
    readonly property real glyphBaselineY: glyph.visible ? glyph.baselineY : 0
    readonly property int glyphFontSize: glyph.visible ? glyph.renderedFontSize : 0
    readonly property real componentPaintedWidth: customIcon.visible ? customIcon.paintedWidth : 0
    readonly property real componentPaintedHeight: customIcon.visible ? customIcon.paintedHeight : 0
    readonly property rect componentSourceBounds: customIcon.sourceBounds

    labelVisible: false
    hasVisualContent: text !== "" || iconComponent !== null || labelText !== ""
    fontSize: Style.bar.iconFont
    fixedWidth: vertical ? -1 : slotSize + (labelText !== "" ? lbl.implicitWidth + Style.space(4) : 0)
    fixedHeight: vertical ? slotSize : -1

    Row {
        anchors.centerIn: parent
        spacing: Style.space(4)
        scale: root.pressScale
        Text {
            id: lbl
            visible: root.labelText !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            color: root.active && root.useActiveColor ? root.activeColor : root.foreground
        }
        Item {
            width: root.canvasSize
            height: root.canvasSize
            anchors.verticalCenter: parent.verticalCenter
            OpticalGlyph {
                id: glyph
                anchors.fill: parent
                visible: root.iconComponent === null && root.text !== ""
                text: root.text
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                color: root.active && root.useActiveColor ? root.activeColor : root.foreground
                rotation: root.textRotation
            }
            BarIconContent {
                id: customIcon
                anchors.fill: parent
                visible: root.iconComponent !== null
                sourceComponent: root.iconComponent
                sourceSize: root.opticalSize
            }
        }
    }
}
