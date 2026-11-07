// Organizar ventanas (vista "snap"): disposiciones tipo «snap layouts» para la ventana activa.
// - Pasa el ratón por una zona y haz clic: la ventana pasa a flotante y se coloca exactamente en esa zona
//   (respeta la barra, gaps_out, gaps_in y el borde de Hyprland).
// - Flechas para moverte por las zonas, Intro para aplicar, 1–6 elige la disposición.
// - «Grupos recientes»: cuando acoplas 2+ ventanas en un mismo espacio se recuerda el grupo; restaurar
//   vuelve a colocarlas (y abre las apps que falten). Se guarda en ~/.local/state/hyprfrijol/snap-groups.json
// Atajos globales propios: hf:snapleft, hf:snapright, hf:snapup (maximizar en zona), hf:snapdown (restaurar:
// la ventana vuelve al tamaño y sitio que tenía si ya flotaba; si estaba en mosaico, vuelve al mosaico; en un
// espacio flotante sin tamaño previo, tamaño cómodo en el centro — services/WinMode.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "snap"
    place: "fill"
    margin: 0

    // Disposiciones del diseño (fracciones del área útil); hl = zona resaltada en reposo
    readonly property var layouts: [
        { key: "mitades", hl: 0, zones: [[0, 0, .5, 1], [.5, 0, .5, 1]] },
        { key: "dos-tercios", hl: 0, zones: [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]] },
        { key: "tercios", hl: 1, zones: [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]] },
        { key: "principal", hl: 0, zones: [[0, 0, .6, 1], [.6, 0, .4, .5], [.6, .5, .4, .5]] },
        { key: "cuadrantes", hl: 0, zones: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] },
        { key: "centro", hl: 1, zones: [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]] }
    ]
    property int selLayout: -1
    property int selZone: -1
    property string target: ""            // dirección de la ventana a colocar (la activa al abrir)
    property var gaps: ({ out: [4, 4, 4, 4], inn: 4, border: 1 })
    property var groups: []               // grupos recientes [{ ws, layout, slots: [{ zone, cls, title, address }], t }]
    property var live: ({})               // ws → grupo en construcción
    property var pending: []              // apps abiertas para restaurar: [{ cls, layout, zone, until }]
    property var prevGeom: ({})           // dirección → { at, size } antes de acoplarla (solo si ya flotaba)

    readonly property var targetClient: { HyprClients.refreshes; return HyprClients.client(target); }
    readonly property bool dry: Quickshell.env("HF_TRY") === "1"

    // ---------- geometría ----------
    function zoneRect(mon, z): var {
        const U = HyprClients.usableRect(mon), o = gaps.out, gi = gaps.inn, b = gaps.border;
        const ax = U.x + o[3], ay = U.y + o[0], aw = U.w - o[1] - o[3], ah = U.h - o[0] - o[2];
        let x0 = ax + z[0] * aw, x1 = ax + (z[0] + z[2]) * aw, y0 = ay + z[1] * ah, y1 = ay + (z[1] + z[3]) * ah;
        if (z[0] > 0.001) x0 += gi;
        if (z[0] + z[2] < 0.999) x1 -= gi;
        if (z[1] > 0.001) y0 += gi;
        if (z[1] + z[3] < 0.999) y1 -= gi;
        return { x: Math.round(x0 + b), y: Math.round(y0 + b), w: Math.round(x1 - x0 - 2 * b), h: Math.round(y1 - y0 - 2 * b) };
    }
    function putWindow(address: string, z): void {
        const c = HyprClients.client(address);
        if (!c) return;
        const r = zoneRect(HyprClients.monitorById(c.monitor) ?? HyprClients.focusedMonitor, z);
        const w = 'window = "address:' + address + '"';
        if (c.floating && !prevGeom[c.address]) { const g = Object.assign({}, prevGeom); g[c.address] = { at: c.at, size: c.size }; prevGeom = g; }
        if (!c.floating) Shell.dispatch('hl.dsp.window.float({ action = "enable", ' + w + ' })');
        Shell.dispatch('hl.dsp.window.resize({ x = ' + r.w + ', y = ' + r.h + ', exact = true, ' + w + ' })');
        Shell.dispatch('hl.dsp.window.move({ x = ' + r.x + ', y = ' + r.y + ', exact = true, ' + w + ' })');
        HyprClients.refresh();
    }
    function apply(li: int, zi: int): void {
        const L = layouts[li], c = targetClient;
        if (!L || !c) { Shell.close(); return; }
        Shell.close();
        putWindow(c.address, L.zones[zi]);
        remember(c, li, zi);
    }
    function unsnap(address: string): void {
        const c = HyprClients.client(address), p = prevGeom[HyprClients.norm(address)];
        const w = 'window = "address:' + address + '"';
        if (p) {
            const g = Object.assign({}, prevGeom); delete g[HyprClients.norm(address)]; prevGeom = g;
            Shell.dispatch('hl.dsp.window.resize({ x = ' + p.size[0] + ', y = ' + p.size[1] + ', exact = true, ' + w + ' })');
            Shell.dispatch('hl.dsp.window.move({ x = ' + p.at[0] + ', y = ' + p.at[1] + ', exact = true, ' + w + ' })');
        } else if (c && WinMode.isFloat(c.workspace?.id ?? 0)) WinMode.placeDefault(address);
        else Shell.dispatch('hl.dsp.window.float({ action = "disable", ' + w + ' })');
        HyprClients.refresh();
    }

    // ---------- grupos recientes ----------
    function remember(c, li: int, zi: int): void {
        const ws = c.workspace?.id ?? 0;
        let g = live[ws];
        if (!g || g.layout !== li) g = { ws: ws, layout: li, slots: [] };
        g.slots = g.slots.filter(s => s.zone !== zi && s.address !== c.address);
        g.slots.push({ zone: zi, cls: c.class, title: c.title, address: c.address });
        const lv = Object.assign({}, live); lv[ws] = g; live = lv;
        if (g.slots.length >= 2) {
            const sig = gsig(g);
            const rest = groups.filter(x => gsig(x) !== sig && !(x.ws === ws && x.t > Date.now() - 600000 && sig.startsWith(gsig(x))));
            groups = [Object.assign({ t: Date.now() }, JSON.parse(JSON.stringify(g)))].concat(rest).slice(0, 4);
            store.setText(JSON.stringify(groups, null, 1));
        }
    }
    function gsig(g): string { return g.layout + ":" + g.slots.slice().sort((a, b) => a.zone - b.zone).map(s => s.cls).join("+"); }
    function groupName(g): string {
        return g.slots.slice().sort((a, b) => a.zone - b.zone).map(s => HyprClients.appName(s.cls)).join(" + ");
    }
    function restore(g): void {
        Shell.close();
        const used = new Set();
        const later = [];
        for (const s of g.slots.slice().sort((a, b) => a.zone - b.zone)) {
            let c = HyprClients.client(s.address);
            if (!c || used.has(c.address)) c = HyprClients.byRecent.find(x => x.class === s.cls && !used.has(x.address));
            if (c) {
                used.add(c.address);
                if (c.workspace?.id !== g.ws && g.ws > 0)
                    Shell.dispatch('hl.dsp.window.move({ workspace = ' + g.ws + ', follow = false, window = "address:' + c.address + '" })');
                putWindow(c.address, layouts[g.layout].zones[s.zone]);
            } else {
                const e = HyprClients.entryFor(s.cls);
                if (e) {
                    later.push({ cls: s.cls, layout: g.layout, zone: s.zone, until: Date.now() + 20000 });
                    if (dry) console.info("[snap] (HF_TRY) abrir " + e.id); else e.execute();
                }
            }
        }
        pending = later;
        if (g.ws > 0) Shell.dispatch("hl.dsp.focus({ workspace = " + g.ws + " })");
    }
    // Coloca las apps que se han abierto para restaurar un grupo
    Connections {
        target: HyprClients
        enabled: win.pending.length > 0
        function onRefreshesChanged() {
            const now = Date.now(), left = [];
            for (const p of win.pending) {
                if (p.until < now) continue;
                const c = HyprClients.clients.find(x => x.class === p.cls && x.focusHistoryID === 0)
                       ?? HyprClients.clients.find(x => x.class === p.cls);
                if (c) win.putWindow(c.address, win.layouts[p.layout].zones[p.zone]); else left.push(p);
            }
            win.pending = left;
        }
    }

    FileView {
        id: store
        path: Paths.state + "/snap-groups.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { win.groups = JSON.parse(text()) ?? []; } catch (e) { win.groups = []; } }
    }

    // gaps / borde actuales de Hyprland
    Process {
        id: opts
        command: ["sh", "-c", "for o in general:gaps_out general:gaps_in general:border_size; do hyprctl getoption $o -j; echo; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\n+/).map(l => { try { return JSON.parse(l); } catch (e) { return {}; } });
                const nums = o => String(o?.css ?? o?.custom ?? o?.int ?? "0").trim().split(/\s+/).map(Number);
                const go = nums(v[0]), gi = nums(v[1]);
                win.gaps = {
                    out: go.length === 4 ? go : [go[0] || 0, go[0] || 0, go[0] || 0, go[0] || 0],
                    inn: gi[0] || 0,
                    border: v[2]?.int ?? 0
                };
            }
        }
    }

    onShownChanged: if (shown) {
        target = HyprClients.activeAddress || (HyprClients.byRecent[0]?.address ?? "");
        selLayout = -1; selZone = -1;
        opts.running = true;
        store.reload();
        HyprClients.refreshNow();
        Qt.callLater(() => card.forceActiveFocus());
    }
    readonly property int warm: HyprClients.refreshes
    onWarmChanged: if (shown && !target) target = HyprClients.activeAddress

    // Atajos de teclado globales (Super + flechas)
    function quick(z): void {
        const a = HyprClients.activeAddress;
        if (a) putWindow(a, z);
    }
    GlobalShortcut { appid: "hf"; name: "snapleft"; description: "HyprFrijol: acoplar a la izquierda"; onPressed: win.quick([0, 0, .5, 1]) }
    GlobalShortcut { appid: "hf"; name: "snapright"; description: "HyprFrijol: acoplar a la derecha"; onPressed: win.quick([.5, 0, .5, 1]) }
    GlobalShortcut { appid: "hf"; name: "snapup"; description: "HyprFrijol: ocupar toda el área"; onPressed: win.quick([0, 0, 1, 1]) }
    GlobalShortcut {
        appid: "hf"; name: "snapdown"; description: "HyprFrijol: restaurar la ventana"
        onPressed: { const a = HyprClients.activeAddress; if (a) win.unsnap(a); }
    }

    MouseArea { anchors.fill: parent; onClicked: Shell.close() }

    Glass {
        id: card
        kind: "panel"
        width: 300
        height: col.implicitHeight + 24
        focus: true
        // Bajo la parte superior de la ventana activa (como el botón de disposición del título), si no, arriba al centro
        readonly property var tc: win.targetClient
        readonly property var mon: HyprClients.monitorById(tc?.monitor) ?? HyprClients.focusedMonitor
        readonly property var ml: HyprClients.logical(mon)
        x: {
            if (!tc) return (parent.width - width) / 2;
            const right = tc.at[0] - ml.x + tc.size[0] - 12;
            return Math.max(8, Math.min(parent.width - width - 8, right - width));
        }
        y: {
            if (!tc) return 40;
            return Math.max(8, Math.min(parent.height - height - 48, tc.at[1] - ml.y + 32));
        }
        MouseArea { anchors.fill: parent; onClicked: {} }

        Keys.onPressed: e => {
            const flat = [];
            win.layouts.forEach((L, li) => L.zones.forEach((z, zi) => flat.push([li, zi])));
            let i = flat.findIndex(f => f[0] === win.selLayout && f[1] === win.selZone);
            if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) i = (i + 1) % flat.length;
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) i = (i - 1 + flat.length) % flat.length;
            else if (e.key === Qt.Key_Down) { const L = Math.min(win.layouts.length - 1, Math.max(0, win.selLayout) + 3); i = flat.findIndex(f => f[0] === L); }
            else if (e.key === Qt.Key_Up) { const L = Math.max(0, win.selLayout - 3); i = flat.findIndex(f => f[0] === L); }
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_6) { const L = e.key - Qt.Key_1; win.apply(L, win.layouts[L].hl); e.accepted = true; return; }
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && win.selLayout >= 0) { win.apply(win.selLayout, win.selZone); e.accepted = true; return; }
            else return;
            if (i < 0) i = 0;
            win.selLayout = flat[i][0]; win.selZone = flat[i][1];
            e.accepted = true;
        }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Txt { text: "Organizar ventanas"; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt {
                    visible: !!win.targetClient
                    text: HyprClients.appName(win.targetClient?.class ?? "")
                    muted: true; size: 11
                    Layout.maximumWidth: 120
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                enabled: !!win.targetClient
                opacity: enabled ? 1 : 0.5
                Repeater {
                    model: win.layouts
                    delegate: Rectangle {
                        id: lay
                        required property var modelData
                        required property int index
                        readonly property bool hovered: win.selLayout === index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: Theme.r(8)
                        color: hovered ? Qt.alpha(Theme.t, 0.14) : Theme.fill2
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Repeater {
                                model: lay.modelData.zones
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool on: lay.hovered ? win.selZone === index : (win.selLayout < 0 && index === lay.modelData.hl)
                                    x: modelData[0] * parent.width + (modelData[0] > 0 ? 1.5 : 0)
                                    y: modelData[1] * parent.height + (modelData[1] > 0 ? 1.5 : 0)
                                    width: modelData[2] * parent.width - (modelData[0] > 0 ? 1.5 : 0) - (modelData[0] + modelData[2] < 0.999 ? 1.5 : 0)
                                    height: modelData[3] * parent.height - (modelData[1] > 0 ? 1.5 : 0) - (modelData[1] + modelData[3] < 0.999 ? 1.5 : 0)
                                    radius: Theme.r(4)
                                    color: on ? Theme.p : Theme.s4
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: { win.selLayout = lay.index; win.selZone = parent.index; }
                                        onClicked: win.apply(lay.index, parent.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Txt {
                visible: !win.targetClient
                Layout.fillWidth: true
                text: "No hay ninguna ventana activa que organizar"
                muted: true; size: 11.5
            }

            Txt { text: "Grupos recientes"; muted: true; size: 11.5 }
            Repeater {
                model: win.groups.slice(0, 3)
                delegate: Rectangle {
                    id: grp
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: Theme.r(6)
                    color: gma.containsMouse ? Qt.alpha(Theme.t, 0.14) : Theme.fill2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6
                        Txt { text: win.groupName(grp.modelData); weight: Font.DemiBold; Layout.fillWidth: true; Layout.maximumWidth: implicitWidth }
                        Txt { text: "· restaurar"; muted: true; size: 12 }
                        Item { Layout.fillWidth: true }
                        Txt { text: grp.modelData.ws > 0 ? "esp. " + grp.modelData.ws : ""; muted: true; size: 11 }
                    }
                    MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.restore(grp.modelData) }
                }
            }
            Rectangle {
                visible: win.groups.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Theme.r(6)
                color: "transparent"
                border.width: 1
                border.color: Theme.ov
                Txt {
                    anchors.centerIn: parent
                    text: "Acopla 2 o más ventanas y aparecerán aquí"
                    muted: true; size: 11.5
                }
            }

            Txt { text: "Super + ← → ↑ ↓ para acoplar con el teclado"; muted: true; size: 11 }
        }
    }
}
