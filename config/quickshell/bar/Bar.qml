// Barra del diseño. Posición: abajo / arriba / izquierda / derecha · forma: fija / flotante / isla / archipiélago
// (isla y archipiélago comparten acabado de vidrio; isla alineada al inicio, centro o final del borde: barAlign)
// (Ajustes › Barra). Medidas en Settings: barThickness (grosor), barOffset (margen si flota) y barScale
// (el contenido se diseña a 32 px y se escala en proporción al tamaño elegido).
// Ajustes que lee aquí:
//   barBehavior          "siempre" · "auto" (se esconde y vuelve al llevar el cursor al borde; también en modo
//                        sin distracciones si «Ocultar la barra» está activo; antes barAutoHide) · "inteligente"
//                        (se aparta cuando una ventana flotante la tapa o hay una maximizada / a pantalla
//                        completa; en los espacios en mosaico reserva su sitio salvo con una maximizada, en los
//                        flotantes no reserva nada; vuelve con el cursor en el borde — WinMode.covered)
//   barScreens           por pantalla: completa · sencilla (espacios y consumo por programa) · oculta (Shell.barModeFor)
//   barAllScreens        false → las pantallas sin elegir en barScreens, sin barra
//   (Transparencia)      la barra es de vidrio esmerilado como la de macOS (Theme.glass = Theme.frost, el mismo de los
//                        paneles y el dock); el contenido con los colores del tema (acento, onda, paleta)
//   visualBell           parpadea al llegar un aviso (alerta visual en vez de sonido)
// Isla: la barra flota y mide lo que su contenido; el resto de la franja deja pasar el ratón.
// Archipiélago: cada grupo de módulos en su propia píldora flotante (BarPill), con el escritorio visible entre
// ellas; solo las píldoras reciben el ratón (máscara con content.item.pills).
// Muesca (barMode "muesca", arriba o abajo): una sola pieza centrada que sale del borde (NotchBg), con la isla dinámica
// en el centro (services/Isla); al desplegarse, de la muesca cuelga un panel con sus filas que es parte de la misma
// figura. Para eso la ventana es más alta que la barra (la reserva sigue siendo el grosor y la máscara solo cubre la
// figura). Sin onda de audio en ese modo.
// Marco (barMode "marco"): fija, con las esquinas de la pantalla redondeadas hacia dentro (ScreenCorners).
// Super + J (Shell.barHidden) la deja escondida: vuelve al llevar el cursor al borde.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"
import "../modules/island"

