// Historial de la salud de la batería: una vez al día guarda la capacidad máxima actual frente a la de fábrica
// en ~/.local/state/hyprfrijol/battery-history.json → [{ d: "AAAA-MM-DD", health: 91.4, full: 52.1, cycles: 210 }]
// (máx. 400 días). Lo dibuja Ajustes › Energía › Estado de la batería (ui/Sparkline.qml).
// Lee /sys/class/power_supply/BAT* (o $HF_POWER_SUPPLY, para pruebas con datos falsos). Sin batería no hace nada.
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Scope {
    id: root
    readonly property string file: Paths.state + "/battery-history.json"
    property var history: []
    property bool loaded: false

    function today(): string {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function tick(): void {
        if (!loaded) return;
        const last = history.length ? history[history.length - 1].d : "";
        if (last !== today() && !reader.running) reader.running = true;
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        atomicWrites: true
        onLoaded: { try { const v = JSON.parse(text()); root.history = Array.isArray(v) ? v : []; } catch (e) { root.history = []; } root.loaded = true; root.tick(); }
        onLoadFailed: { root.history = []; root.loaded = true; root.tick(); }
    }
    Process {
        id: reader
        command: ["sh", "-c", 'ps="${HF_POWER_SUPPLY:-/sys/class/power_supply}"; b=$(ls -d "$ps"/BAT* 2>/dev/null | head -1); [ -n "$b" ] || exit 0; '
            + 'if [ -f "$b/energy_full" ]; then f=$(cat "$b/energy_full"); d=$(cat "$b/energy_full_design" 2>/dev/null); '
            + 'else f=$(cat "$b/charge_full" 2>/dev/null); d=$(cat "$b/charge_full_design" 2>/dev/null); fi; '
            + 'mkdir -p "$1"; echo "$f $d $(cat "$b/cycle_count" 2>/dev/null || echo 0)"', "sh", Paths.state]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length < 2 || !(p[0] > 0) || !(p[1] > 0)) return;
                const e = { d: root.today(), health: Math.round(p[0] / p[1] * 1000) / 10, full: Math.round(p[0] / 1e5) / 10, cycles: p[2] || 0 };
                const h = root.history.filter(x => x.d !== e.d).concat([e]).slice(-400);
                root.history = h;
                store.setText(JSON.stringify(h));
            }
        }
    }
    // Comprueba cada hora (y un minuto después de arrancar) si ya hay dato de hoy
    Timer { interval: 60000; running: root.loaded; onTriggered: root.tick() }
    Timer { interval: 3600000; running: root.loaded; repeat: true; onTriggered: root.tick() }
}
