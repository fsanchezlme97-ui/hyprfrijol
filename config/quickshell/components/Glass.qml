// Superficie con los tokens del estilo Math. El desenfoque lo pone Hyprland (layer_rule blur sobre el espacio
// de nombres "hf-…" de la ventana); aquí se dibuja todo lo demás. Según el material (S.material):
//   sólido   Material 3: superficie tonal sólida, sin borde; elevación con sombra en dos capas (una cercana y nítida,
//            otra amplia y difusa) y un filo de luz de 1 px arriba en los paneles y popups
//   cristal  (transparencia) la estructura de Material hecha de cristal: muy transparente y muy desenfocado, con un
//            esmerilado más claro arriba, un resplandor suave del acento que se desliza despacio y un filo de luz muy
//            tenue, más visible arriba y que se desvanece hacia abajo, sin contorno oscuro, como las ventanas de macOS
//   tonal    (transparencia con «Reducir transparencia») superficie tonal sólida con borde fino
//   Glass { kind: "panel" }   kinds: "bar" (S.bg), "panel" (S.bgPanel), "popup" (S.bgPopup), "fill" (S.bg2)
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

Item {
    id: root
    property string kind: "panel"
    property real radius: kind === "bar" ? Theme.barRadius : kind === "fill" ? Theme.r(8) : Theme.panelRadius
    property bool shadow: kind !== "fill" && kind !== "bar"
    property bool big: kind === "popup"
    property color color: kind === "bar" ? Theme.glass : kind === "popup" ? Theme.glassPopup
                        : kind === "fill" ? Theme.fill2 : Theme.glassPanel
    property bool showBorder: kind !== "fill"
    // Detalles del cristal (esmerilado, resplandor, bordes). Se pueden apagar en superficies pequeñas.
    property bool effects: kind !== "fill"
    default property alias content: inner.data

    readonly property real rr: Math.min(radius, width / 2, height / 2)
    readonly property bool glass: Theme.glassy && root.effects && root.width > 2 && root.height > 2

    // Sombra cercana y nítida (solo sólido: en cristal se transparentaría como una franja)
    RectangularShadow {
        visible: root.shadow && !Theme.glassy && Theme.shadow.a > 0
        anchors.fill: bgRect
        radius: root.rr
        offset.y: 1
        blur: 3
        spread: 0
        color: Qt.alpha(Theme.shadow, Math.min(1, Theme.shadow.a * 0.8))
    }
    // Sombra amplia y difusa
    RectangularShadow {
        visible: root.shadow && (root.big ? Theme.shadowBig.a : Theme.shadow.a) > 0
        anchors.fill: bgRect
        radius: root.rr
        // Radio y caída según el estilo y Ajustes › Apariencia › Sombras (hf-apply: S.shBlur/shY…)
        offset.y: root.big ? Theme.shBigY : Theme.shY
        blur: root.big ? Theme.shBigBlur : Theme.shBlur
        spread: Theme.shSpread
        color: root.big ? Theme.shadowBig : Theme.shadow
    }
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.rr
        color: root.color
        // Cristal: el borde lo dibujan los dos trazos de abajo
        border.width: root.showBorder && !root.glass ? Theme.borderWidth : 0
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }

    // Resplandor del acento que se desliza despacio por los paneles abiertos (el cristal se siente vivo).
    // Nunca en la barra (siempre visible); se para con «Reducir movimiento» o sin animaciones.
    Shape {
        id: flow
        visible: root.glass && root.kind !== "bar" && Theme.tint.a > 0 && root.width > 40 && root.height > 40
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        property real ph: 0.25
        NumberAnimation on ph { from: 0; to: 1; duration: 22000; loops: Animation.Infinite; running: flow.visible && root.visible && !Theme.still }
        readonly property real cx: width * (0.2 + 0.6 * (0.5 - 0.5 * Math.cos(ph * 2 * Math.PI)))
        readonly property real cy: height * (0.25 + 0.4 * (0.5 - 0.5 * Math.sin(ph * 2 * Math.PI)))
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: flow.cx; centerY: flow.cy
                centerRadius: Math.max(70, Math.min(Math.min(flow.width, flow.height) * 0.7, 300))
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Theme.tint }
                GradientStop { position: 0.5; color: Qt.alpha(Theme.tint, Theme.tint.a * 0.35) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.tint, 0) }
            }
            PathRectangle { x: 0; y: 0; width: flow.width; height: flow.height; radius: root.rr }
        }
    }
    Shape {
        id: fx
        visible: root.glass
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Esmerilado: el cristal algo más claro arriba, que se apaga hacia la mitad
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: fx.height * 0.65
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.sheen, 0) }
            }
            PathRectangle { x: 0; y: 0; width: fx.width; height: fx.height; radius: root.rr }
        }
        // Filo exterior: un trazo oscuro casi invisible que recorta el cristal sobre fondos claros
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.showBorder && Theme.edge.a > 0 ? 1 : 0
            strokeColor: Theme.edge
            PathRectangle { x: 0.5; y: 0.5; width: fx.width - 1; height: fx.height - 1; radius: Math.max(0, root.rr - 0.5) }
        }
        // Filo interior de luz: brillante arriba, tenue en los lados y casi nada abajo (el grosor del cristal)
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.showBorder ? 1 : 0
            strokeGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: fx.height
                GradientStop { position: 0.0; color: Theme.rimTop }
                GradientStop { position: Math.min(0.45, 40 / Math.max(1, fx.height)); color: Qt.alpha(Theme.border, Theme.border.a * 0.5) }
                GradientStop { position: 1.0; color: Theme.rimBottom }
            }
            // En el mismo filo del cristal (sin hueco entre el borde y la luz, que se leía como una línea)
            PathRectangle { x: 0.5; y: 0.5; width: Math.max(0, fx.width - 1); height: Math.max(0, fx.height - 1); radius: Math.max(0, root.rr - 0.5) }
        }
    }
    // Sólido: filo de luz arriba que se apaga en las esquinas superiores (no en la barra ni en los rellenos)
    Shape {
        visible: !root.glass && root.kind !== "bar" && root.kind !== "fill" && Theme.rimTop.a > 0 && root.width > 24 && root.height > 24
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1
            strokeGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: Math.max(1, root.rr + 6)
                GradientStop { position: 0.0; color: Theme.rimTop }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.rimTop, 0) }
            }
            PathRectangle { x: 0.5; y: 0.5; width: Math.max(0, root.width - 1); height: Math.max(0, root.height - 1); radius: Math.max(0, root.rr - 0.5) }
        }
    }
    Item { id: inner; anchors.fill: parent }
}
