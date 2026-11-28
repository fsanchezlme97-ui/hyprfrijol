pragma Singleton
// Estado de la isla dinámica, compartido por la isla suelta (modules/island/Island.qml) y la muesca de la barra
// (bar/BarH.qml, barMode «muesca»): qué actividades hay y su IPC. No se despliega: pulsarla abre la vista completa
// de lo que enseña (Isla.open: Pomodoro, procesos, música o agenda).
//   Isla.keys · Isla.top · Isla.info(clave) · Isla.inBar · Isla.dot · Isla.open()
// IPC:  qs -p <repo>/config/quickshell ipc call isla open | state
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // Dentro de la barra (muesca) en la pantalla con foco; si no, la isla flota bajo la barra si está activada
    readonly property bool inBar: Settings.barIslandSlot(Shell.screen)
    readonly property bool on: Settings.get("island", false) === true || inBar
    readonly property bool always: Settings.get("islandAlways", false) === true
    readonly property var wanted: Settings.get("islandShow", ["musica", "pomodoro", "descargas", "reunion"]) ?? []

    // Qué actividades hay, por prioridad. Solo la lista de claves (como texto) para que las filas no se rehagan cada segundo;
    // lo que cambia (cuenta atrás, porcentaje…) lo lee cada fila de info(clave).
    readonly property string keysRaw: {
        const k = [], ev = Events.next, p = Media.active;
        if (wanted.includes("reunion") && ev && !ev.allDay && ev.start - Time.now <= 10 * 60000) k.push("reunion");
        if (wanted.includes("pomodoro") && Pomodoro.running) k.push("pomodoro");
        if (wanted.includes("descargas") && Jobs.items.length > 0) k.push("descargas");
        if (wanted.includes("musica") && p && p.isPlaying) k.push("musica");
        return k.join(",");
    }
    readonly property var keys: keysRaw ? keysRaw.split(",") : []
    readonly property bool shown: on && !Shell.locked && (keys.length > 0 || always || inBar)
    readonly property bool dot: inBar && keys.length === 0 && !always    // sin nada en marcha: un punto en la muesca
    readonly property var top: info(keys.length ? keys[0] : "")

    function pct(v): string { return v >= 0 ? Math.round(v * 100) + " %" : ""; }
    function info(k): var {
        if (k === "reunion") {
            const ev = Events.next;
            return ev ? { icon: "calendar", title: ev.title, sub: ev.start <= Time.now ? "En curso" : Events.relative(ev.start), progress: -1, view: "agenda", link: ev.link } : { title: "", sub: "", progress: -1 };
        }
        if (k === "pomodoro")
            return { icon: "clock", title: Pomodoro.label + (Pomodoro.activity ? " · " + Pomodoro.activity : ""), sub: Pomodoro.time, progress: Pomodoro.progress, view: "w-pomodoro" };
        if (k === "descargas") {
            const j = Jobs.items, v = j.length ? j.reduce((a, x) => a + Math.max(0, x.progress), 0) / j.length : -1;
            return { icon: "download", title: j.length === 1 ? j[0].title : j.length + " procesos en curso", sub: j.length === 1 ? (j[0].detail || pct(v)) : pct(v), progress: j.some(x => x.progress >= 0) ? v : -1, view: "w-descargas" };
        }
        if (k === "musica") {
            const p = Media.active;
            return { icon: "music", title: p?.trackTitle || "Reproduciendo", sub: p?.trackArtist ?? "", art: p?.trackArtUrl ?? "", progress: -1, view: "musica" };
        }
        return { icon: "clock", title: Time.hhmm, sub: Time.longDate, progress: -1, view: "agenda" };
    }
    function open(): void { Shell.open(top.view); }
    IpcHandler {
        target: "isla"
        function open(): void { root.open(); }
        function state(): string { return (root.shown ? "visible" : "oculta") + (root.inBar ? " en la barra" : "") + " · " + (root.keysRaw || "sin actividad"); }
    }
}
