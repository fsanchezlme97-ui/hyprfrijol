pragma Singleton
// Impresora 3D: Moonraker (Klipper) u OctoPrint. Ajustes: printerUrl (p. ej. http://voron.local),
// printerKind "auto" | "moonraker" | "octoprint", printerApiKey (solo OctoPrint).
// Se consulta cada 5 s mientras alguien lo usa (Printer.users++ / --).
//   configured, online, kind, state ("printing"|"paused"|"standby"|"complete"|"error"|…), stateText,
//   file, progress (0–1), layer, layers, elapsed/left (s), nozzle/nozzleTarget, bed/bedTarget, camUrl
//   pause(), resume(), cancel(), openWeb()
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property int users: 0
    readonly property string url: String(Settings.get("printerUrl", "")).replace(/\/+$/, "")
    readonly property string kindSetting: Settings.get("printerKind", "auto")
    readonly property string apiKey: Settings.get("printerApiKey", "")
    readonly property bool configured: url !== ""
    property string kind: ""              // detectado
    property bool online: false
    property string err: ""
    property string state: ""
    property string file: ""
    property real progress: 0
    property int layer: 0
    property int layers: 0
    property real elapsed: 0
    property real left: -1
    property real nozzle: NaN
    property real nozzleTarget: 0
    property real bed: NaN
    property real bedTarget: 0
    property int camTick: 0
    readonly property string camUrl: !online ? "" : kind === "octoprint"
        ? url + "/webcam/?action=snapshot&t=" + camTick
        : url + "/webcam/?action=snapshot&t=" + camTick
    readonly property bool busy: state === "printing" || state === "paused"
    readonly property string stateText: ({
        printing: "Imprimiendo", paused: "En pausa", standby: "En espera", complete: "Terminada",
        cancelled: "Cancelada", error: "Error", operational: "En espera", offline: "Desconectada"
    })[state] ?? (state || "—")
    readonly property string brand: kind === "octoprint" ? "OctoPrint" : kind === "moonraker" ? "Klipper · Moonraker" : ""

    function dur(s: real): string {
        if (s < 0 || !isFinite(s)) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    function poll(): void {
        if (!configured) return;
        const k = kindSetting !== "auto" ? kindSetting : kind;
        if (k === "octoprint") {
            req.command = ["sh", "-c", 'printf "{\\"job\\":"; curl -fsS --max-time 4 -H "X-Api-Key: $2" "$1/api/job" || printf null; printf ",\\"printer\\":"; curl -fsS --max-time 4 -H "X-Api-Key: $2" "$1/api/printer" || printf null; printf "}"', "sh", url, apiKey];
            req.mode = "octoprint";
        } else {
            req.command = ["curl", "-fsS", "--max-time", "4", url + "/printer/objects/query?print_stats&display_status&extruder&heater_bed&virtual_sdcard"];
            req.mode = "moonraker";
        }
        req.running = true;
        camTick++;
    }
    function post(path: string, body: string): void {
        if (Quickshell.env("HF_TRY") === "1") { console.info("[impresora] (HF_TRY) POST " + path); return; }
        const args = ["curl", "-fsS", "--max-time", "5", "-X", "POST", url + path];
        if (kind === "octoprint") args.push("-H", "X-Api-Key: " + apiKey, "-H", "Content-Type: application/json", "-d", body);
        Quickshell.execDetached(args);
        later.restart();
    }
    function pause(): void { kind === "octoprint" ? post("/api/job", '{"command":"pause","action":"pause"}') : post("/printer/print/pause", ""); }
    function resume(): void { kind === "octoprint" ? post("/api/job", '{"command":"pause","action":"resume"}') : post("/printer/print/resume", ""); }
    function cancel(): void { kind === "octoprint" ? post("/api/job", '{"command":"cancel"}') : post("/printer/print/cancel", ""); }
    function openWeb(): void { Quickshell.execDetached(["xdg-open", url]); }

    Timer { running: root.users > 0 && root.configured; repeat: true; interval: 5000; triggeredOnStart: true; onTriggered: root.poll() }
    Timer { id: later; interval: 900; onTriggered: root.poll() }
    onUrlChanged: { kind = ""; online = false; state = ""; if (users > 0) poll(); }

    Process {
        id: req
        property string mode: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (req.mode === "moonraker") {
                        const s = d.result?.status;
                        if (!s) throw "no";
                        root.kind = "moonraker";
                        const ps = s.print_stats ?? {};
                        root.state = ps.state ?? "";
                        root.file = ps.filename ?? "";
                        root.progress = s.display_status?.progress ?? s.virtual_sdcard?.progress ?? 0;
                        root.layer = ps.info?.current_layer ?? 0;
                        root.layers = ps.info?.total_layer ?? 0;
                        root.elapsed = ps.print_duration ?? 0;
                        root.left = root.progress > 0.01 ? root.elapsed / root.progress - root.elapsed : -1;
                        root.nozzle = s.extruder?.temperature ?? NaN;
                        root.nozzleTarget = s.extruder?.target ?? 0;
                        root.bed = s.heater_bed?.temperature ?? NaN;
                        root.bedTarget = s.heater_bed?.target ?? 0;
                    } else {
                        if (!d.job) throw "no";
                        root.kind = "octoprint";
                        const st = String(d.job.state ?? "").toLowerCase();
                        root.state = st.startsWith("printing") ? "printing" : st.startsWith("paus") ? "paused"
                                   : st.startsWith("operational") ? "standby" : st.startsWith("error") ? "error" : st.startsWith("offline") ? "offline" : st;
                        root.file = d.job.job?.file?.name ?? "";
                        root.progress = (d.job.progress?.completion ?? 0) / 100;
                        root.elapsed = d.job.progress?.printTime ?? 0;
                        root.left = d.job.progress?.printTimeLeft ?? -1;
                        root.layer = 0; root.layers = 0;
                        const t = d.printer?.temperature ?? {};
                        root.nozzle = t.tool0?.actual ?? NaN; root.nozzleTarget = t.tool0?.target ?? 0;
                        root.bed = t.bed?.actual ?? NaN; root.bedTarget = t.bed?.target ?? 0;
                    }
                    root.online = true;
                    root.err = "";
                } catch (e) {
                    // Moonraker no respondió: en modo auto, probar OctoPrint
                    if (root.kindSetting === "auto" && req.mode === "moonraker" && root.kind === "" && root.apiKey) root.kind = "octoprint";
                    root.online = false;
                    root.err = "No responde " + root.url.replace(/^https?:\/\//, "");
                }
            }
        }
    }
}
