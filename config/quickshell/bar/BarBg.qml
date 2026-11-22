// Fondo de la barra (toda la barra o una píldora del archipiélago) con el mismo acabado de vidrio en todos
// los modos: curvas Bézier, suavizado de borde y filo opcional. Reemplaza Glass { kind: "bar" } para que
// fija, flotante, isla y archipiélago compartan forma y material.
//   BarBg { radius: …; shadow: …; drawBorder: …; bellLevel: …; feather: … }
import QtQuick
import QtQuick.Shapes
import ".."
import "../components"

Glass {
    id: root
    property real bellLevel: 0
    property bool drawBorder: true
    property real borderW: !drawBorder || Settings.get("activeBorder", "sutil") === "ninguno" || Theme.glassy ? 0 : Theme.borderWidth
    property color borderColor: Theme.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.20)
    property real feather: 1
    kind: "bar"
    // Glass dibuja solo la sombra; el relleno, el esmerilado y el filo los hacemos nosotros con la misma
    // forma Bézier de las píldoras, así todos los modos se ven como el archipiélago.
    color: "transparent"
    showBorder: false
    effects: false

    readonly property real rr: Math.min(radius, width / 2, height / 2)
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
        // Relleno de la superficie
        ShapePath {
            fillColor: Theme.glass
            strokeWidth: -1
            PathSvg { path: root.svg(root.width, root.height, root.rr, 0) }
        }
        // Esmerilado / brillo superficial
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.feather
            strokeColor: Qt.alpha(Theme.glass, Theme.glass.a * 0.38)
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.svg(root.width, root.height, root.rr, -root.feather / 2) }
        }
        // Filo exterior
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.borderW > 0 ? root.borderW : -1
            strokeColor: root.borderW > 0 ? root.borderColor : "transparent"
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.svg(root.width, root.height, root.rr, root.borderW / 2) }
        }
        // Alerta visual (visualBell)
        ShapePath {
            fillColor: Qt.alpha(Theme.p, Theme.p.a * root.bellLevel)
            strokeWidth: -1
            PathSvg { path: root.svg(root.width, root.height, root.rr, 0) }
        }
    }
}
