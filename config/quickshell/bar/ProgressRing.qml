// Anillo de progreso (pomodoro de la barra y su ventana).
//   ProgressRing { value: Pomodoro.progress; color: Theme.p; lineWidth: 2 }
import QtQuick
import ".."

Canvas {
    id: root
    property real value: 0               // 0–1
    property color color: Theme.p
    property color track: Theme.fill2
    property real lineWidth: 2
    implicitWidth: 12
    implicitHeight: 12
    onValueChanged: requestPaint()
    onColorChanged: requestPaint()
    onTrackChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        const r = Math.min(width, height) / 2 - lineWidth / 2, cx = width / 2, cy = height / 2;
        if (r <= 0) return;
        g.lineWidth = lineWidth;
        g.lineCap = "round";
        g.strokeStyle = track;
        g.beginPath(); g.arc(cx, cy, r, 0, 2 * Math.PI); g.stroke();
        const v = Math.max(0, Math.min(1, value));
        if (v <= 0) return;
        g.strokeStyle = color;
        g.beginPath(); g.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + v * 2 * Math.PI); g.stroke();
    }
}
