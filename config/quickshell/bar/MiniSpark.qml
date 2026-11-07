// Gráfica mínima (línea + relleno) para los chips de la barra y las ventanas de widgets.
//   MiniSpark { values: SysStats.cpuHist; max: 100; color: Theme.p }   (max NaN → el máximo de la serie)
import QtQuick
import ".."

Canvas {
    id: root
    property var values: []
    property real max: 100
    property color color: Theme.p
    property real lineWidth: 1.5
    property bool fill: true
    implicitWidth: 40
    implicitHeight: 14
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        const v = values ?? [];
        if (v.length < 2 || width <= 0 || height <= 0) return;
        const hi = isNaN(max) ? Math.max(1, ...v) * 1.15 : max;
        const lw = lineWidth, h = height - lw, n = v.length;
        const px = i => i / (n - 1) * width, py = i => lw / 2 + h - Math.max(0, Math.min(1, v[i] / hi)) * h;
        g.beginPath();
        g.moveTo(px(0), py(0));
        for (let i = 1; i < n; i++) g.lineTo(px(i), py(i));
        g.strokeStyle = color; g.lineWidth = lw; g.lineJoin = "round";
        g.stroke();
        if (fill) {
            g.lineTo(width, height); g.lineTo(0, height); g.closePath();
            g.fillStyle = Qt.alpha(color, 0.18); g.fill();
        }
    }
}
