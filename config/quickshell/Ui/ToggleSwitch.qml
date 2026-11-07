// Compatibilidad con Omarchy · qs.Ui.ToggleSwitch: interruptor. No cambia «checked» solo: emite toggled()
// y el plugin decide (como en Omarchy).
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../"

Item {
    id: root
    property bool checked: false
    property bool busy: false
    property bool interactive: true
    property bool hasCursor: false
    property bool cursorRing: interactive
    property int cursorPad: Style.space(6)
    property bool rounded: true
    property color foreground: Commons.Color.foreground
    property color accent: Commons.Color.accent
    property int trackHeight: Math.max(18, Math.round(Style.spacing.controlHeight * 0.62))
    property int trackWidth: Math.round(trackHeight * 1.8)
    property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
    property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))
    readonly property alias containsMouse: mouse.containsMouse
    readonly property bool hot: hasCursor || mouse.containsMouse
    readonly property bool mirrored: false
    signal toggled()
    signal hovered(bool isHovered)
    implicitWidth: trackWidth
    implicitHeight: trackHeight
    opacity: busy ? 0.6 : enabled ? 1 : 0.45
    Rectangle {
        anchors.fill: parent
        radius: root.rounded ? height / 2 : Style.cornerRadius
        color: root.checked ? root.accent : Style.normalFillFor(root.foreground)
        border.width: root.checked ? 0 : 1
        border.color: Style.normalBorderFor(root.foreground)
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        Rectangle {
            width: root.knobSize; height: root.knobSize; radius: root.rounded ? width / 2 : Math.max(0, Style.cornerRadius - 2)
            y: root.knobInset
            x: root.checked ? parent.width - width - root.knobInset : root.knobInset
            color: root.checked ? Theme.pText : root.foreground
            Behavior on x { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -root.cursorPad
        enabled: root.interactive && root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(true)
        onExited: root.hovered(false)
        onClicked: if (!root.busy) root.toggled()
    }
}
