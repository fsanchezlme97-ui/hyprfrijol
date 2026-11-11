// Base de todos los paneles/emergentes del shell (Spotlight, ajustes rápidos, portapapeles, agenda…).
// - Se muestra cuando Shell.view === view, en la pantalla con foco.
// - Esc o clic fuera → cierra (Shell.close()).  Toma el teclado mientras está abierto.
// - Animación de entrada "softUp" del diseño (.38s, cubic-bezier(.2,.8,.2,1)); abierto con el ratón desde la barra,
//   nace del punto pulsado (Shell.from).
// - place: "center" | "screen" (centrado en la pantalla entera, sea cual sea la barra; `lift` lo sube y
//   `centerHeight` fija la altura con la que se centra, para que no salte al cambiar de tamaño) | "top" | "top-right" | "bottom-right" | "bottom-left" | "right" | "left" | "bottom" | "fill"
//   Respeta la barra (abajo/arriba/izquierda) con los mismos márgenes que el diseño.
//
//   Overlay {
//       view: "agenda"; place: "bottom-right"; panelWidth: 380; panelHeight: 520
//       Glass { anchors.fill: parent; kind: "popup"  … contenido … }
//   }
import QtQuick
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
    property real margin: Settings.winGap   // como las ventanas (gaps_out)
    property real yOffset: 0                 // ajuste fino para "center"/"top"/"screen"
    property real lift: 0                    // "screen": cuánto por encima del centro (como Spotlight de macOS)
    property real centerHeight: 0            // "screen": altura con la que se centra (0 = la del panel)
    // ready: un ciclo después de crearse, para que al cargarlo al abrir (LazyView) se vea la animación de entrada
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => win.ready = true)
    readonly property bool shown: ready && Shell.view === view
    default property alias content: panel.data
    property alias panel: panel
    signal escapePressed()

    screen: Shell.screen
    visible: shown || fade.running
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
    MouseArea {
        anchors.fill: parent
        enabled: win.closeOnOutside
        onClicked: Shell.close()
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

        // Entrada: aparece, crece desde el 94 % y se desliza desde su borde (barra o lateral) con un leve rebote;
        // salida: más corta y sin rebote
        readonly property real dx: win.at === "right" || win.at === "top-right" || win.at === "bottom-right" ? 18
                                 : win.at === "left" || win.at === "top-left" || win.at === "bottom-left" ? -18 : 0
        readonly property real dy: dx !== 0 ? 0 : win.at === "top" || win.at === "top-bar" || win.at === "center" || win.at === "screen" ? -10 : 14
        // Abierto desde la barra con el ratón (Shell.from justo antes de abrir, en esta pantalla): nace del punto
        // pulsado, más pequeño y sin deslizarse; se cierra hacia el mismo punto. Con el teclado, desde su borde.
        property bool fromPress: false
        property point org: Qt.point(0, 0)
        readonly property point edgeOrg: Qt.point(
            win.at === "bottom-right" || win.at === "top-right" || win.at === "right" ? width
                : win.at === "bottom-left" || win.at === "top-left" || win.at === "left" ? 0 : width / 2,
            win.at === "bottom-right" || win.at === "bottom-left" || win.at === "bottom" ? height
                : win.at === "top-right" || win.at === "top-left" || win.at === "top-bar" ? 0 : height / 2)
        opacity: win.shown ? 1 : 0
        // Escala y desplazamiento: se fija el punto de partida y luego se anima (go()), así la apertura sabe ya de
        // dónde sale; con bindings, el valor de partida sería el del cierre anterior
        property real sc: place === "fill" ? 0.985 : 0.94
        readonly property string place: win.place
        property real tx: dx
        property real ty: dy
        property bool anim: true
        function go(open: bool): void {
            if (open) {
                fromPress = !Theme.still && Shell.originScreen === win.screen && Math.abs(Shell.openedAt - Shell.originAt) < 500;
                if (fromPress) org = Qt.point(Shell.origin.x - x, Shell.origin.y - y);
                anim = false;
                sc = fromPress ? 0.82 : place === "fill" ? 0.985 : 0.94; tx = fromPress ? 0 : dx; ty = fromPress ? 0 : dy;
                anim = true;
                sc = 1; tx = 0; ty = 0;
            } else {
                sc = fromPress ? 0.82 : place === "fill" ? 0.985 : 0.94; tx = fromPress ? 0 : dx; ty = fromPress ? 0 : dy;
            }
        }
        transform: [
            Scale {
                origin.x: panel.fromPress ? panel.org.x : panel.edgeOrg.x
                origin.y: panel.fromPress ? panel.org.y : panel.edgeOrg.y
                xScale: panel.sc; yScale: panel.sc
            },
            Translate { x: panel.tx; y: panel.ty }
        ]
        Behavior on sc { enabled: panel.anim; NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
        Behavior on tx { enabled: panel.anim; NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
        Behavior on ty { enabled: panel.anim; NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
        Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn * 0.6 : Theme.durOut; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: { win.escapePressed(); Shell.close(); }
    }
    onShownChanged: { panel.go(shown); if (shown) panel.forceActiveFocus(); }
    OpenProbe { name: win.view; shown: win.shown }
}
