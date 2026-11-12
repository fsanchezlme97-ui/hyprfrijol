pragma Singleton
// Tareas (plan de Productividad, mínimo: una lista con fecha opcional; sin proyectos ni sincronización).
// ~/.local/share/hyprfrijol/tasks.json: [{ id, text, done, due? ("AAAA-MM-DD"), created (ms), doneAt? (ms) }]
// Se ven en la agenda (bajo los eventos del día) y en su app, «Tareas» (modules/tareas), se crean con «+texto» en
// Spotlight y el asistente las añade (hf-ai, acción task: escribe el mismo archivo, que aquí se recarga solo).
//   add(text, due) · edit(id, text, due) · toggle(id) · remove(id) · clearDone() · forDay(fecha) · overdue · pending
// IPC:  qs … ipc call tasks list | add <texto> <AAAA-MM-DD o ""> | done <id> | remove <id> | undo
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property string store: Paths.home + "/.local/share/hyprfrijol/tasks.json"
    property var list: []
    readonly property var pending: list.filter(t => !t.done)
    readonly property string today: Events.key(Time.now)
    readonly property var overdue: pending.filter(t => t.due && t.due < today)

    // Las del día: vencen ese día; hoy además las vencidas (arriba), las sin fecha y las hechas hoy
    function forDay(d): var {
        const k = Events.key(d), isToday = k === today;
        const doneToday = t => t.doneAt && Events.key(new Date(t.doneAt)) === today;
        const rank = t => t.done ? 3 : t.due && t.due < today ? 0 : t.due ? 1 : 2;
        return list.filter(t => t.due === k ? (!t.done || !isToday || doneToday(t))
                                : isToday && (t.done ? !t.due && doneToday(t) : !t.due || t.due < today))
                   .sort((a, b) => rank(a) - rank(b) || a.created - b.created);
    }
    // Una fecha escrita a mano → "AAAA-MM-DD"; "" si está vacía; null si no se entiende.
    // Vale: hoy, mañana, pasado mañana, un día de la semana (lun, viernes…: el próximo), «12 nov», «12/11», «12/11/2027»
    // y AAAA-MM-DD. Las fechas imposibles (2026-13-45, 31 de febrero) no pasan.
    readonly property var _months: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property var _days: ["dom", "lun", "mar", "mie", "jue", "vie", "sab"]
    function parseDue(s): var {
        s = String(s ?? "").trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\s+/g, " ");
        if (s === "" || s === "sin fecha" || s === "sin") return "";
        const now = new Date(), at = n => { const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + n); return Events.key(d); };
        if (s === "hoy") return at(0);
        if (s === "manana") return at(1);
        if (s === "pasado manana" || s === "pasado") return at(2);
        const real = (y, m, d) => { const x = new Date(y, m - 1, d); return x.getFullYear() === y && x.getMonth() === m - 1 && x.getDate() === d ? Events.key(x) : null; };
        let m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(s);
        if (m) return real(+m[1], +m[2], +m[3]);
        const wd = _days.indexOf(s.slice(0, 3));
        if (wd >= 0 && /^[a-z]+$/.test(s) && (s.length === 3 || /^(domingo|lunes|martes|miercoles|jueves|viernes|sabado)$/.test(s)))
            return at(((wd - now.getDay() + 7) % 7) || 7);
        // día y mes: sin año es la próxima vez que caiga esa fecha
        const next = (mo, d, y) => {
            if (y) return real(y < 100 ? 2000 + y : y, mo, d);
            const k = real(now.getFullYear(), mo, d);
            return k !== null && k < at(0) ? real(now.getFullYear() + 1, mo, d) : k;
        };
        m = /^(\d{1,2})[\/.-](\d{1,2})(?:[\/.-](\d{2,4}))?$/.exec(s);
        if (m) return next(+m[2], +m[1], m[3] ? +m[3] : 0);
        m = /^(\d{1,2})(?: de)? ([a-z]{3})[a-z]*(?: (?:de )?(\d{4}))?$/.exec(s);
        if (m && _months.indexOf(m[2]) >= 0) return next(_months.indexOf(m[2]) + 1, +m[1], m[3] ? +m[3] : 0);
        return null;
    }
    function add(text: string, due: string): string {
        text = String(text ?? "").trim().slice(0, 200);
        if (!text) return "";
        const id = Date.now().toString(36), d = parseDue(due);
        save(list.concat([Object.assign({ id: id, text: text, done: false, created: Date.now() }, d ? { due: d } : {})]));
        return id;
    }
    // Cambia el texto y la fecha («» = sin fecha; una fecha mal escrita deja la que tenía)
    function edit(id: string, text: string, due: string): void {
        text = String(text ?? "").trim().slice(0, 200);
        if (!text) return;
        const d = parseDue(due);
        save(list.map(t => {
            if (t.id !== id) return t;
            const n = Object.assign({}, t, { text: text });
            if (d === "") delete n.due;
            else if (d !== null) n.due = d;
            return n;
        }));
    }
    function toggle(id: string): void {
        save(list.map(t => t.id !== id ? t : Object.assign({}, t, { done: !t.done, doneAt: t.done ? undefined : Date.now() })));
    }
    function remove(id: string): void { _forget(list.filter(t => t.id === id), "Tarea borrada"); save(list.filter(t => t.id !== id)); }
    function clearDone(): void {
        const d = list.filter(t => t.done);
        _forget(d, d.length === 1 ? "1 tarea hecha borrada" : d.length + " tareas hechas borradas");
        save(list.filter(t => !t.done));
    }
    // Deshacer lo último que se borró (unos segundos): la app Tareas y la agenda enseñan «Deshacer»
    property var removed: []
    property string removedLabel: ""
    function _forget(items, label): void { if (!items.length) return; removed = items; removedLabel = label; undoTimer.restart(); }
    function undo(): void {
        if (!removed.length) return;
        const have = list.map(t => t.id);
        save(list.concat(removed.filter(t => !have.includes(t.id))));
        removed = []; undoTimer.stop();
    }
    Timer { id: undoTimer; interval: 8000; onTriggered: root.removed = [] }
    function save(l): void { list = l; file.setText(JSON.stringify(l, null, 1)); }

    FileView {
        id: file
        path: root.store
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const v = JSON.parse(text()); root.list = Array.isArray(v) ? v.filter(t => t && t.id) : []; } catch (e) { root.list = []; } }
        onLoadFailed: root.list = []
    }

    IpcHandler {
        target: "tasks"
        function list(): string { return JSON.stringify(root.list); }
        function add(text: string, due: string): string { return root.add(text, due); }
        function done(id: string): void { root.toggle(id); }
        function remove(id: string): void { root.remove(id); }
        function undo(): void { root.undo(); }
    }
}
