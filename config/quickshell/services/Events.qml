pragma Singleton
// Eventos del calendario para la agenda y el resto del shell.
// Fuentes:
//   - Locales: ~/.local/share/hyprfrijol/events.json  (add / remove desde la agenda)
//   - .ics:    ajuste "calendarIcs" = [{ url, name, color }, …] (o solo la URL/ruta como texto; Ajustes › Fecha)
//              color = token del tema ("p", "ter", "tv", "danger"…) o "#RRGGBB". curl cada 15 min, copia en
//              ~/.cache/hyprfrijol/ics/<hash>.ics (si falla la descarga se usa la última copia).
//              Se expanden RRULE sencillas (DAILY/WEEKLY/MONTHLY/YEARLY).
// API:
//   Events.forDay(date)        → eventos de ese día (ordenados)
//   Events.hasDay(date)       → ¿hay algo ese día?
//   Events.next            → próximo evento (o null)  { title, start, end, allDay, where, link, color, source }
//   Events.nextLabel       → "Reunión · en 19 min"
//   Events.add({ title, start: Date, end: Date, allDay, where, link }) / Events.remove(ev) / Events.refresh()
//   Events.calendars       → [{ url, name, color }] normalizados · Events.status → [{ ok, error, count }] por calendario
//   Events.lastSync        → Date de la última descarga (o null) · Events.tint(color) → color de QML
// IPC:  qs … ipc call events next | refresh
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property string store: Paths.home + "/.local/share/hyprfrijol/events.json"
    readonly property string icsDir: Paths.cache + "/ics"
    readonly property var defaultColors: ["p", "ter", "#3FB27F", "#F2A33A"]
    readonly property var calendars: {
        const v = Settings.get("calendarIcs", []);
        const arr = Array.isArray(v) ? v : (v ? String(v).split(/[\s,]+/) : []);
        return arr.map((c, i) => typeof c === "string" ? { url: c, name: "", color: "" } : (c && c.url ? { url: String(c.url), name: String(c.name ?? ""), color: String(c.color ?? "") } : null))
                  .filter(c => c && c.url.trim())
                  .map((c, i) => ({ url: c.url.trim(), name: c.name || calName(c.url), color: c.color || defaultColors[i % defaultColors.length] }));
    }
    readonly property var sources: calendars.map(c => c.url)
    property var status: []             // [{ ok, error, count }] en el orden de calendars
    property var lastSync: null
    // Nombre por defecto: el archivo o el dominio
    function calName(u: string): string {
        const s = String(u).replace(/[?#].*$/, "").replace(/\/+$/, "");
        const f = decodeURIComponent(s.split("/").pop() || "").replace(/\.ics$/i, "");
        if (/^(https?|webcal):/i.test(s)) { const h = s.replace(/^\w+:\/\//, "").split("/")[0]; return f && f !== "basic" ? f : h; }
        return f || s;
    }
    // Errores de curl en español
    function errText(m: string): string {
        const t = String(m).trim(), keep = / \(se usa la última copia\)$/.test(t) ? " (se usa la última copia)" : "";
        const c = (t.match(/^\((\d+)\)/) ?? [])[1], http = (t.match(/error: (\d{3})/) ?? [])[1];
        const base = c === "6" ? "no se encuentra el servidor" : c === "7" ? "no se pudo conectar"
                   : c === "28" ? "tiempo de espera agotado" : c === "22" ? "el servidor respondió " + (http || "con un error")
                   : c === "35" || c === "60" ? "error de certificado (TLS)" : c === "3" ? "dirección no válida" : "";
        return base ? base + keep : t;
    }
    function tint(c): color {
        const k = String(c ?? "");
        if (/^#[0-9a-f]{6}$/i.test(k)) return k;
        return Theme[k] ?? Theme.p;
    }

    property var local: []              // eventos guardados (fechas en ISO)
    property var remote: []             // eventos de los .ics (ya expandidos)
    property bool loading: false
    readonly property var all: {
        const l = local.map(e => ({ id: e.id, title: e.title, start: new Date(e.start), end: new Date(e.end || e.start),
                                    allDay: !!e.allDay, where: e.where || "", link: e.link || linkIn(e.where || ""),
                                    color: e.color || "p", source: "local" }));
        return l.concat(remote).sort((a, b) => a.start - b.start);
    }
    // índice "AAAA-MM-DD" → [eventos]
    readonly property var byDay: {
        const m = {};
        for (const e of all) {
            const d = new Date(e.start); d.setHours(0, 0, 0, 0);
            const last = new Date(e.allDay ? e.end - 1 : e.end); last.setHours(0, 0, 0, 0);
            for (let i = 0; d <= last && i < 60; i++, d.setDate(d.getDate() + 1)) (m[key(d)] = m[key(d)] || []).push(e);
        }
        return m;
    }
    readonly property var next: {
        const now = Time.now;
        return all.find(e => !e.allDay && e.end > now) ?? null;
    }
    readonly property string nextLabel: next ? next.title + " · " + relative(next.start) : ""

    function key(d): string { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
    function forDay(d): var { return byDay[key(d)] ?? []; }
    function hasDay(d): bool { return !!byDay[key(d)]; }
    function hhmm(d): string { return Qt.formatDateTime(d, "HH:mm"); }
    function relative(d): string {
        const min = Math.round((d - Time.now) / 60000);
        if (min <= 0) return "ahora";
        if (min < 60) return "en " + min + " min";
        if (min < 24 * 60) return "en " + Math.floor(min / 60) + " h" + (min % 60 ? " " + (min % 60) + " min" : "");
        return Qt.locale("es_ES").toString(d, "ddd d MMM").replace(/\./g, "") + " " + hhmm(d);
    }
    // Enlace de videollamada (Meet, Zoom, Teams, Jitsi…)
    function linkIn(s: string): string {
        const m = String(s).match(/https?:\/\/(meet\.google\.com|[\w.-]*zoom\.us|teams\.microsoft\.com|teams\.live\.com|meet\.jit\.si|[\w.-]*webex\.com|whereby\.com)\/[^\s"<>\\]*/i);
        return m ? m[0] : "";
    }

    function add(ev): void {
        const e = { id: String(Date.now()), title: ev.title || "Evento", start: ev.start.toISOString(),
                    end: (ev.end || new Date(ev.start.getTime() + 3600000)).toISOString(),
                    allDay: !!ev.allDay, where: ev.where || "", link: ev.link || "", color: ev.color || "p" };
        local = local.concat([e]);
        save();
    }
    function remove(ev): void {
        if (!ev || ev.source !== "local") return;
        local = local.filter(e => e.id !== ev.id);
        save();
    }
    function save(): void { storeFile.setText(JSON.stringify(local, null, 1)); }
    function refresh(): void {
        if (!sources.length) { remote = []; status = []; return; }
        loading = true;
        fetchSoon.restart();
    }
    // Agrupa varias peticiones seguidas y no corta una descarga en marcha
    Timer {
        id: fetchSoon
        interval: 300
        onTriggered: { if (fetcher.running) fetcher.again = true; else fetcher.running = true; }
    }

    FileView {
        id: storeFile
        path: root.store
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.local = JSON.parse(text()) || []; } catch (e) { root.local = []; } }
        onLoadFailed: root.local = []
    }

    // Descarga (o copia) cada .ics y los imprime separados por una marca
    Process {
        id: fetcher
        property bool again: false
        onExited: if (again) { again = false; fetchSoon.restart(); }
        // Por calendario imprime «@@HF-ICS@@ <n> ok|err <motivo>» y después el .ics (o la última copia guardada)
        command: ["bash", "-c", 'd="$1"; shift; mkdir -p "$d"; i=0; for u; do i=$((i+1)); f="$d/$(printf %s "$u" | md5sum | cut -c1-16).ics"; st=ok; msg=""; '
            + 'case "$u" in http*|webcal*) if msg=$(curl -fsSL --max-time 20 "$(printf %s "$u" | sed "s#^webcal#https#")" -o "$f.tmp" 2>&1); then mv "$f.tmp" "$f"; '
            + 'else st=err; rm -f "$f.tmp"; msg="${msg#curl: }"; [ -s "$f" ] && msg="$msg (se usa la última copia)"; fi;; '
            + '*) p="${u#file://}"; p="${p/#\\~/$HOME}"; if [ -r "$p" ]; then cp -f "$p" "$f"; else st=err; msg="no se puede leer el archivo"; rm -f "$f"; fi;; esac; '
            + '[ -s "$f" ] && ! grep -q "BEGIN:VCALENDAR" "$f" && { st=err; msg="no es un calendario .ics"; rm -f "$f"; }; '
            + 'printf "\\n@@HF-ICS@@ %s %s %s\\n" "$i" "$st" "$(printf %s "$msg" | tr "\\n" " " | cut -c1-160)"; cat "$f" 2>/dev/null; done',
            "sh", root.icsDir].concat(root.sources)
        stdout: StdioCollector {
            onStreamFinished: {
                // [antes, n, ok|err, motivo, ics, n, ok|err, motivo, ics, …]
                const parts = text.split(/\n@@HF-ICS@@ (\d+) (ok|err) ?([^\n]*)\n/);
                const out = [], st = [];
                for (let j = 1; j + 3 < parts.length + 1; j += 4) {
                    const i = Number(parts[j]) - 1, cal = root.calendars[i];
                    const evs = root.parseIcs(parts[j + 3] ?? "");
                    for (const e of evs) { e.color = cal?.color ?? root.defaultColors[i % 4]; e.calendar = cal?.name ?? ""; e.source = "ics"; out.push(e); }
                    st[i] = { ok: parts[j + 1] === "ok", error: root.errText(parts[j + 2] ?? ""), count: evs.length };
                }
                root.remote = out;
                root.status = st;
                root.lastSync = new Date();
                root.loading = false;
            }
        }
    }
    Timer { interval: 15 * 60000; repeat: true; running: root.sources.length > 0; onTriggered: root.refresh() }
    // Solo si cambian las direcciones: «sources» se recalcula con cualquier ajuste y volvía a bajar los calendarios
    property string _srcKey: ""
    onSourcesChanged: { const k = sources.join("\n"); if (k !== _srcKey) { _srcKey = k; refresh(); } }
    Component.onCompleted: { _srcKey = sources.join("\n"); refresh(); }

    // ── Lectura de .ics (RFC 5545, lo justo) ────────────────────────────
    function icsDate(v: string, params: string): var {
        const m = v.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?/);
        if (!m) return null;
        const allDay = !m[4];
        if (m[7]) return { d: new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0))), allDay };
        // TZID o flotante: se toma como hora local (suficiente para la mayoría de calendarios personales)
        return { d: new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0)), allDay };
    }
    function icsText(s: string): string { return s.replace(/\\n/gi, "\n").replace(/\\([,;\\])/g, "$1"); }
    function parseIcs(text: string): var {
        const lines = text.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/);
        const out = [];
        const winStart = new Date(Time.now); winStart.setMonth(winStart.getMonth() - 3);
        const winEnd = new Date(Time.now); winEnd.setMonth(winEnd.getMonth() + 9);
        let ev = null;
        for (const raw of lines) {
            if (raw === "BEGIN:VEVENT") { ev = { exdates: [] }; continue; }
            if (raw === "END:VEVENT") {
                if (ev && ev.start && ev.status !== "CANCELLED") {
                    const dur = (ev.end ? ev.end.d - ev.start.d : (ev.start.allDay ? 86400000 : 3600000));
                    const base = { title: ev.summary || "(sin título)", allDay: ev.start.allDay, where: ev.location || "",
                                   link: ev.url && linkIn(ev.url) ? ev.url : linkIn((ev.location || "") + " " + (ev.description || "")) };
                    for (const s of expand(ev.start.d, ev.rrule, winStart, winEnd))
                        if (!ev.exdates.some(x => Math.abs(x - s) < 60000))
                            out.push(Object.assign({ id: (ev.uid || "") + s.getTime(), start: s, end: new Date(s.getTime() + dur) }, base));
                }
                ev = null; continue;
            }
            if (!ev) continue;
            const c = raw.indexOf(":");
            if (c < 0) continue;
            const head = raw.slice(0, c), val = raw.slice(c + 1);
            const name = head.split(";")[0].toUpperCase();
            switch (name) {
            case "SUMMARY": ev.summary = icsText(val); break;
            case "LOCATION": ev.location = icsText(val); break;
            case "DESCRIPTION": ev.description = icsText(val); break;
            case "URL": ev.url = val; break;
            case "UID": ev.uid = val; break;
            case "STATUS": ev.status = val.toUpperCase(); break;
            case "DTSTART": ev.start = icsDate(val, head); break;
            case "DTEND": ev.end = icsDate(val, head); break;
            case "RRULE": ev.rrule = val; break;
            case "EXDATE": for (const x of val.split(",")) { const d = icsDate(x, head); if (d) ev.exdates.push(d.d); } break;
            }
        }
        return out;
    }
    function expand(start, rrule, from, to): var {
        if (!rrule) return start >= from && start <= to ? [start] : [];
        const r = {};
        for (const kv of rrule.split(";")) { const [k, v] = kv.split("="); r[k.toUpperCase()] = v; }
        const freq = r.FREQ, interval = +(r.INTERVAL || 1), count = r.COUNT ? +r.COUNT : 1e9;
        const until = r.UNTIL ? icsDate(r.UNTIL, "").d : null;
        const days = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
        const byday = r.BYDAY && freq === "WEEKLY" ? r.BYDAY.split(",").map(x => days[x.slice(-2)]).filter(x => x !== undefined) : null;
        const out = [];
        let n = 0;
        const cur = new Date(start);
        // Diarios o semanales que empezaron hace años: se salta hasta justo antes de la ventana (si no, el tope de
        // 3000 vueltas se acababa antes de llegar a hoy). Con COUNT y BYDAY no se salta: la primera semana va incompleta.
        const stepDays = freq === "DAILY" ? interval : freq === "WEEKLY" ? 7 * interval : 0;
        if (stepDays && !(byday && r.COUNT)) {
            const k = Math.floor((from - cur) / (stepDays * 86400000)) - 1;
            if (k > 0) {
                cur.setDate(cur.getDate() + k * stepDays);
                if (!byday) n = Math.min(k, count);
            }
        }
        for (let guard = 0; guard < 3000 && n < count; guard++) {
            if (until && cur > until) break;
            if (cur > to) break;
            if (byday) {
                // semana de "cur": cada día marcado
                const wk = new Date(cur); wk.setDate(wk.getDate() - ((wk.getDay() + 6) % 7));
                for (let i = 0; i < 7 && n < count; i++) {
                    const d = new Date(wk); d.setDate(wk.getDate() + i);
                    d.setHours(start.getHours(), start.getMinutes(), start.getSeconds());
                    if (d < start || !byday.includes(d.getDay())) continue;
                    if (until && d > until) break;
                    n++;
                    if (d >= from && d <= to) out.push(d);
                }
                cur.setDate(cur.getDate() + 7 * interval);
                continue;
            }
            n++;
            if (cur >= from) out.push(new Date(cur));
            switch (freq) {
            case "DAILY": cur.setDate(cur.getDate() + interval); break;
            case "WEEKLY": cur.setDate(cur.getDate() + 7 * interval); break;
            case "MONTHLY": cur.setMonth(cur.getMonth() + interval); break;
            case "YEARLY": cur.setFullYear(cur.getFullYear() + interval); break;
            default: guard = 1e9;
            }
        }
        return out;
    }

    IpcHandler {
        target: "events"
        function next(): string { return root.nextLabel; }
        function refresh(): void { root.refresh(); }
    }
}
