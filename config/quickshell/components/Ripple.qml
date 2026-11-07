// Onda al pulsar (Material 3). Solo con el estilo Material; en Aurora no se dibuja.
//   Ripple { id: rip; anchors.fill: parent; radius: parent.radius; color: fg }
//   MouseArea { onPressed: m => rip.burst(m.x, m.y) }
import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    property real radius: 0
    property color color: Theme.t
    readonly property bool on: Theme.estilo === "flat" && !Theme.reduceMotion
    visible: on && anim.running
    clip: true
    layer.enabled: visible && radius > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskRect
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Rectangle { id: maskRect; anchors.fill: parent; radius: root.radius; visible: false; layer.enabled: true }

    function burst(px: real, py: real): void {
        if (!on) return;
        const d = 2 * Math.max(Math.hypot(px, py), Math.hypot(width - px, py), Math.hypot(px, height - py), Math.hypot(width - px, height - py));
        circle.cx = px; circle.cy = py; circle.full = d;
        anim.restart();
    }
    Rectangle {
        id: circle
        property real cx: 0
        property real cy: 0
        property real full: 0
        property real k: 0
        width: full * k; height: width; radius: width / 2
        x: cx - width / 2; y: cy - height / 2
        color: root.color
        opacity: 0
    }
    ParallelAnimation {
        id: anim
        NumberAnimation { target: circle; property: "k"; from: 0.1; to: 1; duration: 420; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: circle; property: "opacity"; from: 0; to: 0.16; duration: 80 }
            PauseAnimation { duration: 140 }
            NumberAnimation { target: circle; property: "opacity"; to: 0; duration: 280 }
        }
    }
}
