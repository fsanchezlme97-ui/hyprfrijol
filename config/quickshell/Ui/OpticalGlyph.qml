// Compatibilidad con Omarchy · qs.Ui.OpticalGlyph: un glifo (Nerd Font) centrado en su caja.
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property string text: ""
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.body
    property real paintedSize: 0
    property color color: Commons.Color.foreground
    property bool debugBounds: false
    readonly property int renderedFontSize: Math.max(1, Math.round(paintedSize > 0 ? Math.max(fontSize, paintedSize) : fontSize))
    readonly property real paintedWidth: glyph.paintedWidth
    readonly property real paintedHeight: glyph.paintedHeight
    readonly property real baselineY: glyph.y + glyph.baselineOffset
    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight
    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.renderedFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
