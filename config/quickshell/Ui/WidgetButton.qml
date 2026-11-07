// Compatibilidad con Omarchy · qs.Ui.WidgetButton: botón de texto/glifo de la barra (clic izquierdo, derecho y
// central → pressed(button); rueda → wheelMoved(delta); tooltipText → globo de la barra).
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property var bar: null
    property string text: ""
    property string fontFamily: bar ? bar.fontFamily : Style.font.family
    property real fontSize: Style.font.body
    property color foreground: bar ? bar.barForeground : Commons.Color.foreground
    property color activeColor: bar ? bar.urgent : Commons.Color.urgent
    property bool active: false
    property real horizontalMargin: 8.5
    property real verticalPadding: 6
    property real fixedWidth: -1
    property real fixedHeight: -1
    property real textRotation: 0
    property bool keepSpace: false
    property bool dimmed: false
    property bool concealed: false
    property bool interactive: true
    property bool pressable: true
    property bool useActiveColor: true
    property bool maintainIndicatorReveal: false
    property bool labelVisible: true
    property bool centerFigures: true
    property bool hasVisualContent: text !== ""
    property var revealHost: bar
    property string tooltipText: ""
    property var registeredBar: null
    property int heldButtons: Qt.NoButton
    property int pressFeedbackButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    readonly property real scaledHorizontalMargin: Style.spaceReal(horizontalMargin)
    readonly property real scaledVerticalPadding: Style.spaceReal(verticalPadding)
    readonly property bool tooltipHovered: visible && interactive && !concealed && mouseArea.containsMouse
    readonly property real labelWidth: label.visible ? label.implicitWidth : 0
    readonly property bool iconLabel: labelVisible && isIconGlyph(text)
    readonly property real iconPaintedWidth: label.paintedWidth
    readonly property real iconPaintedHeight: label.paintedHeight
    readonly property real iconCenterErrorX: 0
    readonly property real iconCenterErrorY: 0
    property real pressScale: pressable && ((mouseArea.pressedButtons | heldButtons) & pressFeedbackButtons) ? 0.9 : 1
    Behavior on pressScale { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

    signal pressed(int button)
    signal wheelMoved(int delta)

    function triggerPress(button) { pressed(button); }
    function hideOwnTooltip() { if (bar && bar.hideTooltip) bar.hideTooltip(root); }
    function syncClickRegistration() {}
    // Un glifo de icono: un solo carácter de las áreas privadas (Nerd Font) o un emoji
    function isIconGlyph(value) {
        const s = String(value ?? "");
        if (!s) return false;
        const cp = s.codePointAt(0);
        return [...s].length === 1 && (cp >= 0xE000 && cp <= 0xF8FF || cp >= 0xF0000);
    }

    visible: !concealed || keepSpace
    opacity: concealed ? 0 : dimmed ? 0.5 : 1
    implicitWidth: fixedWidth >= 0 ? fixedWidth : (vertical ? barSize : Math.ceil(label.implicitWidth + scaledHorizontalMargin * 2))
    implicitHeight: fixedHeight >= 0 ? fixedHeight : (vertical ? Math.ceil(label.implicitHeight + scaledVerticalPadding * 2) : barSize)

    Text {
        id: label
        visible: root.labelVisible
        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: root.active && root.useActiveColor ? root.activeColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.iconLabel ? Style.bar.iconFont : root.fontSize
        rotation: root.textRotation
        scale: root.pressScale
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: if (root.bar && root.tooltipText) root.bar.showTooltip(root, root.tooltipText)
        onExited: if (root.bar) root.bar.hideTooltip(root)
        onClicked: mouse => { if (root.pressable) root.triggerPress(mouse.button); }
        onWheel: wheel => root.wheelMoved(wheel.angleDelta.y)
    }
}
