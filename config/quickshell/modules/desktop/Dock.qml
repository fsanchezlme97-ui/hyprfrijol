// Dock en un borde de la pantalla (side: WinMode.dockSide, ajuste "dockPos"): vertical a la izquierda o a la derecha,
// horizontal abajo o arriba (una ventana por pantalla; lo crea Desktop.qml). Del borde le separa el mismo hueco que a
// las ventanas y a la barra flotante (Settings.dockGap = gapsOut) y sus esquinas son las de las píldoras de la barra
// (las de las ventanas + Ajustes › Barra › Esquinas). Se ve donde las ventanas flotan
// (modo flotante, o un espacio con la excepción de los ajustes rápidos) y en todos con "dockInTiling".
// Comportamiento ("dockBehavior", Ajustes › Escritorio y gestos › Dock):
//   "fijo"         siempre visible y reserva su franja (las ventanas maximizadas se quedan a su lado)
//   "auto"         escondido; aparece al llevar el cursor a su borde
//   "inteligente"  (por defecto) esquiva las ventanas: se aparta cuando una ventana pasa por su zona y vuelve
//                  cuando queda libre (WinMode.covered); en un espacio en mosaico reserva su sitio salvo con una
//                  ventana maximizada / a pantalla completa
// "dockOnTop": siempre a la vista por encima de las ventanas, sin apartarse ni reservar su franja (manda sobre
// dockBehavior); en la capa Top, así una ventana a pantalla completa (vídeo, juegos) sí lo tapa.
// Apps: las fijadas ("dockApps") y las abiertas, con un punto por ventana (alargado = la activa, apagado =
// minimizada). Clic: ir a la app · en la activa: minimizarla · en una minimizada: traerla al espacio actual ·
// clic central: nueva ventana · clic derecho: DockMenu.qml.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: dockWin
    required property var desk          // Desktop.qml (dockItems, activate, launch, togglePin)
    property bool shown: false          // hay dock en el espacio activo de esta pantalla
    property int wsId: -1
    property string side: "izquierda"   // "izquierda" · "derecha" (vertical) · "abajo" · "arriba" (horizontal)
    readonly property bool horiz: side === "abajo" || side === "arriba"
    readonly property int gap: Settings.dockGap
    // Esquinas como las píldoras de la barra (Bar.pillRadius) y los mosaicos de dentro concéntricos (a 9 px del borde)
    readonly property real radius: Math.min((Settings.get("rounding", null) ?? Theme.winRadius)
        + Math.max(0, Math.min(4, Number(Settings.get("barRoundExtra", 4)) || 0)), 27)
    readonly property real tileRadius: Theme.inner(radius, 9)
    readonly property int step: 46      // cada icono mide 42 + 4 de separación

    readonly property string behavior: { const b = Settings.get("dockBehavior", "inteligente"); return ["fijo", "auto", "inteligente", "esquivar"].includes(b) ? b : "inteligente"; }
    readonly property bool onTop: Settings.get("dockOnTop", false) === true
    readonly property string monName: screen?.name ?? ""
    // Zona del dock en coordenadas globales (para saber si una ventana la tapa), con 8 px de margen
    readonly property var zone: {
        HyprClients.refreshes;
        const m = HyprClients.monitorByName(monName);
        if (!m) return null;
        const L = HyprClients.logical(m), r = m.reserved ?? [0, 0, 0, 0];
        // Con el dock fijo, la franja reservada de su lado ya incluye la suya
        const own = behavior === "fijo" && !onTop;
        if (horiz) {
            const w = L.w - r[0] - r[2], x = L.x + r[0] + (w - dock.width) / 2 - 8, h = gap + dock.height + 8;
            return side === "abajo" ? { x: x, y: L.y + L.h - (own ? 0 : r[3]) - h, w: dock.width + 16, h: h }
                                    : { x: x, y: L.y + (own ? 0 : r[1]), w: dock.width + 16, h: h };
        }
        const top = L.y + r[1], hh = L.h - r[1] - r[3], w = gap + dock.width + 8;
        return side === "izquierda" ? { x: L.x + (own ? 0 : r[0]), y: top + (hh - dock.height) / 2 - 8, w: w, h: dock.height + 16 }
                                    : { x: L.x + L.w - (own ? 0 : r[2]) - w, y: top + (hh - dock.height) / 2 - 8, w: w, h: dock.height + 16 };
    }
    readonly property bool covered: !onTop && shown && (behavior === "inteligente" && WinMode.covered(monName, zone) || behavior === "esquivar" && WinMode.coveredAll(monName, zone))
    readonly property bool reserve: { WinMode.overrides; WinMode.mode;
        return shown && !onTop && behavior === "fijo"; }
    property bool menuOpen: false
    property var menuItem: null
    property int menuIndex: -1
    readonly property bool revealed: shown && (onTop || behavior === "fijo" || (behavior === "inteligente" && !covered)
                                               || hov.hovered || hideDelay.running || menuOpen)

    visible: shown || fade.running || slide.running || slideY.running
    color: "transparent"
    WlrLayershell.layer: behavior === "fijo" || onTop ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: "hf-dock"
    exclusionMode: ExclusionMode.Normal
    // Reserva hasta el filo del dock: Hyprland añade gaps_out, así que las ventanas quedan a la misma distancia de él que
    // de la barra
    exclusiveZone: reserve ? gap + 54 : 0
    anchors { top: side !== "abajo"; bottom: side !== "arriba"; left: side !== "derecha"; right: side !== "izquierda" }
    // Sitio para el menú y el nombre: al lado del dock vertical, hacia el centro del horizontal
    implicitWidth: horiz ? 0 : gap + 54 + 8 + 220
    implicitHeight: horiz ? gap + 54 + 8 + 240 : 0
    // Entrada: el dock (o una franja de 2 px en el borde si está escondido); con el menú abierto, toda la ventana
    mask: Region { item: dockWin.menuOpen ? full : dockWin.revealed ? hitDock : strip }

    property int hover: -1

    Item { id: full; anchors.fill: parent }
    Item {
        id: strip
        x: dockWin.side === "derecha" ? parent.width - 2 : 0
        y: dockWin.side === "abajo" ? parent.height - 2 : 0
        width: dockWin.horiz ? parent.width : 2
        height: dockWin.horiz ? 2 : parent.height
    }
    // el dock y el hueco hasta el borde
    Item {
        id: hitDock
        x: dockWin.horiz ? dock.x : dockWin.side === "izquierda" ? 0 : dock.x
        y: !dockWin.horiz ? dock.y : dockWin.side === "arriba" ? 0 : dock.y
        width: dockWin.horiz ? dock.width : dockWin.side === "izquierda" ? dock.x + dock.width : parent.width - dock.x
        height: !dockWin.horiz ? dock.height : dockWin.side === "arriba" ? dock.y + dock.height : parent.height - dock.y
    }
    // Con el menú abierto: clic fuera de él (en esta ventana o en otra) lo cierra
    MouseArea { anchors.fill: parent; enabled: dockWin.menuOpen; acceptedButtons: Qt.AllButtons; onClicked: dockWin.menuOpen = false }
    HyprlandFocusGrab { windows: [dockWin]; active: dockWin.menuOpen; onCleared: dockWin.menuOpen = false }
    onShownChanged: if (!shown) menuOpen = false
    function openMenu(i: int): void {
        const d = desk.dockItems[i];
        if (!d || !shown) return;
        menuItem = d; menuIndex = i;
        menuOpen = true;
    }
    Connections {
        target: dockWin.desk
        function onMenuRequested(i) { if (Hyprland.focusedMonitor?.name === dockWin.monName) dockWin.openMenu(i); }
    }

    Item {
        anchors.fill: parent
        HoverHandler { id: hov; onHoveredChanged: if (!hovered && dockWin.behavior !== "fijo") hideDelay.restart() }
    }
    Timer { id: hideDelay; interval: 700 }

    Glass {
        id: dock
        x: dockWin.horiz ? (parent.width - width) / 2 : dockWin.side === "izquierda" ? dockWin.gap : parent.width - dockWin.gap - width
        y: !dockWin.horiz ? (parent.height - height) / 2 : dockWin.side === "arriba" ? dockWin.gap : parent.height - dockWin.gap - height
        width: dockWin.horiz ? dockCol.implicitWidth + 16 : 54
        height: dockWin.horiz ? 54 : dockCol.implicitHeight + 16
        radius: dockWin.radius
        kind: "panel"
        // Como las píldoras de la barra: con cristal, sin trazo (el filo lo da el propio vidrio)
        showBorder: !Theme.glassy
        opacity: dockWin.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        transform: Translate {
            // escondido: fuera por su borde, también la sombra
            x: dockWin.revealed || dockWin.horiz ? 0 : (dockWin.side === "izquierda" ? -1 : 1) * (dockWin.gap + dock.width + 32)
            y: dockWin.revealed || !dockWin.horiz ? 0 : (dockWin.side === "arriba" ? -1 : 1) * (dockWin.gap + dock.height + 32)
            Behavior on x { NumberAnimation { id: slide; duration: Theme.still ? 0 : Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { id: slideY; duration: Theme.still ? 0 : Theme.durIn; easing.type: Easing.OutCubic } }
        }

        Grid {
            id: dockCol
            anchors.centerIn: parent
            columns: dockWin.horiz ? 99 : 1     // una fila (abajo / arriba) o una columna (izquierda / derecha)
            spacing: 4
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Repeater {
                model: dockWin.desk.dockItems
                delegate: Item {
                    id: di
                    required property var modelData
                    required property int index
                    readonly property var wins: modelData.wins
                    readonly property bool allMin: wins.length > 0 && wins.every(w => WinMode.isMin(w))
                    readonly property bool focused: wins.some(w => w.address === HyprClients.activeAddress && !WinMode.isMin(w))
                    readonly property string name: modelData.entry?.name ?? HyprClients.appName(modelData.cls)
                    width: dockWin.horiz ? 42 : 54; height: dockWin.horiz ? 54 : 42
                    // Separador entre fijadas y abiertas
                    Rectangle {
                        visible: !di.modelData.pinned && di.index > 0 && dockWin.desk.dockItems[di.index - 1].pinned
                        x: dockWin.horiz ? -3 : (parent.width - width) / 2
                        y: dockWin.horiz ? (parent.height - height) / 2 : -3
                        width: dockWin.horiz ? 1 : 28; height: dockWin.horiz ? 28 : 1; color: Theme.ov
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 36; radius: dockWin.tileRadius
                        color: dockIcon.visible ? (dma.containsMouse || dockWin.menuOpen && dockWin.menuIndex === di.index ? Theme.fill2 : "transparent")
                                                : (di.index % 3 === 0 ? Theme.pc : di.index % 3 === 1 ? Theme.s4 : Theme.sc)
                        scale: dma.pressed ? 0.92 : 1
                        opacity: di.allMin ? 0.45 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.ms(90); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                        Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                        Image {
                            id: dockIcon
                            anchors.centerIn: parent
                            width: 30; height: 30
                            sourceSize: Qt.size(60, 60)
                            source: di.modelData.entry?.icon ? HyprClients.entryIcon(di.modelData.entry.icon) : HyprClients.iconFor(di.modelData.cls)
                            visible: status === Image.Ready
                            asynchronous: true
                        }
                        Txt {
                            anchors.centerIn: parent
                            visible: !dockIcon.visible
                            text: di.name.charAt(0).toUpperCase()
                            size: 14; weight: Font.DemiBold
                            color: di.index % 3 === 0 ? Theme.pcText : di.index % 3 === 1 ? Theme.t : Theme.scText
                        }
                    }
                    // Un punto por ventana (hasta 4): alargado = la activa · apagado = minimizada. Del lado del borde de
                    // la pantalla: a la izquierda o a la derecha del icono en vertical, debajo o encima en horizontal
                    Grid {
                        columns: dockWin.horiz ? 4 : 1
                        x: dockWin.horiz ? (parent.width - width) / 2 : dockWin.side === "izquierda" ? 2 : parent.width - width - 2
                        y: !dockWin.horiz ? (parent.height - height) / 2 : dockWin.side === "abajo" ? parent.height - height - 4 : 4
                        spacing: 2
                        Repeater {
                            model: di.wins.slice(0, 4)
                            Rectangle {
                                required property var modelData
                                readonly property bool act: modelData.address === HyprClients.activeAddress && !WinMode.isMin(modelData)
                                width: dockWin.horiz ? (act ? 12 : 4) : 3; height: dockWin.horiz ? 3 : (act ? 12 : 4); radius: 1.5
                                color: WinMode.isMin(modelData) ? Theme.o : Theme.p
                                Behavior on width { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                Behavior on height { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                            }
                        }
                    }
                    MouseArea {
                        id: dma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onContainsMouseChanged: dockWin.hover = containsMouse ? di.index : (dockWin.hover === di.index ? -1 : dockWin.hover)
                        onClicked: e => {
                            if (e.button === Qt.MiddleButton) dockWin.desk.launch(di.modelData);
                            else if (e.button === Qt.RightButton) dockWin.openMenu(di.index);
                            else dockWin.desk.activate(di.modelData);
                        }
                    }
                }
            }
            Rectangle { width: dockWin.horiz ? 1 : 28; height: dockWin.horiz ? 28 : 1; color: Theme.ov }
            Item {
                width: dockWin.horiz ? 42 : 54; height: dockWin.horiz ? 54 : 42
                Rectangle {
                    anchors.centerIn: parent
                    width: 36; height: 36; radius: dockWin.tileRadius
                    color: allMa.containsMouse ? Theme.s4 : Theme.s3
                    Icon { anchors.centerIn: parent; name: "apps"; size: 16; color: Theme.t }
                }
                MouseArea {
                    id: allMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: dockWin.hover = containsMouse ? 999 : (dockWin.hover === 999 ? -1 : dockWin.hover)
                    onClicked: Shell.open("spotlight", "mode:apps")
                }
            }
        }
    }

    // Menú de la app (clic derecho)
    DockMenu {
        id: menu
        // vertical: a su lado (hacia el centro), con la primera acción a la altura del icono · horizontal: encima o
        // debajo (hacia el centro), centrado en el icono
        x: dockWin.horiz ? Math.max(8, Math.min(dockWin.width - width - 8, dock.x + 8 + dockWin.menuIndex * dockWin.step + 21 - width / 2))
                         : dockWin.side === "izquierda" ? dock.x + dock.width + 8 : dock.x - width - 8
        y: !dockWin.horiz ? Math.max(8, Math.min(dockWin.height - height - 8, dock.y + 8 + dockWin.menuIndex * dockWin.step + 21 - 45))
                          : dockWin.side === "abajo" ? dock.y - height - 8 : dock.y + dock.height + 8
        visible: dockWin.menuOpen && dockWin.revealed
        item: dockWin.menuItem
        desk: dockWin.desk
        onDone: dockWin.menuOpen = false
    }

    // Nombre de la app al pasar el ratón
    Rectangle {
        readonly property var item: dockWin.hover === 999 ? null : dockWin.desk.dockItems[dockWin.hover]
        visible: dockWin.hover >= 0 && dockWin.revealed && !dockWin.menuOpen
        readonly property real at: 8 + (dockWin.hover === 999 ? dockWin.desk.dockItems.length * dockWin.step + 5 : dockWin.hover * dockWin.step) + 21
        x: dockWin.horiz ? dock.x + at - width / 2 : dockWin.side === "izquierda" ? dock.x + dock.width + 8 : dock.x - width - 8
        y: !dockWin.horiz ? dock.y + at - height / 2 : dockWin.side === "abajo" ? dock.y - height - 8 : dock.y + dock.height + 8
        width: tip.implicitWidth + 16
        height: 24
        radius: Theme.r(6)
        color: Theme.glassPopup
        border.width: 1
        border.color: Theme.border
        Txt {
            id: tip
            anchors.centerIn: parent
            size: 11.5
            readonly property int mins: parent.item ? parent.item.wins.filter(w => WinMode.isMin(w)).length : 0
            text: dockWin.hover === 999 ? "Aplicaciones"
                : (parent.item ? (parent.item.entry?.name ?? HyprClients.appName(parent.item.cls))
                   + (parent.item.wins.length > 1 ? " · " + parent.item.wins.length + " ventanas" : "")
                   + (mins > 0 ? (parent.item.wins.length > 1 ? " (" + mins + " minimizada" + (mins > 1 ? "s)" : ")") : " · minimizada") : "")
                   + (parent.item.pinned ? "" : " · clic derecho para fijar") : "")
        }
    }
}
