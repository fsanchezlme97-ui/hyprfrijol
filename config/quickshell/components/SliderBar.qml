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
    // Chroma: la parte vacía de la pista es una fila de puntos (Nothing OS)
    Canvas {
        id: dotsTrack
        visible: Theme.chroma
        anchors.fill: parent
        readonly property real from: Math.max(parent.height, parent.width * root.frac)
        onFromChanged: requestPaint()
        onWidthChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = Theme.tv, step = 7, y = height / 2;
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.55);
            for (let x = from + step; x < width - 6; x += step) { ctx.beginPath(); ctx.arc(x, y, 1.2, 0, 2 * Math.PI); ctx.fill(); }
        }
    }
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    Rectangle {
        width: Math.max(parent.height, parent.width * root.frac)
        height: parent.height
        radius: parent.radius
        color: Theme.fillOn
        Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 120 } }
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
