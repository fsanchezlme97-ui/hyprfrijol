pragma Singleton
// Ventanas y monitores de Hyprland con geometría (hyprctl clients/monitors -j).
// Se refresca solo cuando Hyprland avisa de cambios (abrir/cerrar/mover ventanas, cambiar de espacio…).
//   HyprClients.clients   [{ address, class, title, at:[x,y], size:[w,h], floating, workspace:{id,name},
//                            monitor, focusHistoryID, pid, fullscreen, pinned }]
//   HyprClients.monitors  [{ name, id, x, y, width, height, scale, reserved:[l,t,r,b], activeWorkspace:{id} }]
//   HyprClients.toplevelFor(address) → HyprlandToplevel (para ScreencopyView: .wayland)
//   HyprClients.usableRect(monitor) → { x, y, w, h } lógico, sin la barra
//   HyprClients.appName(cls), HyprClients.iconFor(cls), HyprClients.entryFor(cls)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var clients: []
    property var monitors: []
    property string activeAddress: ""
    property int refreshes: 0
    property string lastRaw: ""

    readonly property var focusedMonitor: monitors.find(m => m.focused) ?? monitors[0] ?? null
    // Ventanas ordenadas por uso reciente (0 = la activa)
    readonly property var byRecent: clients.filter(c => c.workspace?.id > 0)
        .slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID)

    // Agrupa los eventos seguidos, pero sin aplazar sin fin: con restart() una ráfaga continua (una ventana que
    // cambia de título sin parar) dejaba la lista sin actualizar mientras durase
    function refresh(): void { if (!debounce.running) debounce.start(); }
    function refreshNow(): void { proc.running = false; proc.running = true; }
    function setTitle(data: string): void {
        const i = data.indexOf(",");
        if (i < 0) return refresh();
        const addr = norm(data.slice(0, i)), title = data.slice(i + 1);
        const k = clients.findIndex(c => c.address === addr);
        if (k < 0) return refresh();                       // aún no la conocemos: lista completa
        if (clients[k].title === title) return;
        const next = clients.slice();
        next[k] = Object.assign({}, clients[k], { title: title });
        clients = next;
        refreshes++;
    }

    // Cambio de foco (activewindowv2 trae la dirección): se pone la activa y el orden de uso como lo lleva Hyprland
    // (la enfocada pasa a 0 y las que iban delante se corren una), sin lanzar hyprctl ni releer todas las ventanas.
    // El foco sigue al ratón: pasar por encima de varias ventanas lanzaba hasta ~8 hyprctl por segundo
    function setActive(data: string): void {
        if (!data || data === ",") { if (activeAddress !== "") { activeAddress = ""; refreshes++; } return; }
        const addr = norm(data), k = clients.findIndex(c => c.address === addr);
        if (k < 0) return refresh();                       // aún no la conocemos: lista completa
        if (addr === activeAddress && clients[k].focusHistoryID === 0) return;
        const h = clients[k].focusHistoryID;
        clients = clients.map((c, i) => i === k ? Object.assign({}, c, { focusHistoryID: 0 })
            : c.focusHistoryID < h ? Object.assign({}, c, { focusHistoryID: c.focusHistoryID + 1 }) : c);
        activeAddress = addr;
        lastRaw = "";                                      // la lista ya no es la de la última lectura
        refreshes++;
    }

    // Solo posiciones y tamaños (el sondeo de WinMode con ventanas flotantes): se pregunta por el socket de Hyprland
    // desde Quickshell, sin lanzar un hyprctl cada 600 ms; monitores y ventana activa siguen llegando por eventos
    property string lastGeo: ""
    function refreshGeometry(): void { Hyprland.refreshToplevels(); geoRead.restart(); }
    Timer {
        id: geoRead
        interval: 120
        onTriggered: {
            const cl = Hyprland.toplevels.values.map(t => t.lastIpcObject).filter(c => c && c.address && c.mapped !== false && !c.hidden);
            if (!cl.length) return;
            const key = JSON.stringify(cl.map(c => [c.address, c.at, c.size, c.floating, c.workspace?.id, c.fullscreen]));
            if (key === root.lastGeo) return;
            root.lastGeo = key;
            root.clients = cl;
            root.refreshes++;
        }
    }

    function norm(a): string { a = String(a ?? ""); return a.startsWith("0x") ? a : "0x" + a; }
    function toplevelFor(address): var {
        const a = norm(address);
        return Hyprland.toplevels.values.find(t => norm(t.address) === a) ?? null;
    }
    function client(address): var { const a = norm(address); return clients.find(c => c.address === a) ?? null; }
    function monitorById(id): var { return monitors.find(m => m.id === id) ?? null; }
    function monitorByName(n): var { return monitors.find(m => m.name === n) ?? null; }
    function onWorkspace(id): var { return clients.filter(c => c.workspace?.id === id); }

    function logical(m): var {
        if (!m) return { x: 0, y: 0, w: 1920, h: 1080 };
        const s = m?.scale || 1;
        const rot = (m?.transform ?? 0) % 2 === 1;
        const w = (rot ? m.height : m.width) / s, h = (rot ? m.width : m.height) / s;
        return { x: m?.x ?? 0, y: m?.y ?? 0, w: w, h: h };
    }
    function usableRect(m): var {
        const L = logical(m), r = m?.reserved ?? [0, 0, 0, 0];
        return { x: L.x + r[0], y: L.y + r[1], w: L.w - r[0] - r[2], h: L.h - r[1] - r[3] };
    }

    // Nombre bonito e icono de una app a partir de su clase
    function entryFor(cls: string): var {
        if (!cls) return null;
        return DesktopEntries.heuristicLookup(cls) ?? DesktopEntries.byId(cls) ?? null;
    }
    function appName(cls: string): string {
        const e = entryFor(cls);
        if (e?.name) return e.name;
        const s = String(cls ?? "").split(".").pop();
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : "Ventana";
    }
    function iconFor(cls: string): string {
        const e = entryFor(cls);
        return e?.icon ? Quickshell.iconPath(e.icon, true) : Quickshell.iconPath(String(cls ?? "").toLowerCase(), true);
    }

    // Enfocar una ventana desde un panel que tenía el teclado: Hyprland devuelve el foco a la ventana
    // anterior al soltarlo, así que se repite el foco un instante después.
    function focusWindow(address): void {
        refocus.lua = 'hl.dsp.focus({ window = "address:' + norm(address) + '" })';
        Hyprland.dispatch(refocus.lua);
        refocus.restart();
    }
    Timer { id: refocus; property string lua: ""; interval: 90; onTriggered: Hyprland.dispatch(lua) }
    Timer { id: debounce; interval: 120; onTriggered: root.refreshNow() }
    Component.onCompleted: refreshNow()

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name;
            // Título nuevo: llega en el propio evento («dirección,título»), no hace falta preguntar a hyprctl
            if (n === "windowtitlev2") { root.setTitle(ev.data); return; }
            if (n === "windowtitle") return;   // siempre llega junto con windowtitlev2
            if (n === "activewindowv2") { root.setActive(ev.data); return; }
            if (n === "activewindow") return;  // siempre llega junto con activewindowv2
            // Un espacio cambia de número (frijol/workspaces.lua lo renumera al cambiar las pantallas): Quickshell no
            // atiende este evento y su lista se quedaría con el número viejo
            if (n === "changeworkspaceid") { Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors(); Hyprland.refreshToplevels(); root.refresh(); return; }
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2", "changefloatingmode", "focusedmon", "focusedmonv2",
                 "monitoradded", "monitorremoved", "fullscreen", "createworkspace", "destroyworkspace", "pin",
                 "monitoraddedv2", "monitorremovedv2", "moveworkspace", "moveworkspacev2"].includes(n))
                root.refresh();
        }
    }

    Process {
        id: proc
        // Un solo hyprctl (antes sh + 5 hyprctl + grep en cada cambio). --batch -j separa las respuestas con
        // líneas en blanco; dentro del JSON los saltos de línea van escapados, así que cortar ahí es seguro.
        command: ["hyprctl", "-j", "--batch", "clients; monitors; activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Sin cambios (el sondeo de 600 ms de WinMode con ventanas flotantes): no se recalcula nada
                if (text === root.lastRaw) return;
                root.lastRaw = text;
                try {
                    const parts = text.split(/\n\s*\n\s*\n/).map(t => t.trim()).filter(Boolean);
                    const cl = JSON.parse(parts[0] ?? "[]"), mons = JSON.parse(parts[1] ?? "[]");
                    let act = {};
                    try { act = JSON.parse(parts[2] ?? "{}"); } catch (e) {}
                    if (!Array.isArray(cl) || !Array.isArray(mons)) return;
                    root.clients = cl.filter(c => c.mapped !== false && !c.hidden);
                    root.monitors = mons;
                    root.activeAddress = act?.address ?? "";
                    root.refreshes++;
                } catch (e) {}
            }
        }
    }
}
