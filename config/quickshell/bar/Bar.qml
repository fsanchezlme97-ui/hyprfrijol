// Barra del diseño. Posición: abajo / arriba / izquierda / derecha · forma: fija / flotante / isla central
// (Ajustes › Barra). Medidas en Settings: barThickness (grosor), barOffset (margen si flota) y barScale
// (el contenido se diseña a 32 px y se escala en proporción al tamaño elegido).
// Ajustes que lee aquí:
//   barBehavior          "siempre" · "auto" (se esconde y vuelve al llevar el cursor al borde; también en modo
//                        sin distracciones si «Ocultar la barra» está activo; antes barAutoHide) · "inteligente"
//                        (se aparta cuando una ventana flotante la tapa o hay una maximizada / a pantalla
//                        completa; en los espacios en mosaico reserva su sitio salvo con una maximizada, en los
//                        flotantes no reserva nada; vuelve con el cursor en el borde — WinMode.covered)
//   barAllScreens        false → solo en la pantalla principal
//   barTransparentEmpty  sin fondo cuando el espacio activo de esa pantalla no tiene ventanas
//   visualBell           parpadea al llegar un aviso (alerta visual en vez de sonido)
// Isla central: la barra flota y mide lo que su contenido, centrada; el resto de la franja deja pasar el ratón.
// Archipiélago: cada grupo de módulos en su propia píldora flotante (BarPill), con el escritorio visible entre
// ellas; solo las píldoras reciben el ratón (máscara con content.item.pills).
// Super + J (Shell.barHidden) la deja escondida: vuelve al llevar el cursor al borde.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"

