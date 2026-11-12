// Pestaña IA del panel lateral (diseño: Asistente.png / PanelHandoff.png).
// Habla con scripts/hf-ai (proveedor en Ajustes › IA: aiProvider/aiModel/aiEndpoint).
// Cuando el modelo propone cambios al shell salen como tarjeta con Aplicar / Descartar y, tras aplicar,
// «✓ Aplicado al shell» + Deshacer. Los comandos de terminal piden confirmación antes de ejecutarse.
// Ajustes › IA: aiContextCapture (chip «+ Captura» e imágenes adjuntas), aiConfirm (false → los cambios se
// aplican solos, con Deshacer), aiHistory (la conversación se guarda en ~/.local/share/hyprfrijol/ai y se
// recupera al volver a abrir). aiTerminal / aiControlShell / aiReadDesktop los aplica hf-ai.
// El modelo puede consultar el escritorio antes de responder (ventanas, avisos, archivos…: «steps», se ven en
// gris sobre la respuesta) y proponer un plan de varios pasos (ventanas, apps, ajustes, música, temporizadores…):
// tarjeta con los pasos numerados, Aplicar / Descartar y Deshacer. Los pasos que no se pueden deshacer (cerrar
// una ventana, borrar avisos) piden confirmación aunque aiConfirm esté apagado.
// Aprobación: cada paso enseña qué cambia (plan[i].preview de hf-ai, p. ej. «abajo → arriba»); con varios pasos hay una
// casilla por paso (sel) y solo se aplican los marcados; «Aprobar siempre esta acción» guarda plan[i].kind en
// aiAlwaysApprove (Ajustes › IA lo revoca) y los planes con todo aprobado siempre se aplican solos (hf-ai: auto),
// nunca los pasos sin vuelta atrás. La primera vez sale una tarjeta con lo que puede hacer y ejemplos (aiOnboarded).
// setWindow({address, class, title}): abierto con Super+Ctrl+A (hf-ai summon) → la conversación va sobre esa ventana.
// Dictado: no tiene micrófono propio; el dictado global (Super + Alt + D o el botón de la barra) escribe en la entrada.
// Imágenes (si aiContextCapture): arrastrar archivos / imágenes de la web, Ctrl+V con una imagen en el portapapeles o el
// clip (selector de archivos). Salen en miniatura sobre la entrada (× para quitarlas) y en la burbuja del mensaje;
// van en messages[i].images y hf-ai las manda al modelo (o su OCR si no ve imágenes). `hf-ai attach` consigue las que
// no son archivos locales (portapapeles, URL, datos crudos del arrastre, selector).
// En directo: `hf-ai chat` con "stream" escribe una línea {"partial": …} por trozo (se ve en una burbuja que crece,
// liveText) y {"step": …} por consulta; la última línea es {"final": respuesta}. «Detener» corta y deja lo que llegó.
// Bajo la última respuesta: Copiar, Regenerar y «Otro modelo» (repite con otro modelo del mismo proveedor:
// `hf-ai models` da la lista y la petición lleva "model").
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../.."
import "../../components"
import "../../services"

