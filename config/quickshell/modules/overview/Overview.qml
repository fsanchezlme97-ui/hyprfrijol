// Vista general (vista "vista", Super + Tab): espacios de trabajo con miniaturas en vivo de sus ventanas.
// - Escribe para buscar entre las ventanas abiertas (título, app o clase); Intro → ir a la primera.
// - Clic en una ventana → foco; clic en un espacio → ir a él; clic central en una ventana → cerrarla.
// - Arrastra una ventana a otro espacio (o a «nuevo espacio») para moverla.
// - Flechas: mover la selección entre espacios (o entre resultados al buscar); Intro: ir.
// Nombres de los espacios: ajustes "wsNames" ({"1": "Trabajo", …}) y "wsIcons" ({"1": "💼"}); el número sigue la numeración de la barra ("wsNumerals", services/WsLabel.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "vista"
    place: "fill"
    dim: true
    margin: 0

    property string query: ""
    property int selWs: 1
    property int selMatch: 0
    property string dragAddress: ""
    property int dropWs: 0

    readonly property var wsNames: Settings.get("wsNames", ({}))
    readonly property var wsIcons: Settings.get("wsIcons", ({}))
    readonly property int activeWs: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // Espacios a mostrar: los que existen + del 1 al 5 (como el diseño), sin especiales
    readonly property var wsIds: {
        const s = new Set([1, 2, 3, 4, 5]);
        for (const w of Hyprland.workspaces.values) if (w.id > 0) s.add(w.id);
        for (const c of HyprClients.clients) if (c.workspace?.id > 0) s.add(c.workspace.id);
        return [...s].sort((a, b) => a - b);
    }
    readonly property int nextFree: { let i = 1; while (wsIds.includes(i) && HyprClients.onWorkspace(i).length) i++; return Math.max(i, Math.max(...wsIds) + 1); }

    function fold(s): string { return String(s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
    function matches(c): bool {
        if (!query) return true;
        const q = fold(query);
        return fold(c.title).includes(q) || fold(c.class).includes(q) || fold(HyprClients.appName(c.class)).includes(q);
    }
    readonly property var matchList: query ? HyprClients.byRecent.filter(c => c.workspace?.id > 0 && matches(c)) : []
    readonly property string selAddress: matchList[Math.min(selMatch, matchList.length - 1)]?.address ?? ""

    function wsLabel(id: int): string {
        // espacios por pantalla: el número que ve esa pantalla en su barra (también para nombre e icono), y el nombre
        // de la pantalla si no es la principal
        const n = WsLabel.local(id);
        const ic = String(wsIcons[String(n)] ?? ""), named = ((ic ? ic + " " : "") + (wsNames[String(n)] ?? "")).trim();
        const apps = [...new Set(HyprClients.onWorkspace(id).map(c => HyprClients.appName(c.class)))];
        // Numeración de la barra (WsLabel) y el número de siempre si no es arábiga
        const mon = n !== id ? " (" + (Hyprland.workspaces.values.find(w => w.id === id)?.monitor?.name ?? WsLabel.groups[Math.floor((id - 1) / 10)] ?? "") + ")" : "";
        const num = (WsLabel.style === "arabiga" || WsLabel.style === "puntos" ? String(n) : WsLabel.numeral(n) + " " + n) + mon;
        if (!apps.length) return num + " · " + (named || "Vacío");
        const list = apps.length > 3 ? apps.slice(0, 3).join(", ") + "…" : apps.join(", ");
        return num + " · " + (named ? named + " — " + list : list);
    }

    function focusWindow(address: string): void {
        Shell.close();
        HyprClients.focusWindow(address);
    }
    function goWorkspace(id: int): void {
        Shell.close();
        Shell.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }
    function moveWindow(address: string, id: int): void {
        Shell.dispatch('hl.dsp.window.move({ workspace = ' + id + ', follow = false, window = "address:' + address + '" })');
        HyprClients.refresh();
    }
    function closeWindow(address: string): void {
        Shell.dispatch('hl.dsp.window.close({ window = "address:' + address + '" })');
        HyprClients.refresh();
    }
    function accept(): void {
        if (query) { if (selAddress) focusWindow(selAddress); }
        else goWorkspace(selWs);
    }
    function step(dx: int, dy: int): void {
        if (query) {
            const n = matchList.length;
            if (n) selMatch = (selMatch + dx + dy + n) % n;
            return;
        }
        const i = wsIds.indexOf(selWs), n = wsIds.length;
        let j = i + dx + dy * 3;
        if (j < 0 || j >= n) j = (i + dx + n) % n;
        selWs = wsIds[j];
    }

    onShownChanged: if (shown) {
        query = ""; search.text = ""; selMatch = 0; selWs = activeWs; dragAddress = "";
        HyprClients.refreshNow();
        Qt.callLater(() => search.focusInput());
    }

    Item {
        anchors.fill: parent
        // Clic en el hueco → cerrar
        MouseArea { anchors.fill: parent; onClicked: Shell.close() }

        ColumnLayout {
            id: box
            width: Math.min(1200, parent.width - 48)
            // Centrada en la pantalla entera (no en el hueco que deja la barra), sin salirse del panel
            x: Math.max(24, Math.min(parent.width - width - 24, win.width / 2 - win.panel.x - width / 2))
            y: Math.max(24, Math.min(parent.height - implicitHeight - 24, win.height / 2 - win.panel.y - implicitHeight / 2))
            spacing: 18

            // Buscar ventanas abiertas…
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 420
                Layout.preferredHeight: 38
                radius: Theme.r(6)
                color: Theme.glassPanel
                border.width: 1
                border.color: Theme.border
                Field {
                    id: search
                    anchors.fill: parent
                    color: "transparent"
                    h: 38
                    textSize: 13
                    placeholder: "Buscar ventanas abiertas…"
                    onTextChanged: { win.query = text.trim(); win.selMatch = 0; }
                    onAccepted: win.accept()
                    onKeyPressed: e => {
                        if (e.key === Qt.Key_Escape) { Shell.close(); e.accepted = true; }
                        else if (e.key === Qt.Key_Left || (e.key === Qt.Key_Backtab)) { win.step(-1, 0); e.accepted = true; }
                        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { win.step(1, 0); e.accepted = true; }
                        else if (e.key === Qt.Key_Up) { win.step(0, -1); e.accepted = true; }
                        else if (e.key === Qt.Key_Down) { win.step(0, 1); e.accepted = true; }
                        else if (e.key === Qt.Key_Delete && win.query && win.selAddress) { win.closeWindow(win.selAddress); e.accepted = true; }
                    }
                }
                Txt {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: win.query !== ""
                    text: win.matchList.length ? win.matchList.length + (win.matchList.length === 1 ? " ventana" : " ventanas") : "Sin resultados"
                    size: 11.5
                    muted: true
                }
            }

            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 20
                rowSpacing: 20
                readonly property real cellW: (width - 2 * columnSpacing) / 3
                readonly property real cellH: Math.min(226, (win.height - 260) / Math.ceil((win.wsIds.length + 1) / 3) - 32)

                Repeater {
                    model: win.wsIds
                    delegate: ColumnLayout {
                        id: cell
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property var wins: HyprClients.onWorkspace(wsId)
                        readonly property bool current: wsId === win.activeWs
                        readonly property bool selected: !win.query && wsId === win.selWs
                        readonly property bool anyMatch: !win.query || wins.some(c => win.matches(c))
                        readonly property var mon: {
                            const id = wins[0]?.monitor ?? Hyprland.workspaces.values.find(w => w.id === wsId)?.monitor?.id;
                            return HyprClients.monitorById(id) ?? HyprClients.focusedMonitor;
                        }
                        Layout.preferredWidth: grid.cellW
                        spacing: 6
                        z: win.dragAddress && wins.some(c => c.address === win.dragAddress) ? 10 : 0
                        opacity: anyMatch ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                        Rectangle {
                            id: card
                            Layout.fillWidth: true
                            Layout.preferredHeight: grid.cellH
                            radius: Theme.r(7)
                            color: Qt.alpha(Theme.bg, 0.85)
                            readonly property bool empty: cell.wins.length === 0
                            readonly property bool dropHere: drop.containsDrag && win.dropWs === cell.wsId
                            border.width: dropHere || cell.current || cell.selected ? 2 : (empty ? 0 : 1)
                            border.color: dropHere ? Theme.p : cell.current ? Theme.p : cell.selected ? Qt.alpha(Theme.p, 0.6) : Theme.ov
                            Behavior on border.color { ColorAnimation { duration: Theme.ms(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                            // borde discontinuo para los vacíos
                            Canvas {
                                anchors.fill: parent
                                visible: card.empty && !card.dropHere && !cell.current && !cell.selected
                                onPaint: {
                                    const g = getContext("2d");
                                    g.reset();
                                    g.strokeStyle = Theme.o; g.lineWidth = 1.5; g.setLineDash([4, 3]);
                                    g.beginPath(); g.roundedRect(0.75, 0.75, width - 1.5, height - 1.5, 7, 7); g.stroke();
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.goWorkspace(cell.wsId)
                                onContainsMouseChanged: if (containsMouse && !win.query) win.selWs = cell.wsId
                            }
                            DropArea {
                                id: drop
                                anchors.fill: parent
                                keys: ["hf-window"]
                                onEntered: win.dropWs = cell.wsId
                                onDropped: d => { if (cell.wsId !== d.source.wsId) win.moveWindow(d.source.address, cell.wsId); }
                            }

                            Txt {
                                anchors.centerIn: parent
                                visible: card.empty
                                text: card.dropHere ? "Soltar aquí" : "Vacío"
                                muted: true
                                size: 12
                            }

                            // Área donde se dibuja el monitor a escala
                            Item {
                                id: screenArea
                                anchors.fill: parent
                                anchors.margins: 6
                                readonly property var geo: HyprClients.logical(cell.mon)
                                // Modo «Desplazamiento»: la cinta de columnas sigue fuera de la pantalla por los lados; se
                                // encoge para que quepa entera y un marco señala la parte que se ve
                                readonly property var ext: {
                                    let x0 = geo.x, x1 = geo.x + geo.w;
                                    for (const c of cell.wins) {
                                        if (c.floating || !c.at || !c.size) continue;
                                        x0 = Math.min(x0, c.at[0]); x1 = Math.max(x1, c.at[0] + c.size[0]);
                                    }
                                    return { x: x0, w: x1 - x0 };
                                }
                                readonly property bool tape: ext.w > geo.w + 4
                                readonly property real k: Math.min(width / Math.max(1, ext.w), height / Math.max(1, geo.h))
                                readonly property real ox: (width - ext.w * k) / 2 + (geo.x - ext.x) * k
                                readonly property real oy: (height - geo.h * k) / 2

                                Rectangle {
                                    visible: screenArea.tape
                                    x: screenArea.ox - 2; y: screenArea.oy - 2
                                    width: screenArea.geo.w * screenArea.k + 4; height: screenArea.geo.h * screenArea.k + 4
                                    z: 3
                                    radius: Theme.r(7)
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Qt.alpha(Theme.p, 0.6)
                                }

                                Repeater {
                                    model: cell.wins.slice().sort((a, b) => (a.floating - b.floating) || (b.focusHistoryID - a.focusHistoryID))
                                    delegate: Item {
                                        id: wthumb
                                        required property var modelData
                                        readonly property string address: modelData.address
                                        readonly property int wsId: cell.wsId
                                        readonly property bool hit: win.query !== "" && win.matches(modelData)
                                        readonly property bool sel: win.query !== "" && address === win.selAddress
                                        readonly property real bx: screenArea.ox + (modelData.at[0] - screenArea.geo.x) * screenArea.k
                                        readonly property real by: screenArea.oy + (modelData.at[1] - screenArea.geo.y) * screenArea.k
                                        x: bx; y: by
                                        width: Math.max(18, modelData.size[0] * screenArea.k)
                                        height: Math.max(14, modelData.size[1] * screenArea.k)
                                        z: dragArea.drag.active ? 100 : modelData.floating ? 2 : 1
                                        opacity: !win.query || hit ? 1 : 0.3
                                        Drag.active: dragArea.drag.active
                                        Drag.keys: ["hf-window"]
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        scale: dragArea.drag.active ? 0.9 : 1
                                        Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                                        WindowThumb {
                                            anchors.fill: parent
                                            address: wthumb.address
                                            cls: wthumb.modelData.class
                                            title: wthumb.modelData.title
                                            live: win.shown
                                            radius: Theme.r(7)
                                            labelSize: 12.5
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.r(7)
                                            color: "transparent"
                                            border.width: wthumb.sel || dragArea.containsMouse ? 2 : 0
                                            border.color: wthumb.sel ? Theme.p : Qt.alpha(Theme.p, 0.7)
                                        }
                                        // Cerrar (al pasar el ratón)
                                        Rectangle {
                                            visible: dragArea.containsMouse && !dragArea.drag.active && wthumb.width > 60
                                            anchors { top: parent.top; right: parent.right; margins: 4 }
                                            width: 18; height: 18; radius: 9
                                            color: closeMa.containsMouse ? Theme.danger : Qt.alpha("#000000", 0.55)
                                            Icon { anchors.centerIn: parent; name: "x"; size: 11; color: "white"; stroke: 2.2 }
                                            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: win.closeWindow(wthumb.address) }
                                        }
                                        MouseArea {
                                            id: dragArea
                                            anchors.fill: parent
                                            z: -1
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            drag.target: wthumb
                                            drag.threshold: 6
                                            onPressed: e => { if (e.button === Qt.LeftButton) win.dragAddress = wthumb.address; }
                                            onReleased: {
                                                if (wthumb.Drag.active || drag.active) wthumb.Drag.drop();
                                                wthumb.x = Qt.binding(() => wthumb.bx);
                                                wthumb.y = Qt.binding(() => wthumb.by);
                                                win.dragAddress = "";
                                            }
                                            onClicked: e => {
                                                if (e.button === Qt.MiddleButton) win.closeWindow(wthumb.address);
                                                else win.focusWindow(wthumb.address);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            text: win.wsLabel(cell.wsId)
                            weight: cell.current ? Font.DemiBold : Font.Medium
                            color: cell.current ? Theme.t : Theme.tv
                            size: 12.5
                        }
                    }
                }

                // Nuevo espacio
                ColumnLayout {
                    Layout.preferredWidth: grid.cellW
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: grid.cellH
                        radius: Theme.r(7)
                        color: newDrop.containsDrag ? Qt.alpha(Theme.p, 0.18) : newMa.containsMouse ? Qt.alpha(Theme.glassPanel, 0.9) : Theme.glassPanel
                        border.width: newDrop.containsDrag ? 2 : 1
                        border.color: newDrop.containsDrag ? Theme.p : Theme.border
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34; height: 34; radius: 17
                                color: Theme.fill2
                                Icon { anchors.centerIn: parent; name: "plus"; size: 16; color: Theme.t }
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: newDrop.containsDrag ? "Soltar para moverla a un espacio nuevo" : "Super + Ctrl + → nuevo espacio"
                                weight: Font.DemiBold
                                size: 12.5
                            }
                        }
                        MouseArea { id: newMa; anchors.fill: parent; hoverEnabled: true; onClicked: win.goWorkspace(win.nextFree) }
                        DropArea {
                            id: newDrop
                            anchors.fill: parent
                            keys: ["hf-window"]
                            onDropped: d => win.moveWindow(d.source.address, win.nextFree)
                        }
                    }
                    Txt { Layout.leftMargin: 4; text: " "; size: 12.5 }
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: win.query
                    ? "↑ ↓ ← → elegir · Intro ir a la ventana · Supr cerrarla · Esc salir"
                    : "Clic para ir · arrastra una ventana a otro espacio para moverla · clic central la cierra · Esc salir"
                muted: true
                size: 11.5
            }
        }
    }
}
