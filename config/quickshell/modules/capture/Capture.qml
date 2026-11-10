// Captura y grabación de pantalla (vista "captura"; Impr Pant), como Captura del diseño y el selector de
// illogical-impulse:
//   · Al abrir se CONGELA la pantalla (hf-capture freeze) y se elige sobre esa imagen: lo de fuera se oscurece,
//     cruz y lupa de píxeles junto al cursor, medida en vivo. Al pasar por una ventana se resalta (hyprctl clients):
//     clic = esa ventana; arrastrar = una zona. Pantalla = la pantalla entera.
//   · Con la zona elegida (se puede mover y ajustar con los tiradores, o con las flechas) aparece la barra de
//     acciones: Copiar · Guardar (~/Imágenes/Capturas) · Anotar · Editar (satty/swappy) · Fijar (imagen flotante)
//     · Copiar texto (OCR spa+eng con las palabras resaltadas: clic = palabra, doble clic = línea, arrastrar = varias)
//     · Google Lens · Preguntar a la IA.
//   · Grabar: wf-recorder (scripts/hf-capture) con indicador «REC 00:12 · Detener» fuera de la zona grabada.
// Argumentos (Shell.open("captura", arg)): "region" | "ventana" | "pantalla" | "grabar".
//   Si se está grabando, abrir la vista (o Super + Shift + R) detiene la grabación.
// Teclas: Intro copiar (o grabar) · flechas mover (Ctrl ×10) · Mayús + flechas tamaño · Tab foto/vídeo · R/V/P modo
//   C copiar · S guardar · A anotar · E editar · F fijar · T texto · I IA · clic derecho deshacer la zona · Esc salir.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"

