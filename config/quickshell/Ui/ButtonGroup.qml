// Compatibilidad con Omarchy · qs.Ui.ButtonGroup: fila de opciones excluyentes; elegir → changed(value).
import QtQuick
import qs.Commons
import qs.Commons as Commons

Row {
    id: root
    property var options: []
    property string value: ""
    property color foreground: Commons.Color.foreground
    property color background: Commons.Color.background
    property color accent: Commons.Color.accent
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.body
    property bool focusable: true
    property int cursorIndex: -1
    signal changed(string value)
    signal hovered(int index, bool isHovered)
    spacing: Style.spacing.xs
    function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o); }
    function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o); }
    function optionIcon(o) { return (o && typeof o === "object" && o.icon) ? String(o.icon) : ""; }
    function optionTooltip(o) { return (o && typeof o === "object" && o.tooltip) ? String(o.tooltip) : ""; }
    function selectedOptionIndex() { for (let i = 0; i < options.length; i++) if (optionValue(options[i]) === value) return i; return -1; }
    function activateFocused() { if (cursorIndex >= 0 && cursorIndex < options.length) changed(optionValue(options[cursorIndex])); }
    Repeater {
        model: root.options
        Button {
            required property var modelData
            required property int index
            text: root.optionLabel(modelData)
            iconText: root.optionIcon(modelData)
            tooltipText: root.optionTooltip(modelData)
            selected: root.optionValue(modelData) === root.value
            hasCursor: root.cursorIndex === index
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: root.fontSize
            bordered: true
            onClicked: root.changed(root.optionValue(modelData))
            onHovered: h => root.hovered(index, h)
        }
    }
}
