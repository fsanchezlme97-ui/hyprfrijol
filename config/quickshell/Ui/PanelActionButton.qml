// Compatibilidad con Omarchy · qs.Ui.PanelActionButton: botón cuadrado de un glifo (cabeceras de panel).
import QtQuick
import qs.Commons
import qs.Commons as Commons

BorderSurface {
    id: root
    property string iconText: ""
    property string tooltipText: ""
    property color foreground: Commons.Color.foreground
    property color hoverColor: foreground
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.icon
    property real size: Math.round(Math.max(Style.space(22), fontSize + Style.spacing.sm * 2)) | 1
    property bool focusable: false
    property bool hasCursor: false
    property bool bordered: false
    signal clicked()
    signal hovered(bool isHovered)
    readonly property bool _hot: (mouse.containsMouse || hasCursor) && enabled
    implicitWidth: size
    implicitHeight: size
    radius: Style.cornerRadius
    opacity: enabled ? 1 : 0.45
    color: mouse.pressed ? Style.pressedFillFor(foreground) : _hot ? Style.hoverFillFor(foreground) : "transparent"
    borderSpec: bordered ? Border.controlSpec(_hot ? "hover-cursor" : "normal", foreground) : Border.none()
    activeFocusOnTab: focusable
    Text {
        anchors.centerIn: parent
        text: root.iconText
        textFormat: Text.PlainText
        color: root._hot ? root.hoverColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(true)
        onExited: root.hovered(false)
        onClicked: root.clicked()
    }
    PanelToolTip { visible: root.tooltipText !== "" && mouse.containsMouse; text: root.tooltipText }
}
