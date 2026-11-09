pragma Singleton
// Memorias USB, tarjetas SD e imágenes de disco (udisks2). Lo hace scripts/hf-devices: este servicio solo lee
// `hf-devices watch` (una línea JSON por cambio) y llama a mount/unmount/eject/open. El aviso al conectar
// («Abrir» / «Expulsar»), el montaje automático y «abrir al conectar» los hace el propio watch según Ajustes ›
// Almacenamiento (devicesNotify, devicesAutomount, devicesOpenOnPlug).
//   Devices.list (extraíbles) · Devices.mounted · Devices.busy (dev en curso) · Devices.error
//   mount(dev) · unmount(dev) · eject(dev) · ejectAll() · open(dev) · openDisks()
// IPC: qs … ipc call devices list|ejectAll
// Pruebas: HF_DEVICES_LSBLK=<json de lsblk> en el entorno del shell (watch vigila ese archivo).
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property var list: []
    readonly property var mounted: list.filter(d => d.mounted)
    readonly property bool any: list.length > 0
    property string busy: ""
    property string error: ""
    property string done: ""

    function human(n): string {
        n = Number(n || 0);
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < u.length - 1) { n /= 1000; i++; }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)).toString().replace(".", ",") + " " + u[i];
    }
    function kindName(k): string {
        return { usb: "Memoria USB", sd: "Tarjeta SD", imagen: "Imagen de disco", optical: "Disco", interno: "Disco interno" }[k] ?? "Unidad";
    }

    function run(op: string, dev: string): void {
        if (act.running) return;
        busy = dev || "*"; error = ""; done = "";
        act.op = op;
        act.command = [Paths.script("hf-devices"), op].concat(dev ? [dev] : []);
        act.running = true;
    }
    function mount(dev: string): void { run("mount", dev); }
    function unmount(dev: string): void { run("unmount", dev); }
    function eject(dev: string): void { run("eject", dev); }
    function ejectAll(): void { run("eject-all", ""); }
    function open(dev: string): void { run("open", dev); }
    function openDisks(): void { Quickshell.execDetached([Paths.script("hf-devices"), "disks"]); }

    Process {
        id: act
        property string op: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) { r = { ok: false, error: "hf-devices no respondió" }; }
                if (!r.ok) root.error = r.error ?? (r.results ?? []).map(x => x.error).filter(Boolean).join(" · ") ?? "No se pudo";
                else root.done = r.text ?? (act.op === "eject-all" ? "Ya puedes quitar las unidades" : "");
                root.busy = "";
            }
        }
        onExited: root.busy = ""
    }

    Process {
        id: watch
        running: true
        command: Paths.reaper.concat([Paths.script("hf-devices"), "watch"])
        stdout: SplitParser {
            onRead: data => {
                try { const j = JSON.parse(data); root.list = (j.devices ?? []).filter(d => d.removable); } catch (e) {}
            }
        }
        onExited: again.start()
    }
    Timer { id: again; interval: 5000; onTriggered: watch.running = true }

    IpcHandler {
        target: "devices"
        function list(): string { return JSON.stringify(root.list); }
        function ejectAll(): void { root.ejectAll(); }
    }
}
