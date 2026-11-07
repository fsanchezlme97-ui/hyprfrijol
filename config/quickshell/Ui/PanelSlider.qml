// Compatibilidad con Omarchy · qs.Ui.PanelSlider: deslizador; arrastrar → moved(value), soltar → released(value).
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property QtObject bar: null
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    property color trackColor: Style.selectedFillFor(Commons.Color.foreground, Commons.Color.accent)
    property color fillColor: Commons.Color.accent
    property color knobColor: Commons.Color.foreground
    property bool dragging: false
    property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.14))
    property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.5))
    property real liveValue: value
    property int tickCount: 0
    property color tickColor: Commons.Color.background
    signal moved(real value)
    signal released(real value)
    signal rightClicked()
    readonly property real range: Math.max(0.0001, maximum - minimum)
    readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
    readonly property bool mirrored: false
    onValueChanged: if (!dragging) liveValue = value
    function trackX(fraction) { return knobSize / 2 + fraction * (width - knobSize); }
    function valueFromX(x) {
        let v = minimum + Math.max(0, Math.min(1, (x - knobSize / 2) / Math.max(1, width - knobSize))) * range;
        if (step > 0) v = Math.round(v / step) * step;
        if (integer) v = Math.round(v);
        return Math.max(minimum, Math.min(maximum, v));
    }
    implicitWidth: 200
    implicitHeight: knobSize
    Rectangle { x: root.knobSize / 2; width: parent.width - root.knobSize; height: root.trackHeight; radius: height / 2; anchors.verticalCenter: parent.verticalCenter; color: root.trackColor }
    Rectangle { x: root.knobSize / 2; width: root.trackX(root.progress) - root.knobSize / 2; height: root.trackHeight; radius: height / 2; anchors.verticalCenter: parent.verticalCenter; color: root.fillColor }
    Rectangle { width: root.knobSize; height: root.knobSize; radius: width / 2; x: root.trackX(root.progress) - width / 2; anchors.verticalCenter: parent.verticalCenter; color: root.knobColor }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { if (mouse.button === Qt.RightButton) { root.rightClicked(); return; } root.dragging = true; root.liveValue = root.valueFromX(mouse.x); root.moved(root.liveValue); }
        onPositionChanged: mouse => { if (root.dragging) { root.liveValue = root.valueFromX(mouse.x); root.moved(root.liveValue); } }
        onReleased: mouse => { if (root.dragging) { root.dragging = false; root.released(root.liveValue); } }
        onWheel: wheel => { const v = Math.max(root.minimum, Math.min(root.maximum, root.liveValue + (wheel.angleDelta.y > 0 ? 1 : -1) * (root.step || root.range / 20))); root.liveValue = v; root.moved(v); root.released(v); }
    }
}
