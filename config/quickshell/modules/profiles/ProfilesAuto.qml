// «Cambiar solo» de los perfiles (ajuste "profileRules", ver Profiles.qml): cambia de perfil al conectar un monitor,
// en un horario o al abrir ciertas apps. Siempre cargado; la vista «perfiles» se carga al abrirla y lee `rules` de aquí.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../.."

Scope {
    id: win
    property string current: ""
    FileView {
        path: Paths.state + "/profile"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: win.current = text().trim() || "trabajo"
        onLoadFailed: win.current = "trabajo"
    }
    function apply(k: string): void {
        current = k;
        Quickshell.execDetached([Paths.script("hf-profile"), k]);
    }
    readonly property var defaultRules: [
        { id: "monitor", on: true, kind: "monitor", value: "DP-1", label: "Al conectar el monitor DP-1 de la oficina", profile: "trabajo" },
        { id: "horario", on: true, kind: "horario", value: "1-5 09:00-18:00", label: "Lunes a viernes de 9:00 a 18:00", profile: "trabajo" },
        { id: "juegos", on: true, kind: "app", value: "^(steam|steam_app_.*|gamescope|heroic|lutris)$", label: "Al abrir Steam o un juego", profile: "juego" },
        { id: "3d", on: false, kind: "app", value: "^(orca-slicer|OrcaSlicer|blender|Blender|org.freecad.FreeCAD|FreeCAD)$", label: "Al abrir OrcaSlicer o Blender", profile: "diseno" }
    ]
    readonly property var rules: {
        const u = Settings.get("profileRules", null);
        if (!Array.isArray(u)) return defaultRules;
        return u;
    }
    function autoSwitch(k: string, why: string): void {
        if (!k || k === current) return;
        console.info("[perfiles] cambio automático → " + k + " (" + why + ")");
        apply(k);
    }
    function inSchedule(v: string, d): bool {
        // "1-5 09:00-18:00"  (días 1=lunes … 7=domingo)
        const m = /^(\d)-(\d)\s+(\d\d?):(\d\d)-(\d\d?):(\d\d)$/.exec(String(v).trim());
        if (!m) return false;
        const wd = d.getDay() === 0 ? 7 : d.getDay(), mins = d.getHours() * 60 + d.getMinutes();
        return wd >= +m[1] && wd <= +m[2] && mins >= +m[3] * 60 + +m[4] && mins < +m[5] * 60 + +m[6];
    }
    property bool wasInSchedule: true      // no cambiar al arrancar si ya estábamos dentro del horario
    Timer {
        running: true; repeat: true; interval: 60000; triggeredOnStart: true
        onTriggered: {
            const r = win.rules.find(x => x.on && x.kind === "horario");
            if (!r) return;
            const inside = win.inSchedule(r.value, new Date());
            if (inside && !win.wasInSchedule) win.autoSwitch(r.profile, "horario");
            win.wasInSchedule = inside;
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "monitoradded" || ev.name === "monitoraddedv2") {
                const name = ev.name === "monitoradded" ? ev.data : String(ev.data).split(",")[1];
                const r = win.rules.find(x => x.on && x.kind === "monitor" && x.value === name);
                if (r) win.autoSwitch(r.profile, "monitor " + name);
            } else if (ev.name === "openwindow") {
                const cls = String(ev.data).split(",")[2] ?? "";
                for (const r of win.rules) {
                    if (!r.on || r.kind !== "app") continue;
                    try { if (new RegExp(r.value, "i").test(cls)) { win.autoSwitch(r.profile, "app " + cls); break; } } catch (e) {}
                }
            }
        }
    }
}
