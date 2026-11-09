// Fondo de una píldora de la barra en modo «Archipiélago» (barMode = "archipielago"): cada grupo de módulos
// flota en su propia píldora de vidrio y entre ellas se ve el escritorio. La ventana de la barra solo recibe el
// ratón sobre las píldoras (Bar.qml: máscara con BarH/BarV.pills).
//   BarPill { bar: root.barWindow; x: …; width: …; height: parent.height }
// Forma: el radio sale de Bar.pillRadius (esquinas de las ventanas + Ajustes › Barra › Esquinas); el contorno se
// dibuja con curvas Bézier y suavizado (CurveRenderer), sin escalones ni tramos rectos.
import QtQuick
import QtQuick.Shapes
import ".."
import "../components"

Glass {
    id: pill
    required property var bar
    z: -1
    kind: "bar"
    radius: bar.pillRadius
    shadow: true
    showBorder: false
    effects: true
    color: "transparent"                 // el relleno lo pinta la forma de abajo
    opacity: bar.emptyWs ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.dur } }

    readonly property real bw: bar.pillBorderW
    readonly property real feather: 1 / bar.k
    // Contorno con cada esquina en una curva Bézier cúbica (con radios de 4–8 px una poligonal se veía octogonal).
    // k = 0,58: algo más llena que un arco circular (0,552), cerca de la esquina continua de las ventanas.
    function svg(w: real, h: real, r: real, inset: real): string {
        const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
        const q = Math.max(0, Math.min(r - inset, (x1 - x0) / 2, (y1 - y0) / 2)), c = q * (1 - 0.58);
        const f = v => v.toFixed(3);
        return "M" + f(x0 + q) + "," + f(y0)
            + " L" + f(x1 - q) + "," + f(y0) + " C" + f(x1 - c) + "," + f(y0) + " " + f(x1) + "," + f(y0 + c) + " " + f(x1) + "," + f(y0 + q)
            + " L" + f(x1) + "," + f(y1 - q) + " C" + f(x1) + "," + f(y1 - c) + " " + f(x1 - c) + "," + f(y1) + " " + f(x1 - q) + "," + f(y1)
            + " L" + f(x0 + q) + "," + f(y1) + " C" + f(x0 + c) + "," + f(y1) + " " + f(x0) + "," + f(y1 - c) + " " + f(x0) + "," + f(y1 - q)
            + " L" + f(x0) + "," + f(y0 + q) + " C" + f(x0) + "," + f(y0 + c) + " " + f(x0 + c) + "," + f(y0) + " " + f(x0 + q) + "," + f(y0) + " Z";
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Relleno de vidrio de la barra
        ShapePath {
            fillColor: Theme.glass
            strokeWidth: -1
            PathSvg { path: pill.svg(pill.width, pill.height, pill.rr, 0) }
        }
        // Suavizado extra: un anillo tenue de 1 px por fuera del contorno ensancha la transición del borde, como el
        // suavizado de las esquinas de Hyprland (con radios de 6–10 px a 1x, el borde nítido se leía como escalones)
        ShapePath {
            fillColor: "transparent"
            strokeWidth: pill.feather
            strokeColor: Qt.alpha(Theme.glass, Theme.glass.a * 0.38)
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: pill.svg(pill.width, pill.height, pill.rr, -pill.feather / 2) }
        }
        // Filo (Bar.pillBorder), medio trazo hacia dentro para que no se recorte
        ShapePath {
            fillColor: "transparent"
            strokeWidth: pill.bw > 0 ? pill.bw : -1
            strokeColor: pill.bw > 0 ? pill.bar.pillBorder : "transparent"
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: pill.svg(pill.width, pill.height, pill.rr, pill.bw / 2) }
        }
        // Alerta visual (visualBell) en cada píldora
        ShapePath {
            fillColor: Qt.alpha(Theme.p, Theme.p.a * pill.bar.bellLevel)
            strokeWidth: -1
            PathSvg { path: pill.svg(pill.width, pill.height, pill.rr, 0) }
        }
    }
}
