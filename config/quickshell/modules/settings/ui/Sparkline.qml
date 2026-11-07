// Línea simple de una serie de valores (salud de la batería…), con relleno suave y el último punto marcado.
//   Sparkline { values: [98, 97.5, 96]; min: 80; max: 100 }
import QtQuick
import "../../.."

Canvas {
    id: root
    property var values: []
    property real min: NaN              // NaN → automático
    property real max: NaN
    property color color: Theme.p
    property real lineWidth: 2
    implicitHeight: 48
    readonly property real lo: isNaN(min) ? Math.min(...values) - 1 : min
    readonly property real hi: isNaN(max) ? Math.max(...values) + 1 : max
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values ?? [];
        if (v.length < 1 || width <= 0) return;
        const pad = 4, w = width - pad * 2, h = height - pad * 2, span = Math.max(0.0001, hi - lo);
        const pt = i => [pad + (v.length === 1 ? w : i / (v.length - 1) * w), pad + h - (Math.max(lo, Math.min(hi, v[i])) - lo) / span * h];
        // relleno
        ctx.beginPath();
        ctx.moveTo(pt(0)[0], pad + h);
        for (let i = 0; i < v.length; i++) ctx.lineTo(...pt(i));
        ctx.lineTo(pt(v.length - 1)[0], pad + h);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(color, 0.14);
        ctx.fill();
        // línea
        ctx.beginPath();
        for (let i = 0; i < v.length; i++) { const p = pt(i); if (i) ctx.lineTo(p[0], p[1]); else ctx.moveTo(p[0], p[1]); }
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();
        // último punto
        const l = pt(v.length - 1);
        ctx.beginPath();
        ctx.arc(l[0], l[1], 3.5, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
    }
}
