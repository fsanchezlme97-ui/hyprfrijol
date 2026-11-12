pragma Singleton
// Tareas (plan de Productividad, mínimo: una lista con fecha opcional; sin proyectos ni sincronización).
// ~/.local/share/hyprfrijol/tasks.json: [{ id, text, done, due? ("AAAA-MM-DD"), created (ms), doneAt? (ms) }]
// Se ven en la agenda (bajo los eventos del día) y en su app, «Tareas» (modules/tareas), se crean con «+texto» en
// Spotlight y el asistente las añade (hf-ai, acción task: escribe el mismo archivo, que aquí se recarga solo).
//   add(text, due) · edit(id, text, due) · toggle(id) · remove(id) · clearDone() · forDay(fecha) · overdue · pending
// IPC:  qs … ipc call tasks list | add <texto> <AAAA-MM-DD o ""> | done <id> | remove <id>
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
    function add(text: string, due: string): string {
        text = String(text ?? "").trim().slice(0, 200);
        if (!text) return "";
        const id = Date.now().toString(36);
        save(list.concat([Object.assign({ id: id, text: text, done: false, created: Date.now() },
                                        /^\d{4}-\d{2}-\d{2}$/.test(due ?? "") ? { due: due } : {})]));
        return id;
    }
    // Cambia el texto y la fecha («» = sin fecha; una fecha mal escrita deja la que tenía)
    function edit(id: string, text: string, due: string): void {
        text = String(text ?? "").trim().slice(0, 200);
        if (!text) return;
        due = String(due ?? "").trim();
        save(list.map(t => {
            if (t.id !== id) return t;
            const n = Object.assign({}, t, { text: text });
            if (due === "") delete n.due;
            else if (/^\d{4}-\d{2}-\d{2}$/.test(due)) n.due = due;
            return n;
        }));
    }
    function toggle(id: string): void {
        save(list.map(t => t.id !== id ? t : Object.assign({}, t, { done: !t.done, doneAt: t.done ? undefined : Date.now() })));
    }
    function remove(id: string): void { save(list.filter(t => t.id !== id)); }
    function clearDone(): void { save(list.filter(t => !t.done)); }
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
    }
}
