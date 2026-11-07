// Superficie con los tokens del estilo activo. El desenfoque lo pone Hyprland (layer_rule blur sobre el espacio
// de nombres "hf-…" de la ventana); aquí se dibuja todo lo demás:
//   Aurora  vidrio esmerilado con una aurora de color: resplandores radiales del primario (arriba-izquierda),
//           del terciario (abajo-derecha) y un velo de la mezcla en medio, borde especular teñido y brillo
//   Flat    Material 3: superficie tonal sólida, sin borde, elevación con sombra corta
//   Mica    Windows 11: material translúcido (Hyprland desenfoca mucho detrás) con trazo de elevación de 1 px
//           (más claro arriba que abajo) y sombra suave
//   Suave   superficie sólida con tinte pastel, sin borde, un degradado vertical muy leve y sombra difusa
//   Tonal   (interno: Aurora con «Reducir transparencia») superficie tonal sólida con borde fino
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
    // Detalles del vidrio (brillo, borde especular, tinte). Se pueden apagar en superficies pequeñas.
    property bool effects: kind !== "fill"
    default property alias content: inner.data

    readonly property real rr: Math.min(radius, width / 2, height / 2)

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
        // Aurora y Mica: el borde lo dibuja el trazo con degradado de abajo
        border.width: root.showBorder && !(root.effects && (Theme.glassy || Theme.mica)) ? Theme.borderWidth : 0
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.dur } }
    }

    Shape {
        id: fx
        visible: root.effects && (Theme.glassy || Theme.mica || Theme.suave) && root.width > 2 && root.height > 2
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Tamaño de los resplandores: proporcional, pero sin pasar de un halo razonable en paneles grandes
        readonly property real glowR: Math.max(60, Math.min(Math.max(width, height) * 0.75, 420))

        // Aurora: resplandor del primario arriba a la izquierda…
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: fx.width * 0.08; centerY: 0; centerRadius: fx.glowR
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Theme.tint }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.tint, Theme.tint.a * 0.35) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.tint, 0) }
            }
            PathRectangle { x: 0; y: 0; width: fx.width; height: fx.height; radius: root.rr }
        }
        // …del terciario abajo a la derecha…
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: fx.width * 0.95; centerY: fx.height; centerRadius: fx.glowR * 0.9
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Theme.tint2 }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.tint2, Theme.tint2.a * 0.3) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.tint2, 0) }
            }
            PathRectangle { x: 0; y: 0; width: fx.width; height: fx.height; radius: root.rr }
        }
        // …y una banda de la mezcla cruzando en diagonal (la «cortina» de la aurora)
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: fx.height; x2: fx.width; y2: 0
                GradientStop { position: 0.25; color: Qt.alpha(Theme.tint3, 0) }
                GradientStop { position: 0.5; color: Theme.tint3 }
                GradientStop { position: 0.75; color: Qt.alpha(Theme.tint3, 0) }
            }
            PathRectangle { x: 0; y: 0; width: fx.width; height: fx.height; radius: root.rr }
        }
        // Brillo interior: luz que entra por arriba y se apaga hacia el centro (en Suave, todo el alto: arcilla)
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: Theme.suave ? fx.height : Math.min(fx.height, 90)
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.sheen, 0) }
            }
            PathRectangle { x: 0; y: 0; width: fx.width; height: fx.height; radius: root.rr }
        }
        // Borde: especular teñido (Aurora) o trazo de elevación neutro (Mica)
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.showBorder && !Theme.suave ? 1 : 0
            strokeGradient: LinearGradient {
                x1: 0; y1: 0; x2: Theme.mica ? 0 : fx.width * 0.55; y2: Theme.mica ? Math.min(fx.height, 28) : fx.height
                GradientStop { position: 0.0; color: Theme.rimTop }
                GradientStop { position: 0.35; color: Theme.border }
                GradientStop { position: 1.0; color: Theme.rimBottom }
            }
            PathRectangle { x: 0.5; y: 0.5; width: fx.width - 1; height: fx.height - 1; radius: Math.max(0, root.rr - 0.5) }
        }
    }
    // Línea de luz justo bajo el borde superior (el «labio» del vidrio)
    Rectangle {
        visible: root.effects && Theme.glassy && root.showBorder && root.height > 20
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.rr * 0.9; rightMargin: root.rr * 0.9; topMargin: 1 }
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.highlight, 0) }
            GradientStop { position: 0.3; color: Theme.highlight }
            GradientStop { position: 0.7; color: Qt.alpha(Theme.highlight, Theme.highlight.a * 0.4) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.highlight, 0) }
        }
    }
    Item { id: inner; anchors.fill: parent }
}
