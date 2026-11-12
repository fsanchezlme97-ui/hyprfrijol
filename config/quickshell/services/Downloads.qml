pragma Singleton
// Cola de descargas. La lleva scripts/hf-download (yt-dlp, gallery-dl, aria2c); este servicio solo vigila
// ~/.local/state/hyprfrijol/downloads/queue.json y llama al script para añadir, pausar, reanudar, cancelar…
//   Downloads.items · active (en cola o descargando) · running · progress (0–1 de las activas; -1 si no se sabe)
//   add(urls, type, format) · pause(id) · resume(id) · cancel(id) · retry(id) · remove(id) · clear() · open(id)
// IPC: qs … ipc call downloads add <url> · list
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property var items: []
    readonly property var active: items.filter(x => ["queued", "running", "pausing", "canceling"].includes(x.status))
    readonly property var running: items.filter(x => x.status === "running")
    readonly property int errors: items.filter(x => x.status === "error").length
    readonly property real progress: {
        const r = active.filter(x => x.total > 0);
        if (!r.length) return running.length ? -1 : 0;
        const t = r.reduce((a, x) => a + x.total, 0);
        return t > 0 ? r.reduce((a, x) => a + x.done, 0) / t : -1;
    }
    readonly property bool any: items.length > 0

    function human(n): string {
        n = Number(n || 0);
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)).toString().replace(".", ",") + " " + u[i];
    }
    function eta(s): string {
        s = Number(s);
        if (!(s >= 0)) return "";
        if (s < 60) return s + " s";
        if (s < 3600) return Math.round(s / 60) + " min";
        return Math.floor(s / 3600) + " h " + Math.round((s % 3600) / 60) + " min";
    }
    function statusText(x): string {
        return { queued: "En cola", running: "Descargando", pausing: "Pausando…", paused: "En pausa", canceling: "Cancelando…",
                 done: "Terminada", error: "Error", canceled: "Cancelada" }[x.status] ?? x.status;
    }
    function typeIcon(t): string { return { video: "camera", audio: "music", image: "image", file: "file" }[t] ?? "download"; }

    function cmd(args: var): void { Quickshell.execDetached([Paths.script("hf-download")].concat(args)); }
    function add(urls: var, type: string, format: string): void {
        const u = (Array.isArray(urls) ? urls : String(urls).split(/\s+/)).filter(x => /^https?:\/\//.test(x));
        if (!u.length) return;
        cmd(["add"].concat(type && type !== "auto" ? ["--type", type] : [], format ? ["--format", format] : [], u));
    }
    function addFile(path: string, type: string): void { cmd(["add", "--file", path].concat(type && type !== "auto" ? ["--type", type] : [])); }
    function pause(id: string): void { cmd(["pause", id]); }
    function resume(id: string): void { cmd(["resume", id]); }
    function cancel(id: string): void { cmd(["cancel", id]); }
    function retry(id: string): void { cmd(["retry", id]); }
    function remove(id: string): void { cmd(["remove", id]); }
    function clear(): void { cmd(["clear"]); }
    function open(id: string): void { cmd(["open", id]); }

    FileView {
        id: fv
        path: Paths.state + "/downloads/queue.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // Solo si el archivo cambió: asignar una lista nueva cada vez recalculaba la pastilla de la barra sin motivo
        property string raw: ""
        onLoaded: { const t = text(); if (t === raw) return; raw = t; try { root.items = JSON.parse(t).items ?? []; } catch (e) {} }
        onLoadFailed: { raw = ""; if (root.items.length) root.items = []; }
    }
    // El archivo se reescribe entero (rename atómico): si inotify pierde la pista, se vuelve a leer mientras haya activas
    Timer { interval: 1500; repeat: true; running: root.active.length > 0; onTriggered: fv.reload() }
    Timer { interval: 8000; repeat: true; running: root.active.length === 0; onTriggered: fv.reload() }

    IpcHandler {
        target: "downloads"
        function add(url: string): void { root.add(url, "auto", ""); }
        function list(): string { return JSON.stringify(root.items); }
    }
}
