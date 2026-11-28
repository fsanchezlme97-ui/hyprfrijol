// Forma «Marco» (barMode = "marco"): la barra va fija a un borde y en los otros tres hay un marco fino (FRAME px) de su
// mismo color; las cuatro esquinas de dentro se redondean hacia dentro, concéntricas con las de las ventanas (radio de
// las ventanas + su hueco con el borde), así la barra y el marco abrazan el contenido. hf-apply aparta las ventanas
// FRAME px más de los bordes con marco (frame_gaps; derivado de barMode, nada se guarda: al cambiar de forma vuelven
// los huecos de antes). Son ventanas pequeñas sin reserva ni ratón (máscara vacía) en la capa «Top»: una ventana a
// pantalla completa las tapa.
//   ScreenCorners { screen: … }   (shell.qml, una por pantalla con barra)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ".."

Scope {
    id: root
    required property var screen
    readonly property int frame: 6          // = FRAME de scripts/hf-apply
    readonly property bool on: Settings.barMode === "marco" && Shell.barModeFor(screen) !== "oculta" && !Shell.focusMode
    readonly property string pos: Settings.barPos
    readonly property int bar: Settings.barReserves ? Settings.barThickness : 0
    readonly property int gap: Math.max(0, Math.round(Number(Settings.get("gapsOut", 4)) || 0))
    readonly property real size: Math.max(10, (Settings.get("rounding", null) ?? Theme.winRadius) + gap)
    function edge(side: string): int { return side === pos ? bar : frame; }   // grosor de cada borde

    // Marco fino de los tres bordes sin barra
    Variants {
        model: ["arriba", "abajo", "izquierda", "derecha"].filter(s => s !== root.pos)
        PanelWindow {
            required property string modelData
            readonly property bool vert: modelData === "izquierda" || modelData === "derecha"
            screen: root.screen
            visible: root.on
            color: Theme.glass
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "hf-marco"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: modelData !== "abajo"; bottom: modelData !== "arriba"; left: modelData !== "derecha"; right: modelData !== "izquierda" }
            // los laterales no pisan la barra ni el marco de arriba/abajo (sin solapes que doblen la transparencia)
            margins { top: vert ? root.edge("arriba") : 0; bottom: vert ? root.edge("abajo") : 0 }
            implicitWidth: vert ? root.frame : 0
            implicitHeight: vert ? 0 : root.frame
            mask: Region {}
        }
    }

    // Esquinas de dentro: un cuadrado menos un cuarto de círculo (arco exacto), dibujado arriba a la izquierda y reflejado
    Variants {
        model: [["arriba", "izquierda"], ["arriba", "derecha"], ["abajo", "izquierda"], ["abajo", "derecha"]]
        PanelWindow {
            id: w
            required property var modelData
            readonly property bool top: modelData[0] === "arriba"
            readonly property bool left: modelData[1] === "izquierda"
            screen: root.screen
            visible: root.on
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "hf-marco"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: w.top; bottom: !w.top; left: w.left; right: !w.left }
            margins {
                top: w.top ? root.edge("arriba") : 0
                bottom: w.top ? 0 : root.edge("abajo")
                left: w.left ? root.edge("izquierda") : 0
                right: w.left ? 0 : root.edge("derecha")
            }
            implicitWidth: root.size
            implicitHeight: root.size
            mask: Region {}
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { xScale: w.left ? 1 : -1; yScale: w.top ? 1 : -1; origin.x: root.size / 2; origin.y: root.size / 2 }
                ShapePath {
                    fillColor: Theme.glass
                    strokeWidth: -1
                    PathSvg { path: "M0,0 L" + root.size + ",0 A" + root.size + "," + root.size + " 0 0 0 0," + root.size + " Z" }
                }
            }
        }
    }
}
