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

    readonly property var focusedMonitor: monitors.find(m => m.focused) ?? monitors[0] ?? null
    // Ventanas ordenadas por uso reciente (0 = la activa)
    readonly property var byRecent: clients.filter(c => c.workspace?.id > 0)
        .slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID)

    function refresh(): void { debounce.restart(); }
    function refreshNow(): void { proc.running = false; proc.running = true; }

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
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2", "activewindow",
                 "activewindowv2", "changefloatingmode", "windowtitle", "windowtitlev2", "focusedmon", "focusedmonv2",
                 "monitoradded", "monitorremoved", "fullscreen", "createworkspace", "destroyworkspace", "pin",
                 "monitoraddedv2", "monitorremovedv2", "moveworkspace", "moveworkspacev2"].includes(n))
                root.refresh();
        }
    }

    Process {
        id: proc
        command: ["sh", "-c", "printf '{\"clients\":'; hyprctl clients -j; printf ',\"monitors\":'; hyprctl monitors -j; printf ',\"active\":'; hyprctl activewindow -j | grep -q address && hyprctl activewindow -j || printf '{}'; printf '}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.clients = (d.clients ?? []).filter(c => c.mapped !== false && !c.hidden);
                    root.monitors = d.monitors ?? [];
                    root.activeAddress = d.active?.address ?? "";
                    root.refreshes++;
                } catch (e) {}
            }
        }
    }
}
