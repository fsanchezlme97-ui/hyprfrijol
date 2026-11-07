// Compatibilidad con Omarchy · qs.Ui.Dropdown: selector desplegable; elegir → changed(value).
//   options: ["a", "b"] o [{ value, label }]
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property string label: ""
    property string value: ""
    property var options: []
    property color foreground: Commons.Color.popups.text
    property color background: Commons.Color.popups.background
    property color popupBorder: Commons.Color.popups.border
    property color accent: Commons.Color.accent
    property string fontFamily: Style.font.family
    property int rowHeight: Style.spacing.controlHeight
    property int popupRowHeight: Style.spacing.popupRowHeight
    property bool showLabel: true
    property bool hasCursor: false
    readonly property bool popupOpen: popup.opened
    signal changed(string value)
    signal hovered(bool isHovered)
    function open() { popup.open(); }
    function close() { popup.close(); }
    function toggle() { popup.opened ? popup.close() : popup.open(); }
    function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o); }
    function optionLabel(o) { return (o && typeof o === "object") ? String(o.label) : String(o); }
    function currentLabel() { for (const o of options) if (optionValue(o) === value) return optionLabel(o); return value; }
    implicitWidth: Style.spacing.dropdownWidth
    implicitHeight: col.implicitHeight
    Column {
        id: col
        width: parent.width
        spacing: Style.spacing.labelGap
        Text { visible: root.showLabel && root.label !== ""; text: root.label; textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.3); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Button {
            id: trigger
            width: parent.width
            height: root.rowHeight
            leftAlign: true
            bordered: true
            hasCursor: root.hasCursor
            text: root.currentLabel() + "  ▾"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onClicked: root.toggle()
            onHovered: h => root.hovered(h)
        }
    }
    Popup {
        id: popup
        y: col.height + 2
        width: root.width
        padding: 4
        background: BorderSurface { color: root.background; borderSpec: Border.flat(root.popupBorder, 1); radius: Style.cornerRadius }
        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, root.popupRowHeight * 8)
            clip: true
            model: root.options
            delegate: Button {
                required property var modelData
                width: ListView.view.width
                height: root.popupRowHeight
                leftAlign: true
                text: root.optionLabel(modelData)
                selected: root.optionValue(modelData) === root.value
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: { popup.close(); root.changed(root.optionValue(modelData)); }
            }
        }
    }
}
