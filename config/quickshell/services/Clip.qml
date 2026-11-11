pragma Singleton
// Historial del portapapeles (cliphist) y fijados: los datos y acciones que comparten el Portapapeles
// (Super + V, modules/clipboard) y el modo «:» del Spotlight.
//   Clip.history  [{ id, line, text, kind, meta, img, file? }]   (img = miniatura en ~/.cache/hyprfrijol/clip/<id>.png;
//                 file = imagen copiada como archivo desde el gestor de archivos: la miniatura es el propio archivo)
//   Clip.pins     [{ text, kind, meta, img, ts }]         (~/.local/share/hyprfrijol/clipboard-pins.json)
//   Clip.refresh() · Clip.rows(q) → { pinned: [...], recent: [...] } (filas { pinned, pinIndex?, text, kind, meta, img, line? })
//   Clip.copy(r, paste) · Clip.remove(r) · Clip.togglePin(r) · Clip.wipe() · Clip.classify(t) · Clip.glyphs · Clip.isMono(kind)
// Requiere: cliphist + wl-clipboard (wl-paste --watch cliphist store en el autostart), wtype para pegar.
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    readonly property string pinFile: Paths.home + "/.local/share/hyprfrijol/clipboard-pins.json"
    readonly property string pinDir: Paths.home + "/.local/share/hyprfrijol/clipboard-pins"
    readonly property string imgCache: Paths.cache + "/clip"
    readonly property bool autoPaste: Settings.get("clipboardAutoPaste", true) !== false

    property var history: []
    property var pins: []
    property int imgGen: 0          // sube cuando hay miniaturas nuevas (para recargar las Image)
    property bool loaded: false

    // ── Clasificación (glifo + metadatos como en el diseño) ──────────────
    function classify(t: string): var {
        const s = t.trim();
        let m;
        if ((m = s.match(/^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/)))
            return { kind: "imagen", meta: "Imagen · " + m[3] + " × " + m[4] };
        if (/^\[\[ binary data/.test(s)) return { kind: "imagen", meta: "Imagen" };
        // Un archivo de imagen copiado en el gestor de archivos llega como ruta (text/uri-list): se ve como imagen
        const f = imageFile(s);
        if (f) return { kind: "imagen", meta: "Imagen · " + f.split("/").pop(), file: f };
        if (/^(#[0-9a-f]{3,8}|rgba?\([^)]*\)|hsla?\([^)]*\))$/i.test(s)) return { kind: "color", meta: "Color" };
        if ((m = s.match(/^https?:\/\/([^\/\s]+)\S*$/i))) return { kind: "enlace", meta: "Enlace · " + m[1].replace(/^www\./, "") };
        if (/^(~?\/[^\s]+)$/.test(s)) return { kind: "archivo", meta: "Ruta" };
        if (/^(\$ |sudo |paru |yay |pacman |git |cd |ls |cat |grep |find |systemctl |journalctl |hyprctl |npm |pnpm |yarn |php |python3? |pip |docker |kubectl |ssh |scp |curl |wget |make |cargo |go |rm |mv |cp |mkdir |chmod |chown |echo |export |! )/.test(s) && s.length < 300 && !s.includes("\n"))
            return { kind: "terminal", meta: "Terminal" };
        if (/[{};]\s*$|^\s*(function|const|let|var|def|class|import|#include|public|private|<\w+)/m.test(s))
            return { kind: "codigo", meta: "Código · " + s.split("\n").length + " líneas" };
        const words = s.split(/\s+/).filter(x => x).length;
        return { kind: "texto", meta: "Texto · " + (words === 1 ? "1 palabra" : words + " palabras") };
    }
    readonly property var imageTypes: ({ png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp",
                                         gif: "image/gif", bmp: "image/bmp", avif: "image/avif" })
    function imageFile(s: string): string {
        const m = s.match(/^(?:file:\/\/)?(\/[^\n]*\.(\w+))$/);
        if (!m || !imageTypes[m[2].toLowerCase()] || /\sfile:\/\//.test(s)) return "";   // varias a la vez: se quedan en texto
        try { return s.startsWith("file://") ? decodeURIComponent(m[1]) : m[1]; } catch (e) { return m[1]; }
    }
    // URL de la miniatura: cada trozo de la ruta codificado (las rutas del usuario pueden traer #, ? o %) + imgGen
    // (sin tipo en «path»: con «path: string», undefined llegaba como el texto "undefined")
    function imgUrl(path): string { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") + "?" + imgGen : ""; }
    function mimeOf(path: string): string { return imageTypes[String(path).split(".").pop().toLowerCase()] ?? "image/png"; }
    readonly property var glyphs: ({ texto: "¶", codigo: "</>", terminal: "›", enlace: "↗", imagen: "▣", color: "", archivo: "/" })
    function isMono(kind: string): bool { return kind === "terminal" || kind === "codigo" || kind === "color" || kind === "archivo"; }

    // Fijados y recientes que coinciden con q (los recientes que ya están fijados no se repiten)
    function rows(q: string): var {
        q = (q ?? "").trim().toLowerCase();
        const match = t => !q || t.toLowerCase().includes(q);
        const pinned = pins.map((p, i) => ({ pinned: true, pinIndex: i, text: p.text, kind: p.kind, meta: p.meta ?? classify(p.text).meta, img: p.img ?? "" }))
                           .filter(r => match(r.text + " " + r.meta));
        // cliphist list solo da una vista previa (espacios juntos, recortada): se compara así
        const norm = t => String(t).replace(/\s+/g, " ").trim().slice(0, 90);
        const pinnedTexts = new Set(pins.map(p => norm(p.text)));
        const recent = history.filter(h => !pinnedTexts.has(norm(h.text)) && match(h.text + " " + h.meta))
                              .map(h => Object.assign({ pinned: false }, h));
        return { pinned: pinned, recent: recent };
    }

    // ── Acciones ─────────────────────────────────────────────────────────
    function refresh(): void {
        lister.running = false; lister.running = true;
        pinStore.reload();
    }
    // Copia la fila (y pega en la ventana anterior si paste); cierra el panel abierto
    function copy(r, paste: bool): void {
        if (!r) return;
        let cmd;
        if (r.pinned) cmd = r.img ? ["sh", "-c", 'wl-copy --type "$2" < "$1"', "sh", r.img, mimeOf(r.img)]
                                  : ["wl-copy", "--", r.text];
        else if (r.file) cmd = ["sh", "-c", 'wl-copy --type "$2" < "$1"', "sh", r.file, mimeOf(r.file)];   // la imagen, no su ruta
        else cmd = ["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", r.line];
        Quickshell.execDetached(cmd);
        Shell.close();
        if (paste) Quickshell.execDetached(["sh", "-c", "sleep 0.25; wtype -M ctrl -k v -m ctrl"]);
    }
    function remove(r): void {
        if (!r) return;
        if (r.pinned) { togglePin(r); return; }
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", r.line]);
        history = history.filter(h => h.id !== r.id);
    }
    function togglePin(r): void {
        if (!r) return;
        if (r.pinned) {
            const p = pins[r.pinIndex];
            pins = pins.filter((_, i) => i !== r.pinIndex);
            if (p?.img) Quickshell.execDetached(["rm", "-f", p.img]);
        } else if (r.kind === "imagen") {
            // Las imágenes fijadas se copian a ~/.local/share/hyprfrijol/clipboard-pins/ (la del archivo, tal cual:
            // así sigue fijada aunque se borre o mueva el original)
            const dest = pinDir + "/" + Date.now() + "." + (r.file ? r.file.split(".").pop().toLowerCase() : "png");
            Quickshell.execDetached(r.file ? ["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp -- "$1" "$2"', "sh", r.file, dest]
                                           : ["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" | cliphist decode > "$2"', "sh", r.line, dest]);
            pins = [{ text: r.text, kind: r.kind, meta: r.meta, img: dest, ts: Date.now() }, ...pins];
        } else {
            // Texto completo (el historial solo guarda una vista previa de una línea)
            pinReader.row = r;
            pinReader.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode', "sh", r.line];
            pinReader.running = true;
            return;
        }
        savePins();
    }
    function savePins(): void { pinStore.setText(JSON.stringify(pins, null, 1)); }
    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        history = [];
    }

    // ── Datos ────────────────────────────────────────────────────────────
    Process {
        id: lister
        command: ["cliphist", "-preview-width", "400", "list"]   // rutas largas de imágenes enteras (por defecto 100)
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    // los textos en UTF-16 (Chrome) traen un byte nulo entre letras: se quitan para mostrarlos
                    const id = line.slice(0, tab), t = line.slice(tab + 1).replace(/\u0000/g, "");
                    const c = root.classify(t);
                    // img se rellena cuando la miniatura ya está en disco (thumbs)
                    out.push({ id, line, text: c.file ? c.file.split("/").pop() : c.kind === "imagen" ? "Imagen " + id : t,
                               kind: c.kind, meta: c.meta, file: c.file ?? "",
                               img: c.file ? c.file : c.kind === "imagen" && root.thumbIds[id] ? root.imgCache + "/" + id + ".png" : "" });
                }
                root.history = out;
                root.loaded = true;
                if (out.some(h => h.kind === "imagen")) { thumbs.running = false; thumbs.running = true; }
            }
        }
    }
    // Miniaturas de las imágenes del historial (se decodifican una vez a ~/.cache/hyprfrijol/clip/); imprime los ids listos.
    // grep -a: Chrome guarda algunos textos en UTF-16 (con bytes nulos) y, sin -a, grep tomaba la lista entera por
    // binaria y no devolvía ninguna imagen (el portapapeles se quedaba sin miniaturas).
    property var thumbIds: ({})
    Process {
        id: thumbs
        command: ["sh", "-c", 'mkdir -p "$1"; cliphist list | grep -a -P "^\\d+\\t\\[\\[ binary data" | head -n 60 | while IFS= read -r l; do id="${l%%\t*}"; [ -s "$1/$id.png" ] || printf "%s" "$l" | cliphist decode > "$1/$id.png"; [ -s "$1/$id.png" ] && echo "$id"; done', "sh", root.imgCache]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                for (const id of text.split("\n")) if (id) ids[id] = true;
                root.thumbIds = ids;
                root.history = root.history.map(h => h.kind === "imagen" && !h.file && ids[h.id] ? Object.assign({}, h, { img: root.imgCache + "/" + h.id + ".png" }) : h);
                root.imgGen++;
            }
        }
    }
    Process {
        id: pinReader
        property var row: null
        stdout: StdioCollector {
            onStreamFinished: {
                const r = pinReader.row;
                const full = text.length ? text : r.text;
                root.pins = [{ text: full, kind: r.kind, meta: r.meta, ts: Date.now() }, ...root.pins];
                root.savePins();
            }
        }
    }
    FileView {
        id: pinStore
        path: root.pinFile
        printErrors: false
        atomicWrites: true
        onLoaded: { try { root.pins = JSON.parse(text()) || []; } catch (e) { root.pins = []; } }
        onLoadFailed: root.pins = []
    }
}
