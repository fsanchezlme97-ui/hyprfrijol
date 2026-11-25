pragma Singleton
// Procesos en curso (centro de notificaciones, «En curso»): las descargas de hf-download y lo que cuenta
// scripts/hf-jobs (copias de las apps de KDE, descargas del navegador, actualizaciones e instalaciones). hf-jobs avisa
// al terminar cada uno; aquí solo se enseñan.
//   Jobs.items [{ id, title, detail, icon, progress (0–1; -1 si no se sabe), cancel }] · Jobs.cancel(id)
// Singleton perezoso: Modules.qml lo nombra para que el demonio esté desde que arranca el shell.
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property var other: []
    readonly property var items: Downloads.active.map(d => ({
        id: "hf:" + d.id, title: d.title || d.name || d.url, icon: Downloads.typeIcon(d.type), cancel: true,
        detail: [Downloads.statusText(d), d.total > 0 ? Downloads.human(d.done) + " de " + Downloads.human(d.total) : "",
                 d.speed > 0 ? Downloads.human(d.speed) + "/s" : ""].filter(x => x).join(" · "),
        progress: d.total > 0 ? d.done / d.total : -1
    })).concat(other)

    function cancel(id: string): void {
        if (id.startsWith("hf:")) Downloads.cancel(id.slice(3));
        else daemon.write("cancel " + id + "\n");
    }

    Process {
        id: daemon
        command: [Paths.script("hf-jobs"), "daemon"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => { try { root.other = JSON.parse(line).jobs ?? []; } catch (e) {} } }
        onExited: root.other = []
    }
}
