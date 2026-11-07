// Dock vertical a la izquierda (una ventana por pantalla; lo crea Desktop.qml). Se ve donde las ventanas flotan
// (modo flotante, o un espacio con la excepción de los ajustes rápidos) y en todos con "dockInTiling".
// Comportamiento ("dockBehavior", Ajustes › Escritorio y gestos › Dock):
//   "fijo"         siempre visible y reserva su franja (las ventanas maximizadas se quedan a su lado)
//   "auto"         escondido; aparece al llevar el cursor al borde izquierdo
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

    readonly property string behavior: { const b = Settings.get("dockBehavior", "inteligente"); return ["fijo", "auto", "inteligente"].includes(b) ? b : "inteligente"; }
    readonly property string monName: screen?.name ?? ""
    // Zona del dock en coordenadas globales (para saber si una ventana la tapa), con 8 px de margen
    readonly property var zone: {
        HyprClients.refreshes;
        const m = HyprClients.monitorByName(monName);
        if (!m) return null;
        const L = HyprClients.logical(m), r = m.reserved ?? [0, 0, 0, 0];
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

    visible: shown || fade.running || slide.running
    color: "transparent"
    WlrLayershell.layer: behavior === "fijo" ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: "hf-dock"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: reserve ? 6 + 54 + 4 : 0
    anchors { top: true; bottom: true; left: true }
    implicitWidth: 6 + 54 + 8 + 220
    // Entrada: el dock (o una franja de 2 px en el borde si está escondido); con el menú abierto, toda la ventana
    mask: Region { item: dockWin.menuOpen ? full : dockWin.revealed ? hitDock : strip }

    property int hover: -1

    Item { id: full; anchors.fill: parent }
    Item { id: strip; x: 0; y: 0; width: 2; height: parent.height }
    Item { id: hitDock; x: 0; y: dock.y; width: dock.x + dock.width; height: dock.height }   // el dock y el hueco hasta el borde
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
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 54
        height: dockCol.implicitHeight + 16
        radius: Theme.r(14)
        kind: "panel"
        opacity: dockWin.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.dur } }
        transform: Translate {
            x: dockWin.revealed ? 0 : -(6 + dock.width + 32)   // también la sombra
            Behavior on x { NumberAnimation { id: slide; duration: Theme.reduceMotion ? 0 : Theme.durIn; easing.type: Easing.OutCubic } }
        }

        Column {
            id: dockCol
            anchors.centerIn: parent
            spacing: 4
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
                    width: 54; height: 42
                    // Separador entre fijadas y abiertas
                    Rectangle {
                        visible: !di.modelData.pinned && di.index > 0 && dockWin.desk.dockItems[di.index - 1].pinned
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -3 }
                        width: 28; height: 1; color: Theme.ov
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 36; radius: Theme.r(9)
                        color: dockIcon.visible ? (dma.containsMouse || dockWin.menuOpen && dockWin.menuIndex === di.index ? Theme.fill2 : "transparent")
                                                : (di.index % 3 === 0 ? Theme.pc : di.index % 3 === 1 ? Theme.s4 : Theme.sc)
                        scale: dma.pressed ? 0.92 : 1
                        opacity: di.allMin ? 0.45 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
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
                    // Un punto por ventana (hasta 4): alargado = la activa · apagado = minimizada
                    Column {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: di.wins.slice(0, 4)
                            Rectangle {
                                required property var modelData
                                readonly property bool act: modelData.address === HyprClients.activeAddress && !WinMode.isMin(modelData)
                                width: 3; height: act ? 12 : 4; radius: 1.5
                                color: WinMode.isMin(modelData) ? Theme.o : Theme.p
                                Behavior on height { NumberAnimation { duration: 140 } }
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
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 28; height: 1; color: Theme.ov }
            Item {
                width: 54; height: 42
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
        x: dock.x + dock.width + 8
        // la primera acción a la altura del icono (cada elemento mide 42 + 4 de separación)
        y: Math.max(8, Math.min(dockWin.height - height - 8, dock.y + 8 + dockWin.menuIndex * 46 + 21 - 45))
        visible: dockWin.menuOpen && dockWin.revealed
        item: dockWin.menuItem
        desk: dockWin.desk
        onDone: dockWin.menuOpen = false
    }

    // Nombre de la app al pasar el ratón
    Rectangle {
        readonly property var item: dockWin.hover === 999 ? null : dockWin.desk.dockItems[dockWin.hover]
        visible: dockWin.hover >= 0 && dockWin.revealed && !dockWin.menuOpen
        x: dock.x + dock.width + 8
        y: dock.y + 8 + (dockWin.hover === 999 ? dockWin.desk.dockItems.length * 46 + 5 : dockWin.hover * 46) + 21 - height / 2
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
