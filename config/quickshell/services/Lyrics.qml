pragma Singleton
// Letras de canciones (vista "musica"): las pide a lrclib.net (gratis, sin cuenta) con el artista, el título y la
// duración de lo que suena. Solo con musicLyrics = true: es mandar a un servicio de fuera lo que escuchas, así que
// se activa a mano desde la propia vista. Una búsqueda por canción; se guardan en memoria las últimas 30.
//   Lyrics.want(artista, título, duración s) · lines [{ t: segundos, text }] (sincronizada) · plain (sin sincronizar)
//   state: "" · "buscando" · "ok" · "nada" (lrclib no la tiene) · "error" (sin red)
//   indexAt(segundos) → línea que toca
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property bool enabled: Settings.get("musicLyrics", false) === true
    property string key: ""
    property var lines: []
    property string plain: ""
    property string state: ""
    property var cache: ({})
    property var order: []

    function want(artist: string, title: string, len: real): void {
        if (!enabled || !title.trim()) { key = ""; lines = []; plain = ""; state = ""; return; }
        const k = artist.trim().toLowerCase() + "\n" + title.trim().toLowerCase();
        if (k === key) return;
        key = k;
        const c = cache[k];
        if (c) { lines = c.lines; plain = c.plain; state = c.state; return; }
        lines = []; plain = ""; state = "buscando";
        proc.k = k;
        proc.command = ["curl", "-fsG", "--max-time", "10", "-A", "hyprfrijol (https://github.com/fsanchezlme97-ui/hyprfrijol)",
                        "https://lrclib.net/api/get", "--data-urlencode", "artist_name=" + artist, "--data-urlencode", "track_name=" + title]
            .concat(len > 0 ? ["--data-urlencode", "duration=" + Math.round(len)] : []);
        proc.running = false;
        proc.running = true;
    }
    // «[01:02.34] texto» → { t: 62.34, text }
    function parse(lrc: string): var {
        const out = [];
        for (const l of String(lrc).split("\n")) {
            const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
            if (m) out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] });
        }
        return out;
    }
    function indexAt(s: real): int {
        let i = -1;
        for (let j = 0; j < lines.length && lines[j].t <= s + 0.3; j++) i = j;
        return i;
    }
    function remember(k: string, v): void {
        const c = Object.assign({}, cache); c[k] = v;
        const o = order.filter(x => x !== k).concat([k]);
        while (o.length > 30) delete c[o.shift()];
        cache = c; order = o;
    }

    Process {
        id: proc
        property string k: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;        // sin respuesta: lo resuelve onExited
                let v;
                try {
                    const j = JSON.parse(text);
                    const ls = j.syncedLyrics ? root.parse(j.syncedLyrics) : [];
                    v = { lines: ls, plain: ls.length ? "" : String(j.plainLyrics ?? "").trim(), state: ls.length || j.plainLyrics ? "ok" : "nada" };
                } catch (e) { v = { lines: [], plain: "", state: "nada" }; }
                root.remember(proc.k, v);
                if (proc.k === root.key) { root.lines = v.lines; root.plain = v.plain; root.state = v.state; }
            }
        }
        // curl -f: 404 = lrclib no la tiene; otro error = sin red (no se guarda: se reintenta la próxima vez)
        onExited: code => {
            if (code === 0 || proc.k !== root.key) return;
            if (code === 22) { root.remember(proc.k, { lines: [], plain: "", state: "nada" }); root.state = "nada"; }
            else { root.state = "error"; root.key = ""; }
        }
    }
}