PanelWindow {
    id: bar
    readonly property string pos: Settings.barPos
    readonly property bool floating: Settings.barFloating
    readonly property bool island: Settings.barIsland
    readonly property bool archi: Settings.barArchipelago
    readonly property bool notch: Settings.barNotch && Shell.barModeFor(screen) !== "sencilla"   // la sencilla va fija
    readonly property bool slot: Settings.barIslandSlot(screen)   // la isla dinámica va dentro de la muesca
    readonly property real extra: slot ? Isla.expandedMax + 8 : 0  // alto de más para el panel que cuelga
    readonly property bool vertical: Settings.barVertical
    readonly property int off: Settings.barOffset
    readonly property int thickness: Settings.barThickness
    readonly property real k: Settings.barScale
    // Barra escondida con Super + J (Shell.barHidden) = se esconde sola: nunca desaparece sin forma de volver
    readonly property bool autoHide: Settings.barAutoHide || Shell.barHidden
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
    readonly property bool onThisScreen: Shell.barModeFor(screen) !== "oculta"
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
    // Con cristal (transparencia) sin filo: el borde lo da el propio cristal, suave; un trazo se veía marcado
    readonly property real pillBorderW: (borderMode === "ninguno" || Theme.glassy ? 0 : 1) / k
    readonly property color pillBorder: Theme.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.20)
    property real bellLevel: 0
    // Rectángulo de la píldora i del archipiélago en px de la ventana (vacío si no toca)
    function pillRect(i: int): var {
        const p = content.item?.pills?.[i];
        if (!archi || !revealed || !p || !p.visible) return { x: 0, y: 0, w: 0, h: 0 };
        return { x: Math.floor(body.x + p.x * k), y: Math.floor(body.y + p.y * k), w: Math.ceil(p.width * k) + 1, h: Math.ceil(p.height * k) + 1 };
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
    implicitHeight: vertical ? 0 : thickness + inner + extra
    implicitWidth: vertical ? thickness + inner : 0
    exclusiveZone: autoHide ? 0 : smart ? (smartReserve ? thickness + off : 0) : thickness

    // Zona que recibe el ratón: la barra (o la isla), o una franja de 2 px en el borde si está escondida
    // (archipiélago: solo las píldoras)
    mask: Region {
        item: hit
        Region { item: panel }
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
        // Fondo de la barra con un panel suyo abierto (los que se transforman entre sí y dejan pasar el ratón a la
        // barra: los de los chips y el centro de control): pulsar aquí lo cierra
        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: Shell.view !== "" && Shell.morphViews[Shell.view] === true
            onPressed: Shell.close()
        }

        Item {
            id: body
            // Largo natural del contenido (isla) ya escalado
            readonly property real natural: (content.item?.naturalLength ?? 400) * bar.k
            readonly property real full: bar.vertical ? parent.height : parent.width
            readonly property real length: bar.island || bar.notch ? Math.min(natural, full) : full
            // Hueco libre a lo largo del borde, repartido según la alineación (isla)
            // (con el largo animado: el borde alineado se queda quieto mientras crece o encoge)
            readonly property real shown: bar.vertical ? height : width
            readonly property real along: bar.notch ? (full - shown) / 2 : Settings.barAlign === "inicio" ? 0 : Settings.barAlign === "fin" ? full - shown : (full - shown) / 2
            x: bar.vertical ? (bar.pos === "izquierda" ? bar.inner : 0) : along
            y: bar.vertical ? along : (bar.pos === "arriba" ? bar.inner : parent.height - bar.thickness - bar.inner)
            width: bar.vertical ? bar.thickness : length
            height: bar.vertical ? length : bar.thickness
            Behavior on width { enabled: (bar.island || bar.notch) && !Theme.still; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: bar.island && !Theme.still; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            // Escondida: se desliza hacia el borde
            readonly property real hiddenShift: bar.thickness + bar.off + 2
            transform: Translate {
                x: bar.revealed || !bar.vertical ? 0 : bar.pos === "derecha" ? body.hiddenShift : -body.hiddenShift
                y: bar.revealed || bar.vertical ? 0 : bar.pos === "arriba" ? -body.hiddenShift : body.hiddenShift
                Behavior on x { enabled: !Theme.still; NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                Behavior on y { enabled: !Theme.still; NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            }

            BarBg {
                id: bg
                anchors.fill: parent
                radius: bar.floating ? (Theme.pill || bar.island ? Math.min(Theme.barRadius * 2, bar.thickness / 2) : Theme.barRadius) : 0
                shadow: bar.floating
                drawBorder: bar.floating
                // Archipiélago: el fondo lo ponen las píldoras de cada grupo (BarPill)
                visible: !bar.archi && !bar.notch
                bellLevel: bar.bellLevel
                feather: 1
            }

            NotchBg {
                visible: bar.notch
                anchors.fill: parent
                radius: Math.min(Theme.r(16), bar.thickness / 2)
                flip: bar.pos === "abajo"
                panelW: panel.width
                panelH: panel.height
                bellLevel: bar.bellLevel
            }
            // Isla desplegada: cuelga del centro de la muesca (hacia abajo; hacia arriba con la barra abajo)
            Item {
                id: panel
                readonly property bool open: bar.slot && Isla.expanded
                x: (parent.width - width) / 2
                y: bar.pos === "abajo" ? -height : parent.height
                width: open ? Math.min(400, parent.width - 56) : 120
                height: open ? Isla.expandedH : 0
                clip: true
                Behavior on width { enabled: !Theme.still; NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !Theme.still; NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
                HoverHandler { enabled: bar.slot; onHoveredChanged: Isla.hovered(hovered) }
                IslaRows { width: 400 - 24; anchors.fill: undefined; x: (parent.width - width) / 2; y: 12; height: Isla.expandedH - 24 }
            }

            // Alerta visual (visualBell): dos destellos del color primario sobre el fondo
            SequentialAnimation {
                id: flash
                loops: 2
                NumberAnimation { target: bar; property: "bellLevel"; to: 0.45; duration: 120 }
                NumberAnimation { target: bar; property: "bellLevel"; to: 0; duration: 220 }
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
    Component { id: hComp; BarH { barWindow: bar; compact: bar.island; islands: bar.archi; notch: bar.notch; slot: bar.slot } }
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
