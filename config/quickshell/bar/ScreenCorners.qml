// Esquinas de la forma «Marco» (barMode = "marco"): la barra va fija al borde y las cuatro esquinas de la zona de las
// ventanas se redondean hacia dentro con el color de la barra, así la barra «abraza» el contenido como un marco. Son
// cuatro ventanas pequeñas sin reserva ni ratón (la máscara vacía deja pasar los clics) en la capa «Top»: una ventana a
// pantalla completa las tapa. Por el lado de la barra se apartan su grosor (si la barra reserva sitio).
//   ScreenCorners { screen: … }   (shell.qml, una por pantalla con barra)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ".."

Scope {
    id: root
    required property var screen
    readonly property bool on: Settings.barMode === "marco" && Shell.barModeFor(screen) !== "oculta"
    readonly property real size: Math.max(8, Settings.get("rounding", null) ?? Theme.winRadius) + 6
    readonly property string pos: Settings.barPos
    readonly property int bar: Settings.barReserves ? Settings.barThickness : 0

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
            WlrLayershell.namespace: "hf-esquinas"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: w.top; bottom: !w.top; left: w.left; right: !w.left }
            margins {
                top: root.pos === "arriba" ? root.bar : 0
                bottom: root.pos === "abajo" ? root.bar : 0
                left: root.pos === "izquierda" ? root.bar : 0
                right: root.pos === "derecha" ? root.bar : 0
            }
            implicitWidth: root.size
            implicitHeight: root.size
            mask: Region {}
            // Esquina rellena menos un cuarto de círculo (dibujada arriba a la izquierda y girada con un espejo)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { xScale: w.left ? 1 : -1; yScale: w.top ? 1 : -1; origin.x: root.size / 2; origin.y: root.size / 2 }
                ShapePath {
                    readonly property real s: root.size
                    fillColor: Theme.glass
                    strokeWidth: -1
                    PathSvg { path: "M0,0 L" + root.size + ",0 C" + (root.size * 0.448) + ",0 0," + (root.size * 0.448) + " 0," + root.size + " Z" }
                }
            }
        }
    }
}
