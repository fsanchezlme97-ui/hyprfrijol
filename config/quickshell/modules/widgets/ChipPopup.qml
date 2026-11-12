// Ventana flotante de un widget de la barra (clima, sistema, impresora): se abre pegada a su chip, como la
// de la música, y crece desde él. Esc o clic fuera la cierran (Shell.close()).
//   ChipPopup { view: "w-clima"; panelWidth: 380; panelHeight: body.implicitHeight; … contenido … }
// El chip la abre con BarAnchor.open(chip, "w-clima"): Shell.arg = { chip: true, c, screen } con c = centro
// del chip a lo largo de la barra (px lógicos de la pantalla). Sin arg (atajo, IPC) se centra en la barra.
// La barra sigue recibiendo el ratón con el panel abierto (barStrip): un clic en otro chip salta a su panel y el
// panel se transforma en el nuevo (components/Morph); un clic en el fondo de la barra lo cierra (bar/Bar.qml).
import QtQuick
import QtQuick.Window
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
        panel.go(shown);
    }

    screen: Quickshell.screens.find(s => s.name === a?.screen) ?? Shell.screen
    visible: shown || fade.running || morph.busy
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

    // Todo recibe el ratón menos la franja de la barra de esta pantalla (sus chips siguen funcionando)
    mask: Region { item: whole; Region { item: barStrip; intersection: Intersection.Subtract } }
    Item { id: whole; anchors.fill: parent }
    Item {
        id: barStrip
        readonly property bool on: Shell.barModeFor(win.screen) !== "oculta" && !Settings.barAutoHide && !Shell.barHidden
        readonly property real t: on ? Settings.barOffset + Settings.barThickness + 2 : 0
        x: win.pos === "derecha" ? win.width - t : 0
        y: win.pos === "abajo" ? win.height - t : 0
        width: win.vertical ? t : (on ? win.width : 0)
        height: win.vertical ? (on ? win.height : 0) : t
    }
    MouseArea { anchors.fill: parent; enabled: win.shown; onPressed: Shell.close() }

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
        // Una sola animación como components/Overlay: «p» (0 → 1) mueve a la vez opacidad, escala y desplazamiento,
        // y antes se dibuja una vez casi transparente para que el primer dibujo (el lento) no caiga en la entrada
        property real p: 0
        opacity: (waitFrame.running ? 0.004 : Math.min(1, p * 1.5)) * morph.op
        function go(open: bool): void {
            if (!open) { waitFrame.stop(); if (p > 0 && morph.leave()) return; p = 0; }
            else if (p > 0) p = 1;
            else { waitFrame.restart(); }
        }
        function start(): void { waitFrame.stop(); if (win.shown) { morph.enter(); p = 1; } }
        Timer { id: waitFrame; interval: 120; onTriggered: panel.start() }
        // El primer dibujo (el lento) ya está en pantalla: empieza la entrada
        Connections {
            target: waitFrame.running ? panel.Window.window : null
            function onFrameSwapped() { panel.start(); }
        }
        Morph {
            id: morph
            target: panel; view: win.view; screenName: win.screen?.name ?? ""
            onFinished: panel.p = 0          // sin animar: busy aún es true
            onReleased: if (!win.shown) panel.p = 0
        }
        transform: [
            Scale {
                origin.x: panel.ox; origin.y: panel.oy
                xScale: 0.92 + 0.08 * panel.p; yScale: 0.86 + 0.14 * panel.p
            },
            Translate { x: panel.dx * (1 - panel.p); y: panel.dy * (1 - panel.p) },
            Scale { xScale: morph.sx; yScale: morph.sy },
            Translate { x: morph.tx; y: morph.ty }
        ]
        Behavior on p {
            enabled: !morph.busy
            NumberAnimation {
                id: fade
                duration: win.shown ? Theme.durIn : Theme.durOut
                easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.ease : Theme.easeOut
            }
        }
    }
    OpenProbe { name: win.view; shown: win.shown }
}
