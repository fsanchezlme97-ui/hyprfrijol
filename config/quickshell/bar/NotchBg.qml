// Fondo de la barra en forma «Muesca» (barMode = "muesca"): una sola pieza que sale del borde de la pantalla. Cada lado es
// una curva en S suave (como cubic-bezier(0.5, 0, 0.5, 1)): nace plana en el borde, baja despacio y llega plana a la base,
// sin esquinas ni curvas cerradas. La S va por fuera del contenido (slope px a cada lado). Dibujada para la barra arriba;
// con la barra abajo se refleja (flip).
//   NotchBg { anchors.fill: body; slope: …; flip: pos === "abajo" }
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real slope: height * 1.8     // ancho de cada curva lateral
    property bool flip: false
    property real bellLevel: 0

    // Figura en coordenadas de la barra (x de -slope a width + slope; y de 0 a height)
    function path(W: real, T: real, L: real): string {
        const n = v => v.toFixed(2), P = (x, y) => n(x) + "," + n(y);
        return "M" + P(-L, 0) + " L" + P(W + L, 0)
            + " C" + P(W + L / 2, 0) + " " + P(W + L / 2, T) + " " + P(W, T)
            + " L" + P(0, T)
            + " C" + P(-L / 2, T) + " " + P(-L / 2, 0) + " " + P(-L, 0) + " Z";
    }

    Shape {
        id: shape
        width: root.width; height: root.height
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { yScale: root.flip ? -1 : 1; origin.y: root.height / 2 }
        readonly property string d: root.path(root.width, root.height, root.slope)
        ShapePath { fillColor: Theme.glass; strokeWidth: -1; PathSvg { path: shape.d } }
        // Alerta visual (visualBell)
        ShapePath { fillColor: Qt.alpha(Theme.p, Theme.p.a * root.bellLevel); strokeWidth: -1; PathSvg { path: shape.d } }
    }
}
