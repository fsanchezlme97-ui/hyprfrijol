pragma Singleton
// Audio (PipeWire): volumen y silencio de la salida y del micrófono predeterminados.
// Listas para los selectores (components/AudioDevices.qml y AudioStreams.qml):
//   sinks / sources (dispositivos), streams (apps reproduciendo), kind(n) → "bluetooth" | "headphones" |
//   "hdmi" | "usb" | "speakers" | "mic" | "webcam", kindIcon(n), kindLabel(n), nodeName(n), appName(s), appIcon(s),
//   setDefault(n), refreshPorts() (puerto activo de cada salida con «pactl -f json list sinks») y portSets/setPort()
//   para elegir entre parlante y auricular de la misma tarjeta (scripts/hf-audio).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    // Sobreamplificar (Ajustes › Sonido, overAmplify): permite subir la salida hasta el 150 %
    readonly property real maxVolume: Settings.get("overAmplify", false) ? 1.5 : 1.0
    // Balance -1 (izquierda) … 1 (derecha) de la salida estéreo
    readonly property var volumes: sink?.audio?.volumes ?? []
    readonly property real balance: volumes.length === 2 && Math.max(volumes[0], volumes[1]) > 0 ? (volumes[1] - volumes[0]) / Math.max(volumes[0], volumes[1]) : 0
    function setBalance(b: real): void {
        if (!sink?.audio || sink.audio.volumes.length !== 2) return;
        const v = Math.max(sink.audio.volumes[0], sink.audio.volumes[1]), k = Math.max(-1, Math.min(1, b));
        sink.audio.volumes = [v * (k > 0 ? 1 - k : 1), v * (k < 0 ? 1 + k : 1)];
    }
    readonly property string sinkName: sink?.description ?? sink?.nickname ?? ""
    // Apps usando el micrófono (indicador de privacidad)
    readonly property var micUsers: Pipewire.linkGroups.values
        .filter(g => g.target === source && g.source?.isStream).map(g => g.source)

    function setVolume(v: real): void {
        if (!sink?.audio) return;
        sink.audio.muted = false;
        const x = Math.max(0, Math.min(maxVolume, v)), b = balance;
        if (b !== 0 && sink.audio.volumes.length === 2) sink.audio.volumes = [x * (b > 0 ? 1 - b : 1), x * (b < 0 ? 1 + b : 1)];
        else sink.audio.volume = x;
    }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function setMic(v: real): void { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function toggleMic(): void { if (source?.audio) source.audio.muted = !source.audio.muted; }

    // ── Listas de dispositivos y apps ──
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream && !String(n.name).includes(".monitor"))
    readonly property var streams: nodes.filter(n => n.isStream && String(n.properties?.["media.class"] ?? "").startsWith("Stream/Output"))
    function nodeName(n): string { return n ? (n.description || n.nickname || n.name || "") : ""; }
    function setDefault(n): void {
        if (!n) return;
        if (n.isSink) Pipewire.preferredDefaultAudioSink = n;
        else Pipewire.preferredDefaultAudioSource = n;
    }
    // puerto activo (pactl) por nombre de salida: { "alsa_output…": "headphones" | "lineout" | "speaker" | "hdmi" … }
    property var ports: ({})
    // puertos elegibles por salida: { "alsa_output…": { active: "analog-output-headphones", list: [{ name, label, type }] } }
    // (solo si tiene 2 o más disponibles: parlante + auricular en la misma tarjeta)
    property var portSets: ({})
    function setPort(sinkName: string, port: string): void {
        Quickshell.execDetached([Paths.script("hf-audio"), "port", sinkName, port]);
        portRefresh.restart();
    }
    Timer { id: portRefresh; interval: 400; onTriggered: root.refreshPorts() }
    function refreshPorts(): void { if (!portProc.running) portProc.running = true; }
    Process {
        id: portProc
        command: ["sh", "-c", "pactl -f json list sinks 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = {}, ps = {};
                    for (const s of JSON.parse(text)) {
                        const p = (s.ports ?? []).find(x => x.name === s.active_port);
                        m[s.name] = String((p?.type ?? "") + " " + (s.active_port ?? "")).toLowerCase();
                        const av = (s.ports ?? []).filter(x => x.availability !== "not available");
                        if (av.length > 1)
                            ps[s.name] = { active: s.active_port, list: av.map(x => ({ name: x.name, type: x.type,
                                label: x.type === "Line" ? "Parlante (línea)" : x.type === "Speaker" ? "Parlante" : x.description })) };
                    }
                    root.ports = m;
                    root.portSets = ps;
                } catch (e) { root.ports = {}; root.portSets = {}; }
            }
        }
    }
    onSinkChanged: refreshPorts()
    function kind(n): string {
        if (!n) return "speakers";
        const p = n.properties ?? {}, name = String(n.name ?? "").toLowerCase();
        const ff = String(p["device.form-factor"] ?? "").toLowerCase(), icon = String(p["device.icon-name"] ?? "").toLowerCase();
        const port = ports[n.name] ?? "";
        if (String(p["device.api"] ?? "") === "bluez5" || name.startsWith("bluez")) return "bluetooth";
        if (ff === "webcam") return "webcam";
        if (/headphone|headset|hands-free|earbud/.test(ff + " " + icon) || /headphone|headset/.test(port)) return "headphones";
        if (/hdmi|displayport/.test(name + " " + port) || /hdmi|displayport/.test(String(p["device.profile.name"] ?? ""))) return "hdmi";
        if (!n.isSink) return "mic";
        if (String(p["device.bus"] ?? "") === "usb") return "usb";
        return "speakers";
    }
    function kindIcon(n): string {
        const k = kind(n);
        return k === "bluetooth" ? "bluetooth" : k === "headphones" ? "headphones" : k === "hdmi" ? "hdmi"
             : k === "webcam" ? "camera" : k === "mic" ? "mic" : k === "usb" ? "headphones" : "speaker";
    }
    function kindLabel(n): string {
        const k = kind(n), p = n?.properties ?? {};
        return k === "bluetooth" ? "Bluetooth" + (p["api.bluez5.codec"] ? " · " + String(p["api.bluez5.codec"]).toUpperCase() : "")
             : k === "headphones" ? (n?.isSink ? "Auriculares" : "Micrófono de los auriculares") : k === "hdmi" ? "HDMI / DisplayPort"
             : k === "webcam" ? "Micrófono de la webcam" : k === "usb" ? (n?.isSink ? "USB" : "Micrófono USB")
             : k === "mic" ? (String(p["device.bus"] ?? "") === "usb" ? "Micrófono USB" : "Micrófono integrado") : "Altavoces";
    }
    function appName(s): string {
        const p = s?.properties ?? {};
        return String(p["application.name"] ?? "") || nodeName(s);
    }
    function appIcon(s): string {
        const p = s?.properties ?? {};
        for (const k of [p["application.icon-name"], p["application.icon_name"]]) { if (k) { const x = Quickshell.iconPath(String(k), true); if (x) return x; } }
        for (const k of [p["application.process.binary"], p["pipewire.access.portal.app_id"], p["application.id"], p["application.name"]]) {
            if (!k) continue;
            const x = HyprClients.iconFor(String(k));
            if (x) return x;
        }
        return "";
    }

    PwObjectTracker { objects: [root.sink, root.source] }
}
