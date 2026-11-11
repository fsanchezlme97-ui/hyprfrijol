// Deslizador grueso con icono dentro (brillo / volumen de los ajustes rápidos).
//   SliderBar { icon: "sun"; value: 0.6; onMoved: v => … }
import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property real value: 0.5
    property real from: 0
    property real to: 1
    signal moved(real value)
    signal released()                       // al soltar (p. ej. para confirmar una previsualización)
    readonly property bool dragging: drag.pressed
    implicitHeight: 30
    radius: Theme.ctl(height)
    color: Theme.fill2
    clip: true
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    Rectangle {
        width: Math.max(parent.height, parent.width * root.frac)
        height: parent.height
        radius: parent.radius
        color: Theme.fillOn
        Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }
    Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: root.icon; color: Theme.fillOnText }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(mx) { root.moved(root.from + Math.max(0, Math.min(1, mx / width)) * (root.to - root.from)); }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onReleased: root.released()
        onCanceled: root.released()
        onWheel: w => root.moved(Math.max(root.from, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05) * (root.to - root.from))))
    }
}