Item {
    id: root
    property bool active: false
    // [{ role: "user"|"ai", text, images, actions, labels, code, state: ""|"applied"|"discarded"|"undone", undo, error, confirm }]
    property var messages: []
    property bool busy: false
    readonly property string aiName: String(Settings.get("aiName", "") ?? "").trim()
    property bool useWindow: Settings.get("aiContextWindow", true)
    property bool useClipboard: Settings.get("aiContextClipboard", true)
    property string captureText: ""
    // Imágenes que se mandarán con el próximo mensaje (rutas locales)
    property var pending: []
    // Documentos (PDF, texto, código, DOCX…) que se mandarán con el próximo mensaje: hf-ai lee su texto
    property var pendingDocs: []
    readonly property int maxDocs: 8
    property bool showHistory: false        // lista de conversaciones guardadas (botón del reloj en la cabecera)
    readonly property int maxImages: 6
    readonly property bool allowCapture: Settings.get("aiContextCapture", true) !== false
    readonly property bool confirmChanges: Settings.get("aiConfirm", true) !== false
    readonly property bool keepHistory: Settings.get("aiHistory", true) === true
    readonly property string historyDir: Paths.home + "/.local/share/hyprfrijol/ai"
    property string historyFile: ""
    property bool capturing: false
    property var notice: null              // aviso del handoff { text, sub }
    property var winInfo: null             // ventana desde la que se abrió (hf-ai summon)

    readonly property var suggestions: root.winInfo
        ? ["Resume lo que hay en esta ventana", "Explica el error que se ve", "Pon esta ventana en pantalla completa", "Mándala al espacio 2"]
        : ["Resume mis notificaciones", "Temporizador de 10 min para el té", "Pon la barra arriba y el fondo lago", "Cierra las ventanas de Firefox"]

    function focusInput() { input.forceActiveFocus(); }
    function clear() { messages = []; notice = null; busy = false; applyingIdx = -1; chatProc.running = false; liveText = ""; liveSteps = []; modelMenu = -1; input.text = ""; pending = []; pendingDocs = []; captureText = ""; historyFile = ""; winInfo = null; showHistory = false; focusInput(); }
    function setWindow(w) { if (w && w.address) { winInfo = w; useWindow = true; } Qt.callLater(focusInput); }
    function patch(i, p) { const m = messages.slice(); m[i] = Object.assign({}, m[i], p); messages = m; }
    function push(m) { messages = [...messages, m]; Qt.callLater(scrollEnd); }
    function scrollEnd() { flick.contentY = Math.max(0, flick.contentHeight - flick.height); }

    function context() {
        return { window: useWindow, clipboard: useClipboard, capture: allowCapture && captureText !== "",
                 captureText: allowCapture ? captureText : "",
                 windowInfo: useWindow && winInfo ? winInfo : null };
    }
    // Tarea de la próxima petición: "quick" para lo que llega de Spotlight o de la voz (hf-ai usa aiModelQuick)
    property string nextTask: ""
    function payload(extra) {
        const task = nextTask;
        nextTask = "";
        return JSON.stringify(Object.assign({ task: task, messages: messages.filter(m => !m.error && !m.local)
                                    .map(m => Object.assign({ role: m.role, text: String(m.text).slice(0, 6000) },
                                                            m.images?.length ? { images: m.images } : {},
                                                            m.files?.length ? { files: m.files } : {},
                                                            m.steps?.length ? { queried: true } : {})),   // ver mcp_auto en hf-ai
                                context: context() }, extra ?? {}));
    }

    function ask(text, task) {
        nextTask = task ?? "";
        text = String(text ?? "").trim();
        if ((text === "" && !pending.length && !pendingDocs.length) || busy) return;
        const m = { role: "user", text: text };
        if (pending.length) m.images = pending;
        if (pendingDocs.length) m.files = pendingDocs;
        push(m);
        pending = []; pendingDocs = [];
        showHistory = false;
        input.text = "";
        send();
    }

    // ---- imágenes adjuntas
    readonly property var imgRe: /\.(png|jpe?g|webp|gif|bmp|tiff?|avif|heic|heif|jxl|svg|ico)$/i
    function addImages(list) {
        if (!allowCapture) { if ((list ?? []).length) note("Adjuntar imágenes está desactivado en Ajustes › IA."); return; }
        const p = pending.slice();
        for (const x of list ?? []) if (x && !p.includes(String(x))) p.push(String(x));
        if (p.length > maxImages) note("Como mucho " + maxImages + " imágenes por mensaje.");
        pending = p.slice(0, maxImages);
    }
    function removeImage(i) { const p = pending.slice(); p.splice(i, 1); pending = p; }
    function addDocs(list) {
        const p = pendingDocs.slice();
        for (const x of list ?? []) if (x && !p.includes(String(x))) p.push(String(x));
        if (p.length > maxDocs) note("Como mucho " + maxDocs + " documentos por mensaje.");
        pendingDocs = p.slice(0, maxDocs);
    }
    function removeDoc(i) { const p = pendingDocs.slice(); p.splice(i, 1); pendingDocs = p; }
    function baseName(f) { return String(f).split("/").pop(); }
    function note(t) { push({ role: "ai", text: t, local: true }); }
    // Ruta local, file://…, https://… (Captura › «Preguntar a la IA», Spotlight, arrastres)
    function attach(src) {
        if (!allowCapture || !src) return;
        src = String(src);
        const local = src.startsWith("file://") ? decodeURIComponent(src.slice(7).replace(/^[^/]*/, "")) : src;
        if (local.startsWith("/") && imgRe.test(local)) addImages([local]);
        else if (local.startsWith("/") && /\.[A-Za-z0-9]{1,6}$/.test(local)) addDocs([local]);
        else attachFrom([src]);
    }
    function attachFrom(srcs) {
        if (!allowCapture || !srcs.length) return;
        attachProc.command = [Paths.script("hf-ai"), "attach"].concat(srcs);
        attachProc.running = true;
    }
    function attachResult(text) {
        let r = {};
        try { r = JSON.parse(text); } catch (e) { r = { error: "No pude adjuntar la imagen" }; }
        if (r.images?.length) addImages(r.images);
        if (r.files?.length) addDocs(r.files);
        if (!r.images?.length && !r.files?.length && r.error) note(r.error);
        if (!Shell.view) Shell.open("ia", "ia");   // el selector de archivos pudo cerrar el panel
        Qt.callLater(focusInput);
    }
    Process {
        id: attachProc
        property bool paste: false              // Ctrl+V: si no hay imagen, se pega el texto
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) {}
                if (attachProc.paste && !(r.images?.length)) input.paste();
                else root.attachResult(text);
                attachProc.paste = false;
            }
        }
    }
    function pasteImage() {
        if (!allowCapture || attachProc.running) { input.paste(); return; }
        attachProc.paste = true;
        attachFrom(["clipboard"]);
    }
    // Datos crudos de un arrastre (navegadores): base64 por stdin a `hf-ai attach -`
    property string rawB64: ""
    Process {
        id: rawProc
        command: [Paths.script("hf-ai"), "attach", "-"]
        stdinEnabled: true
        onStarted: { write(root.rawB64); root.rawB64 = ""; stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: root.attachResult(text) }
        onExited: stdinEnabled = true
    }
    function b64(buf) {
        const a = new Uint8Array(buf), T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const out = [];
        let i = 0;
        for (; i + 2 < a.length; i += 3) {
            const n = (a[i] << 16) | (a[i + 1] << 8) | a[i + 2];
            out.push(T[n >> 18] + T[(n >> 12) & 63] + T[(n >> 6) & 63] + T[n & 63]);
        }
        if (i < a.length) {
            const n = (a[i] << 16) | ((a[i + 1] ?? 0) << 8);
            out.push(T[n >> 18] + T[(n >> 12) & 63] + (i + 1 < a.length ? T[(n >> 6) & 63] : "=") + "=");
        }
        return out.join("");
    }
    function dropped(d) {
        const urls = (d.hasUrls ? d.urls : []).map(u => String(u));
        const files = urls.filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7).replace(/^[^/]*/, "")));
        const fmts = d.formats ?? [];
        const imgFmt = fmts.find(f => String(f).startsWith("image/"));
        if (files.length) { addImages(files.filter(f => imgRe.test(f))); addDocs(files.filter(f => !imgRe.test(f))); }
        else if (imgFmt && typeof d.getDataAsArrayBuffer === "function" && !rawProc.running) {
            rawB64 = b64(d.getDataAsArrayBuffer(imgFmt));
            rawProc.stdinEnabled = true;
            rawProc.running = true;
        } else {
            const m = d.hasHtml ? /<img[^>]+src="([^"]+)"/i.exec(d.html) : null;
            const web = m ? [m[1].replace(/&amp;/g, "&")] : urls.filter(u => /^https?:/.test(u)).slice(0, maxImages);
            if (web.length) attachFrom(web);
            else if (d.hasText && /^(https?:\/\/|file:\/\/|\/)/.test(d.text.trim())) attachFrom([d.text.trim()]);
            else if (d.hasText && d.text.trim() !== "") { input.insert(input.cursorPosition, d.text); }
            else note("Eso no parece una imagen ni un archivo.");
        }
        d.accept(Qt.CopyAction);
        focusInput();
    }
    // Respuesta en directo: lo que va llegando (sin los bloques internos) y las consultas hechas mientras tanto
    property string liveText: ""
    property var liveSteps: []
    property bool gotFinal: false
    function send(model) {
        busy = true;
        notice = null;
        liveText = ""; liveSteps = []; gotFinal = false; modelMenu = -1;
        // La conversación va por la entrada estándar: como argumento, una larga pasa del límite del sistema (128 KB)
        chatProc.sendIn = payload(Object.assign({ stream: true }, model !== undefined ? { model: model } : {}));
        chatProc.command = [Paths.script("hf-ai"), "chat", "-"];
        chatProc.stdinEnabled = true;
        chatProc.running = true;
        Qt.callLater(scrollEnd);
    }
    function onLine(line) {
        let j = null;
        try { j = JSON.parse(line); } catch (e) { return; }
        if (j.final !== undefined) { gotFinal = true; reply(j.final); }
        else if (j.partial !== undefined) { liveText = j.partial; Qt.callLater(scrollEnd); }
        else if (j.step !== undefined) liveSteps = liveSteps.concat([j.step]);
        else { gotFinal = true; reply(j); }            // salida de una sola vez (sin "stream")
    }
    // Cortar la respuesta: se queda lo que ya llegó (sin acciones: no estaban completas)
    function stop() {
        if (!busy) return;
        busy = false;
        gotFinal = true;
        chatProc.running = false;
        if (liveText.trim() !== "") push({ role: "ai", text: liveText, steps: liveSteps.concat(["Respuesta detenida"]), actions: [], labels: [], plan: [], code: "", state: "" });
        liveText = ""; liveSteps = [];
    }
    // Otra respuesta para la última pregunta (quita la respuesta y lo que vino con ella); `model`: con otro modelo
    function regenerate(model) {
        if (busy) return;
        let i = messages.length - 1;
        while (i >= 0 && messages[i].role !== "user") i--;
        if (i < 0) return;
        messages = messages.slice(0, i + 1);
        send(model);
    }
    // «Otro modelo»: lista de `hf-ai models` (se pide al abrir el menú; modelMenu = índice del mensaje, -1 cerrado)
    property int modelMenu: -1
    property var modelList: []
    property string modelErr: ""
    function openModels(i) {
        if (modelMenu === i) { modelMenu = -1; return; }
        modelMenu = i;
        modelsProc.running = false; modelsProc.running = true;
    }
    Process {
        id: modelsProc
        command: [Paths.script("hf-ai"), "models"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const j = JSON.parse(text); root.modelList = j.models ?? []; root.modelErr = j.error ?? ""; }
                catch (e) { root.modelList = []; root.modelErr = "No pude leer la lista de modelos"; }
            }
        }
    }
    property string toastText: ""
    property int toastIdx: -1
    function toast(t, i) { toastText = t; toastIdx = i; toastT.restart(); }
    Timer { id: toastT; interval: 1400; onTriggered: root.toastText = "" }
    function retry() {
        if (messages.length && messages[messages.length - 1].error) messages = messages.slice(0, -1);
        send();
    }

    function reply(r) {
        root.busy = false;
        root.liveText = ""; root.liveSteps = [];
        if (!r || typeof r !== "object") r = { error: "Respuesta no válida de hf-ai" };
        if (r.error) {
            root.push({ role: "ai", text: r.error, error: true });
            if (!root.active) Quickshell.execDetached(["notify-send", "-a", Settings.get("aiName", "") || "Asistente", "-i", "dialog-error", r.error]);
        } else {
            root.push({ role: "ai", text: r.text || (r.actions?.length ? "Puedo hacerlo. Estos son los pasos:" : "…"),
                        actions: r.actions ?? [], labels: r.labels ?? [], plan: r.plan ?? [],
                        // filtro de secretos de hf-ai: se avisa cuántos datos sensibles no salieron del equipo
                        steps: (r.steps ?? []).concat(r.redacted ? [(r.redacted === 1 ? "Se ocultó 1 dato sensible" : "Se ocultaron " + r.redacted + " datos sensibles") + " del contexto"] : []),
                        code: r.code ?? "", state: "", sel: (r.actions ?? []).map(() => true), auto: !!r.auto, model: r.model ?? "" });
            if (Settings.get("aiVoice", false)) Quickshell.execDetached([Paths.script("hf-ai"), "speak", r.text || ""]);
            // Sin confirmación (Ajustes › IA) o todo «aprobado siempre» (aiAlwaysApprove): se aplica ya y queda
            // el botón Deshacer (salvo pasos sin vuelta atrás, que siempre preguntan)
            const auto = ((!root.confirmChanges && !r.confirm) || r.auto) && (r.actions?.length ?? 0) > 0;
            if (auto) root.apply(root.messages.length - 1);
            // con el panel cerrado (conversación por voz) hay que verlo para aprobar los cambios
            else if ((r.actions?.length ?? 0) > 0 && !root.active) Shell.open("ia");
        }
    }
    Process {
        id: chatProc
        property string sendIn: ""
        stdinEnabled: true
        onStarted: { write(sendIn); sendIn = ""; stdinEnabled = false; }
        stdout: SplitParser { onRead: line => root.onLine(line) }
        onExited: code => {
            if (root.gotFinal || !root.busy) return;
            root.busy = false; root.liveText = ""; root.liveSteps = [];
            root.push({ role: "ai", text: code !== 0 ? "hf-ai falló (código " + code + ")." : "hf-ai terminó sin responder.", error: true });
        }
    }

    // ---- aplicar / descartar / deshacer
    property int applyingIdx: -1
    // Aprobar o rechazar cada paso (casillas del plan): solo se aplican los marcados
    function selOf(m) { return (m.actions ?? []).map((a, k) => (m.sel ?? [])[k] !== false); }
    function toggleStep(i, k) { const s = selOf(messages[i]); s[k] = !s[k]; patch(i, { sel: s }); }
    function apply(i) {
        if (applyProc.running) return;             // un plan cada vez: el resultado se apunta en el que se lanzó
        const sel = selOf(messages[i]);
        const acts = messages[i].actions.filter((a, k) => sel[k]);
        if (!acts.length) { discard(i); return; }
        applyingIdx = i;
        applyProc.sendIn = JSON.stringify(acts);
        applyProc.command = [Paths.script("hf-ai"), "apply", "-"];
        applyProc.stdinEnabled = true;
        applyProc.running = true;
    }
    // «Aprobar siempre para esta acción» (Ajustes › IA › Aprobadas siempre la revoca). Nunca para los pasos sin vuelta atrás.
    readonly property var always: Settings.get("aiAlwaysApprove", [])
    function setAlways(kind, on) {
        if (!kind) return;
        const l = always.filter(k => k !== kind);
        Settings.set("aiAlwaysApprove", on ? l.concat([kind]) : l);
    }
    readonly property bool onboarded: Settings.get("aiOnboarded", false) === true
    function finishOnboarding() { if (!onboarded) Settings.set("aiOnboarded", true); }
    readonly property var examples: [
        ["Pon la barra arriba y el tema oscuro", false],
        ["Resume mis notificaciones", false],
        ["Descarga el audio en mp3 de este vídeo: ", true],
        ["Busca fondos de montañas en Wallhaven y añade uno a mis fondos", false],
        ["¿Qué memorias USB hay conectadas? Expulsa la que esté montada", false],
        ["Temporizador de 10 min para el té", false]
    ]
    function useExample(e) {
        finishOnboarding();
        if (e[1]) { input.text = e[0]; focusInput(); input.cursorPosition = input.text.length; }
        else ask(e[0]);
    }
    Process {
        id: applyProc
        property string sendIn: ""
        stdinEnabled: true
        onStarted: { write(sendIn); sendIn = ""; stdinEnabled = false; }
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) {}
                if (r.error) root.push({ role: "ai", text: r.error, error: true, local: true });
                else {
                    // si mientras tanto se vació el chat o se abrió otra conversación, ese plan ya no está
                    if (root.applyingIdx >= 0 && root.applyingIdx < root.messages.length) root.patch(root.applyingIdx, { state: "applied", undo: r.undo ?? "" });
                    root.applyingIdx = -1;
                    for (const t of r.results ?? []) root.push({ role: "ai", text: t, local: true });   // herramientas MCP de solo lectura
                    if (r.errors?.length) root.push({ role: "ai", text: "Algunos pasos no se pudieron hacer: " + r.errors.join(" · "), local: true });
                }
            }
        }
    }
    function discard(i) {
        patch(i, { state: "discarded" });
        push({ role: "ai", text: "De acuerdo, no cambié nada.", local: true });
    }
    function undo(i) {
        if (messages[i].undo) Quickshell.execDetached([Paths.script("hf-ai"), "undo", messages[i].undo]);
        patch(i, { state: "undone" });
    }
    function runCode(code) {
        const term = Settings.get("terminal", "kitty");
        Quickshell.execDetached([term, "-e", "sh", "-c", code + '; echo; printf "Pulsa Intro para cerrar…"; read _']);
    }

    // ---- handoff «Continuar en Claude ↗»
    function handoff() {
        handoffProc.command = [Paths.script("hf-ai"), "handoff", payload()];
        handoffProc.running = true;
    }
    Process {
        id: handoffProc
        stdout: StdioCollector {
            onStreamFinished: { try { root.notice = JSON.parse(text); } catch (e) { root.notice = { text: "No se pudo continuar en Claude", sub: "" }; } }
        }
    }

    // ---- captura de pantalla con OCR: el panel se aparta un momento para no salir en ella
    function toggleCapture() {
        if (captureText !== "") { captureText = ""; return; }
        capturing = true;
        Shell.close();
        capTimer.restart();
    }
    Timer { id: capTimer; interval: 450; onTriggered: { capProc.running = true; } }
    Process {
        id: capProc
        command: [Paths.script("hf-ai"), "capture"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) {}
                root.capturing = false;
                root.captureText = r.text || " ";
                Shell.open("ia", "ia");
            }
        }
    }

    // ---- historial (aiHistory)
    property bool histLoading: false               // al abrir una guardada no se vuelve a escribir (subía a «Hoy»)
    onMessagesChanged: if (keepHistory && !histLoading) histTimer.restart()
    Timer {
        id: histTimer
        interval: 800
        onTriggered: {
            const msgs = root.messages.filter(m => !m.local);
            if (!msgs.length) return;
            if (root.historyFile === "") root.historyFile = root.historyDir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".json";
            histWriter.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && cat > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", root.historyFile];
            histWriter.sendIn = (
                                  JSON.stringify({ messages: msgs.map(m => ({ role: m.role, text: m.text, images: m.images ?? [], files: m.files ?? [], labels: m.labels ?? [], plan: m.plan ?? [],
                                                                              steps: m.steps ?? [], code: m.code ?? "",
                                                                              state: m.state ?? "", error: !!m.error })) }, null, 1));
            histWriter.stdinEnabled = true;
            histWriter.running = true;
        }
    }
    Process {
        id: histWriter
        property string sendIn: ""
        stdinEnabled: true
        onStarted: { write(sendIn); sendIn = ""; stdinEnabled = false; }
        onExited: if (root.showHistory) root.loadHistory()
    }
    // Lista de conversaciones guardadas: [{ file, t (epoch), title, n, text (para buscar) }]
    property var histList: []
    property string histQuery: ""
    readonly property var histShown: {
        const q = histQuery.trim().toLowerCase();
        return q === "" ? histList : histList.filter(h => h.title.toLowerCase().includes(q) || h.text.includes(q));
    }
    function toggleHistory() { showHistory = !showHistory; if (showHistory) { histQuery = ""; loadHistory(); } else focusInput(); }
    function loadHistory() { histLister.running = false; histLister.running = true; }
    Process {
        id: histLister
        command: ["python3", "-c", `
import json, os, sys, glob
out = []
for f in glob.glob(os.path.join(sys.argv[1], "*.json")):
    try:
        d = json.load(open(f)); ms = [m for m in d.get("messages", []) if not m.get("error")]
    except Exception:
        continue
    if not ms: continue
    us = [str(m.get("text", "")) for m in ms if m.get("role") == "user"]
    first = next((u for u in us if u.strip()), "") or ("Imagen" if any(m.get("images") for m in ms) else "Conversación")
    out.append({"file": f, "t": os.path.getmtime(f), "title": " ".join(first.split())[:90], "n": len(ms),
                "text": " ".join(str(m.get("text", "")) for m in ms).lower()[:4000]})
out.sort(key=lambda h: -h["t"])
print(json.dumps(out[:300]))
`, root.historyDir]
        stdout: StdioCollector { onStreamFinished: { try { root.histList = JSON.parse(text); } catch (e) { root.histList = []; } } }
    }
    function openHistory(h) {
        histOpener.target = h.file;
        histOpener.running = true;
    }
    Process {
        id: histOpener
        property string target: ""
        command: ["cat", target]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.busy = false; chatProc.running = false; root.notice = null;
                    root.historyFile = histOpener.target;
                    root.histLoading = true;
                    root.messages = (d.messages ?? []).map(m => Object.assign({ actions: [] }, m, { state: m.state || (m.labels?.length ? "discarded" : "") }));
                    root.histLoading = false;
                    root.showHistory = false;
                    Qt.callLater(root.scrollEnd);
                    Qt.callLater(root.focusInput);
                } catch (e) { root.note("No pude abrir esa conversación."); root.showHistory = false; }
            }
        }
    }
    // Borrar con deshacer: el archivo pasa a «.borrado» y se elimina del todo a los 8 s (o al borrar otra)
    property var histDeleted: null
    function deleteHistory(h) {
        purgeDeleted();
        Quickshell.execDetached(["mv", "-f", h.file, h.file + ".borrado"]);
        histDeleted = h;
        histUndoT.restart();
        histList = histList.filter(x => x.file !== h.file);
        if (h.file === historyFile) clear();
    }
    function undoDeleteHistory() {
        const h = histDeleted;
        if (!h) return;
        histUndoT.stop(); histDeleted = null;
        Quickshell.execDetached(["mv", "-f", h.file + ".borrado", h.file]);
        histList = histList.concat([h]).sort((a, b) => b.t - a.t);
    }
    function purgeDeleted() {
        if (histDeleted) Quickshell.execDetached(["rm", "-f", histDeleted.file + ".borrado"]);
        histDeleted = null; histUndoT.stop();
    }
    Timer { id: histUndoT; interval: 8000; onTriggered: root.purgeDeleted() }
    // lo que quedó a medio borrar si el shell se cerró antes de los 8 s
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.json.borrado', "sh", root.historyDir])
    function histWhen(t) {
        const d = new Date(t * 1000), now = new Date();
        const days = Math.floor((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        return days === 0 ? "Hoy · " + Time.fmt(d) : days === 1 ? "Ayer · " + Time.fmt(d)
             : days < 7 ? Qt.formatDate(d, "dddd") : Qt.formatDate(d, "d MMM yyyy");
    }
    // Al cargar: recupera la última conversación (si es de hoy)
    Process {
        running: root.keepHistory
        command: ["sh", "-c", 'f=$(ls -1t "$1"/*.json 2>/dev/null | head -n1); [ -n "$f" ] && [ "$(date -r "$f" +%F)" = "$(date +%F)" ] && { echo "$f"; cat "$f"; }', "sh", root.historyDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                if (nl < 0 || root.messages.length) return;
                try {
                    const d = JSON.parse(text.slice(nl + 1));
                    root.historyFile = text.slice(0, nl);
                    root.histLoading = true;
                    root.messages = (d.messages ?? []).map(m => Object.assign({ actions: [] }, m, { state: m.state || (m.labels?.length ? "discarded" : "") }));
                    root.histLoading = false;
                } catch (e) {}
            }
        }
    }

    // ======================================================================= UI
    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool on: false
        property bool outline: false
        signal clicked()
        implicitHeight: 22
        implicitWidth: chipTxt.implicitWidth + 16
        radius: Theme.r(6)
        color: on ? Theme.pc : "transparent"
        border.width: outline && !on ? 1 : 0
        border.color: Theme.ov
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.light ? "#000" : "#FFF"; opacity: chipMouse.containsMouse ? 0.06 : 0 }
        Txt { id: chipTxt; anchors.centerIn: parent; text: chip.text; size: 11.5; color: chip.on ? Theme.pcText : Theme.t; weight: Font.Medium }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
    // Miniatura redondeada de una imagen adjunta (× para quitarla si `removable`; clic → la abre)
    component ImgThumb: ClippingRectangle {
        id: th
        property string path: ""
        property bool removable: false
        property bool cover: true               // recorte cuadrado; false → respeta la proporción (alto según `ratio`)
        readonly property real ratio: thImg.implicitWidth > 0 ? thImg.implicitHeight / thImg.implicitWidth : 0.65
        signal remove()
        radius: Theme.r(7)
        color: Theme.s4
        border.width: 1; border.color: Theme.ov
        Icon { anchors.centerIn: parent; visible: thImg.status !== Image.Ready; name: "image"; size: 16; color: Theme.tv }
        Image {
            id: thImg
            anchors.fill: parent
            source: th.path ? "file://" + th.path : ""
            sourceSize: th.cover ? Qt.size(Math.round(th.width * 2), Math.round(th.height * 2)) : Qt.size(Math.round(th.width * 2), 0)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("file://" + th.path) }
        Rectangle {
            visible: th.removable
            anchors { top: parent.top; right: parent.right; margins: 3 }
            width: 18; height: 18; radius: 9
            color: Qt.alpha(Theme.bg, xMa.containsMouse ? 0.95 : 0.78)
            Icon { anchors.centerIn: parent; name: "x"; size: 9; color: Theme.t }
            MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: th.remove() }
        }
    }
    // Documento adjunto (nombre con icono; × para quitarlo si `removable`; clic → lo abre)
    component DocChip: Rectangle {
        id: dc
        property string path: ""
        property bool removable: false
        property color fg: Theme.t
        signal remove()
        implicitHeight: 26
        implicitWidth: Math.min(220, dcRow.implicitWidth + 16)
        radius: Theme.r(7)
        color: Qt.alpha(Theme.t, dcMa.containsMouse ? 0.10 : 0.06)
        border.width: 1; border.color: Theme.ov
        Row {
            id: dcRow
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 5
            CatIcon { anchors.verticalCenter: parent.verticalCenter; path: dc.path; size: 13 }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220 - 16 - 17 - (dc.removable ? 20 : 0))
                text: root.baseName(dc.path); size: 11.5; color: dc.fg; elide: Text.ElideMiddle
            }
            Item { visible: dc.removable; width: 15; height: 15 }
        }
        MouseArea { id: dcMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("file://" + dc.path) }
        Rectangle {
            visible: dc.removable
            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
            width: 16; height: 16; radius: 8
            color: dxMa.containsMouse ? Qt.alpha(Theme.t, 0.16) : "transparent"
            Icon { anchors.centerIn: parent; name: "x"; size: 8; color: Theme.t }
            MouseArea { id: dxMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dc.remove() }
        }
    }
    component SmallBtn: Rectangle {
        id: sb
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitHeight: 26
        implicitWidth: sbTxt.implicitWidth + 22
        radius: Theme.r(7)
        color: primary ? Theme.p : "transparent"
        border.width: primary ? 0 : 1
        border.color: Theme.ov
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.light ? "#000" : "#FFF"; opacity: sbMouse.containsMouse ? 0.07 : 0 }
        Txt { id: sbTxt; anchors.centerIn: parent; text: sb.text; size: 12; weight: Font.DemiBold; color: sb.primary ? Theme.pText : Theme.t }
        MouseArea { id: sbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sb.clicked() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------- contexto
        Flow {
            Layout.fillWidth: true
            Layout.preferredWidth: root.width - 24
            Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 8
            spacing: 6
            Txt { height: 22; text: "Contexto"; size: 11.5; muted: true; rightPadding: 2 }
            Chip {
                text: root.winInfo ? "Ventana: " + String(root.winInfo.title || root.winInfo["class"] || "").slice(0, 26) + (String(root.winInfo.title || "").length > 26 ? "…" : "")
                                   : "Documento activo"
                on: root.useWindow
                onClicked: root.useWindow = !root.useWindow
            }
            Chip { text: "Portapapeles"; on: root.useClipboard; onClicked: root.useClipboard = !root.useClipboard }
            Chip {
                visible: root.allowCapture
                text: root.capturing ? "Capturando…" : root.captureText !== "" ? "Captura ✓" : "+ Captura"
                on: root.captureText !== ""
                outline: true
                onClicked: root.toggleCapture()
            }
            Rectangle {
                implicitHeight: 24
                implicitWidth: hoTxt.implicitWidth + 20
                radius: Theme.r(6)
                color: Theme.p
                Rectangle { anchors.fill: parent; radius: parent.radius; color: "#FFF"; opacity: hoMouse.containsMouse ? 0.08 : 0 }
                Txt { id: hoTxt; anchors.centerIn: parent; text: "Continuar en Claude ↗"; size: 11.5; weight: Font.DemiBold; color: Theme.pText }
                MouseArea { id: hoMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.handoff() }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }

        // ---------------------------------------------------- aviso del handoff
        Rectangle {
            visible: root.notice !== null
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.bottomMargin: 0
            implicitHeight: noticeRow.implicitHeight + 20
            radius: Theme.r(10)
            color: Theme.fill2
            RowLayout {
                id: noticeRow
                anchors.fill: parent; anchors.margins: 10
                spacing: 10
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26; radius: Theme.r(7); color: Theme.ter
                    Text { anchors.centerIn: parent; text: "C"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.px(12); font.weight: Font.Bold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { Layout.fillWidth: true; text: root.notice?.text ?? ""; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; text: root.notice?.sub ?? ""; size: 11.5; muted: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
                }
                IconBtn { icon: "x"; iconSize: 12; fg: Theme.tv; onClicked: root.notice = null }
            }
        }

        // ---------------------------------------------------- conversación
        Flickable {
            id: flick
            visible: !root.showHistory
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, msgs.implicitHeight + 24, onboard.visible ? onboard.height + 24 : 0)
            boundsBehavior: Flickable.StopAtBounds
            onHeightChanged: Qt.callLater(root.scrollEnd)

            // Primera vez: qué puede hacer y ejemplos (aiOnboarded; «Empezar» o usar un ejemplo lo cierra)
            Rectangle {
                id: onboard
                visible: root.messages.length === 0 && !root.busy && !root.onboarded
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(12, (flick.height - height) / 2)
                width: parent.width - 24
                height: obCol.implicitHeight + 28
                radius: Theme.r(12)
                color: Theme.fill2
                border.width: 1; border.color: Theme.ov
                ColumnLayout {
                    id: obCol
                    x: 14; y: 14
                    width: parent.width - 28
                    spacing: 10
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: Theme.r(10); color: Theme.pc
                            Icon { anchors.centerIn: parent; name: "ai"; size: 16; color: Theme.pcText }
                        }
                        ColumnLayout {
                            spacing: 0
                            Txt { text: root.aiName ? root.aiName + ", tu asistente del escritorio" : "Tu asistente del escritorio"; size: 14; weight: Font.DemiBold }
                            Txt { text: "Esto es lo que puede hacer"; size: 11.5; muted: true }
                        }
                    }
                    Repeater {
                        model: [
                            ["sparkle", "Responde, resume y redacta, con el contexto que elijas arriba (ventana, portapapeles, captura)."],
                            ["sliders", "Cambia el escritorio con palabras: ajustes, ventanas, apps, música, fondos, descargas, memorias USB…"],
                            ["check", "Nada cambia sin tu aprobación: ves qué pasa (antes → después), eliges qué pasos, y casi todo se deshace."],
                            ["shield", "Solo mira tus ventanas, avisos o archivos si se lo permites en Ajustes › IA."]
                        ]
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 9
                            Icon { Layout.alignment: Qt.AlignTop; Layout.topMargin: 1; name: parent.modelData[0]; size: 13; color: Theme.p }
                            Txt { Layout.fillWidth: true; text: parent.modelData[1]; size: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
                        }
                    }
                    Txt { Layout.topMargin: 2; text: "Prueba con"; size: 10.5; muted: true; weight: Font.DemiBold }
                    Repeater {
                        model: root.examples
                        Rectangle {
                            id: ex
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: exT.implicitHeight + 12
                            radius: Theme.r(7)
                            color: exMa.containsMouse ? Qt.alpha(Theme.t, 0.07) : "transparent"
                            border.width: 1; border.color: Theme.ov
                            Txt {
                                id: exT
                                x: 10; y: 6; width: parent.width - 40
                                text: "«" + ex.modelData[0].replace(/: $/, "…") + "»"
                                size: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                            }
                            Icon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: ex.modelData[1] ? "edit" : "send"; size: 12; color: Theme.tv }
                            MouseArea { id: exMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.useExample(ex.modelData) }
                        }
                    }
                    RowLayout {
                        Layout.topMargin: 2
                        spacing: 6
                        SmallBtn { text: "Empezar"; primary: true; onClicked: { root.finishOnboarding(); root.focusInput(); } }
                        SmallBtn { text: "Ajustes de IA"; onClicked: Shell.open("ajustesapp", "ia") }
                    }
                }
            }

            // Vacío
            ColumnLayout {
                visible: root.messages.length === 0 && !root.busy && root.onboarded
                anchors.centerIn: parent
                width: parent.width - 64
                spacing: 8
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 40; implicitHeight: 40; radius: Theme.r(11); color: Theme.pc
                    Icon { anchors.centerIn: parent; name: "ai"; size: 18; color: Theme.pcText }
                }
                Txt { Layout.alignment: Qt.AlignHCenter; text: root.aiName ? "Soy " + root.aiName + ". ¿En qué te ayudo?" : "¿En qué te ayudo?"; size: 15; weight: Font.DemiBold }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap; elide: Text.ElideNone
                    muted: true; size: 12
                    text: "Pregunta lo que quieras, pide un comando o cambia el escritorio con palabras. Los cambios se aplican solo si los apruebas (o si marcaste «Aprobar siempre» esa acción)."
                }
            }

            Column {
                id: msgs
                width: parent.width - 24
                x: 12
                y: Math.max(12, flick.contentHeight - implicitHeight - 12)
                spacing: 10

                Repeater {
                    model: root.messages
                    delegate: Item {
                        id: msg
                        required property var modelData
                        required property int index
                        readonly property bool mine: modelData.role === "user"
                        width: msgs.width
                        // respuestas: Copiar · Regenerar (la última) debajo de la burbuja, al pasar el cursor
                        readonly property bool hasActs: !msg.mine && !msg.modelData.local && !msg.modelData.error && (msg.modelData.text ?? "") !== ""
                        readonly property bool isLast: msg.index === root.messages.length - 1
                        readonly property bool menuOpen: msg.isLast && root.modelMenu === msg.index && !root.busy
                        height: bubble.height + (hasActs ? 26 : 0) + (menuOpen ? modelFlow.implicitHeight + 6 : 0)
                        HoverHandler { id: msgHover }
                        Row {
                            id: actsRow
                            visible: msg.hasActs
                            anchors { left: parent.left; top: bubble.bottom; topMargin: 3; leftMargin: 2 }
                            spacing: 2
                            opacity: msgHover.hovered || msg.isLast ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                            IconBtn {
                                icon: "copy"; iconSize: 12; fg: Theme.tv; implicitWidth: 24; implicitHeight: 22
                                tooltip: "Copiar la respuesta"
                                onClicked: { Quickshell.execDetached(["wl-copy", "--", String(msg.modelData.text)]); root.toast("Copiada", msg.index); }
                            }
                            IconBtn {
                                visible: msg.isLast && !root.busy
                                icon: "refresh"; iconSize: 12; fg: Theme.tv; implicitWidth: 24; implicitHeight: 22
                                tooltip: "Otra respuesta"
                                onClicked: root.regenerate()
                            }
                            IconBtn {
                                visible: msg.isLast && !root.busy
                                icon: "sparkle"; iconSize: 12; fg: msg.menuOpen ? Theme.p : Theme.tv; implicitWidth: 24; implicitHeight: 22
                                tooltip: "Repetir con otro modelo"
                                onClicked: root.openModels(msg.index)
                            }
                            // Modelo que respondió
                            Txt {
                                visible: (msg.modelData.model ?? "") !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: msg.modelData.model ?? ""; size: 10.5; muted: true; leftPadding: 4
                            }
                            Txt { id: copiedTxt; anchors.verticalCenter: parent.verticalCenter; visible: root.toastText !== "" && root.toastIdx === msg.index; text: root.toastText; size: 10.5; muted: true; leftPadding: 4 }
                        }

                        // «Otro modelo»: los del proveedor; clic → la última pregunta otra vez con ese modelo
                        Flow {
                            id: modelFlow
                            visible: msg.menuOpen
                            anchors { left: parent.left; right: parent.right; top: actsRow.bottom; topMargin: 4; leftMargin: 2 }
                            spacing: 5
                            Txt {
                                height: 22
                                verticalAlignment: Text.AlignVCenter
                                text: root.modelErr !== "" && !root.modelList.length ? root.modelErr
                                    : modelsProc.running && !root.modelList.length ? "Buscando modelos…" : "Repetir con"
                                size: 11; muted: true; rightPadding: 2
                            }
                            Repeater {
                                model: msg.menuOpen ? root.modelList : []
                                Chip {
                                    required property var modelData
                                    readonly property string mid: String(modelData[0] ?? "")
                                    text: String(modelData[1] ?? modelData[0] ?? "") || "Predeterminado"
                                    on: mid !== "" && mid === (msg.modelData.model ?? "")
                                    outline: true
                                    onClicked: root.regenerate(mid)
                                }
                            }
                        }

                        Rectangle {
                            id: bubble
                            anchors.right: msg.mine ? parent.right : undefined
                            width: Math.min(msg.width * (msg.mine ? 0.85 : 0.92), Math.max(body.implicitWidth, rich.visible && rich.wide ? 10000 : 0, extra.implicitWidth, stepsCol.implicitWidth, imgFlow.wantW) + 24)
                            height: inner.implicitHeight + 20
                            color: msg.mine ? Theme.pc : Theme.fill2
                            border.width: msg.modelData.error ? 1 : 0
                            border.color: Theme.danger
                            // esquinas "7 14 4 14" (mías) / "7 14 14 4" (IA)
                            topLeftRadius: 7; topRightRadius: 14
                            bottomRightRadius: msg.mine ? 4 : 14
                            bottomLeftRadius: msg.mine ? 14 : 4

                            ColumnLayout {
                                id: inner
                                x: 12; y: 10
                                width: bubble.width - 24
                                spacing: 10
                                // Consultas que hizo antes de responder
                                Column {
                                    id: stepsCol
                                    visible: (msg.modelData.steps?.length ?? 0) > 0
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Repeater {
                                        model: msg.modelData.steps ?? []
                                        Row {
                                            required property string modelData
                                            spacing: 6
                                            Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.modelData.startsWith("Se ocult") ? "shield" : "search"; size: 10; color: Theme.tv }
                                            Txt { text: parent.modelData; size: 11; muted: true }
                                        }
                                    }
                                }
                                // Imágenes adjuntas (una grande; varias en cuadrícula)
                                Flow {
                                    id: imgFlow
                                    readonly property var list: msg.modelData.images ?? []
                                    readonly property int n: list.length
                                    readonly property real wantW: n === 0 ? 0 : n === 1 ? 220 : Math.min(n, 3) * 76 - 6
                                    visible: n > 0
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: imgFlow.list
                                        ImgThumb {
                                            required property string modelData
                                            path: modelData
                                            cover: imgFlow.n !== 1
                                            width: imgFlow.n === 1 ? Math.min(220, imgFlow.width) : 70
                                            height: imgFlow.n === 1 ? Math.max(48, Math.min(180, width * ratio)) : 70
                                        }
                                    }
                                }
                                Flow {
                                    visible: (msg.modelData.files ?? []).length > 0
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: msg.modelData.files ?? []
                                        DocChip { required property string modelData; path: modelData; fg: msg.mine ? Theme.pcText : Theme.t }
                                    }
                                }
                                // Respuesta del asistente con formato (AiRich: comandos con «Copiar», gráficos, imágenes)
                                AiRich {
                                    id: rich
                                    visible: !msg.mine && !msg.modelData.error && (msg.modelData.text ?? "") !== ""
                                    Layout.fillWidth: true
                                    text: visible ? msg.modelData.text : ""
                                }
                                Text {
                                    id: body
                                    visible: text !== "" && (msg.mine || !!msg.modelData.error)
                                    Layout.fillWidth: true
                                    text: msg.modelData.text
                                    textFormat: msg.mine ? Text.PlainText : Text.MarkdownText
                                    wrapMode: Text.Wrap
                                    color: msg.mine ? Theme.pcText : msg.modelData.error ? Theme.danger : Theme.t
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(12.5)
                                    lineHeight: 1.18
                                    linkColor: Theme.p
                                    onLinkActivated: l => Qt.openUrlExternally(l)
                                }
                                ColumnLayout {
                                    id: extra
                                    visible: (msg.modelData.labels?.length ?? 0) > 0 || (msg.modelData.code ?? "") !== "" || !!msg.modelData.error
                                    Layout.fillWidth: true
                                    spacing: 10
                                    implicitWidth: (msg.modelData.labels?.length ?? 0) > 0 || (msg.modelData.code ?? "") !== "" ? 1000 : 200

                                    // Plan propuesto: pasos numerados (✓ al aplicarse; «sin deshacer» si no tiene vuelta atrás)
                                    Rectangle {
                                        visible: (msg.modelData.labels?.length ?? 0) > 0
                                        Layout.fillWidth: true
                                        implicitWidth: 1000
                                        implicitHeight: planCol.implicitHeight + 14
                                        radius: Theme.r(8)
                                        color: Theme.s1
                                        border.width: 1; border.color: Theme.ov
                                        opacity: msg.modelData.state === "discarded" || msg.modelData.state === "undone" ? 0.55 : 1
                                        Column {
                                            id: planCol
                                            x: 10; y: 7
                                            width: parent.width - 20
                                            spacing: 5
                                            Txt {
                                                width: planCol.width
                                                text: msg.modelData.state === "" && (msg.modelData.labels?.length ?? 0) > 1
                                                    ? "Plan · " + msg.modelData.labels.length + " pasos · desmarca los que no quieras"
                                                    : msg.modelData.state === "" ? "Cambio propuesto · revisa antes de aplicar"
                                                    : (msg.modelData.labels?.length ?? 0) > 1 ? "Plan · " + msg.modelData.labels.length + " pasos" : "Cambio"
                                                size: 10.5; muted: true; weight: Font.DemiBold
                                                wrapMode: Text.Wrap; elide: Text.ElideNone
                                            }
                                            Repeater {
                                                model: msg.modelData.labels ?? []
                                                RowLayout {
                                                    id: stepRow
                                                    required property string modelData
                                                    required property int index
                                                    readonly property var info: (msg.modelData.plan ?? [])[index] ?? {}
                                                    readonly property bool multi: (msg.modelData.labels?.length ?? 0) > 1
                                                    readonly property bool pending: msg.modelData.state === ""
                                                    readonly property bool on: (msg.modelData.sel ?? [])[index] !== false
                                                    readonly property bool done: msg.modelData.state === "applied" && on
                                                    readonly property bool isAlways: !!info.kind && root.always.includes(info.kind)
                                                    width: planCol.width
                                                    spacing: 8
                                                    // Número del paso; con varios pasos y sin aplicar, casilla para aprobarlo o no
                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignTop
                                                        implicitWidth: 18; implicitHeight: 18
                                                        radius: stepRow.multi && stepRow.pending ? Theme.r(5) : 9
                                                        color: stepRow.done || (stepRow.multi && stepRow.pending && stepRow.on) ? Theme.p : Theme.fill2
                                                        border.width: stepRow.multi && stepRow.pending && !stepRow.on ? 1.5 : 0
                                                        border.color: Theme.tv
                                                        Txt {
                                                            anchors.centerIn: parent
                                                            text: stepRow.done || (stepRow.multi && stepRow.pending && stepRow.on) ? "✓"
                                                                : stepRow.multi && stepRow.pending ? "" : String(stepRow.index + 1)
                                                            size: 10; weight: Font.Bold; tabular: true
                                                            color: stepRow.done || (stepRow.multi && stepRow.pending && stepRow.on) ? Theme.pText : Theme.t
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent; anchors.margins: -4
                                                            enabled: stepRow.multi && stepRow.pending
                                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                            onClicked: root.toggleStep(msg.index, stepRow.index)
                                                        }
                                                    }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Txt {
                                                            Layout.fillWidth: true
                                                            text: stepRow.modelData + (!stepRow.on && !stepRow.pending ? " · omitido" : "")
                                                            size: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                                                            opacity: stepRow.on ? 1 : 0.5
                                                            font.strikeout: !stepRow.on
                                                        }
                                                        // Qué cambia: «abajo → arriba», la carpeta, la ventana…
                                                        Txt {
                                                            visible: (stepRow.info.preview ?? "") !== "" && stepRow.on
                                                            Layout.fillWidth: true
                                                            text: stepRow.info.preview ?? ""
                                                            size: 11; muted: true; font.family: Theme.mono
                                                            wrapMode: Text.WrapAnywhere; elide: Text.ElideNone; maximumLineCount: 3
                                                        }
                                                        // Aprobar siempre (no para lo que no se puede deshacer)
                                                        Txt {
                                                            visible: stepRow.pending && stepRow.on && !stepRow.info.confirm && !!stepRow.info.kind
                                                            text: stepRow.isAlways ? "✓ Aprobado siempre · quitar" : "Aprobar siempre esta acción"
                                                            size: 10.5; color: stepRow.isAlways ? Theme.p : Theme.tv
                                                            font.underline: alwaysMa.containsMouse
                                                            MouseArea {
                                                                id: alwaysMa
                                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.setAlways(stepRow.info.kind, !stepRow.isAlways)
                                                            }
                                                        }
                                                    }
                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignTop
                                                        visible: stepRow.info.undo === false
                                                        implicitHeight: 16; implicitWidth: nuT.implicitWidth + 10; radius: Theme.r(4)
                                                        color: Qt.alpha(Theme.danger, 0.14)
                                                        Txt { id: nuT; anchors.centerIn: parent; text: "sin deshacer"; size: 9.5; weight: Font.DemiBold; color: Theme.danger }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: (msg.modelData.labels?.length ?? 0) > 0
                                        spacing: 6
                                        SmallBtn {
                                            readonly property int n: msg.modelData.labels?.length ?? 0
                                            readonly property int k: root.selOf(msg.modelData).filter(x => x).length
                                            visible: msg.modelData.state === ""
                                            opacity: k > 0 ? 1 : 0.5
                                            text: root.applyingIdx === msg.index && applyProc.running ? "Aplicando…"
                                                : n > 1 ? (k === n ? "Aplicar los " + n + " pasos" : k === 0 ? "Ningún paso marcado" : "Aplicar " + k + " de " + n)
                                                : "Aprobar y aplicar"
                                            primary: true
                                            onClicked: if (k > 0) root.apply(msg.index)
                                        }
                                        SmallBtn { visible: msg.modelData.state === ""; text: (msg.modelData.labels?.length ?? 0) > 1 ? "Rechazar todo" : "Rechazar"; onClicked: root.discard(msg.index) }
                                        Txt {
                                            visible: msg.modelData.state !== ""
                                            text: msg.modelData.state === "applied" ? (msg.modelData.auto ? "✓ Hecho · aprobado siempre" : "✓ Hecho")
                                                : msg.modelData.state === "undone" ? "Cambios deshechos" : "Descartado"
                                            size: 12; weight: Font.DemiBold
                                            color: msg.modelData.state === "applied" ? Theme.p : Theme.tv
                                        }
                                        SmallBtn { visible: msg.modelData.state === "applied"; text: "Deshacer"; onClicked: root.undo(msg.index) }
                                    }

                                    // Comando propuesto
                                    Rectangle {
                                        visible: (msg.modelData.code ?? "") !== ""
                                        Layout.fillWidth: true
                                        implicitHeight: codeTxt.implicitHeight + 16
                                        radius: Theme.r(7)
                                        color: Theme.s1
                                        border.width: 1; border.color: Theme.ov
                                        Text {
                                            id: codeTxt
                                            x: 10; y: 8; width: parent.width - 20
                                            text: msg.modelData.code ?? ""
                                            wrapMode: Text.WrapAnywhere
                                            color: Theme.t
                                            font.family: Theme.mono; font.pixelSize: Theme.px(11.5)
                                        }
                                    }
                                    RowLayout {
                                        visible: (msg.modelData.code ?? "") !== ""
                                        spacing: 6
                                        SmallBtn {
                                            visible: !msg.modelData.confirm
                                            text: "Ejecutar (pide confirmación)"; primary: true
                                            onClicked: root.patch(msg.index, { confirm: true })
                                        }
                                        Txt { visible: !!msg.modelData.confirm; text: "¿Ejecutar en la terminal?"; size: 12; weight: Font.DemiBold }
                                        SmallBtn {
                                            visible: !!msg.modelData.confirm; text: "Sí, ejecutar"; primary: true
                                            onClicked: { root.runCode(msg.modelData.code); root.patch(msg.index, { confirm: false }); }
                                        }
                                        SmallBtn { visible: !!msg.modelData.confirm; text: "No"; onClicked: root.patch(msg.index, { confirm: false }) }
                                        SmallBtn {
                                            visible: !msg.modelData.confirm; text: "Copiar"
                                            onClicked: Quickshell.execDetached(["wl-copy", msg.modelData.code])
                                        }
                                    }

                                    // Error: reintentar / ajustes
                                    RowLayout {
                                        visible: !!msg.modelData.error
                                        spacing: 6
                                        SmallBtn { text: "Reintentar"; primary: true; onClicked: root.retry() }
                                        SmallBtn { text: "Ajustes de IA"; onClicked: Shell.open("ajustesapp", "ia") }
                                    }
                                }
                            }
                        }
                    }
                }

                // En directo: lo que va llegando (con las consultas que hizo encima)
                Rectangle {
                    id: liveBubble
                    visible: root.busy && (root.liveText !== "" || root.liveSteps.length > 0)
                    width: Math.min(msgs.width * 0.92, Math.max(liveRich.implicitWidth, liveStepsCol.implicitWidth, 40) + 24)
                    height: liveCol.implicitHeight + 20
                    color: Theme.fill2
                    topLeftRadius: 7; topRightRadius: 14; bottomRightRadius: 14; bottomLeftRadius: 4
                    ColumnLayout {
                        id: liveCol
                        x: 12; y: 10
                        width: liveBubble.width - 24
                        spacing: 10
                        Column {
                            id: liveStepsCol
                            visible: root.liveSteps.length > 0
                            Layout.fillWidth: true
                            spacing: 3
                            Repeater {
                                model: root.liveSteps
                                Row {
                                    required property string modelData
                                    spacing: 6
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 10; color: Theme.tv }
                                    Txt { text: parent.modelData; size: 11; muted: true }
                                }
                            }
                        }
                        AiRich {
                            id: liveRich
                            visible: root.liveText !== ""
                            Layout.fillWidth: true
                            text: root.liveText
                        }
                    }
                }
                // Pensando…
                Rectangle {
                    visible: root.busy && root.liveText === ""
                    width: 56; height: 32
                    color: Theme.fill2
                    topLeftRadius: 7; topRightRadius: 14; bottomRightRadius: 14; bottomLeftRadius: 4
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                width: 6; height: 6; radius: 3
                                color: Theme.tv
                                SequentialAnimation on opacity {
                                    running: root.busy && root.liveText === "" && root.visible && !Theme.still
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 160 }
                                    NumberAnimation { from: 0.3; to: 1; duration: 320 }
                                    NumberAnimation { from: 1; to: 0.3; duration: 320 }
                                    PauseAnimation { duration: (2 - index) * 160 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------- sugerencias
        Flow {
            visible: !root.busy && !onboard.visible && !root.showHistory
            Layout.fillWidth: true
            Layout.preferredWidth: root.width - 24
            Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 8; Layout.topMargin: 4
            spacing: 6
            Repeater {
                model: root.suggestions
                delegate: Rectangle {
                    required property string modelData
                    implicitHeight: 24
                    implicitWidth: sTxt.implicitWidth + 16
                    radius: Theme.r(7)
                    color: "transparent"
                    border.width: 1; border.color: Theme.ov
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.light ? "#000" : "#FFF"; opacity: sMouse.containsMouse ? 0.06 : 0 }
                    Txt { id: sTxt; anchors.centerIn: parent; text: parent.modelData; size: 11.5 }
                    MouseArea { id: sMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ask(parent.modelData) }
                }
            }
        }

        // ---------------------------------------------------- historial de conversaciones
        ColumnLayout {
            visible: root.showHistory
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 10
                spacing: 8
                Txt { text: "Conversaciones"; size: 14; weight: Font.DemiBold }
                Txt { text: root.histList.length ? String(root.histList.length) : ""; size: 11.5; muted: true }
                Item { Layout.fillWidth: true }
                SmallBtn { text: "Nueva"; primary: true; onClicked: root.clear() }
                IconBtn { icon: "x"; iconSize: 12; fg: Theme.tv; implicitWidth: 26; implicitHeight: 26; onClicked: root.toggleHistory() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12
                implicitHeight: 32
                radius: Theme.r(6)
                color: Theme.fill2
                Icon { id: hsIcon; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 12; color: Theme.tv }
                TextInput {
                    id: histSearch
                    anchors { left: hsIcon.right; right: parent.right; leftMargin: 8; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    color: Theme.t; selectionColor: Theme.pc; selectedTextColor: Theme.pcText
                    font.family: Theme.font; font.pixelSize: Theme.px(12.5)
                    clip: true
                    text: root.histQuery
                    onTextEdited: root.histQuery = text
                    Keys.onEscapePressed: root.toggleHistory()
                    onAccepted: if (root.histShown.length) root.openHistory(root.histShown[0])
                    Txt { anchors.fill: parent; visible: histSearch.text === ""; text: "Buscar en las conversaciones…"; muted: true }
                }
            }
            onVisibleChanged: if (visible) Qt.callLater(() => histSearch.forceActiveFocus())
            ListView {
                id: histView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 12; Layout.rightMargin: 12
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.histShown
                Txt {
                    anchors.centerIn: parent
                    visible: histView.count === 0 && !histLister.running
                    text: root.histQuery.trim() !== "" ? "Nada coincide con «" + root.histQuery.trim() + "»"
                        : root.keepHistory ? "Aún no hay conversaciones guardadas" : "El historial está desactivado (Ajustes › IA)"
                    muted: true
                }
                delegate: Rectangle {
                    id: hrow
                    required property var modelData
                    readonly property bool current: modelData.file === root.historyFile
                    width: ListView.view.width
                    height: hcol.implicitHeight + 14
                    radius: Theme.r(8)
                    color: current ? Theme.pc : hMa.containsMouse ? Theme.fill2 : "transparent"
                    MouseArea { id: hMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openHistory(hrow.modelData) }
                    ColumnLayout {
                        id: hcol
                        anchors { left: parent.left; right: delBtn.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 6 }
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: hrow.modelData.title; size: 12.5; weight: Font.Medium; color: hrow.current ? Theme.pcText : Theme.t }
                        Txt {
                            Layout.fillWidth: true
                            text: root.histWhen(hrow.modelData.t) + " · " + hrow.modelData.n + (hrow.modelData.n === 1 ? " mensaje" : " mensajes")
                            size: 10.5; muted: !hrow.current; color: hrow.current ? Qt.alpha(Theme.pcText, 0.75) : Theme.tv
                        }
                    }
                    IconBtn {
                        id: delBtn
                        opacity: hMa.containsMouse || hrow.current ? 1 : 0.4
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        icon: "trash"; iconSize: 12; fg: Theme.tv; implicitWidth: 26; implicitHeight: 26
                        tooltip: "Borrar esta conversación"
                        onClicked: root.deleteHistory(hrow.modelData)
                    }
                }
            }
            RowLayout {
                visible: root.histDeleted !== null
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 12; Layout.bottomMargin: 6
                Txt { Layout.fillWidth: true; text: "Conversación borrada"; size: 12; muted: true; elide: Text.ElideRight }
                SmallBtn { text: "Deshacer"; onClicked: root.undoDeleteHistory() }
            }
        }

        // ---------------------------------------------------- imágenes para el próximo mensaje
        Flow {
            visible: root.pending.length > 0 || root.pendingDocs.length > 0 || attachProc.running && !attachProc.paste || rawProc.running
            Layout.fillWidth: true
            Layout.preferredWidth: root.width - 24
            Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 8
            spacing: 6
            Repeater {
                model: root.pending
                ImgThumb {
                    required property string modelData
                    required property int index
                    width: 54; height: 54
                    path: modelData
                    removable: true
                    onRemove: root.removeImage(index)
                }
            }
            Repeater {
                model: root.pendingDocs
                Item {
                    required property string modelData
                    required property int index
                    width: dch.width; height: root.pending.length ? 54 : 26
                    DocChip { id: dch; anchors.verticalCenter: parent.verticalCenter; path: parent.modelData; removable: true; onRemove: root.removeDoc(parent.index) }
                }
            }
            Rectangle {   // adjuntando…
                visible: attachProc.running && !attachProc.paste || rawProc.running
                width: 54; height: 54; radius: Theme.r(7)
                color: "transparent"; border.width: 1; border.color: Theme.ov
                Txt { anchors.centerIn: parent; text: "…"; size: 16; muted: true }
            }
        }

        // ---------------------------------------------------- entrada
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 12
            implicitHeight: 38
            radius: Theme.r(6)
            color: Theme.fill2
            Rectangle {
                id: clipBtn
                visible: root.allowCapture
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                width: visible ? 30 : 0; height: 30; radius: Theme.r(7)
                color: clipMa.containsMouse ? Qt.alpha(Theme.t, 0.08) : "transparent"
                Icon {   // clip
                    anchors.centerIn: parent; size: 15; color: Theme.tv
                    svg: '<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/>'
                }
                MouseArea { id: clipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.attachFrom(["pick"]) }
            }
            TextInput {
                id: input
                anchors { left: clipBtn.visible ? clipBtn.right : parent.left; right: sendBtn.left; verticalCenter: parent.verticalCenter; leftMargin: clipBtn.visible ? 4 : 14; rightMargin: 8 }
                color: Theme.t
                selectionColor: Theme.pc
                selectedTextColor: Theme.pcText
                font.family: Theme.font
                font.pixelSize: Theme.px(12.5)
                clip: true
                onAccepted: root.ask(text)
                Keys.onEscapePressed: Shell.close()
                Keys.onPressed: e => { if (e.matches(StandardKey.Paste)) { e.accepted = true; root.pasteImage(); } }
                Txt {
                    anchors.fill: parent
                    visible: input.text === "" && !input.preeditText
                    text: root.busy ? "Pensando…" : root.pending.length ? "Pregunta sobre la imagen…" : root.pendingDocs.length ? "Pregunta sobre el documento…" : root.winInfo ? "Pregunta sobre esta ventana o pide algo…" : "Pregunta o pide algo al escritorio…"
                    muted: true
                }
            }
            Rectangle {
                id: sendBtn
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 30; height: 30; radius: Theme.r(7)
                color: Theme.p
                opacity: root.busy || input.text.trim() !== "" || root.pending.length || root.pendingDocs.length ? 1 : 0.55
                // respondiendo: «Detener» (un cuadrado) corta la respuesta y deja lo que llegó
                Icon { anchors.centerIn: parent; visible: !root.busy; name: "arrow_right"; color: Theme.pText; size: 14 }
                Rectangle { anchors.centerIn: parent; visible: root.busy; width: 10; height: 10; radius: 2; color: Theme.pText }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.busy ? root.stop() : root.ask(input.text) }
            }
        }
    }

    // ---------------------------------------------------- soltar imágenes
    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: d => d.accept(Qt.CopyAction)
        onDropped: d => root.dropped(d)
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        visible: dropArea.containsDrag
        radius: Theme.r(12)
        color: Qt.alpha(Theme.bg, 0.82)
        border.width: 2; border.color: Theme.p
        Column {
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 44; height: 44; radius: Theme.r(12); color: Theme.pc
                Icon { anchors.centerIn: parent; name: "file"; size: 20; color: Theme.pcText }
            }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Suelta para adjuntarlo"; size: 13; weight: Font.DemiBold }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Imágenes, PDF, documentos, código o texto"; size: 11.5; muted: true }
        }
    }
}