Scope {
    id: root

    // ── Estado ───────────────────────────────────────────────────────────
    property string kind: "foto"          // foto | video
    property string mode: "region"        // region | ventana | pantalla
    property string stage: "off"          // off | congelando | elegir | listo | anotar | texto
    property bool hiding: false           // oculta mientras se congela de nuevo / empieza a grabar
    property bool cursor: false
    property bool mic: false
    property bool sysAudio: false
    // Formato de la grabación (se recuerda: recFormat): "video" (normal, sin límite) · "clip" (vídeo ligero para
    // compartir, 60 s como mucho) · "gif" (sin audio, 30 s como mucho). Al parar, el archivo queda copiado.
    property string recFormat: Settings.get("recFormat", "video")
    onRecFormatChanged: if (Settings.get("recFormat", "video") !== recFormat) Settings.set("recFormat", recFormat)
    readonly property int recLimit: recFormat === "gif" ? 30 : recFormat === "clip" ? 60 : 0
    property rect sel: Qt.rect(0, 0, 0, 0)        // coordenadas locales (lógicas) de la pantalla
    property rect preset: Qt.rect(0, 0, 0, 0)     // zona pedida por IPC antes de abrir
    property var screenUsed: Shell.screen
    property string frozen: ""                     // pantalla congelada (temporal)
    property string cropFile: ""                   // recorte de la zona (temporal)
    property string cropFor: ""
    property string shot: ""                       // imagen que se anota
    property string tool: "flecha"
    property color ink: "#E0603F"
    property var shapes: []
    property rect crop: Qt.rect(0, 0, 0, 0)
    property var windows: []
    property string busy: ""                       // mensaje mientras se recorta / OCR
    property bool exporting: false
    property string editor: ""                     // satty | swappy | ""
    property int countdown: 0
    property string toast: ""
    // OCR
    property var words: []                         // [{ x, y, w, h, text, line }] relativo a la zona
    property var lines: []                         // [{ x, y, w, h, text }]
    property string ocrText: ""
    property var picked: ({})                      // índice de palabra → true (arrastre)
    // Fijadas
    property var pins: []
    property int pinSeq: 0

    // Grabación
    property bool recording: false
    property string recFile: ""
    property real recStart: 0
    property rect recRect: Qt.rect(0, 0, 0, 0)
    property var recScreen: null

    property bool ready: false      // ver components/Overlay (carga diferida)
    Component.onCompleted: Qt.callLater(() => root.ready = true)
    readonly property bool shown: ready && Shell.view === "captura"
    readonly property string hc: Paths.script("hf-capture")
    readonly property real dpr: capWin.width > 0 && bg.implicitWidth > 0 ? bg.implicitWidth / capWin.width : 1
    readonly property var inks: [["Naranja", "#E0603F"], ["Amarillo", "#D9A400"], ["Verde", "#3E9D6E"], ["Azul", "#4A7BD0"]]
    readonly property var tools: [["flecha", "↗ Flecha"], ["caja", "▭ Recuadro"], ["texto", "T Texto"], ["resaltar", "▬ Resaltar"], ["difuminar", "▒ Difuminar"], ["recortar", "⌗ Recortar"]]
    readonly property string scanSvg: '<path d="M4 7V5a1 1 0 0 1 1-1h2M17 4h2a1 1 0 0 1 1 1v2M20 17v2a1 1 0 0 1-1 1h-2M7 20H5a1 1 0 0 1-1-1v-2"/><path d="M8 9h8M8 12h8M8 15h5"/>'
    readonly property string lensSvg: '<circle cx="12" cy="12" r="3.2"/><path d="M4 9V6a2 2 0 0 1 2-2h3M15 4h3a2 2 0 0 1 2 2v3M20 15v3a2 2 0 0 1-2 2h-3M9 20H6a2 2 0 0 1-2-2v-3"/>'

    function geom(r, scr): string {
        return Math.round(scr.x + r.x) + "," + Math.round(scr.y + r.y) + " " + Math.round(r.width) + "x" + Math.round(r.height);
    }
    function fullRect(): rect { return Qt.rect(0, 0, screenUsed?.width ?? 0, screenUsed?.height ?? 0); }
    function hasSel(): bool { return sel.width >= 4 && sel.height >= 4; }
    function clampRect(r): rect {
        const W = capWin.width, H = capWin.height;
        const x1 = Math.max(0, Math.min(W, r.x)), y1 = Math.max(0, Math.min(H, r.y));
        const x2 = Math.max(0, Math.min(W, r.x + r.width)), y2 = Math.max(0, Math.min(H, r.y + r.height));
        return Qt.rect(x1, y1, Math.max(0, x2 - x1), Math.max(0, y2 - y1));
    }
    function setMode(m: string): void {
        mode = m;
        if (stage === "off" || stage === "congelando") return;
        if (m === "pantalla") { sel = fullRect(); stage = "listo"; }
        else { sel = Qt.rect(0, 0, 0, 0); stage = "elegir"; clientsProc.running = true; }
    }
    function winAt(x: real, y: real): var {
        return windows.find(w => x >= w.rect.x && x < w.rect.x + w.rect.width && y >= w.rect.y && y < w.rect.y + w.rect.height) ?? null;
    }
    function flash(t: string): void { toast = t; toastTimer.restart(); }
    function copyText(t: string, what: string): void {
        if (!t) return;
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", t]);
        flash((what || "Copiado") + ": «" + (t.length > 48 ? t.slice(0, 46) + "…" : t.replace(/\n/g, " ")) + "»");
    }

    onShownChanged: {
        if (!shown) { if (!hiding) reset(); return; }
        if (recording) { stopRec(); Shell.close(); return; }
        screenUsed = Shell.screen;
        const a = Shell.arg;
        if (a === "grabar") kind = "video";
        else if (a === "region" || a === "ventana" || a === "pantalla") { kind = "foto"; mode = a; }
        shapes = []; crop = Qt.rect(0, 0, 0, 0); shot = ""; cropFile = ""; cropFor = ""; words = []; lines = []; ocrText = "";
        stage = "congelando";
        clientsProc.running = true;
        // Deja que se vaya el panel que estuviera abierto (Spotlight, ajustes rápidos…) antes de congelar
        freezeTimer.interval = Theme.durOut + 60;
        freezeTimer.restart();
    }
    function reset(): void {
        if (frozen) Quickshell.execDetached(["rm", "-f", frozen]);
        stage = "off"; shapes = []; shot = ""; busy = ""; hiding = false; frozen = ""; cropFile = ""; cropFor = "";
        sel = Qt.rect(0, 0, 0, 0); words = []; lines = []; ocrText = ""; picked = ({}); countdown = 0; toast = "";
        freezeTimer.stop(); countTimer.stop();
    }

    // ── Congelar la pantalla ─────────────────────────────────────────────
    Timer { id: freezeTimer; onTriggered: root.freeze() }
    function freeze(): void {
        if (!shown) return;
        freezeProc.command = [hc, "freeze", screenUsed.name].concat(cursor ? ["--cursor"] : []);
        freezeProc.running = true;
    }
    Process {
        id: freezeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (!root.shown) { if (p) Quickshell.execDetached(["rm", "-f", p]); return; }
                if (!p) {
                    Quickshell.execDetached(["notify-send", "-a", "Captura", "No se pudo capturar la pantalla", "¿Está instalado grim?"]);
                    Shell.close(); return;
                }
                const old = root.frozen;
                root.frozen = p;
                if (old) Quickshell.execDetached(["rm", "-f", old]);
                root.cropFile = ""; root.cropFor = "";
                root.hiding = false;
                if (root.stage === "congelando") {
                    if (root.preset.width >= 4) { root.sel = root.preset; root.preset = Qt.rect(0, 0, 0, 0); root.stage = "listo"; }
                    else if (root.mode === "pantalla") { root.sel = root.fullRect(); root.stage = "listo"; }
                    else root.stage = "elegir";
                }
            }
        }
    }
    // Volver a congelar (cursor activado o retardo): se oculta, espera y captura otra vez; la zona se queda
    function refreeze(wait: int): void {
        hiding = true;
        if (wait > 0) { countdown = Math.round(wait / 1000); countTimer.restart(); }
        else { freezeTimer.interval = 220; freezeTimer.restart(); }
    }
    Timer {
        id: countTimer
        interval: 1000; repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0) { stop(); freezeTimer.interval = 180; freezeTimer.restart(); }
        }
    }

    // ── Recorte y acciones ───────────────────────────────────────────────
    function cropGeom(): string {
        const d = dpr, s = sel;
        return Math.round(s.x * d) + "," + Math.round(s.y * d) + " " + Math.max(1, Math.round(s.width * d)) + "x" + Math.max(1, Math.round(s.height * d));
    }
    // then: copiar | guardar | anotar | editar | fijar | texto | lens | ia | grabar
    function run(then: string): void {
        if (stage !== "listo" || !hasSel() || !frozen || cropProc.running) return;
        if (kind === "video" || then === "grabar") { startRec(); return; }
        const g = cropGeom();
        if (cropFile && cropFor === g) { act(then, cropFile); return; }
        busy = "Un momento…";
        cropProc.after = then; cropProc.g = g;
        cropProc.command = [hc, "crop", frozen, g];
        cropProc.running = true;
    }
    Process {
        id: cropProc
        property string after: ""
        property string g: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                root.busy = "";
                if (!p) { root.flash("No se pudo recortar (¿falta imagemagick?)"); return; }
                root.cropFile = p; root.cropFor = cropProc.g;
                root.act(cropProc.after, p);
            }
        }
    }
    function act(then: string, file: string): void {
        if (then === "copiar") {
            Quickshell.execDetached([hc, "copy", file]);
            Quickshell.execDetached(["notify-send", "-a", "Captura", "-i", file, "Captura copiada", "Pégala donde quieras"]);
            Shell.close();
        } else if (then === "guardar") {
            saver.command = ["sh", "-c", 'f="$("$1" save "$2")" && "$1" copy "$f" && notify-send -a Captura -i "$f" "Captura guardada" "$(basename "$f") · también en el portapapeles"', "sh", hc, file];
            saver.running = true;
            Shell.close();
        } else if (then === "editar") {
            Quickshell.execDetached([hc, "edit", file]);
            Shell.close();
        } else if (then === "anotar") {
            shot = file; shapes = []; crop = Qt.rect(0, 0, 0, 0); stage = "anotar";
        } else if (then === "fijar") {
            addPin(file, sel, screenUsed);
            Shell.close();
        } else if (then === "texto") {
            startOcr(file);
        } else if (then === "ocr") {          // desde la anotación: todo el texto al portapapeles
            busy = "Leyendo texto…";
            ocr.command = [hc, "ocr", file];
            ocr.running = true;
        } else if (then === "lens") {
            Quickshell.execDetached([hc, "lens", file]);
            Shell.close();
        } else if (then === "ia") {
            iaSaver.command = [hc, "save", file];
            iaSaver.running = true;
        }
    }
    Process { id: saver }
    Process {
        id: ocr
        stdout: StdioCollector { onStreamFinished: { root.busy = ""; if (text.trim()) Shell.close(); } }
        onExited: code => { root.busy = code === 0 ? "" : "No se encontró texto"; }
    }
    Process {
        id: iaSaver
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                root.busy = "";
                // Se adjunta al chat y el cursor queda en la caja para que escribas tu pregunta
                if (f) Shell.open("ia", { image: f });
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v satty >/dev/null && echo satty || { command -v swappy >/dev/null && echo swappy; } || true"]
        stdout: StdioCollector { onStreamFinished: root.editor = text.trim() }
    }

    // ── Exportar la captura anotada ─────────────────────────────────────
    // then: "copiar" | "guardar" | "ocr" | "ia" | "fijar" | "editar"
    function exportAs(then: string): void {
        if (!shot) return;
        busy = then === "ocr" ? "Leyendo texto…" : "Un momento…";
        const sheet = capWin.sheetItem;
        const natW = sheet.naturalW, natH = sheet.naturalH;
        const out = shot.replace(/\.png$/, "") + "-anotada-" + Date.now() + ".png";
        const plain = shapes.length === 0 && crop.width < 4;
        const finish = file => {
            const c = crop, f = sheet.factor;
            if (c.width >= 4 && c.height >= 4) {
                const g = Math.round(c.width * f) + "x" + Math.round(c.height * f) + "+" + Math.round(c.x * f) + "+" + Math.round(c.y * f);
                post.after = then; post.file = file.replace(/\.png$/, "") + "-rec.png";
                post.command = ["magick", file, "-crop", g, "+repage", post.file];
                post.running = true;
            } else { busy = ""; act(then, file); }
        };
        if (plain) { finish(shot); return; }
        exporting = true;      // sin el marco del recorte
        sheet.grabToImage(res => { exporting = false; res.saveToFile(out); finish(out); }, Qt.size(natW, natH));
    }
    Process { id: post; property string after: ""; property string file: ""; onExited: { root.busy = ""; root.act(after, file); } }

    function undo(): void {
        if (shapes.length) shapes = shapes.slice(0, -1);
        else crop = Qt.rect(0, 0, 0, 0);
    }

    // ── OCR con cajas ────────────────────────────────────────────────────
    function startOcr(file: string): void {
        stage = "texto"; words = []; lines = []; ocrText = ""; picked = ({});
        busy = "Leyendo texto…";
        tsvProc.command = [hc, "ocr-tsv", file];
        tsvProc.running = true;
    }
    Process {
        id: tsvProc
        stdout: StdioCollector { onStreamFinished: root.parseTsv(text) }
        onExited: code => { if (code !== 0) root.busy = "No se pudo leer el texto (¿falta tesseract?)"; }
    }
    function parseTsv(text: string): void {
        const rows = text.split("\n");
        let n = 1;
        const m = (rows[0] ?? "").match(/^scale (\d+)/);
        if (m) n = +m[1];
        const k = n * dpr;                                   // píxeles del TSV → unidades lógicas
        const ws = [], byLine = {}, order = [];
        let lastBlock = "";
        for (const r of rows) {
            const f = r.split("\t");
            if (f.length < 12 || f[0] !== "5") continue;
            const t = f.slice(11).join("\t").trim();
            if (!t || +f[10] < 0) continue;
            const key = f[2] + "-" + f[3] + "-" + f[4];
            const w = { x: +f[6] / k, y: +f[7] / k, w: +f[8] / k, h: +f[9] / k, text: t, line: key, block: f[2] + "-" + f[3] };
            ws.push(w);
            if (!byLine[key]) { byLine[key] = []; order.push(key); }
            byLine[key].push(w);
        }
        const ls = [];
        let out = "";
        for (const key of order) {
            const g = byLine[key];
            const x1 = Math.min(...g.map(w => w.x)), y1 = Math.min(...g.map(w => w.y));
            const x2 = Math.max(...g.map(w => w.x + w.w)), y2 = Math.max(...g.map(w => w.y + w.h));
            const t = g.map(w => w.text).join(" ");
            ls.push({ x: x1, y: y1, w: x2 - x1, h: y2 - y1, text: t, key: key });
            if (out) out += g[0].block === lastBlock ? "\n" : "\n\n";
            out += t; lastBlock = g[0].block;
        }
        words = ws; lines = ls; ocrText = out;
        busy = ws.length ? "" : "No se encontró texto";
    }
    function lineText(key: string): string { return (lines.find(l => l.key === key) ?? {}).text ?? ""; }
    function pickedText(): string {
        let out = "", last = "";
        words.forEach((w, i) => {
            if (!picked[i]) return;
            if (out) out += w.line === last ? " " : "\n";
            out += w.text; last = w.line;
        });
        return out;
    }
    Process {
        id: transProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.busy = "";
                if (t) { root.ocrText = t; root.copyText(t, "Traducción copiada"); }
                else root.flash("No se pudo traducir (¿hay conexión?)");
            }
        }
    }
    function translate(): void {
        if (!ocrText || transProc.running) return;
        busy = "Traduciendo…";
        transProc.command = ["sh", "-c", 'command -v trans >/dev/null || exit 1; printf %s "$1" | trans -brief -no-autocorrect :es 2>/dev/null', "sh", ocrText];
        transProc.running = true;
    }

    // ── Grabación ────────────────────────────────────────────────────────
    function startRec(): void {
        const scr = screenUsed;
        const full = mode === "pantalla" || (sel.width >= capWin.width - 1 && sel.height >= capWin.height - 1);
        const r = full ? fullRect() : sel;
        const args = [hc, "record", full ? scr.name : geom(r, scr)];
        if (mic && recFormat !== "gif") args.push("--mic");
        if (sysAudio && recFormat !== "gif") args.push("--system");
        if (recFormat === "gif") args.push("--gif");
        if (recFormat === "clip") args.push("--clip");
        recLimitNow = recLimit;
        recRect = r; recScreen = scr;
        hiding = true;
        recProc.command = args;
        recProc.running = true;
    }
    Process {
        id: recProc
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                root.hiding = false;
                if (f) { root.recFile = f; root.recStart = Date.now(); root.recording = true; }
                else Quickshell.execDetached(["notify-send", "-a", "Captura", "No se pudo empezar a grabar", "Mira $XDG_RUNTIME_DIR/hyprfrijol/record.log"]);
                Shell.close();
            }
        }
    }
    function stopRec(): void {
        recording = false;
        Quickshell.execDetached([hc, "stop"]);
    }
    // Si el shell se recarga a mitad de una grabación, se recupera el estado
    Process {
        running: true
        command: [root.hc, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^recording (.+) (\d+)$/);
                if (m) { root.recFile = m[1]; root.recStart = +m[2] * 1000; root.recording = true; root.recScreen = Shell.screen; root.recRect = Qt.rect(0, 0, 0, 0); }
            }
        }
    }
    property int recSecs: 0
    property int recLimitNow: 0           // límite de la grabación en curso (GIF 30 s, clip 60 s): para sola
    Timer {
        interval: 500; repeat: true; running: root.recording
        onTriggered: {
            root.recSecs = Math.floor((Date.now() - root.recStart) / 1000);
            if (root.recLimitNow > 0 && root.recSecs >= root.recLimitNow) root.stopRec();
        }
    }
    function mmss(s: int): string { return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0"); }

    // ── Ventanas (resalte al pasar y clic = esa ventana) ────────────────
    Process {
        id: clientsProc
        command: ["sh", "-c", 'printf \'{"m":%s,"c":%s}\' "$(hyprctl monitors -j)" "$(hyprctl clients -j)"']
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(text); } catch (e) {}
                const scr = root.screenUsed;
                const mon = (d.m ?? []).find(m => m.name === scr?.name) ?? {};
                const ws = [mon.activeWorkspace?.id, mon.specialWorkspace?.id].filter(x => x !== undefined && x !== 0);
                root.windows = (d.c ?? []).filter(c => c.mapped && !c.hidden && (ws.includes(c.workspace?.id) || c.pinned))
                    // encima: flotantes y luego por foco reciente
                    .sort((a, b) => (b.floating ? 1 : 0) - (a.floating ? 1 : 0) || (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0))
                    .map(c => ({ title: c.title || c["class"], app: c["class"] ?? "", rect: Qt.rect(c.at[0] - scr.x, c.at[1] - scr.y, c.size[0], c.size[1]) }))
                    .filter(w => w.rect.width > 8 && w.rect.height > 8);
            }
        }
    }

    // ── Ventana principal ───────────────────────────────────────────────
    PanelWindow {
        id: capWin
        screen: root.screenUsed
        visible: root.shown && !root.hiding && root.frozen !== "" && root.stage !== "off"
        color: "black"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hfx-captura"      // sin el blur de las capas "hf-…"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        property alias sheetItem: sheet

        readonly property bool choosing: root.stage === "elegir" || root.stage === "listo"
        readonly property var hoverWin: root.stage === "elegir" && root.mode !== "pantalla" && picker.containsMouse && !picker.moved
                                        ? root.winAt(picker.mouseX, picker.mouseY) : null
        // Zona clara: la elegida o, mientras se elige, la ventana bajo el ratón
        readonly property rect area: root.hasSel() ? root.sel : hoverWin ? root.clampRect(hoverWin.rect) : Qt.rect(0, 0, 0, 0)

        // Pantalla congelada
        Image {
            id: bg
            anchors.fill: parent
            source: root.frozen ? "file://" + root.frozen : ""
            asynchronous: false
            cache: true
            smooth: true
            mipmap: false
        }

        // Oscurecer fuera de la zona (cuatro bandas)
        Item {
            id: dim
            anchors.fill: parent
            readonly property real a: root.stage === "anotar" || root.stage === "texto" ? 0.55 : 0.42
            readonly property rect r: capWin.area
            Rectangle { x: 0; y: 0; width: parent.width; height: dim.r.y; color: "black"; opacity: dim.a }
            Rectangle { x: 0; y: dim.r.y + dim.r.height; width: parent.width; height: parent.height - y; color: "black"; opacity: dim.a }
            Rectangle { x: 0; y: dim.r.y; width: dim.r.x; height: dim.r.height; color: "black"; opacity: dim.a }
            Rectangle { x: dim.r.x + dim.r.width; y: dim.r.y; width: parent.width - x; height: dim.r.height; color: "black"; opacity: dim.a }
        }

        // ── Elegir / ajustar la zona ─────────────────────────────────
        MouseArea {
            id: picker
            anchors.fill: parent
            enabled: capWin.choosing
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point p0
            property rect r0
            property string dragKind: ""      // nuevo | mover | t b l r tl tr bl br
            property bool moved: false
            readonly property string handle: root.stage === "listo" && root.mode === "region" && !pressed ? handleAt(mouseX, mouseY) : dragKind
            cursorShape: root.mode === "ventana" ? Qt.PointingHandCursor
                       : root.mode === "pantalla" ? Qt.ArrowCursor
                       : ({ tl: Qt.SizeFDiagCursor, br: Qt.SizeFDiagCursor, tr: Qt.SizeBDiagCursor, bl: Qt.SizeBDiagCursor,
                            t: Qt.SizeVerCursor, b: Qt.SizeVerCursor, l: Qt.SizeHorCursor, r: Qt.SizeHorCursor,
                            mover: Qt.SizeAllCursor })[handle] ?? Qt.CrossCursor
            function inside(x, y): bool { const s = root.sel; return root.hasSel() && x > s.x && x < s.x + s.width && y > s.y && y < s.y + s.height; }
            function handleAt(x, y): string {
                const s = root.sel, d = 10;
                if (!root.hasSel()) return "";
                const nearX = x > s.x - d && x < s.x + s.width + d, nearY = y > s.y - d && y < s.y + s.height + d;
                const L = Math.abs(x - s.x) < d && nearY, R = Math.abs(x - s.x - s.width) < d && nearY;
                const T = Math.abs(y - s.y) < d && nearX, B = Math.abs(y - s.y - s.height) < d && nearX;
                const v = T ? "t" : B ? "b" : "", h = L ? "l" : R ? "r" : "";
                return v + h || (inside(x, y) ? "mover" : "");
            }
            onPressed: m => {
                if (m.button === Qt.RightButton) {
                    if (root.stage === "listo" && root.mode !== "pantalla") { root.sel = Qt.rect(0, 0, 0, 0); root.stage = "elegir"; }
                    else Shell.close();
                    return;
                }
                p0 = Qt.point(m.x, m.y); r0 = root.sel; moved = false;
                if (root.mode !== "region") dragKind = "";
                else if (root.stage === "listo") dragKind = handleAt(m.x, m.y) || "nuevo";
                else dragKind = "nuevo";
            }
            onPositionChanged: m => {
                if (!pressed || !dragKind) return;
                const dx = m.x - p0.x, dy = m.y - p0.y, r = r0, W = width, H = height;
                if (!moved && Math.abs(dx) < 4 && Math.abs(dy) < 4) return;
                moved = true;
                const box = (x1, y1, x2, y2) => {
                    const ax = Math.max(0, Math.min(x1, x2)), ay = Math.max(0, Math.min(y1, y2));
                    const bx = Math.min(W, Math.max(x1, x2)), by = Math.min(H, Math.max(y1, y2));
                    return Qt.rect(ax, ay, bx - ax, by - ay);
                };
                if (dragKind === "nuevo") { root.stage = "elegir"; root.sel = box(p0.x, p0.y, m.x, m.y); }
                else if (dragKind === "mover") root.sel = Qt.rect(Math.max(0, Math.min(W - r.width, r.x + dx)), Math.max(0, Math.min(H - r.height, r.y + dy)), r.width, r.height);
                else {
                    let x1 = r.x, y1 = r.y, x2 = r.x + r.width, y2 = r.y + r.height;
                    if (dragKind.includes("t")) y1 += dy;
                    if (dragKind.includes("b")) y2 += dy;
                    if (dragKind.includes("l")) x1 += dx;
                    if (dragKind.includes("r")) x2 += dx;
                    root.sel = box(x1, y1, x2, y2);
                }
            }
            onReleased: m => {
                if (m.button !== Qt.LeftButton) return;
                const d = dragKind; dragKind = "";
                if (moved) {
                    moved = false;
                    if (root.hasSel()) root.stage = "listo";
                    else { root.sel = Qt.rect(0, 0, 0, 0); root.stage = "elegir"; }
                    return;
                }
                // Clic sin arrastrar
                if (root.mode === "pantalla") { root.sel = root.fullRect(); root.stage = "listo"; return; }
                if (root.stage === "listo" && d !== "nuevo" && root.mode === "region") return;
                const w = root.winAt(m.x, m.y);
                if (w) { root.sel = root.clampRect(w.rect); root.stage = "listo"; }
                else if (root.stage === "listo") { root.sel = Qt.rect(0, 0, 0, 0); root.stage = "elegir"; }
            }
            onDoubleClicked: m => { if (root.stage === "listo" && (inside(m.x, m.y) || root.mode !== "region")) root.run("copiar"); }
            onWheel: w => w.accepted = true
        }

        // Cruz a lo ancho de la pantalla
        Item {
            anchors.fill: parent
            visible: root.stage === "elegir" && root.mode === "region" && picker.containsMouse && !capWin.hoverWin
            Rectangle { x: 0; y: Math.floor(picker.mouseY); width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.45) }
            Rectangle { x: Math.floor(picker.mouseX); y: 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.45) }
        }

        // Ventana bajo el ratón
        Item {
            visible: !!capWin.hoverWin && !root.hasSel()
            x: capWin.area.x; y: capWin.area.y; width: capWin.area.width; height: capWin.area.height
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, 0.08)
                border.width: 2; border.color: Theme.p; radius: Theme.winRadius
            }
            Rectangle {
                x: 8; y: 8
                width: Math.min(parent.width - 16, wt.implicitWidth + 16); height: 24; radius: Theme.ctl(24)
                color: Qt.rgba(0, 0, 0, 0.66)
                Txt {
                    id: wt; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 16); elide: Text.ElideRight
                    size: 11.5; color: "white"; tabular: true
                    text: (capWin.hoverWin?.title ?? "") + "  ·  " + Math.round(capWin.area.width) + " × " + Math.round(capWin.area.height)
                }
            }
        }

        // Marco de la zona
        Item {
            visible: root.hasSel() && root.stage !== "anotar"
            x: root.sel.x; y: root.sel.y; width: root.sel.width; height: root.sel.height
            Rectangle {
                anchors.fill: parent; anchors.margins: -1.5; color: "transparent"
                border.width: 1.5; border.color: Theme.p
                visible: root.sel.width < capWin.width - 1 || root.sel.height < capWin.height - 1
            }
            // Tiradores: esquinas y lados
            Repeater {
                model: root.stage === "listo" && root.mode === "region" ? 8 : 0
                Rectangle {
                    required property int index
                    readonly property var pos: [[0, 0], [0.5, 0], [1, 0], [1, 0.5], [1, 1], [0.5, 1], [0, 1], [0, 0.5]][index]
                    readonly property bool side: index % 2 === 1
                    width: side ? (pos[1] === 0.5 ? 6 : 18) : 11; height: side ? (pos[1] === 0.5 ? 18 : 6) : 11
                    radius: side ? 3 : 5.5
                    x: pos[0] * root.sel.width - width / 2; y: pos[1] * root.sel.height - height / 2
                    visible: !side || (root.sel.width > 60 && root.sel.height > 60)
                    color: "white"; border.width: 1.5; border.color: Theme.p
                }
            }
            // Medida
            Rectangle {
                visible: root.stage === "elegir" || root.stage === "listo"
                x: Math.min(0, capWin.width - root.sel.x - width)
                y: root.sel.y > 30 ? -28 : 8
                width: sizeTxt.implicitWidth + 16; height: 22; radius: Theme.ctl(22)
                color: Qt.rgba(0, 0, 0, 0.66)
                Txt {
                    id: sizeTxt; anchors.centerIn: parent; size: 11.5; color: "white"; tabular: true
                    text: Math.round(root.sel.width * root.dpr) + " × " + Math.round(root.sel.height * root.dpr)
                          + (root.mode === "pantalla" || Quickshell.screens.length > 1 ? "  ·  " + (root.screenUsed?.name ?? "") : "")
                }
            }
        }

        // Lupa (y coordenadas) junto al cursor mientras se elige o se ajusta
        Item {
            id: loupeBox
            visible: root.mode === "region" && picker.containsMouse
                     && (root.stage === "elegir" && !capWin.hoverWin || picker.moved)
            readonly property real off: 26
            x: picker.mouseX + off + width > capWin.width ? picker.mouseX - off - width : picker.mouseX + off
            y: picker.mouseY + off + height > capWin.height ? picker.mouseY - off - height : picker.mouseY + off
            width: loupe.width; height: loupe.height + 28
            Loupe {
                id: loupe
                source: bg.source
                screenW: capWin.width; screenH: capWin.height
                px: picker.mouseX; py: picker.mouseY
                zoom: 7; cells: 19
                frame: Theme.p
            }
            Rectangle {
                anchors { horizontalCenter: loupe.horizontalCenter; top: loupe.bottom; topMargin: 6 }
                width: coordTxt.implicitWidth + 14; height: 22; radius: Theme.ctl(22)
                color: Qt.rgba(0, 0, 0, 0.7)
                Txt {
                    id: coordTxt; anchors.centerIn: parent; size: 11; color: "white"; tabular: true
                    text: picker.moved && picker.dragKind === "nuevo"
                          ? Math.round(root.sel.width * root.dpr) + " × " + Math.round(root.sel.height * root.dpr)
                          : Math.round(picker.mouseX * root.dpr) + ", " + Math.round(picker.mouseY * root.dpr)
                }
            }
        }

        // Ayuda cuando aún no hay zona
        Rectangle {
            visible: root.stage === "elegir" && !root.hasSel() && !capWin.hoverWin && !picker.containsMouse
            anchors.centerIn: parent
            width: helpTxt.implicitWidth + 28; height: 36; radius: Theme.ctl(36)
            color: Qt.rgba(0, 0, 0, 0.6)
            Txt { id: helpTxt; anchors.centerIn: parent; size: 13.5; color: "white"
                  text: root.mode === "ventana" ? "Haz clic en una ventana" : "Arrastra para elegir una zona · clic en una ventana para capturarla" }
        }

        // ── Hoja de anotación ────────────────────────────────────────
        Item {
            id: sheet
            visible: root.stage === "anotar"
            x: root.sel.x; y: root.sel.y; width: root.sel.width; height: root.sel.height
            readonly property real naturalW: base.implicitWidth || width
            readonly property real naturalH: base.implicitHeight || height
            readonly property real factor: width > 0 ? naturalW / width : 1
            Image {
                id: base
                anchors.fill: parent
                source: root.shot ? "file://" + root.shot : ""
                cache: false
                smooth: true
                mipmap: true
            }
            // Formas
            Repeater {
                model: root.shapes
                delegate: Loader {
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    sourceComponent: shapeComp
                    onLoaded: { item.s = modelData; item.idx = index; }
                }
            }
            Loader { anchors.fill: parent; sourceComponent: shapeComp; active: !!draw.cur; onLoaded: item.s = Qt.binding(() => draw.cur) }

            // Recorte (oscurece fuera del recorte)
            Item {
                id: cropDim
                anchors.fill: parent
                visible: root.crop.width >= 4 && !root.exporting
                readonly property rect c: root.crop
                Rectangle { x: 0; y: 0; width: parent.width; height: cropDim.c.y; color: "black"; opacity: 0.55 }
                Rectangle { x: 0; y: cropDim.c.y + cropDim.c.height; width: parent.width; height: parent.height - y; color: "black"; opacity: 0.55 }
                Rectangle { x: 0; y: cropDim.c.y; width: cropDim.c.x; height: cropDim.c.height; color: "black"; opacity: 0.55 }
                Rectangle { x: cropDim.c.x + cropDim.c.width; y: cropDim.c.y; width: parent.width - x; height: cropDim.c.height; color: "black"; opacity: 0.55 }
                Rectangle { x: cropDim.c.x; y: cropDim.c.y; width: cropDim.c.width; height: cropDim.c.height; color: "transparent"; border.width: 1.5; border.color: "white" }
            }

            MouseArea {
                id: draw
                anchors.fill: parent
                enabled: root.stage === "anotar" && !root.busy
                cursorShape: root.tool === "texto" ? Qt.IBeamCursor : Qt.CrossCursor
                property var cur: null
                onPressed: m => {
                    if (root.tool === "texto") {
                        root.shapes = root.shapes.concat([{ tool: "texto", color: String(root.ink), x1: m.x, y1: m.y, x2: m.x, y2: m.y, text: "" }]);
                        return;
                    }
                    cur = { tool: root.tool, color: String(root.ink), x1: m.x, y1: m.y, x2: m.x, y2: m.y };
                }
                onPositionChanged: m => {
                    if (!cur) return;
                    const c = Object.assign({}, cur);
                    c.x2 = Math.max(0, Math.min(width, m.x)); c.y2 = Math.max(0, Math.min(height, m.y));
                    cur = c;
                }
                onReleased: {
                    if (!cur) return;
                    const c = cur; cur = null;
                    if (Math.abs(c.x2 - c.x1) < 3 && Math.abs(c.y2 - c.y1) < 3) return;
                    if (c.tool === "recortar")
                        root.crop = Qt.rect(Math.min(c.x1, c.x2), Math.min(c.y1, c.y2), Math.abs(c.x2 - c.x1), Math.abs(c.y2 - c.y1));
                    else root.shapes = root.shapes.concat([c]);
                }
            }
        }

        Component {
            id: shapeComp
            Item {
                id: sh
                property var s: ({})
                property int idx: -1
                readonly property real l: Math.min(s.x1 ?? 0, s.x2 ?? 0)
                readonly property real t: Math.min(s.y1 ?? 0, s.y2 ?? 0)
                readonly property real w: Math.abs((s.x2 ?? 0) - (s.x1 ?? 0))
                readonly property real h: Math.abs((s.y2 ?? 0) - (s.y1 ?? 0))
                // Recuadro
                Rectangle {
                    visible: sh.s.tool === "caja"
                    x: sh.l; y: sh.t; width: sh.w; height: sh.h; radius: Theme.r(4)
                    color: "transparent"; border.width: 3; border.color: sh.s.color ?? "red"
                }
                // Resaltar
                Rectangle {
                    visible: sh.s.tool === "resaltar"
                    x: sh.l; y: sh.t; width: sh.w; height: sh.h; radius: 2
                    color: sh.s.color ?? "yellow"; opacity: 0.35
                }
                // Recorte en curso
                Rectangle {
                    visible: sh.s.tool === "recortar"
                    x: sh.l; y: sh.t; width: sh.w; height: sh.h
                    color: "transparent"; border.width: 1.5; border.color: "white"
                }
                // Difuminar: la zona de la captura, desenfocada
                Item {
                    visible: sh.s.tool === "difuminar"
                    x: sh.l; y: sh.t; width: sh.w; height: sh.h
                    clip: true
                    ShaderEffectSource {
                        id: blurSrc
                        anchors.fill: parent
                        sourceItem: sh.s.tool === "difuminar" ? base : null
                        sourceRect: Qt.rect(sh.l, sh.t, sh.w, sh.h)
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: blurSrc
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                        autoPaddingEnabled: false
                    }
                }
                // Flecha
                Shape {
                    id: arrow
                    visible: sh.s.tool === "flecha"
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real ang: Math.atan2((sh.s.y2 ?? 0) - (sh.s.y1 ?? 0), (sh.s.x2 ?? 0) - (sh.s.x1 ?? 0))
                    readonly property real hl: 16
                    ShapePath {
                        strokeColor: sh.s.color ?? "red"; strokeWidth: 4; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: sh.s.x1 ?? 0; startY: sh.s.y1 ?? 0
                        PathLine { x: (sh.s.x2 ?? 0) - Math.cos(arrow.ang) * 8; y: (sh.s.y2 ?? 0) - Math.sin(arrow.ang) * 8 }
                    }
                    ShapePath {
                        strokeColor: sh.s.color ?? "red"; strokeWidth: 2; fillColor: sh.s.color ?? "red"
                        joinStyle: ShapePath.RoundJoin
                        startX: sh.s.x2 ?? 0; startY: sh.s.y2 ?? 0
                        PathLine { x: (sh.s.x2 ?? 0) - Math.cos(arrow.ang - 0.45) * arrow.hl; y: (sh.s.y2 ?? 0) - Math.sin(arrow.ang - 0.45) * arrow.hl }
                        PathLine { x: (sh.s.x2 ?? 0) - Math.cos(arrow.ang + 0.45) * arrow.hl; y: (sh.s.y2 ?? 0) - Math.sin(arrow.ang + 0.45) * arrow.hl }
                        PathLine { x: sh.s.x2 ?? 0; y: sh.s.y2 ?? 0 }
                    }
                }
                // Texto
                TextInput {
                    id: ti
                    visible: sh.s.tool === "texto"
                    x: sh.s.x1 ?? 0; y: (sh.s.y1 ?? 0) - 12
                    color: sh.s.color ?? "white"
                    font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Bold
                    text: sh.s.text ?? ""
                    Component.onCompleted: if (sh.s.tool === "texto" && !sh.s.text && sh.idx >= 0) forceActiveFocus()
                    onTextChanged: if (sh.idx >= 0 && root.shapes[sh.idx] && root.shapes[sh.idx].text !== text) root.shapes[sh.idx].text = text
                    Keys.onEscapePressed: e => { focus = false; keys.forceActiveFocus(); e.accepted = true; }
                    Keys.onReturnPressed: e => { focus = false; keys.forceActiveFocus(); e.accepted = true; }
                    Rectangle { anchors.fill: parent; anchors.margins: -3; z: -1; radius: Theme.r(3); color: "transparent"
                                border.width: 1; border.color: ti.activeFocus ? Qt.rgba(1, 1, 1, 0.6) : "transparent" }
                    Txt { visible: !ti.text && ti.activeFocus; text: "Escribe…"; color: Qt.rgba(1, 1, 1, 0.6); size: 15 }
                }
            }
        }

        // ── Texto detectado (OCR): cajas sobre la zona ──────────────
        Item {
            id: ocrLayer
            visible: root.stage === "texto"
            x: root.sel.x; y: root.sel.y; width: root.sel.width; height: root.sel.height
            property rect band: Qt.rect(0, 0, 0, 0)
            // Arrastrar: elige varias palabras (se copian al soltar)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                property point p0
                onPressed: m => { p0 = Qt.point(m.x, m.y); ocrLayer.band = Qt.rect(m.x, m.y, 0, 0); root.picked = ({}); }
                onPositionChanged: m => {
                    const b = Qt.rect(Math.min(p0.x, m.x), Math.min(p0.y, m.y), Math.abs(m.x - p0.x), Math.abs(m.y - p0.y));
                    ocrLayer.band = b;
                    const p = {};
                    root.words.forEach((w, i) => { if (w.x < b.x + b.width && w.x + w.w > b.x && w.y < b.y + b.height && w.y + w.h > b.y) p[i] = true; });
                    root.picked = p;
                }
                onReleased: {
                    const t = root.pickedText();
                    ocrLayer.band = Qt.rect(0, 0, 0, 0);
                    if (t) root.copyText(t, "Copiado");
                }
            }
            Repeater {
                model: root.lines
                Rectangle {
                    required property var modelData
                    x: modelData.x - 3; y: modelData.y - 2; width: modelData.w + 6; height: modelData.h + 4
                    radius: Theme.r(3)
                    color: "transparent"
                    border.width: 1; border.color: Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, 0.55)
                }
            }
            Repeater {
                model: root.words
                Rectangle {
                    id: wbox
                    required property var modelData
                    required property int index
                    readonly property bool lineHover: root.hoverLine === modelData.line
                    x: modelData.x - 2; y: modelData.y - 1; width: modelData.w + 4; height: modelData.h + 2
                    radius: Theme.r(3)
                    color: Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, root.picked[index] ? 0.5 : wma.containsMouse ? 0.45 : lineHover ? 0.3 : 0.2)
                    border.width: wma.containsMouse || root.picked[index] ? 1.5 : 0
                    border.color: Theme.p
                    MouseArea {
                        id: wma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.hoverLine = containsMouse ? wbox.modelData.line : (root.hoverLine === wbox.modelData.line ? "" : root.hoverLine)
                        onClicked: root.copyText(wbox.modelData.text, "Palabra copiada")
                        onDoubleClicked: root.copyText(root.lineText(wbox.modelData.line), "Línea copiada")
                    }
                }
            }
            Rectangle {
                visible: ocrLayer.band.width > 2
                x: ocrLayer.band.x; y: ocrLayer.band.y; width: ocrLayer.band.width; height: ocrLayer.band.height
                color: Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, 0.12); border.width: 1; border.color: Theme.p
            }
            Rectangle { anchors.fill: parent; anchors.margins: -1.5; color: "transparent"; border.width: 1.5; border.color: Theme.p }
        }

        // Panel con el texto
        Glass {
            id: textPanel
            visible: root.stage === "texto"
            kind: "panel"; big: true
            readonly property real gap: 12
            readonly property bool onRight: root.sel.x + root.sel.width + gap + width < capWin.width - 8
            readonly property bool onLeft: root.sel.x - gap - width > 8
            width: 340
            height: Math.min(capWin.height - 32, Math.max(220, tcol.implicitHeight + 24))
            x: onRight ? root.sel.x + root.sel.width + gap : onLeft ? root.sel.x - gap - width : capWin.width - width - 16
            y: Math.max(16, Math.min(capWin.height - height - 16, root.sel.y))
            ColumnLayout {
                id: tcol
                anchors { fill: parent; margins: 12 }
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Icon { svg: root.scanSvg; size: 16; color: Theme.p }
                    Txt { Layout.fillWidth: true; text: "Texto detectado"; weight: Font.DemiBold; size: 13.5 }
                    Txt { visible: root.words.length > 0; text: root.words.length + " palabras"; muted: true; size: 11.5 }
                    IconBtn { icon: "x"; implicitWidth: 26; implicitHeight: 26; onClicked: root.stage = "listo" }
                }
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; size: 11.5; muted: true
                    text: root.busy ? root.busy : "Clic en una palabra: la copia · doble clic: la línea · arrastra sobre la zona: varias. También puedes seleccionar aquí abajo."
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: Math.min(360, ocrEdit.contentHeight + 20)
                    Layout.minimumHeight: 60
                    radius: Theme.r(8)
                    color: Theme.fill2
                    Flickable {
                        id: fl
                        anchors { fill: parent; margins: 10 }
                        contentHeight: ocrEdit.contentHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        TextEdit {
                            id: ocrEdit
                            width: fl.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            text: root.ocrText
                            color: Theme.t
                            selectionColor: Theme.selBg
                            selectedTextColor: Theme.selText
                            font.family: Theme.font; font.pixelSize: 13
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Btn {
                        kind: "primary"; h: 30; padX: 12; icon: "copy"
                        text: ocrEdit.selectedText ? "Copiar selección" : "Copiar todo"
                        enabled: root.ocrText !== ""
                        onClicked: root.copyText(ocrEdit.selectedText || root.ocrText, "Texto copiado")
                    }
                    Btn { kind: "tonal"; h: 30; padX: 10; icon: "globe"; text: "Traducir"; enabled: root.ocrText !== "" && !transProc.running; onClicked: root.translate() }
                    Item { Layout.fillWidth: true }
                    IconBtn {
                        icon: "ai"; implicitWidth: 30; implicitHeight: 30; tooltip: "Preguntar a la IA por este texto"
                        onClicked: if (root.ocrText) Shell.open("ia", { ask: "Este es el texto de una captura de pantalla:\n\n" + root.ocrText + "\n\n¿Me ayudas con él?" })
                    }
                }
            }
        }

        // ── Barra superior (modo) ────────────────────────────────────
        Glass {
            visible: capWin.choosing && !picker.pressed
            kind: "panel"; radius: Theme.r(10); big: true
            // Arriba; abajo si tapa la zona elegida
            readonly property bool low: root.hasSel() && root.sel.y < 24 + height + 8 && root.sel.y + root.sel.height < capWin.height - 150
            anchors.horizontalCenter: parent.horizontalCenter
            y: low ? capWin.height - height - 104 : 24
            width: bar.implicitWidth + 8; height: bar.implicitHeight + 8
            RowLayout {
                id: bar
                anchors.centerIn: parent
                spacing: 4
                Opt { text: "Captura"; icon: "camera"; on: root.kind === "foto"; onClicked: root.kind = "foto" }
                Opt { text: "Grabar"; icon: "record"; on: root.kind === "video"; onClicked: root.kind = "video" }
                Sep {}
                Opt { text: "Región"; icon: "crop"; on: root.mode === "region"; onClicked: root.setMode("region") }
                Opt { text: "Ventana"; icon: "window"; on: root.mode === "ventana"; onClicked: root.setMode("ventana") }
                Opt { text: "Pantalla"; icon: "monitor"; on: root.mode === "pantalla"; onClicked: root.setMode("pantalla") }
                Sep {}
                Opt { visible: root.kind === "foto"; text: "Cursor"; on: root.cursor; onClicked: { root.cursor = !root.cursor; root.refreeze(0); } }
                Opt { visible: root.kind === "foto"; text: "Retardo 3 s"; icon: "clock"; onClicked: root.refreeze(3000) }
                Opt { visible: root.kind === "video"; text: "Vídeo"; on: root.recFormat === "video"; onClicked: root.recFormat = "video" }
                Opt { visible: root.kind === "video"; text: "Clip 60 s"; on: root.recFormat === "clip"; onClicked: root.recFormat = "clip" }
                Opt { visible: root.kind === "video"; text: "GIF 30 s"; on: root.recFormat === "gif"; onClicked: root.recFormat = "gif" }
                Sep { visible: root.kind === "video" && root.stage === "elegir" && root.recFormat !== "gif" }
                Opt { visible: root.kind === "video" && root.stage === "elegir" && root.recFormat !== "gif"; text: "Micrófono"; on: root.mic; onClicked: root.mic = !root.mic }
                Opt { visible: root.kind === "video" && root.stage === "elegir" && root.recFormat !== "gif"; text: "Audio del sistema"; on: root.sysAudio; onClicked: root.sysAudio = !root.sysAudio }
                IconBtn { icon: "x"; implicitHeight: 30; implicitWidth: 30; onClicked: Shell.close() }
            }
        }

        // ── Barra de acciones (zona elegida) ─────────────────────────
        Glass {
            id: actBar
            visible: root.stage === "listo" && !picker.pressed
            kind: "panel"; radius: Theme.r(12); big: true
            width: acts.implicitWidth + 10; height: acts.implicitHeight + 10
            readonly property real below: root.sel.y + root.sel.height + 12
            x: Math.max(8, Math.min(parent.width - width - 8, root.sel.x + root.sel.width / 2 - width / 2))
            y: below + height < parent.height - 8 ? below
               : root.sel.y - height - 12 > 8 ? root.sel.y - height - 12
               : root.sel.y + root.sel.height - height - 72
            RowLayout {
                id: acts
                anchors.centerIn: parent
                spacing: 2
                // Foto
                Act { visible: root.kind === "foto"; icon: "copy"; text: "Copiar"; onClicked: root.run("copiar") }
                Act { visible: root.kind === "foto"; icon: "download"; text: "Guardar"; onClicked: root.run("guardar") }
                Act { visible: root.kind === "foto"; icon: "edit"; text: "Anotar"; onClicked: root.run("anotar") }
                Act { visible: root.kind === "foto" && root.editor !== ""; icon: "external"; text: root.editor === "satty" ? "Satty" : "Swappy"; onClicked: root.run("editar") }
                Act { visible: root.kind === "foto"; icon: "pin"; text: "Fijar"; onClicked: root.run("fijar") }
                Act { visible: root.kind === "foto"; iconSvg: root.scanSvg; text: "Copiar texto"; onClicked: root.run("texto") }
                Act { visible: root.kind === "foto"; iconSvg: root.lensSvg; text: "Lens"; onClicked: root.run("lens") }
                Btn { visible: root.kind === "foto"; kind: "primary"; h: 32; padX: 12; icon: "ai"; text: "Preguntar a la IA"; onClicked: root.run("ia") }
                // Vídeo
                Act { visible: root.kind === "video" && root.recFormat !== "gif"; icon: "mic"; text: "Micrófono"; kind: root.mic ? "tonal" : "ghost"; onClicked: root.mic = !root.mic }
                Act { visible: root.kind === "video" && root.recFormat !== "gif"; icon: "volume"; text: "Audio del sistema"; kind: root.sysAudio ? "tonal" : "ghost"; onClicked: root.sysAudio = !root.sysAudio }
                Rectangle {
                    visible: root.kind === "video"
                    implicitHeight: 32; implicitWidth: recTxt.implicitWidth + 26; radius: Theme.ctl(32)
                    color: "#C2453B"
                    Txt { id: recTxt; anchors.centerIn: parent; text: root.recFormat === "gif" ? "● Grabar GIF" : root.recFormat === "clip" ? "● Grabar clip" : "● Grabar"; weight: Font.DemiBold; color: "white" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run("grabar") }
                }
                IconBtn { icon: "x"; implicitHeight: 32; implicitWidth: 32; onClicked: Shell.close() }
            }
        }

        // ── Barra de anotación ───────────────────────────────────────
        Glass {
            id: annBar
            visible: root.stage === "anotar"
            kind: "panel"; radius: Theme.r(10); big: true
            width: ann.implicitWidth + 8; height: ann.implicitHeight + 8
            x: Math.max(8, Math.min(parent.width - width - 8, root.sel.x + root.sel.width / 2 - width / 2))
            y: root.sel.y + root.sel.height + 12 + height < parent.height - 8 ? root.sel.y + root.sel.height + 12
               : Math.max(8, root.sel.y + root.sel.height - height - 12)
            RowLayout {
                id: ann
                anchors.centerIn: parent
                spacing: 4
                IconBtn { icon: "chevron_left"; implicitHeight: 30; implicitWidth: 30; tooltip: "Volver"; onClicked: root.stage = "listo" }
                Repeater {
                    model: root.tools
                    Opt { required property var modelData; text: modelData[1]; on: root.tool === modelData[0]; onClicked: root.tool = modelData[0] }
                }
                Sep {}
                Repeater {
                    model: root.inks
                    delegate: Item {
                        required property var modelData
                        implicitWidth: 24; implicitHeight: 30
                        Rectangle {
                            anchors.centerIn: parent
                            width: 22; height: 22; radius: 11
                            color: "transparent"
                            border.width: Qt.colorEqual(root.ink, parent.modelData[1]) ? 2 : 0
                            border.color: parent.modelData[1]
                            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: parent.parent.modelData[1] }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ink = parent.modelData[1] }
                    }
                }
                Sep {}
                IconBtn { icon: "restart"; implicitHeight: 30; implicitWidth: 30; opacity: root.shapes.length || root.crop.width ? 1 : 0.4
                          onClicked: root.undo() }
                Opt { text: "Copiar"; onClicked: root.exportAs("copiar") }
                Opt { text: "Guardar"; onClicked: root.exportAs("guardar") }
                Opt { text: "Fijar"; onClicked: root.exportAs("fijar") }
                Opt { text: "Texto"; onClicked: root.exportAs("ocr") }
                Btn { kind: "primary"; h: 30; padX: 12; icon: "ai"; text: "Preguntar a la IA"; onClicked: root.exportAs("ia") }
                IconBtn { icon: "x"; implicitHeight: 30; implicitWidth: 30; onClicked: Shell.close() }
            }
        }

        // Mensaje de espera (recorte, OCR…) y avisos («Copiado…»)
        Rectangle {
            visible: (root.busy !== "" && root.stage !== "texto") || root.toast !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 120 }
            width: busyTxt.implicitWidth + 24; height: 30; radius: Theme.ctl(30)
            color: Qt.rgba(0, 0, 0, 0.75)
            Txt { id: busyTxt; anchors.centerIn: parent; text: root.toast || root.busy; color: "white"; size: 12 }
        }

        // Ayuda inferior
        Txt {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 72 }
            visible: capWin.choosing && !picker.pressed
            text: root.stage === "listo"
                  ? (root.kind === "video" ? "Intro grabar · flechas mover · Mayús + flechas tamaño · clic derecho otra zona · Esc salir"
                     : "Intro copiar · S guardar · A anotar · F fijar · T texto · I IA · flechas mover · Mayús + flechas tamaño · Esc salir")
                  : "Arrastra una zona · clic en una ventana · R región · V ventana · P pantalla · Tab foto/vídeo · Esc salir"
            size: 11.5; color: "white"
            style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.55)
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier;
                const k = e.key;
                if (k === Qt.Key_Escape) {
                    if (root.stage === "texto" || root.stage === "anotar") root.stage = "listo";
                    else Shell.close();
                } else if (root.stage === "elegir" || root.stage === "listo") {
                    const arrows = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] };
                    if (arrows[k] && root.hasSel() && root.mode === "region") {
                        const st = ctrl ? 10 : 1, d = arrows[k], s = root.sel;
                        root.sel = shift
                            ? root.clampRect(Qt.rect(s.x, s.y, Math.max(4, s.width + d[0] * st), Math.max(4, s.height + d[1] * st)))
                            : Qt.rect(Math.max(0, Math.min(capWin.width - s.width, s.x + d[0] * st)), Math.max(0, Math.min(capWin.height - s.height, s.y + d[1] * st)), s.width, s.height);
                        root.stage = "listo";
                    }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                        if (root.stage === "listo") root.run(root.kind === "video" ? "grabar" : "copiar");
                        else if (capWin.hoverWin) { root.sel = root.clampRect(capWin.hoverWin.rect); root.stage = "listo"; }
                    }
                    else if (k === Qt.Key_Tab) root.kind = root.kind === "foto" ? "video" : "foto";
                    else if (ctrl && k === Qt.Key_C) root.run("copiar");
                    else if (ctrl && k === Qt.Key_S) root.run("guardar");
                    else if (ctrl) return;
                    else if (k === Qt.Key_R) root.setMode("region");
                    else if (k === Qt.Key_V) root.setMode("ventana");
                    else if (k === Qt.Key_P) root.setMode("pantalla");
                    else if (root.stage === "listo" && root.kind === "foto" && ({ [Qt.Key_C]: 1, [Qt.Key_S]: 1, [Qt.Key_A]: 1, [Qt.Key_E]: 1, [Qt.Key_F]: 1, [Qt.Key_T]: 1, [Qt.Key_I]: 1, [Qt.Key_L]: 1 })[k])
                        root.run(({ [Qt.Key_C]: "copiar", [Qt.Key_S]: "guardar", [Qt.Key_A]: "anotar", [Qt.Key_E]: root.editor ? "editar" : "anotar",
                                    [Qt.Key_F]: "fijar", [Qt.Key_T]: "texto", [Qt.Key_I]: "ia", [Qt.Key_L]: "lens" })[k]);
                    else return;
                } else if (root.stage === "anotar") {
                    if (ctrl && k === Qt.Key_Z) root.undo();
                    else if (ctrl && k === Qt.Key_C) root.exportAs("copiar");
                    else if (ctrl && k === Qt.Key_S) root.exportAs("guardar");
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.exportAs("copiar");
                    else if (!ctrl && k >= Qt.Key_1 && k <= Qt.Key_6) root.tool = root.tools[k - Qt.Key_1][0];
                    else return;
                } else if (root.stage === "texto") {
                    if (ctrl && k === Qt.Key_C || k === Qt.Key_Return || k === Qt.Key_Enter) root.copyText(ocrEdit.selectedText || root.ocrText, "Texto copiado");
                    else return;
                } else return;
                e.accepted = true;
            }
        }
        onVisibleChanged: if (visible) Qt.callLater(() => keys.forceActiveFocus())
    }
    property string hoverLine: ""
    Timer { id: toastTimer; interval: 1800; onTriggered: root.toast = "" }

    // Cuenta atrás del retardo (la pantalla real, sin la capa)
    PanelWindow {
        screen: root.screenUsed
        visible: root.shown && root.countdown > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hfx-cuenta"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 64; implicitHeight: 64
        mask: Region {}
        Rectangle {
            anchors.fill: parent; radius: 32
            color: Qt.rgba(0, 0, 0, 0.6)
            Txt { anchors.centerIn: parent; text: root.countdown; size: 26; weight: Font.DemiBold; color: "white"; tabular: true }
        }
    }

    component Sep: Rectangle { implicitWidth: 1; implicitHeight: 18; color: Theme.ov; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 2; Layout.rightMargin: 2 }
    component Opt: Btn {
        property bool on: false
        kind: on ? "tonal" : "ghost"; h: 30; padX: 11
    }
    component Act: Btn { kind: "ghost"; h: 32; padX: 10 }

    // ── Capturas fijadas (imagen flotante encima de todo) ───────────────
    function addPin(file: string, r, scr): void {
        const maxW = (scr?.width ?? 1440) * 0.6, maxH = (scr?.height ?? 900) * 0.6;
        const k = Math.min(1, maxW / Math.max(1, r.width), maxH / Math.max(1, r.height));
        pins = pins.concat([{ id: ++pinSeq, file: file, w: r.width, h: r.height, k: k, x: r.x, y: r.y, scr: scr }]);
    }
    function removePin(id: int): void { pins = pins.filter(p => p.id !== id); }
    Variants {
        model: root.pins
        PanelWindow {
            id: pin
            required property var modelData
            property real px: modelData.x
            property real py: modelData.y
            property real k: modelData.k
            property bool hovered: pinMa.containsMouse || pinBar.hov
            screen: modelData.scr
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "hfx-fijada"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true }
            margins { left: Math.round(px); top: Math.round(py) }
            implicitWidth: Math.round(modelData.w * k) + 6
            implicitHeight: Math.round(modelData.h * k) + 6
            Rectangle {
                anchors.fill: parent
                radius: Theme.r(9)
                color: Theme.glassPopup
                border.width: pin.hovered ? 2 : 1; border.color: pin.hovered ? Theme.p : Theme.ov
                Image {
                    anchors { fill: parent; margins: 3 }
                    source: "file://" + pin.modelData.file
                    smooth: true; mipmap: true
                    fillMode: Image.Stretch
                }
            }
            MouseArea {
                id: pinMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point p0
                onPressed: m => p0 = Qt.point(m.x, m.y)
                onPositionChanged: m => {
                    if (!pressed) return;
                    pin.px = Math.max(-pin.width + 40, Math.min((pin.screen?.width ?? 2000) - 40, pin.px + m.x - p0.x));
                    pin.py = Math.max(0, Math.min((pin.screen?.height ?? 2000) - 40, pin.py + m.y - p0.y));
                }
                onClicked: m => { if (m.button !== Qt.LeftButton) root.removePin(pin.modelData.id); }
                onDoubleClicked: root.removePin(pin.modelData.id)
                onWheel: w => pin.k = Math.max(0.15, Math.min(3, pin.k * (w.angleDelta.y > 0 ? 1.1 : 1 / 1.1)))
            }
            Rectangle {
                id: pinBar
                property bool hov: pinHov.hovered
                visible: pin.hovered && pin.width > 110
                anchors { top: parent.top; right: parent.right; margins: 10 }
                width: pinRow.implicitWidth + 8; height: 30; radius: Theme.ctl(30)
                color: Theme.glassPopup; border.width: 1; border.color: Theme.ov
                HoverHandler { id: pinHov }
                Row {
                    id: pinRow
                    anchors.centerIn: parent
                    spacing: 2
                    IconBtn { icon: "copy"; implicitWidth: 26; implicitHeight: 24; tooltip: "Copiar"
                              onClicked: { Quickshell.execDetached([root.hc, "copy", pin.modelData.file]); } }
                    IconBtn { icon: "download"; implicitWidth: 26; implicitHeight: 24; tooltip: "Guardar"
                              onClicked: Quickshell.execDetached(["sh", "-c", 'f="$("$1" save "$2")" && notify-send -a Captura -i "$f" "Captura guardada" "$(basename "$f")"', "sh", root.hc, pin.modelData.file]) }
                    IconBtn { icon: "x"; implicitWidth: 26; implicitHeight: 24; tooltip: "Cerrar"; onClicked: root.removePin(pin.modelData.id) }
                }
            }
        }
    }

    // IPC "capture" (en modules/Modules.qml, siempre cargado; llama a estas funciones):
    function ipcRegion(x: int, y: int, w: int, h: int): void {
        mode = "region";
        if (shown && frozen) { sel = Qt.rect(x, y, w, h); stage = "listo"; }
        else { preset = Qt.rect(x, y, w, h); Shell.open("captura"); }
    }
    function ipcShoot(): void { if (shown) run(kind === "video" ? "grabar" : "copiar"); }
    function ipcStatus(): string { return recording ? "recording " + recFile : stage; }
    // Carga diferida: no se descarga mientras graba, hay capturas fijadas o queda trabajo pendiente
    readonly property bool busyState: recording || pins.length > 0 || stage !== "off" || busy !== "" || exporting || countdown > 0 || toast !== ""

    // ── Indicador de grabación (fuera de la zona grabada) ───────────────
    PanelWindow {
        id: recWin
        screen: root.recScreen ?? Shell.screen
        visible: root.recording
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hfx-grabando"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region { item: pill }

        // Marco alrededor de lo que se graba
        Rectangle {
            visible: root.recRect.width > 0 && root.recRect.width < recWin.width - 4
            x: root.recRect.x - 3; y: root.recRect.y - 3
            width: root.recRect.width + 6; height: root.recRect.height + 6
            color: "transparent"; border.width: 2; border.color: "#C2453B"; radius: Theme.r(3)
            opacity: 0.85
        }
        Rectangle {
            id: pill
            readonly property bool above: root.recRect.y > 40
            x: root.recRect.width > 0 && root.recRect.width < recWin.width - 4
               ? Math.min(recWin.width - width - 8, root.recRect.x + root.recRect.width - width)
               : recWin.width / 2 - width / 2
            y: root.recRect.width > 0 && root.recRect.width < recWin.width - 4
               ? (above ? root.recRect.y - height - 8 : Math.min(recWin.height - height - 8, root.recRect.y + root.recRect.height + 8))
               : 8
            width: pr.implicitWidth + 16; height: 28; radius: Theme.ctl(28)
            color: "#C2453B"
            RowLayout {
                id: pr
                anchors.centerIn: parent
                spacing: 8
                Rectangle { width: 8; height: 8; radius: 4; color: "white"
                    SequentialAnimation on opacity { running: root.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600 } NumberAnimation { to: 1; duration: 600 } } }
                Txt { text: (root.recLimitNow === 30 ? "GIF " : "REC ") + root.mmss(root.recSecs) + (root.recLimitNow > 0 ? " / " + root.mmss(root.recLimitNow) : ""); color: "white"; weight: Font.DemiBold; size: 12; tabular: true }
                Rectangle { implicitWidth: 1; implicitHeight: 14; color: Qt.rgba(1, 1, 1, 0.4) }
                Txt { text: "■ Detener"; color: "white"; size: 12 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stopRec() }
        }
    }
}
