// Esquinas redondeadas de la pantalla (ajuste screenCorners, por defecto no; Ajustes › Apariencia › Redondeo):
// un trozo negro con la esquina en cuarto de círculo en cada esquina de cada monitor, por encima de todo y sin
// recibir el ratón ni reservar sitio. Se quitan en un monitor con una ventana a pantalla completa (juegos, vídeo).
// Radio: el doble del de las ventanas (rounding, o el del estilo), mínimo 12 px. Salen en las capturas.
// Apagado no crea ninguna ventana.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"

Scope {
    id: root
    readonly property bool on: Settings.get("screenCorners", false) === true
    readonly property int radius: Math.max(12, (Settings.get("rounding", null) ?? Theme.winRadius) * 2)

    Variants {
        model: root.on ? Quickshell.screens : []
        Scope {
            id: scr
            required property var modelData
            // Ventana a pantalla completa (fullscreen 2; 1 es maximizada) en el espacio activo de este monitor
            readonly property bool full: {
                HyprClients.refreshes;
                const m = HyprClients.monitors.find(m => m.name === scr.modelData.name);
                const ws = m?.activeWorkspace?.id ?? 0;
                return HyprClients.clients.some(c => c.workspace?.id === ws && (c.fullscreen ?? 0) === 2);
            }
            Variants {
                model: scr.full ? [] : ["tl", "tr", "br", "bl"]
                PanelWindow {
                    id: corner
                    required property string modelData
                    screen: scr.modelData
                    anchors {
                        top: corner.modelData[0] === "t"; bottom: corner.modelData[0] === "b"
                        left: corner.modelData[1] === "l"; right: corner.modelData[1] === "r"
                    }
                    implicitWidth: root.radius
                    implicitHeight: root.radius
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "hf-corners"
                    mask: Region {}        // el ratón pasa a lo de debajo (el cerrar de una ventana maximizada)

                    // Dibujada la de arriba a la izquierda; las otras, giradas
                    Shape {
                        anchors.fill: parent
                        rotation: ({ tl: 0, tr: 90, br: 180, bl: 270 })[corner.modelData]
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            fillColor: "black"
                            strokeWidth: -1
                            startX: 0; startY: 0
                            PathLine { x: root.radius; y: 0 }
                            PathArc { x: 0; y: root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                            PathLine { x: 0; y: 0 }
                        }
                    }
                }
            }
        }
    }
}
