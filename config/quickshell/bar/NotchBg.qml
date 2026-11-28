// Fondo de la barra en forma «Muesca» (barMode = "muesca"): una sola pieza que sale del borde de la pantalla, con el lado
// del borde recto y dos «orejas» cóncavas que la funden con él, y los extremos de fuera redondeados como una cápsula.
// Dibujada para la barra arriba; con la barra abajo se refleja (flip).
//   NotchBg { anchors.fill: body; radius: …; flip: pos === "abajo" }
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real radius: 12           // esquinas de fuera de la barra
    property real ear: 14              // orejas cóncavas junto al borde
    property bool flip: false
    property real bellLevel: 0

    // Figura en coordenadas de la barra (x de -ear a width + ear)
    function path(W: real, T: real): string {
        const k = 0.552, e = ear, r = Math.min(radius, T / 2, W / 4);
        const n = v => v.toFixed(2), P = (x, y) => n(x) + "," + n(y);
        return "M" + P(-e, 0) + " L" + P(W + e, 0)
            + " C" + P(W + e - e * k, 0) + " " + P(W, e - e * k) + " " + P(W, e)
            + " L" + P(W, T - r)
            + " C" + P(W, T - r + r * k) + " " + P(W - r + r * k, T) + " " + P(W - r, T)
            + " L" + P(r, T)
            + " C" + P(r - r * k, T) + " " + P(0, T - r + r * k) + " " + P(0, T - r)
            + " L" + P(0, e)
            + " C" + P(0, e - e * k) + " " + P(-e + e * k, 0) + " " + P(-e, 0) + " Z";
    }

    Shape {
        id: shape
        width: root.width; height: root.height
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { yScale: root.flip ? -1 : 1; origin.y: root.height / 2 }
        readonly property string d: root.path(root.width, root.height)
        ShapePath { fillColor: Theme.glass; strokeWidth: -1; PathSvg { path: shape.d } }
        // Alerta visual (visualBell)
        ShapePath { fillColor: Qt.alpha(Theme.p, Theme.p.a * root.bellLevel); strokeWidth: -1; PathSvg { path: shape.d } }
    }
}
