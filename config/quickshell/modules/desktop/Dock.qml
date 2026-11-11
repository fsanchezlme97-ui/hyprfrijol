// Dock vertical a la izquierda, u horizontal abajo (bottom: WinMode.dockSide, ajuste "dockPos"; una ventana por
// pantalla; lo crea Desktop.qml). Se ve donde las ventanas flotan
// (modo flotante, o un espacio con la excepción de los ajustes rápidos) y en todos con "dockInTiling".
// Comportamiento ("dockBehavior", Ajustes › Escritorio y gestos › Dock):
//   "fijo"         siempre visible y reserva su franja (las ventanas maximizadas se quedan a su lado)
//   "auto"         escondido; aparece al llevar el cursor a su borde
//   "inteligente"  (por defecto) esquiva las ventanas: se aparta cuando una ventana pasa por su zona y vuelve
//                  cuando queda libre (WinMode.covered); en un espacio en mosaico reserva su sitio salvo con una
//                  ventana maximizada / a pantalla completa
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
    property bool bottom: false         // abajo y en horizontal (si no, a la izquierda y en vertical)
    readonly property int step: 46      // cada icono mide 42 + 4 de separación

    readonly property string behavior: { const b = Settings.get("dockBehavior", "inteligente"); return ["fijo", "auto", "inteligente"].includes(b) ? b : "inteligente"; }
    readonly property string monName: screen?.name ?? ""
    // Zona del dock en coordenadas globales (para saber si una ventana la tapa), con 8 px de margen
    readonly property var zone: {
        HyprClients.refreshes;
        const m = HyprClients.monitorByName(monName);
        if (!m) return null;
        const L = HyprClients.logical(m), r = m.reserved ?? [0, 0, 0, 0];
        if (bottom) {
            const below = behavior === "fijo" ? 0 : r[3];       // con el dock fijo, r[3] ya incluye su franja
            const w = L.w - r[0] - r[2];
            return { x: L.x + r[0] + (w - dock.width) / 2 - 8, y: L.y + L.h - below - (6 + dock.height + 8), w: dock.width + 16, h: 6 + dock.height + 8 };
        }
        const left = behavior === "fijo" ? 0 : r[0];          // con el dock fijo, r[0] ya incluye su franja
        const top = L.y + r[1], h = L.h - r[1] - r[3];
        return { x: L.x + left, y: top + (h - dock.height) / 2 - 8, w: 6 + dock.width + 8, h: dock.height + 16 };
    }
    readonly property bool covered: behavior === "inteligente" && shown && WinMode.covered(monName, zone)
    readonly property bool reserve: { WinMode.overrides; WinMode.mode;
        return shown && (behavior === "fijo" || (behavior === "inteligente" && !WinMode.isFloat(wsId) && !WinMode.hasFullscreen(monName))); }
    property bool menuOpen: false
    property var menuItem: null
    property int menuIndex: -1
    readonly property bool revealed: shown && (behavior === "fijo" || (behavior === "inteligente" && !covered)
                                               || hov.hovered || hideDelay.running || menuOpen)

    visible: shown || fade.running || slide.running || slideY.running
    color: "transparent"
    WlrLayershell.layer: behavior === "fijo" ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: "hf-dock"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: reserve ? 6 + 54 + 4 : 0
    anchors { top: !bottom; bottom: true; left: true; right: bottom }
    // Sitio para el menú y el nombre: a la derecha del dock vertical, encima del horizontal
    implicitWidth: bottom ? 0 : 6 + 54 + 8 + 220
    implicitHeight: bottom ? 6 + 54 + 8 + 240 : 0
    // Entrada: el dock (o una franja de 2 px en el borde si está escondido); con el menú abierto, toda la ventana
    mask: Region { item: dockWin.menuOpen ? full : dockWin.revealed ? hitDock : strip }

    property int hover: -1

    Item { id: full; anchors.fill: parent }
    Item { id: strip; x: 0; y: dockWin.bottom ? parent.height - 2 : 0; width: dockWin.bottom ? parent.width : 2; height: dockWin.bottom ? 2 : parent.height }
    // el dock y el hueco hasta el borde
    Item { id: hitDock; x: dockWin.bottom ? dock.x : 0; y: dock.y; width: dockWin.bottom ? dock.width : dock.x + dock.width; height: dockWin.bottom ? parent.height - dock.y : dock.height }
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
        x: dockWin.bottom ? (parent.width - width) / 2 : 6
        y: dockWin.bottom ? parent.height - 6 - height : (parent.height - height) / 2
        width: dockWin.bottom ? dockCol.implicitWidth + 16 : 54
        height: dockWin.bottom ? 54 : dockCol.implicitHeight + 16
        radius: Theme.r(14)
        kind: "panel"
        opacity: dockWin.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        transform: Translate {
            x: dockWin.revealed || dockWin.bottom ? 0 : -(6 + dock.width + 32)   // también la sombra
            y: dockWin.revealed || !dockWin.bottom ? 0 : 6 + dock.height + 32
            Behavior on x { NumberAnimation { id: slide; duration: Theme.reduceMotion ? 0 : Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { id: slideY; duration: Theme.reduceMotion ? 0 : Theme.durIn; easing.type: Easing.OutCubic } }
        }

        Grid {
            id: dockCol
            anchors.centerIn: parent
            columns: dockWin.bottom ? 99 : 1    // una fila (abajo) o una columna (izquierda)
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
                    width: dockWin.bottom ? 42 : 54; height: dockWin.bottom ? 54 : 42
                    // Separador entre fijadas y abiertas
                    Rectangle {
                        visible: !di.modelData.pinned && di.index > 0 && dockWin.desk.dockItems[di.index - 1].pinned
                        x: dockWin.bottom ? -3 : (parent.width - width) / 2
                        y: dockWin.bottom ? (parent.height - height) / 2 : -3
                        width: dockWin.bottom ? 1 : 28; height: dockWin.bottom ? 28 : 1; color: Theme.ov
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 36; radius: Theme.r(9)
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
                            source: di.modelData.entry?.icon ? Quickshell.iconPath(di.modelData.entry.icon, true) : HyprClients.iconFor(di.modelData.cls)
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
                    // Un punto por ventana (hasta 4): alargado = la activa · apagado = minimizada. A la izquierda del
                    // icono en vertical, debajo en horizontal
                    Grid {
                        columns: dockWin.bottom ? 4 : 1
                        x: dockWin.bottom ? (parent.width - width) / 2 : 2
                        y: dockWin.bottom ? parent.height - height - 4 : (parent.height - height) / 2
                        spacing: 2
                        Repeater {
                            model: di.wins.slice(0, 4)
                            Rectangle {
                                required property var modelData
                                readonly property bool act: modelData.address === HyprClients.activeAddress && !WinMode.isMin(modelData)
                                width: dockWin.bottom ? (act ? 12 : 4) : 3; height: dockWin.bottom ? 3 : (act ? 12 : 4); radius: 1.5
                                color: WinMode.isMin(modelData) ? Theme.o : Theme.p
                                Behavior on width { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                Behavior on height { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
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
            Rectangle { width: dockWin.bottom ? 1 : 28; height: dockWin.bottom ? 28 : 1; color: Theme.ov }
            Item {
                width: dockWin.bottom ? 42 : 54; height: dockWin.bottom ? 54 : 42
                Rectangle {
                    anchors.centerIn: parent
                    width: 36; height: 36; radius: Theme.r(9)
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
        // vertical: a la derecha, con la primera acción a la altura del icono · horizontal: encima, centrado en el icono
        x: dockWin.bottom ? Math.max(8, Math.min(dockWin.width - width - 8, dock.x + 8 + dockWin.menuIndex * dockWin.step + 21 - width / 2))
                          : dock.x + dock.width + 8
        y: dockWin.bottom ? dock.y - height - 8
                          : Math.max(8, Math.min(dockWin.height - height - 8, dock.y + 8 + dockWin.menuIndex * dockWin.step + 21 - 45))
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
        x: dockWin.bottom ? dock.x + at - width / 2 : dock.x + dock.width + 8
        y: dockWin.bottom ? dock.y - height - 8 : dock.y + at - height / 2
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
