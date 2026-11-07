// Compatibilidad con Omarchy · qs.Ui.Toggle: fila con título, descripción e interruptor; clic → clicked().
import QtQuick
import qs.Commons
import qs.Commons as Commons

BorderSurface {
    id: root
    property string label: ""
    property string description: ""
    property bool checked: false
    property bool busy: false
    property bool hasCursor: false
    property bool focusable: false
    property bool rounded: Style.cornerRadius > 0
    property color foreground: Commons.Color.foreground
    property color accent: Commons.Color.accent
    property string fontFamily: Style.font.family
    property real titleSize: Style.font.subtitle
    property real descriptionSize: Style.font.caption
    signal clicked()
    signal hovered(bool isHovered)
    readonly property bool _hot: hasCursor || mouse.containsMouse
    radius: Style.cornerRadius
    color: _hot ? Style.hoverFillFor(foreground, accent) : "transparent"
    implicitWidth: Math.ceil(texts.implicitWidth + sw.implicitWidth + Style.spacing.rowPaddingX * 2 + Style.spacing.controlGap)
    implicitHeight: Math.max(Style.spacing.controlHeight, Math.ceil(texts.implicitHeight + Style.spacing.controlPaddingY * 2))
    activeFocusOnTab: focusable
    Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) { root.clicked(); event.accepted = true; } }
    Column {
        id: texts
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.rowPaddingX
        anchors.right: sw.left
        anchors.rightMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; text: root.label; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: root.titleSize; elide: Text.ElideRight }
        Text { width: parent.width; visible: root.description !== ""; text: root.description; textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily; font.pixelSize: root.descriptionSize; wrapMode: Text.WordWrap }
    }
    ToggleSwitch {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        busy: root.busy
        interactive: false
        foreground: root.foreground
        accent: root.accent
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(true)
        onExited: root.hovered(false)
        onClicked: if (!root.busy) root.clicked()
    }
}
