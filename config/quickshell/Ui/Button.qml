// Compatibilidad con Omarchy · qs.Ui.Button: botón de texto y/o glifo de los paneles.
import QtQuick
import qs.Commons
import qs.Commons as Commons

BorderSurface {
    id: root
    property string text: ""
    property string iconText: ""
    property string tooltipText: ""
    property bool selected: false
    property bool active: false
    property bool hasCursor: false
    property bool focusable: false
    property bool bordered: false
    property color foreground: Commons.Color.foreground
    property color background: "transparent"
    property color accent: Commons.Color.accent
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.body
    property real iconSize: Style.font.icon
    property real iconRotation: 0
    property bool iconSpinning: false
    property real horizontalPadding: Style.spacing.controlPaddingX
    property real verticalPadding: Style.spacing.controlPaddingY
    property bool leftAlign: false
    property color tooltipBackground: Commons.Color.tooltip.background
    property color tooltipForeground: Commons.Color.tooltip.text
    property color tooltipBorder: Commons.Color.tooltip.border
    readonly property bool hot: mouseArea.containsMouse || hasCursor
    signal clicked()
    signal rightClicked()
    signal hovered(bool isHovered)

    activeFocusOnTab: focusable
    radius: Style.cornerRadius
    implicitWidth: Math.ceil(row.implicitWidth + horizontalPadding * 2)
    implicitHeight: Math.max(Style.spacing.controlHeight, Math.ceil(row.implicitHeight + verticalPadding * 2))
    opacity: enabled ? 1 : 0.45
    color: mouseArea.pressed ? Style.pressedFillFor(foreground, accent)
        : (selected || active) ? Style.selectedFillFor(foreground, accent)
        : hot || activeFocus ? Style.hoverFillFor(foreground, accent)
        : (background.a > 0 ? background : bordered ? Style.normalFillFor(foreground, accent) : "transparent")
    borderSpec: activeFocus && focusable ? Border.controlSpec("focus", foreground, accent)
        : bordered ? Border.controlSpec(hot ? "hover-cursor" : "normal", foreground, accent) : Border.none()
    Behavior on color { ColorAnimation { duration: Style.duration(90) } }
    Keys.onPressed: event => { if (focusable && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) { root.clicked(); event.accepted = true; } }

    Row {
        id: row
        spacing: root.iconText !== "" && root.text !== "" ? Style.spacing.controlGap : 0
        x: root.leftAlign ? root.horizontalPadding : (root.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        scale: mouseArea.pressed ? 0.97 : 1
        Text {
            visible: root.iconText !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconText
            textFormat: Text.PlainText
            color: root.selected ? Style.selectedStateColor(root.foreground, root.accent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.iconSize
            rotation: root.iconRotation
            RotationAnimation on rotation { running: root.iconSpinning; loops: Animation.Infinite; from: 0; to: 360; duration: 1000 }
        }
        Text {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
        }
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(true)
        onExited: root.hovered(false)
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked(); }
    }
    PanelToolTip { visible: root.tooltipText !== "" && mouseArea.containsMouse; text: root.tooltipText }
}
