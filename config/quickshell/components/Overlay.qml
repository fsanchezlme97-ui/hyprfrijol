// Base de todos los paneles/emergentes del shell (Spotlight, ajustes rápidos, portapapeles, agenda…).
// - Se muestra cuando Shell.view === view, en la pantalla con foco.
// - Esc o clic fuera → cierra (Shell.close()).  Toma el teclado mientras está abierto.
// - Una sola animación de entrada (fundido, escala y deslizamiento desde su borde a la vez, Theme.durIn y Theme.ease).
// - place: "center" | "screen" (centrado en la pantalla entera, sea cual sea la barra; `lift` lo sube y
//   `centerHeight` fija la altura con la que se centra, para que no salte al cambiar de tamaño) | "top" | "top-right" | "bottom-right" | "bottom-left" | "right" | "left" | "bottom" | "fill"
//   Respeta la barra (abajo/arriba/izquierda) con los mismos márgenes que el diseño.
// - morph: true → se transforma desde/hacia otro panel al saltar entre ellos sin cerrar (components/Morph).
// - passBar: true → la barra sigue recibiendo el ratón con el panel abierto (sus botones abren otro panel).
// - warmup: true → al crearse se dibuja una vez, invisible y sin ratón ni teclado: el primer dibujo de la sesión
//   (sombreadores, texto) es el lento, y así no lo paga la primera apertura.
//
//   Overlay {
//       view: "agenda"; place: "bottom-right"; panelWidth: 380; panelHeight: 520
//       Glass { anchors.fill: parent; kind: "popup"  … contenido … }
//   }
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: win
    required property string view
    property string place: "center"
    property real panelWidth: 600
    property real panelHeight: 400
    property bool dim: false                 // oscurecer el fondo (vista general, energía…)
    property bool closeOnOutside: true
    property bool grabKeyboard: true
    property bool morphs: false
    property bool passBar: false
    property bool warmup: false
    property bool warming: false
    property real margin: Settings.winGap   // como las ventanas (gaps_out)
    property real yOffset: 0                 // ajuste fino para "center"/"top"/"screen"
    property real lift: 0                    // "screen": cuánto por encima del centro (como Spotlight de macOS)
    property real centerHeight: 0            // "screen": altura con la que se centra (0 = la del panel)
    // ready: un ciclo después de crearse, para que al cargarlo al abrir (LazyView) se vea la animación de entrada
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => { win.ready = true; if (win.warmup && !win.shown) win.warming = true; })
    readonly property bool shown: ready && Shell.view === view
    default property alias content: panel.data
    property alias panel: panel
    signal escapePressed()

    screen: Shell.screen
    visible: shown || fade.running || mo.busy || warming
    Connections {
        target: win.warming ? panel.Window.window : null
        function onFrameSwapped() { win.warming = false; }
    }
    Timer { running: win.warming; interval: 500; onTriggered: win.warming = false }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-" + view
    WlrLayershell.keyboardFocus: shown && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // Márgenes respecto a la barra (design: edge = off + barH + 4)
    readonly property string barPos: Settings.barPos
    readonly property real barEdge: Math.max(margin, Settings.barEdge)
    readonly property real mT: barPos === "arriba" ? barEdge : margin
    readonly property real mB: barPos === "abajo" ? barEdge : margin
    readonly property real mL: barPos === "izquierda" ? barEdge : margin
    readonly property real mR: barPos === "derecha" ? barEdge : margin
    // Los paneles «de la barra» (abajo / abajo-derecha) se abren junto a ella si está arriba
    readonly property string at: barPos === "arriba"
        ? ({ "bottom-right": "top-right", "bottom-left": "top-left", "bottom": "top-bar" })[place] ?? place
        : place

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: win.dim && win.shown ? 0.28 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }
    // passBar: todo recibe el ratón menos la franja de la barra de esta pantalla
    mask: warming ? noInput : passBar ? passMask : null
    Region { id: noInput }
    Region { id: passMask; item: whole; Region { item: barStrip; intersection: Intersection.Subtract } }
    Item { id: whole; anchors.fill: parent }
    Item {
        id: barStrip
        readonly property bool vertical: win.barPos === "izquierda" || win.barPos === "derecha"
        readonly property bool on: win.passBar && Shell.barModeFor(win.screen) !== "oculta" && !Settings.barAutoHide && !Shell.barHidden
        readonly property real t: on ? Settings.barOffset + Settings.barThickness + 2 : 0
        x: win.barPos === "derecha" ? win.width - t : 0
        y: win.barPos === "abajo" ? win.height - t : 0
        width: vertical ? t : (on ? win.width : 0)
        height: vertical ? (on ? win.height : 0) : t
    }
    // Al pulsar (no al soltar): se cierra en cuanto tocas fuera
    MouseArea {
        anchors.fill: parent
        enabled: win.closeOnOutside && win.shown
        onPressed: Shell.close()
    }

    Item {
        id: panel
        focus: true
        width: win.place === "fill" ? parent.width - win.mL - win.mR : Math.min(win.panelWidth, parent.width - win.mL - win.mR)
        height: win.place === "fill" || win.place === "right" || win.place === "left"
                ? parent.height - win.mT - win.mB : Math.min(win.panelHeight, parent.height - win.mT - win.mB)
        x: {
            switch (win.at) {
            case "top-right": case "bottom-right": case "right": return parent.width - width - win.mR;
            case "left": case "fill": case "bottom-left": case "top-left": return win.mL;
            case "screen": return Math.max(win.mL, Math.min(parent.width - win.mR - width, (parent.width - width) / 2));
            default: return win.mL + (parent.width - win.mL - win.mR - width) / 2;
            }
        }
        y: {
            switch (win.at) {
            case "center": return win.mT + (parent.height - win.mT - win.mB - height) / 2 + win.yOffset;
            case "screen": return Math.max(win.mT, Math.min(parent.height - win.mB - height,
                                   (parent.height - (win.centerHeight > 0 ? win.centerHeight : height)) / 2 - win.lift + win.yOffset));
            case "top": return win.mT + Math.max(0, (parent.height - win.mT - win.mB) * 0.12) + win.yOffset;
            case "top-right": case "top-left": case "top-bar": case "right": case "left": case "fill": return win.mT;
            default: return parent.height - win.mB - height;     // bottom, bottom-right
            }
        }
        // Clics dentro del panel no cierran
        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onClicked: {} }

        // Una sola animación: «p» va de 0 a 1 y de ella salen a la vez la opacidad, la escala (desde el 94 %) y el
        // deslizamiento desde su borde (barra o lateral). Antes cada una llevaba su duración y su curva (el fundido
        // acababa enseguida, el movimiento seguía y la escala rebotaba) y además, con el ratón, nacía del punto
        // pulsado y con el teclado del borde: se veían dos animaciones distintas. Entrada desacelerando, sin rebote;
        // salida más corta.
        readonly property real dx: win.at === "right" || win.at === "top-right" || win.at === "bottom-right" ? 18
                                 : win.at === "left" || win.at === "top-left" || win.at === "bottom-left" ? -18 : 0
        readonly property real dy: dx !== 0 ? 0 : win.at === "top" || win.at === "top-bar" || win.at === "center" || win.at === "screen" ? -10 : 14
        readonly property point edgeOrg: Qt.point(
            win.at === "bottom-right" || win.at === "top-right" || win.at === "right" ? width
                : win.at === "bottom-left" || win.at === "top-left" || win.at === "left" ? 0 : width / 2,
            win.at === "bottom-right" || win.at === "bottom-left" || win.at === "bottom" ? height
                : win.at === "top-right" || win.at === "top-left" || win.at === "top-bar" ? 0 : height / 2)
        readonly property real sc0: win.place === "fill" ? 0.985 : 0.94
        property real p: 0
        // Antes de animar se dibuja una vez casi transparente (con opacidad 0 Qt no dibuja nada): el primer dibujo
        // del contenido es el lento (texto, iconos, efectos) y, si cae dentro de la entrada, el panel se quedaba
        // quieto unos fotogramas como un bloque gris desenfocado y luego arrancaba: parecían dos animaciones.
        // Con 0,004 no se ve ni lleva desenfoque (ignore_alpha de la capa en look.lua).
        // Empieza en cuanto ese primer dibujo llega a la pantalla (antes esperaba un fotograma más).
        opacity: (waitFrame.running || win.warming ? 0.004 : Math.min(1, p * 1.5)) * mo.op
        function go(open: bool): void {
            if (!open) { waitFrame.stop(); if (p > 0 && win.morphs && mo.leave()) return; p = 0; }
            else if (p > 0) p = 1;                      // reabierto mientras se cerraba: ya está pintado
            else waitFrame.restart();
        }
        function start(): void { waitFrame.stop(); if (win.shown) { if (win.morphs) mo.enter(); p = 1; } }
        Timer { id: waitFrame; interval: 120; onTriggered: panel.start() }   // por si no llega el aviso del fotograma
        Connections {
            target: waitFrame.running ? panel.Window.window : null
            function onFrameSwapped() { panel.start(); }
        }
        Morph {
            id: mo
            target: panel; view: win.view; screenName: win.screen?.name ?? ""; on: win.morphs
            onFinished: panel.p = 0          // sin animar: busy aún es true
            onReleased: if (!win.shown) panel.p = 0
        }
        transform: [
            Scale {
                origin.x: panel.edgeOrg.x; origin.y: panel.edgeOrg.y
                xScale: panel.sc0 + (1 - panel.sc0) * panel.p; yScale: xScale
            },
            Translate { x: panel.dx * (1 - panel.p); y: panel.dy * (1 - panel.p) },
            Scale { xScale: mo.sx; yScale: mo.sy },
            Translate { x: mo.tx; y: mo.ty }
        ]
        Behavior on p {
            enabled: !mo.busy
            NumberAnimation {
                id: fade
                duration: win.shown ? Theme.durIn : Theme.durOut
                easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.ease : Theme.easeOut
            }
        }

        Keys.onEscapePressed: { win.escapePressed(); Shell.close(); }
    }
    onShownChanged: { if (shown) warming = false; panel.go(shown); if (shown) panel.forceActiveFocus(); }
    OpenProbe { name: win.view; shown: win.shown }
}
