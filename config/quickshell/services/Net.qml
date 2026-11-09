pragma Singleton
// Red (NetworkManager vía nmcli): estado de Wi-Fi, red actual e intensidad. Se refresca cada 6 s
// y al instante tras cambiar algo. Para la lista de redes usa Net.scan() → Net.networks.
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property bool wifiEnabled: true
    property bool connected: false
    property string ssid: ""
    property int signal: 0
    property string type: ""          // "wifi" | "ethernet" | ""
    property var networks: []         // [{ ssid, signal, secure, active }]

    function refresh(): void { status.running = true; }
    function setWifi(on: bool): void { Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]); wifiEnabled = on; later.restart(); }
    function scan(): void { scanner.running = true; }
    function connect(ssid: string, password: string): void {
        Quickshell.execDetached(password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
                                         : ["nmcli", "device", "wifi", "connect", ssid]);
        later.restart();
    }

    // Cambios de conexión al momento por `nmcli monitor` (sin sondear); la intensidad de la señal no avisa, así que
    // se repasa cada 30 s. Antes eran tres nmcli cada 6 s.
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: later; interval: 1500; onTriggered: root.refresh() }
    Timer { id: soon; interval: 400; onTriggered: root.refresh() }
    Process {
        id: monitor
        running: true
        command: Paths.reaper.concat(["nmcli", "monitor"])
        stdout: SplitParser { onRead: _ => soon.restart() }
        // NetworkManager reiniciado o nmcli que falta: se reintenta, sin agobiar
        onRunningChanged: if (!running) retry.start()
    }
    Timer { id: retry; interval: 20000; onTriggered: monitor.running = true }

    Process {
        id: status
        command: ["sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f TYPE,STATE,CONNECTION device | grep ':connected:' | head -1; nmcli -t -f ACTIVE,SSID,SIGNAL device wifi 2>/dev/null | grep '^yes' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.wifiEnabled = (l[0] ?? "") === "enabled";
                const dev = (l.find(x => x.includes(":connected:")) ?? "").split(":");
                root.connected = dev.length > 1;
                root.type = dev[0] === "802-11-wireless" || dev[0] === "wifi" ? "wifi" : dev[0] === "ethernet" ? "ethernet" : dev[0] ?? "";
                const w = (l.find(x => x.startsWith("yes:")) ?? "").split(":");
                root.ssid = w.length > 2 ? w[1] : (root.type === "ethernet" ? "Cable" : dev[2] ?? "");
                root.signal = w.length > 2 ? parseInt(w[2]) : (root.connected ? 100 : 0);
            }
        }
    }
    Process {
        id: scanner
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                root.networks = text.trim().split("\n").filter(Boolean).map(l => {
                    const f = l.split(":");
                    return { active: f[0] === "yes", ssid: f[1], signal: parseInt(f[2]) || 0, secure: (f[3] ?? "") !== "" };
                }).filter(n => n.ssid && !seen[n.ssid] && (seen[n.ssid] = true))
                  .sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
            }
        }
    }
}
