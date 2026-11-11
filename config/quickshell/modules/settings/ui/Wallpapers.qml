// Fondos disponibles (hf-wallpaper list) y el actual (~/.local/state/hyprfrijol/wallpaper-path).
//   Wallpapers { id: wp }  wp.files · wp.images · wp.animated · wp.current · wp.set(file[, pantalla]) · wp.refresh()
//   wp.own(pantalla): su fondo propio (imagen o vídeo; "" si usa el general) · wp.reset(pantalla): quitárselo
//   wp.deps { mpvpaper, ffmpeg, ffmpegthumbnailer, "linux-wallpaperengine" } (instalado o no) · wp.tick (miniaturas de
//   vídeo listas → Thumb { tick: wp.tick }) · wp.addAnimated() (elige un vídeo/GIF, lo copia y lo pone) · wp.error
import QtQuick
import Quickshell
import Quickshell.Io
import "../../.."

Item {
    id: root
    property var files: []
    property string current: ""
    readonly property var images: files.filter(f => !isVideo(f))
    readonly property var animated: files.filter(f => isVideo(f))
    readonly property int videos: animated.length
    property var deps: ({})
    property int tick: 0
    property string error: ""
    readonly property bool adding: picker.running
    function name(f: string): string { return String(f).split("/").pop().replace(/\.[^.]+$/, ""); }
    function isVideo(f: string): bool { return /\.(mp4|webm|mkv|mov|gif)$/i.test(f); }
    function set(f: string, mon: string): void {
        if (mon) { Quickshell.execDetached([Paths.script("hf-wallpaper"), "-o", mon, f]); return; }
        current = f; Quickshell.execDetached([Paths.script("hf-wallpaper"), f]);
    }
    function reset(mon: string): void { Quickshell.execDetached([Paths.script("hf-wallpaper"), "-o", mon, "reset"]); }
    // Fondo propio de una pantalla (wallpaper.json: el vídeo en motions; la imagen en monitors)
    function own(mon: string): string { return (wj.motions ?? {})[mon] ?? (wj.monitors ?? {})[mon] ?? ""; }
    FileView {
        path: Paths.state + "/wallpaper.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: wj; property var monitors: ({}); property var motions: ({}) }
    }
    function refresh(): void { lister.running = false; lister.running = true; depsProc.running = true; }
    function addAnimated(): void { error = ""; picker.running = true; }
    Process {
        id: lister
        running: true
        command: [Paths.script("hf-wallpaper"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(Boolean);
                if (root.animated.length) { thumber.running = false; thumber.running = true; }
            }
        }
    }
    // Miniaturas de los vídeos/GIF (primer cuadro); al terminar se recargan las tarjetas
    Process {
        id: thumber
        command: [Paths.script("hf-wallpaper"), "vthumbs"]
        stdout: StdioCollector { onStreamFinished: root.tick++ }
    }
    Process {
        id: depsProc
        running: true
        command: [Paths.script("hf-wallpaper"), "deps"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                text.split("\n").forEach(l => { const p = l.trim().split(" "); if (p.length === 2) d[p[0]] = p[1] === "1"; });
                root.deps = d;
            }
        }
    }
    Process {
        id: picker
        command: [Paths.script("hf-wallpaper"), "pick-animated"]
        stderr: StdioCollector { id: pickErr }
        onExited: code => { if (code !== 0 && pickErr.text.trim() !== "") root.error = pickErr.text.trim().split("\n").pop(); root.refresh(); }
    }
    FileView {
        path: Paths.state + "/wallpaper-path"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }
}