PanelWindow {
    id: bar
    readonly property string pos: Settings.barPos
    readonly property bool floating: Settings.barFloating
    readonly property bool island: Settings.barIsland
    readonly property bool archi: Settings.barArchipelago
    readonly property bool vertical: Settings.barVertical
    readonly property int off: Settings.barOffset
    readonly property int thickness: Settings.barThickness
    readonly property real k: Settings.barScale
    // Barra escondida con Super + J (Shell.barHidden) = se esconde sola: nunca desaparece sin forma de volver.
    // En las pantallas secundarias (solo espacios y título) también se esconde sola.
    readonly property bool secondary: screen !== Shell.primaryScreen
    readonly property bool autoHide: Settings.barAutoHide || Shell.barHidden || secondary
    // Ocultación inteligente: se esconde si una ventana tapa su franja (WinMode.covered)
    readonly property bool smart: Settings.barSmartHide && !autoHide
    readonly property bool edgeMode: autoHide || smart
    readonly property int wsId: Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? -1
    readonly property bool smartCovered: {
        if (!smart) return false;
        const m = HyprClients.monitorByName(screen?.name ?? "");
        if (!m) return false;
        const L = HyprClients.logical(m), t = thickness + off, len = body.length;
        const r = vertical ? { x: pos === "izquierda" ? L.x : L.x + L.w - t, y: L.y + (L.h - len) / 2, w: t, h: len }
                           : { x: L.x + (L.w - len) / 2, y: pos === "arriba" ? L.y : L.y + L.h - t, w: len, h: t };
        return WinMode.covered(m.name, r);
    }
    // En mosaico reserva su sitio (salvo con una ventana maximizada, que así ocupa toda la pantalla)
    readonly property bool smartReserve: { WinMode.overrides; WinMode.mode; return smart && !WinMode.isFloat(wsId) && !WinMode.hasFullscreen(screen?.name ?? ""); }
    readonly property bool onThisScreen: Settings.get("barAllScreens", true) || screen === Shell.primaryScreen
    // Mostrada: siempre, salvo que se oculte sola y el cursor no esté encima
    readonly property bool revealed: (!autoHide && !smartCovered) || hover.hovered || hideDelay.running || flash.running
    // Para que los textos escalados se vean nítidos (Txt usa QtRendering si la ventana lo pide)
    readonly property bool textScaled: Math.abs(k - 1) > 0.01
    // Píldoras (isla / archipiélago): radio en px del contenido (que va escalado ×k) y destello de visualBell
    // Esquinas de las ventanas (Ajustes › Apariencia › Esquinas: decoration:rounding, px físicos) + 0/2/4 px
    // (Ajustes › Barra › Esquinas: barRoundExtra, por defecto +4: más suaves sin salirse del estilo)
    readonly property real pillRadius: Math.min((Settings.get("rounding", null) ?? Theme.winRadius)
        + Math.max(0, Math.min(4, Number(Settings.get("barRoundExtra", 4)) || 0)), thickness / 2) / k
    // Filo de las cápsulas: un recorte oscuro casi invisible (perfila la curva sobre fondos claros sin dibujar una
    // línea). El borde gris de las ventanas sin foco, más claro que el relleno, se leía como un contorno basto.
    // Sin borde de ventanas (Ajustes › Apariencia › Borde: ninguno), tampoco aquí.
    readonly property string borderMode: Settings.get("activeBorder", "sutil")
    // En vidrio (Aurora/SkySoul) sin filo: el borde lo da el propio cristal, suave; un trazo se veía marcado
    readonly property real pillBorderW: (borderMode === "ninguno" || Theme.glassy ? 0 : 1) / k
    readonly property color pillBorder: Theme.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.20)
    readonly property real bellLevel: bell.opacity
    // Rectángulo de la píldora i del archipiélago en px de la ventana (vacío si no toca)
    function pillRect(i: int): var {
        const p = content.item?.pills?.[i];
        if (!archi || !revealed || !p || !p.visible) return { x: 0, y: 0, w: 0, h: 0 };
        return { x: Math.floor(body.x + p.x * k), y: Math.floor(body.y + p.y * k), w: Math.ceil(p.width * k) + 1, h: Math.ceil(p.height * k) + 1 };
    }

    // Espacio activo vacío (solo se consulta si el ajuste está activo)
    readonly property bool emptyWs: {
        if (!Settings.get("barTransparentEmpty", false)) return false;
        const m = HyprClients.monitorByName(screen?.name ?? "");
        return !!m && HyprClients.onWorkspace(m.activeWorkspace?.id).length === 0;
    }

    WlrLayershell.namespace: "hf-bar"
    WlrLayershell.layer: edgeMode ? WlrLayer.Overlay : WlrLayer.Top
    visible: onThisScreen
    color: "transparent"
    anchors {
        top: pos !== "abajo"
        bottom: pos !== "arriba"
        left: pos !== "derecha"
        right: pos !== "izquierda"
    }
    // Oculta sola: la ventana llega al borde (para poder «tocarlo» con el cursor) y el hueco va por dentro
    readonly property int inner: edgeMode ? off : 0
    margins {
        top: pos === "arriba" && edgeMode ? 0 : off
        bottom: pos === "abajo" && edgeMode ? 0 : off
        left: pos === "izquierda" && edgeMode ? 0 : off
        right: pos === "derecha" && edgeMode ? 0 : off
    }
    implicitHeight: vertical ? 0 : thickness + inner
    implicitWidth: vertical ? thickness + inner : 0
    exclusiveZone: autoHide ? 0 : smart ? (smartReserve ? thickness + off : 0) : thickness

    // Zona que recibe el ratón: la barra (o la isla), o una franja de 2 px en el borde si está escondida
    // (archipiélago: solo las píldoras)
    mask: Region {
        item: hit
        Region { readonly property var r: bar.pillRect(0); x: r.x; y: r.y; width: r.w; height: r.h }
        Region { readonly property var r: bar.pillRect(1); x: r.x; y: r.y; width: r.w; height: r.h }
        Region { readonly property var r: bar.pillRect(2); x: r.x; y: r.y; width: r.w; height: r.h }
        Region { readonly property var r: bar.pillRect(3); x: r.x; y: r.y; width: r.w; height: r.h }
    }
    Item {
        id: hit
        readonly property bool none: bar.revealed && bar.archi
        x: !bar.revealed ? (bar.pos === "derecha" ? parent.width - 2 : 0) : body.x
        y: !bar.revealed ? (bar.pos === "abajo" ? parent.height - 2 : 0) : body.y
        width: none ? 0 : !bar.revealed ? (bar.vertical ? 2 : parent.width) : body.width
        height: none ? 0 : !bar.revealed ? (bar.vertical ? parent.height : 2) : body.height
    }

    Item {
        id: root
        anchors.fill: parent
        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered && bar.edgeMode) hideDelay.restart()
        }
        Timer { id: hideDelay; interval: 600 }

        Item {
            id: body
            // Largo natural del contenido (isla) ya escalado
            readonly property real natural: (content.item?.naturalLength ?? 400) * bar.k
            readonly property real length: bar.island ? Math.min(natural, bar.vertical ? parent.height : parent.width)
                                                      : (bar.vertical ? parent.height : parent.width)
            x: bar.vertical ? (bar.pos === "izquierda" ? bar.inner : 0) : (parent.width - width) / 2
            y: bar.vertical ? (parent.height - height) / 2 : (bar.pos === "arriba" ? bar.inner : 0)
            width: bar.vertical ? bar.thickness : length
            height: bar.vertical ? length : bar.thickness
            Behavior on width { enabled: bar.island && !Theme.reduceMotion; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: bar.island && !Theme.reduceMotion; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            // Escondida: se desliza hacia el borde
            readonly property real hiddenShift: bar.thickness + bar.off + 2
            transform: Translate {
                x: bar.revealed || !bar.vertical ? 0 : bar.pos === "derecha" ? body.hiddenShift : -body.hiddenShift
                y: bar.revealed || bar.vertical ? 0 : bar.pos === "arriba" ? -body.hiddenShift : body.hiddenShift
                Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                Behavior on y { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            }

            Glass {
                id: bg
                anchors.fill: parent
                kind: "bar"
                radius: bar.floating ? (Theme.pill || bar.island ? Math.min(Theme.barRadius * 2, bar.thickness / 2) : Theme.barRadius) : 0
                shadow: bar.floating
                showBorder: bar.floating
                effects: bar.floating
                // Archipiélago: el fondo lo ponen las píldoras de cada grupo (BarPill)
                visible: !bar.archi
                opacity: bar.emptyWs ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                // Fija: solo la línea del lado de las ventanas
                Rectangle {
                    visible: !bar.floating && (Theme.borderWidth > 0 || Theme.glassy)
                    color: Theme.glassy ? Theme.rimTop : Theme.border
                    opacity: Theme.glassy ? 0.6 : 1
                    width: bar.vertical ? 1 : parent.width
                    height: bar.vertical ? parent.height : 1
                    x: bar.pos === "izquierda" ? parent.width - 1 : 0
                    y: bar.pos === "arriba" ? parent.height - 1 : 0
                }
            }

            // Alerta visual (visualBell): dos destellos del color primario
            Rectangle {
                id: bell
                anchors.fill: parent
                radius: bg.radius
                color: Theme.p
                opacity: 0
                visible: !bar.archi
                SequentialAnimation {
                    id: flash
                    loops: 2
                    NumberAnimation { target: bell; property: "opacity"; to: 0.45; duration: 120 }
                    NumberAnimation { target: bell; property: "opacity"; to: 0; duration: 220 }
                }
            }

            // Contenido diseñado a su tamaño normal y escalado (nítido: ver textScaled)
            Item {
                id: scaler
                width: parent.width / bar.k
                height: parent.height / bar.k
                scale: bar.k
                transformOrigin: Item.TopLeft
                Loader {
                    id: content
                    anchors.fill: parent
                    sourceComponent: bar.vertical ? vComp : hComp
                }
            }
        }
    }
    Component { id: hComp; BarH { barWindow: bar; compact: bar.island; islands: bar.archi } }
    Component { id: vComp; BarV { barWindow: bar; compact: bar.island; islands: bar.archi } }

    Connections {
        id: bellWatch
        target: Notifs
        enabled: Settings.get("visualBell", false)
        property int last: Notifs.count
        function onCountChanged() {
            if (Notifs.count > bellWatch.last && !Notifs.dnd) flash.restart();
            bellWatch.last = Notifs.count;
        }
    }
}
