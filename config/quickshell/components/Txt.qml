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
    // Los textos grandes (≥ 17 px: relojes, cifras, títulos) usan la tipografía del estilo (Theme.displayFont):
    // de puntos en Chroma. `display: false` lo evita.
    property bool display: size >= 17
    readonly property bool useDisplay: display && Theme.displayFont !== Theme.font
    font.family: useDisplay ? Theme.displayFont : Theme.font
    font.pixelSize: Theme.px(size)
    font.weight: useDisplay ? Theme.displayWeight : weight
    font.letterSpacing: useDisplay && Theme.chroma ? 0.04 * Theme.px(size) : -0.005 * Theme.px(size)
    font.features: tabular ? { "tnum": 1 } : {}
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    // En ventanas que escalan su contenido (la barra a otro tamaño) el texto nativo se vería borroso
    renderType: QsWindow.window?.textScaled ? Text.QtRendering : Text.NativeRendering
}
