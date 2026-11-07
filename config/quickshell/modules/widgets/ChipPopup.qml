// Ventana flotante de un widget de la barra (clima, sistema, impresora): se abre pegada a su chip, como la
// de la música, y crece desde él. Esc o clic fuera la cierran (Shell.close()).
//   ChipPopup { view: "w-clima"; panelWidth: 380; panelHeight: body.implicitHeight; … contenido … }
// El chip la abre con BarAnchor.open(chip, "w-clima"): Shell.arg = { chip: true, c, screen } con c = centro
// del chip a lo largo de la barra (px lógicos de la pantalla). Sin arg (atajo, IPC) se centra en la barra.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"

PanelWindow {
    id: win
    required property string view
    property real panelWidth: 360
    property real panelHeight: 300
    property real margin: 6
    property bool ready: false              // ver components/Overlay (carga diferida)
    Component.onCompleted: Qt.callLater(() => win.ready = true)
    readonly property bool shown: ready && Shell.view === view
    default property alias content: panel.data
    property alias panel: panel

    // (por IPC el arg llega como texto: openWith w-clima chip:1500  ·  '{"chip":true,"c":1500}')
    function chipArg(v): var {
        if (typeof v === "string" && /^chip:\d/.test(v)) v = { chip: true, c: Number(v.slice(5)) };      // openWith w-clima chip:1500
        if (typeof v === "string" && v.trim().startsWith("{")) { try { v = JSON.parse(v); } catch (e) { v = null; } }
        return v && typeof v === "object" && v.chip ? v : null;
    }
    readonly property var a: shown ? chipArg(Shell.arg) : lastArg
    property var lastArg: null
    onShownChanged: {
        if (shown) { lastArg = chipArg(Shell.arg); panel.forceActiveFocus(); }
    }

    screen: Quickshell.screens.find(s => s.name === a?.screen) ?? Shell.screen
    visible: shown || fade.running
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-" + view
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property string pos: Settings.barPos
    readonly property bool vertical: pos === "izquierda" || pos === "derecha"
    readonly property real edge: Math.max(margin, Settings.barEdge + 2)
    // Centro del chip a lo largo de la barra (o el centro de la pantalla si no hay chip)
    readonly property real c: a && isFinite(a.c) ? a.c : (vertical ? height / 2 : width / 2)

    MouseArea { anchors.fill: parent; onClicked: Shell.close() }

    Item {
        id: panel
        focus: true
        width: Math.min(win.panelWidth, win.width - 2 * win.margin - (win.vertical ? win.edge : 0))
        height: Math.min(win.panelHeight, win.height - 2 * win.margin - (win.vertical ? 0 : win.edge))
        x: win.pos === "izquierda" ? win.edge : win.pos === "derecha" ? win.width - win.edge - width
         : Math.max(win.margin, Math.min(win.width - win.margin - width, win.c - width / 2))
        y: win.pos === "arriba" ? win.edge : win.pos === "abajo" ? win.height - win.edge - height
         : Math.max(win.margin, Math.min(win.height - win.margin - height, win.c - height / 2))

        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onClicked: {} }
        Keys.onEscapePressed: Shell.close()

        // Crece desde el chip: el origen de la escala es el punto del borde más cercano a él
        readonly property real ox: win.vertical ? (win.pos === "izquierda" ? 0 : width) : Math.max(0, Math.min(width, win.c - x))
        readonly property real oy: win.vertical ? Math.max(0, Math.min(height, win.c - y)) : (win.pos === "arriba" ? 0 : height)
        readonly property real dx: win.pos === "izquierda" ? -12 : win.pos === "derecha" ? 12 : 0
        readonly property real dy: win.pos === "arriba" ? -12 : win.pos === "abajo" ? 12 : 0
        opacity: win.shown ? 1 : 0
        transform: [
            Scale {
                origin.x: panel.ox; origin.y: panel.oy
                xScale: win.shown ? 1 : 0.92; yScale: win.shown ? 1 : 0.86
                Behavior on xScale { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
                Behavior on yScale { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
            },
            Translate {
                x: win.shown ? 0 : panel.dx; y: win.shown ? 0 : panel.dy
                Behavior on x { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
                Behavior on y { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
            }
        ]
        Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn * 0.6 : Theme.durOut; easing.type: Easing.OutCubic } }
    }
    OpenProbe { name: win.view; shown: win.shown }
}
