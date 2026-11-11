// Texto con la tipografía del shell (Inter 12.5 px, como el diseño).
//   Txt { text: "Hola"; size: 13; weight: Font.DemiBold; muted: true; tabular: true }
//   display: tipografía del estilo para textos grandes (por defecto con size ≥ 17)
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
    font.pixelSize: Theme.px(size)
    font.weight: weight
    font.letterSpacing: -0.005 * Theme.px(size)
    font.features: tabular ? { "tnum": 1 } : {}
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    // En ventanas que escalan su contenido (la barra a otro tamaño) el texto nativo se vería borroso
    renderType: QsWindow.window?.textScaled ? Text.QtRendering : Text.NativeRendering
}
