// Texto con la tipografía del shell (Inter 12.5 px, como el diseño).
//   Txt { text: "Hola"; size: 13; weight: Font.DemiBold; muted: true; tabular: true }
//   display: tipografía del estilo para textos grandes (por defecto con size ≥ 17)
// Escala tipográfica: el tamaño pedido se ajusta al escalón más cercano de Theme.typeScale (los empates, hacia arriba).
// Antes había ~30 tamaños (10, 10.5, 11, 11.5, 12, 12.5, 13…) que no se distinguían entre sí; ahora la jerarquía
// es clara y ninguno se mueve más de 1 px.
import QtQuick
import Quickshell
import ".."

Text {
    property real size: 12.5
    property bool muted: false
    property bool tabular: false
    property int weight: Font.Normal
    color: muted ? Theme.tv : Theme.t
    font.family: Theme.font
    readonly property real step: Theme.typeStep(size)
    font.pixelSize: Theme.px(step)
    font.weight: weight
    font.letterSpacing: -0.005 * Theme.px(step)
    font.features: tabular ? { "tnum": 1 } : {}
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    // En ventanas que escalan su contenido (la barra a otro tamaño) el texto nativo se vería borroso
    renderType: QsWindow.window?.textScaled ? Text.QtRendering : Text.NativeRendering
}
