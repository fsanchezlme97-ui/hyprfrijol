// Lo que los ajustes necesitan «vivo» mientras corre el shell:
//  · Luz nocturna (hyprsunset) según nightLight/nightTemp/nightFrom/nightTo (o el sol: services/Sun.qml)
//  · Tema claro/oscuro automático (themeMode = "auto"): vuelve a aplicar al cruzar lightFrom/lightTo o, con
//    themeSchedule = "sol", el amanecer/atardecer (la misma fuente que la luz nocturna)
//  · Ahorro automático con batería baja y vidrio sin desenfoque con batería
//  · Esquinas calientes (hotCorners)
//  · Lector de pantalla (Orca) al iniciar si está activado
//  · Reglas de notificaciones por app, sonido y «no molestar» programado (NotifRules.qml)
//  · Historial diario de la salud de la batería (BatteryLog.qml)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../.."
import "../../services"

Scope {
    id: root

    NotifRules {}
    BatteryLog {}       // historial diario de la salud de la batería (battery-history.json)

    // ---------- luz nocturna ----------
    function hm(s: string): int { const p = String(s || "0:0").split(":"); return parseInt(p[0]) * 60 + (parseInt(p[1]) || 0); }
    function inRange(now: int, a: int, b: int): bool { return a <= b ? (now >= a && now < b) : (now >= a || now < b); }
    readonly property string nlMode: Settings.get("nightLight", "off")
    readonly property int nlTemp: Settings.get("nightTemp", 4000)
    property bool nlOn: false
    property int nlApplied: -1
    function nightTick(): void {
        const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
        let on = false;
        if (nlMode === "atardecer") on = !Sun.isDay(now);
        else if (nlMode === "horario") on = inRange(now, hm(Settings.get("nightFrom", "22:00")), hm(Settings.get("nightTo", "07:00")));
        else if (nlMode === "siempre") on = true;
        const want = on ? nlTemp : 0;
        if (want === nlApplied) return;
        nlApplied = want; nlOn = on;
        // hf-sunset: solo el hyprsunset de esta sesión (una prueba anidada no apaga el de la tuya)
        Quickshell.execDetached(on ? [Paths.script("hf-sunset"), "set", String(nlTemp)] : [Paths.script("hf-sunset"), "off"]);
    }
    onNlModeChanged: nightTick()
    onNlTempChanged: { nlApplied = -1; nightTick(); }

    // ---------- tema automático ----------
    property var lastLight: null
    property real lastFix: 0
    function themeTick(): void {
        if (Settings.get("themeMode", "oscuro") !== "auto") { lastLight = null; return; }
        const d = new Date(), h = d.getHours();
        const light = Settings.get("themeSchedule", "horas") === "sol" ? Sun.isDay(h * 60 + d.getMinutes())
            : Settings.get("lightFrom", 7) <= h && h < Settings.get("lightTo", 19);
        if (lastLight !== null && light !== lastLight) {
            Settings.apply();
            if (Settings.get("themeWallpaper", false)) Quickshell.execDetached([Paths.script("hf-wallpaper"), "next"]);
        } else if (light !== Theme.light && Date.now() - lastFix > 120000) {
            // hf-apply decide por su cuenta (mismo cálculo): si el tema aplicado no coincide, se reaplica
            lastFix = Date.now();
            Settings.apply();
        }
        lastLight = light;
    }
    // Al cambiar el horario (o las horas del sol) se recalcula enseguida. Sun solo se usa si hace falta
    // (así no se pregunta la ubicación a quien no usa el sol).
    readonly property bool needSun: Settings.get("themeSchedule", "horas") === "sol" || nlMode === "atardecer"
    readonly property string sched: Settings.get("themeMode", "oscuro") + Settings.get("themeSchedule", "horas") + Settings.get("lightFrom", 7)
        + "-" + Settings.get("lightTo", 19) + (needSun ? Sun.sunrise + Sun.sunset : "")
    onSchedChanged: if (Settings.loaded) { nightTick(); themeTick(); }

    Timer {
        interval: 30000; running: Settings.loaded; repeat: true; triggeredOnStart: true
        onTriggered: { root.nightTick(); root.themeTick(); root.batteryTick(); }
    }

    // ---------- batería ----------
    property bool saverDone: false
    property bool blurOff: false
    function batteryTick(): void {
        if (!Battery.present) return;
        if (Battery.onBattery && Battery.percent < 0.2 && Settings.get("lowBatterySaver", true) && !saverDone) {
            saverDone = true;
            if (Battery.profile !== "ahorro") Battery.setProfile("ahorro");
        }
        if (!Battery.onBattery) saverDone = false;
        const wantOff = Battery.onBattery && Settings.get("blurOnBattery", true) && Theme.blur;
        if (wantOff !== blurOff) {
            blurOff = wantOff;
            if (wantOff) Shell.dispatch("hl.config({ decoration = { blur = { enabled = false } } })");
            else Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
        }
    }
    Connections { target: Battery; function onOnBatteryChanged() { root.batteryTick(); } }


    // (La suspensión por inactividad la hace hypridle: config/apply/85-idle.py genera hypridle.conf)

    // ---------- cambiar a auriculares al conectarlos ----------
    property var knownSinks: null
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    onSinksChanged: {
        const ids = sinks.map(n => n.id);
        if (knownSinks !== null && Settings.get("audioAutoSwitch", true)) {
            const fresh = sinks.find(n => !knownSinks.includes(n.id) && /bluez|usb/i.test(String(n.name)));
            if (fresh) Pipewire.preferredDefaultAudioSink = fresh;
        }
        if (Pipewire.ready) knownSinks = ids;
    }

    // ---------- brillo automático (sensor de luz iio) ----------
    Process {
        id: lux
        command: ["sh", "-c", "cat /sys/bus/iio/devices/*/in_illuminance_raw 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text); if (isNaN(v)) return;
                const target = Math.max(0.15, Math.min(1, Math.log10(Math.max(1, v)) / 3));
                if (Math.abs(target - Brightness.value) > 0.08) Brightness.set(target);
            }
        }
    }
    Timer { interval: 15000; running: Settings.get("autoBrightness", false); repeat: true; onTriggered: lux.running = true }

    // ---------- lector de pantalla ----------
    Component.onCompleted: if (Settings.get("screenReader", false)) Quickshell.execDetached(["sh", "-c", "pgrep -x orca >/dev/null || setsid orca --replace >/dev/null 2>&1 &"])

    // ---------- una vez por sesión: teclado en pantalla, audio mono, EasyEffects y fondo al iniciar ----------
    Timer {
        running: !Quickshell.env("HF_TRY")
        interval: 3000
        onTriggered: {
            const c = ['m="${XDG_RUNTIME_DIR:-/tmp}/hf-session-started"; [ -e "$m" ] && exit 0; touch "$m"'];
            if (Settings.get("osk", false)) c.push("(command -v wvkbd-mobintl >/dev/null && setsid wvkbd-mobintl -H 0 >/dev/null 2>&1 &) || (command -v squeekboard >/dev/null && setsid squeekboard >/dev/null 2>&1 &)");
            if (Settings.get("monoAudio", false)) c.push("pactl list short sinks | grep -q hf-mono || { s=$(pactl get-default-sink); pactl load-module module-remap-sink sink_name=hf-mono sink_properties=device.description=Mono master=$s channels=2 channel_map=mono,mono >/dev/null && pactl set-default-sink hf-mono; }");
            if (Settings.get("noiseSuppression", false)) c.push("pgrep -x easyeffects >/dev/null || setsid easyeffects --gapplication-service >/dev/null 2>&1 &");
            if (Settings.get("wallpaperOnStart", false))
                c.push("sleep 2; HF_QUIET=1 " + Paths.script("hf-wallpaper") + (Settings.get("wallpaperRandom", false) ? " random" : " next"));
            Quickshell.execDetached(["sh", "-c", c.join("\n")]);
        }
    }

    // ---------- modo sin distracciones: silenciar notificaciones mientras dura ----------
    property bool dndBefore: false
    Connections {
        target: Shell
        function onFocusModeChanged() {
            if (!Settings.get("focusMuteNotifs", true)) return;
            if (Shell.focusMode) { root.dndBefore = Notifs.dnd; Notifs.dnd = true; }
            else Notifs.dnd = root.dndBefore;
        }
    }

    // ---------- esquinas calientes ----------
    readonly property var corners: Settings.get("hotCorners", { tl: "vista", tr: "ninguna", bl: "ninguna", br: "escritorio" })
    readonly property int cornerDelay: Settings.get("hotCornerDelay", 150)
    // Las esquinas no reaccionan al arrancar (si el cursor ya estaba en una esquina abriría la vista sola)
    property bool cornersArmed: false
    Timer { interval: 2000; running: true; onTriggered: root.cornersArmed = true }
    function cornerAction(a: string): void {
        switch (a) {
        case "vista": Shell.toggle("vista"); break;
        case "ia": Shell.toggle("ia"); break;
        case "spotlight": Shell.toggle("spotlight"); break;
        case "notificaciones": Shell.toggle("notificaciones"); break;
        case "ajustes": Shell.toggle("ajustes"); break;
        case "bloquear": Quickshell.execDetached(["loginctl", "lock-session"]); break;
        case "escritorio": Shell.dispatch('hl.dsp.focus({ workspace = "empty" })'); break;
        }
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Variants {
                model: ["tl", "tr", "bl", "br"].filter(k => !["", "ninguna"].includes(root.corners[k] ?? "ninguna"))
                PanelWindow {
                    id: corner
                    required property string modelData
                    screen: perScreen.modelData
                    color: "transparent"
                    implicitWidth: 2
                    implicitHeight: 2
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "hf-hotcorner"
                    anchors {
                        top: corner.modelData[0] === "t"
                        bottom: corner.modelData[0] === "b"
                        left: corner.modelData[1] === "l"
                        right: corner.modelData[1] === "r"
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (root.cornersArmed) fire.restart()
                        onExited: fire.stop()
                    }
                    Timer { id: fire; interval: Math.max(1, root.cornerDelay); onTriggered: root.cornerAction(root.corners[corner.modelData]) }
                }
            }
        }
    }
}
