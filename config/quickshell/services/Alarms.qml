pragma Singleton
// Alarmas a una hora del día (pestaña «Alarmas» de la ventana del pomodoro). Se guardan en Ajustes (`alarms`):
//   [{ id, h, m, label, days: [1..7] (lunes = 1; vacío = una sola vez), on }]
// Suenan al llegar el minuto (alarm-clock-elapsed, tres veces) con un aviso urgente que trae «Posponer 5 min» y
// «Detener». Una alarma de una sola vez se apaga sola al sonar. Las pospuestas viven solo en memoria.
//   add(h, m, label, days) · update(id, cambios) · remove(id) · toggle(id) · snooze(id, min) · next (la próxima)
// IPC:  qs … ipc call alarms list | add <HH:MM> <etiqueta> | snooze <id> | stop <id>
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property var list: (Settings.get("alarms", []) ?? []).filter(a => a && a.id)
    readonly property int count: list.length
    readonly property bool sound: Settings.get("systemSounds", true) !== false
    property var snoozed: []          // [{ id, at (ms), label }]
    property string lastKey: ""       // «AAAA-MM-DD HH:MM» del último minuto revisado (no suena dos veces)
    readonly property var dayNames: ["L", "M", "X", "J", "V", "S", "D"]

    function save(l): void { Settings.set("alarms", l); }
    function add(h: int, m: int, label: string, days): string {
        const id = Date.now().toString(36);
        save(list.concat([{ id: id, h: Math.max(0, Math.min(23, h)), m: Math.max(0, Math.min(59, m)),
                            label: String(label ?? "").trim().slice(0, 60), days: (days ?? []).slice().sort(), on: true }]));
        return id;
    }
    function update(id: string, ch): void { save(list.map(a => a.id === id ? Object.assign({}, a, ch) : a)); }
    function remove(id: string): void { save(list.filter(a => a.id !== id)); snoozed = snoozed.filter(s => s.id !== id); }
    function toggle(id: string): void { const a = list.find(x => x.id === id); if (a) update(id, { on: !a.on }); }
    function snooze(id: string, min: int): void {
        const a = list.find(x => x.id === id);
        snoozed = snoozed.filter(s => s.id !== id).concat([{ id: id, at: Date.now() + Math.max(1, min) * 60000, label: a?.label ?? "" }]);
    }
    function stop(id: string): void { snoozed = snoozed.filter(s => s.id !== id); }

    function hhmm(a): string { return String(a.h).padStart(2, "0") + ":" + String(a.m).padStart(2, "0"); }
    function daysText(a): string {
        const d = a.days ?? [];
        if (!d.length) return "Una vez";
        if (d.length === 7) return "Todos los días";
        if (d.join() === "1,2,3,4,5") return "Entre semana";
        if (d.join() === "6,7") return "Fines de semana";
        return d.map(x => dayNames[x - 1]).join(" ");
    }
    // Próximo disparo (ms) de una alarma encendida, o 0
    function nextAt(a, from): real {
        if (!a?.on) return 0;
        const base = new Date(from);
        for (let i = 0; i < 8; i++) {
            const t = new Date(base.getFullYear(), base.getMonth(), base.getDate() + i, a.h, a.m, 0, 0);
            if (t.getTime() <= from) continue;
            const wd = (t.getDay() + 6) % 7 + 1;
            if (!(a.days ?? []).length || a.days.includes(wd)) return t.getTime();
        }
        return 0;
    }
    property real now: Date.now()
    readonly property var next: {
        let best = null;
        for (const a of list) { const t = nextAt(a, now); if (t && (!best || t < best.at)) best = { id: a.id, at: t, label: a.label, time: hhmm(a) }; }
        for (const s of snoozed) if (!best || s.at < best.at) best = { id: s.id, at: s.at, label: s.label, time: Qt.formatTime(new Date(s.at), "HH:mm") };
        return best;
    }
    function untilText(ms: real): string {
        const m = Math.max(0, Math.round((ms - now) / 60000)), h = Math.floor(m / 60);
        return m < 1 ? "ahora" : h ? "en " + h + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : "en " + m + " min";
    }

    function ring(id: string, label: string): void {
        if (sound)
            Quickshell.execDetached(["sh", "-c", "for i in 1 2 3; do canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null "
                + "|| pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null "
                + "|| pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || break; done"]);
        const qs = "qs -p '" + Paths.root + "/config/quickshell' ipc call alarms";
        Quickshell.execDetached(["sh", "-c", 'a=$(notify-send -u critical -a Alarma -i alarm-clock -A snooze="Posponer 5 min" -A stop=Detener "$1" "$2"); '
            + '[ "$a" = snooze ] && ' + qs + ' snooze "$3"', "sh", "⏰ " + (label || "Alarma"), Qt.formatTime(new Date(), "HH:mm"), id]);
    }
    function check(): void {
        const d = new Date();
        now = d.getTime();
        const key = Qt.formatDateTime(d, "yyyy-MM-dd HH:mm");
        if (key !== lastKey) {
            lastKey = key;
            const wd = (d.getDay() + 6) % 7 + 1;
            let off = [];
            for (const a of list) {
                if (!a.on || a.h !== d.getHours() || a.m !== d.getMinutes()) continue;
                if ((a.days ?? []).length && !a.days.includes(wd)) continue;
                ring(a.id, a.label);
                if (!(a.days ?? []).length) off.push(a.id);
            }
            if (off.length) save(list.map(a => off.includes(a.id) ? Object.assign({}, a, { on: false }) : a));
        }
        const due = snoozed.filter(s => s.at <= now);
        if (due.length) { snoozed = snoozed.filter(s => s.at > now); for (const s of due) ring(s.id, s.label); }
    }
    // Revisa cada pocos segundos (no hace falta más: la alarma suena dentro de su minuto)
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.check() }
    Component.onCompleted: lastKey = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")   // al arrancar no suena lo de este minuto

    IpcHandler {
        target: "alarms"
        function list(): string { return JSON.stringify(root.list); }
        function add(time: string, label: string): string {
            const m = /^(\d{1,2}):(\d{2})$/.exec(String(time).trim());
            return m ? root.add(+m[1], +m[2], label, []) : "formato: HH:MM";
        }
        function snooze(id: string): void { root.snooze(id, 5); }
        function stop(id: string): void { root.stop(id); }
        function remove(id: string): void { root.remove(id); }
    }
}
