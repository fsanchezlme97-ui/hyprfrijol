// Fondo de la barra en forma «Muesca» (barMode = "muesca"): una sola pieza que sale del borde de la pantalla, con el lado
// del borde recto y dos «orejas» cóncavas que la funden con él, y las esquinas de fuera redondeadas. Con la isla dinámica
// desplegada, de su centro cuelga un panel (panelW × panelH) que forma parte de la misma figura, así crece como una
// muesca de verdad y no como dos piezas encima. Dibujada para la barra arriba; con la barra abajo se refleja (flip).
//   NotchBg { anchors.fill: body; radius: …; panelW: …; panelH: …; flip: pos === "abajo" }
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real radius: 12           // esquinas de fuera de la barra
    property real ear: 14              // orejas cóncavas junto al borde
    property real panelX: (width - panelW) / 2   // borde izquierdo del panel colgado
    property real panelW: 0
    property real panelH: 0
    property real panelRadius: Theme.r(22)
    property bool flip: false
    property real bellLevel: 0

    // Figura entera en coordenadas de la barra (x de -ear a width + ear; y de 0 a height + panelH)
    function path(W: real, T: real, Wp: real, Hp: real): string {
        const k = 0.552, e = ear, r = Math.min(radius, T / 2, W / 4);
        const f0 = 14, f = Math.min(f0, Hp / 2);
        const wp = Math.min(Wp, W - 2 * (r + f0));
        const panel = Hp >= 1 && wp > 0;
        const rp = Math.max(0, Math.min(panelRadius, wp / 2, Hp - f));
        const x0 = Math.max(r + f0, Math.min(panelX, W - r - f0 - wp)), x1 = x0 + wp, B = T + Hp;
        const n = v => v.toFixed(2), P = (x, y) => n(x) + "," + n(y);
        let d = "M" + P(-e, 0) + " L" + P(W + e, 0)
            + " C" + P(W + e - e * k, 0) + " " + P(W, e - e * k) + " " + P(W, e)
            + " L" + P(W, T - r)
            + " C" + P(W, T - r + r * k) + " " + P(W - r + r * k, T) + " " + P(W - r, T);
        if (panel)
            d += " L" + P(x1 + f, T)
                + " C" + P(x1 + f - f * k, T) + " " + P(x1, T + f - f * k) + " " + P(x1, T + f)
                + " L" + P(x1, B - rp)
                + " C" + P(x1, B - rp + rp * k) + " " + P(x1 - rp + rp * k, B) + " " + P(x1 - rp, B)
                + " L" + P(x0 + rp, B)
                + " C" + P(x0 + rp - rp * k, B) + " " + P(x0, B - rp + rp * k) + " " + P(x0, B - rp)
                + " L" + P(x0, T + f)
                + " C" + P(x0, T + f - f * k) + " " + P(x0 - f + f * k, T) + " " + P(x0 - f, T);
        d += " L" + P(r, T)
            + " C" + P(r - r * k, T) + " " + P(0, T - r + r * k) + " " + P(0, T - r)
            + " L" + P(0, e)
            + " C" + P(0, e - e * k) + " " + P(-e + e * k, 0) + " " + P(-e, 0) + " Z";
        return d;
    }

    Shape {
        id: shape
        width: root.width; height: root.height
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { yScale: root.flip ? -1 : 1; origin.y: root.height / 2 }
        readonly property string d: root.path(root.width, root.height, root.panelW, root.panelH)
        ShapePath { fillColor: Theme.glass; strokeWidth: -1; PathSvg { path: shape.d } }
        // Alerta visual (visualBell)
        ShapePath { fillColor: Qt.alpha(Theme.p, Theme.p.a * root.bellLevel); strokeWidth: -1; PathSvg { path: shape.d } }
    }
}
