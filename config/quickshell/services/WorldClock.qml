pragma Singleton
// Relojes del mundo (ajuste worldClocks: [["Madrid", "Europe/Madrid"], …]; Ajustes › Fecha, hora e idioma).
//   WorldClock.clocks          [{ name, tz, time "18:25", diff "+6 h" / "misma hora", day "mañana"/"ayer"/"" , offset (min) }]
//   WorldClock.zones           todas las zonas de /usr/share/zoneinfo/zone.tab con ciudad y país en español
//                              [{ tz, city, country, cc, key (para buscar, sin tildes) }]
//   WorldClock.search("peru")  filtra zones por ciudad, país o zona
//   WorldClock.add(tz) · remove(i) · move(i, d)
// La hora de cada zona se calcula aquí cada segundo con su desfase (TZ=… date +%z, que se relee cada 10 min
// y al cambiar la lista), así que no lanza un proceso por segundo. Nombres: services/zonas-es.json.
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property int users: 0                  // quien enseña horas: WorldClock.users++ / --
    readonly property var list: Settings.get("worldClocks", [])
    property var names: ({ countries: {}, cities: {} })
    property var offsets: ({})             // tz → minutos respecto a UTC
    readonly property var clocks: {
        const now = Time.now, mine = -now.getTimezoneOffset(), out = [];
        for (const z of list) {
            const tz = z[1], off = offsets[tz];
            if (off === undefined) { out.push({ name: z[0], tz: tz, time: "--:--", diff: "", day: "", offset: 0 }); continue; }
            const t = new Date(now.getTime() + (off - mine) * 60000);
            const d = (off - mine) / 60;
            const dd = Math.round((new Date(t.getFullYear(), t.getMonth(), t.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
            out.push({
                name: z[0], tz: tz, offset: off,
                time: Time.fmtHM(String(t.getHours()).padStart(2, "0") + ":" + String(t.getMinutes()).padStart(2, "0")),
                diff: d === 0 ? "misma hora" : (d > 0 ? "+" : "−") + String(Math.abs(d)).replace(".", ",") + " h",
                day: dd > 0 ? "mañana" : dd < 0 ? "ayer" : ""
            });
        }
        return out;
    }

    function norm(s): string { return String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
    readonly property var byTz: { const m = {}; for (const z of zones) m[z.tz] = z; return m; }
    // «America/Lima» → «Lima · Perú» (nombres en español de zonas-es.json)
    function label(tz: string): string {
        const z = byTz[tz];
        return z ? z.city + " · " + z.country : tz.replace(/_/g, " ").replace(/\//g, " · ");
    }
    function cityOf(tz: string): string { return names.cities[tz] ?? tz.split("/").pop().replace(/_/g, " "); }
    function search(q: string): var {
        const n = norm(q.trim());
        if (!n) return zones;
        const words = n.split(/\s+/);
        return zones.filter(z => words.every(w => z.key.includes(w)));
    }
    function add(tz: string): void {
        if (list.some(c => c[1] === tz)) return;
        Settings.set("worldClocks", list.concat([[cityOf(tz), tz]]));
    }
    function remove(i: int): void { const c = list.slice(); c.splice(i, 1); Settings.set("worldClocks", c); }
    function move(i: int, d: int): void {
        const j = i + d;
        if (j < 0 || j >= list.length) return;
        const c = list.slice(); const t = c[i]; c[i] = c[j]; c[j] = t;
        Settings.set("worldClocks", c);
    }
    // La orden se monta aquí y no con un enlace: onListChanged llega antes de que el enlace se recalcule y el proceso
    // salía con la lista vieja (vacía al arrancar) → relojes en «--:--» hasta la vuelta de 10 min
    function refresh(): void {
        if (!list.length) return;
        offProc.running = false;
        offProc.command = ["sh", "-c", 'for z; do printf "%s %s\\n" "$z" "$(TZ="$z" date +%z)"; done', "sh"].concat(list.map(z => z[1]));
        offProc.running = true;
    }
    // «list» cambia de referencia con cualquier ajuste: solo se recalcula si cambian los relojes
    property string _listKey: ""
    onListChanged: { const k = JSON.stringify(list); if (k !== _listKey) { _listKey = k; refresh(); } }
    // El servicio puede nacer con la lista ya leída (sin cambio que avise): se piden los desfases al crearse
    Component.onCompleted: { _listKey = JSON.stringify(list); refresh(); }

    property string tab: ""
    readonly property var zones: {
        const out = [], n = names;
        for (const l of tab.split("\n")) {
            if (!l || l[0] === "#") continue;
            const f = l.split("\t");
            if (f.length < 3) continue;
            const cc = f[0], tz = f[2], city = n.cities[tz] ?? tz.split("/").pop().replace(/_/g, " "), country = n.countries[cc] ?? cc;
            out.push({ tz: tz, cc: cc, city: city, country: country, key: norm(city + " " + country + " " + tz.replace(/[_/]/g, " ")) });
        }
        if (out.length) out.push({ tz: "UTC", cc: "", city: "UTC", country: "Tiempo universal", key: "utc gmt tiempo universal coordinado" });
        return out.sort((a, b) => a.city.localeCompare(b.city, "es"));
    }
    FileView {
        path: Paths.root + "/config/quickshell/services/zonas-es.json"
        printErrors: false
        onLoaded: { try { root.names = JSON.parse(text()); } catch (e) {} }
    }
    // zone.tab: una línea por zona con su país (Europe/Madrid → ES)
    FileView {
        path: "/usr/share/zoneinfo/zone.tab"
        printErrors: false
        onLoaded: root.tab = text()
    }

    Process {
        id: offProc
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const m = l.match(/^(\S+) ([+-])(\d\d)(\d\d)$/);
                    if (m) o[m[1]] = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]));
                }
                root.offsets = o;
            }
        }
    }
    Timer { interval: 600000; running: root.list.length > 0; repeat: true; onTriggered: root.refresh() }
}
