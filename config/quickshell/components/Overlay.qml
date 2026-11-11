// Base de todos los paneles/emergentes del shell (Spotlight, ajustes rápidos, portapapeles, agenda…).
// - Se muestra cuando Shell.view === view, en la pantalla con foco.
// - Esc o clic fuera → cierra (Shell.close()).  Toma el teclado mientras está abierto.
// - Animación de entrada "softUp" del diseño (.38s, cubic-bezier(.2,.8,.2,1)).
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
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : (win.place === "fill" ? 0.985 : 0.94)
        transformOrigin: win.at === "bottom-right" ? Item.BottomRight : win.at === "top-right" ? Item.TopRight
                       : win.at === "bottom-left" ? Item.BottomLeft : win.at === "top-left" ? Item.TopLeft
                       : win.at === "bottom" ? Item.Bottom : win.at === "top-bar" ? Item.Top : win.at === "right" ? Item.Right
                       : win.at === "left" ? Item.Left : Item.Center
        transform: Translate {
            x: win.shown ? 0 : panel.dx
            y: win.shown ? 0 : panel.dy
            Behavior on x { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
            Behavior on y { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
        }
        Behavior on scale { NumberAnimation { duration: win.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.easeIn : Theme.easeOut } }
        Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn * 0.6 : Theme.durOut; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: { win.escapePressed(); Shell.close(); }
    }
    onShownChanged: if (shown) panel.forceActiveFocus()
    OpenProbe { name: win.view; shown: win.shown }
}
