// Dictado y comandos de voz (local, como SuperWhisper): atajos globales hf:dictado (Super + Alt + D), hf:comando
// (Super + Alt + V) y hf:hablar (Super + Alt + H). Hablar con el asistente (aiTalkMode): «conversacion» (por defecto)
// la activa y la desactiva: escucha, al callarte (aiConvSilence s) se lo pasa al asistente, Helpert contesta en voz
// alta y vuelve a escuchar, hasta que la desactivas (o dices «adiós» / «eso es todo»). Mientras Helpert habla sigue
// escuchando (aiConvInterrupt): si le hablas, se calla y tu frase es el turno siguiente; para no oírse a sí mismo,
// durante la conversación su voz y el micrófono pasan por el cancelador de eco de PipeWire (hf-dictate aec). «pulsar»: una sola pregunta por pulsación (contesta con voz si aiVoice). Modo «ptt»: hablar mientras se mantiene (un toque corto deja el micrófono abierto hasta volver a
// pulsar); «toggle»: cada pulsación empieza/termina; «continuo»: empieza al pulsar y para solo tras unos segundos
// callado. Mientras hablas el texto se va escribiendo en la ventana y lo provisional se corrige al terminar cada frase
// (scripts/hf-dictate: VAD + whisper-server residente). Al dictar, «Distro, …» al principio de una frase es una orden (dictationWake);
// las órdenes las entiende scripts/hf-voice (sin IA) y lo demás va al asistente.
// La píldora va donde el OSD y con su estilo (services/OsdStack.qml): pegada al borde y el OSD se aparta.
// IPC:  qs -p <repo>/config/quickshell ipc call dictado toggle|start|stop|cancel|state|command
//       … dictado file <clip.wav> [dictado|comando]  (pruebas: el audio sale del archivo, a tiempo real)
// Ajustes › Dictado (sections/Dictado.qml).
// Botón de la barra: módulo «dictado» de barModules (bar/MicBtn.qml: Shell.dictToggle / micCycle / dictPhase).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    // idle | rec | trans | cmd | done | error  (el dictado no usa IA: sin fase de «mejorar»)
    property string phase: "idle"
    property string kind: "dictado"         // dictado | comando | ia (lo dicho va al asistente, no se escribe)
    property string msg: ""
    property string code: ""
    property string partial: ""             // lo provisional de la frase en curso
    property string committed: ""           // lo ya escrito en esta sesión
    property string cmdText: ""             // orden reconocida
    property string cmdMsg: ""              // resultado («Hecho», error…)
    property bool cmdOk: true
    property bool ready: false              // el modelo ya está cargado
    property bool speaking: false
    property real secs: 0
    property var levels: Array(12).fill(0)
    property double pressedAt: 0
    property bool latched: false            // toque corto en modo ptt: sigue grabando hasta la próxima pulsación
    property string pendingKind: ""
    property var args: []
    readonly property string mode: Settings.get("dictationMode", "ptt")
    readonly property bool busy: proc.running

    // ---------- conversación por voz ----------
    readonly property bool conv: Shell.aiConversation
    property string convState: ""           // escucha | piensa | habla
    property int convMisses: 0              // turnos seguidos sin oír nada (3 = se da por terminada)
    property bool convProactive: false      // la empezó Helpert (modo compañero): si no contestas, se va sin despedirse
    onConvChanged: {
        if (conv) { aecOff.stop(); if (convBarge) Quickshell.execDetached([Paths.script("hf-dictate"), "aec", "on"]); }
        else { convTest = false; convFiles = []; convState = ""; convProactive = false; convLater.stop(); thinkTimer.stop(); replyTimer.stop(); aecOff.restart(); }
    }
    // Interrumpir a Helpert hablando (Ajustes › Asistente de IA › Conversación)
    readonly property bool convBarge: Settings.get("aiConvInterrupt", true) !== false
    // El cancelador de eco se quita al acabar, cuando ya no suena el «Hasta luego»
    Timer { id: aecOff; interval: 4000; onTriggered: if (root.conv) return; else if (Shell.aiSpeaking) restart(); else Quickshell.execDetached([Paths.script("hf-dictate"), "aec", "off"]) }
    // Modo compañero: Helpert ya está pensando qué decir (AiChat.checkIn); al terminar de hablar, escucha una vez
    function companionTalk(): void {
        if (conv || proc.running) return;
        Shell.aiConversation = true;
        convProactive = true;
        convMisses = 2;
        convState = "piensa";
    }
    Companion { id: companion; busy: proc.running; onVisiting: root.companionTalk() }
    readonly property string talkMode: Settings.get("aiTalkMode", "conversacion")
    function convToggle(): void { if (conv) convEnd(false); else convStart(); }
    function convStart(): void {
        if (conv) return;
        if (Audio.micMuted) { phase = "done"; msg = "Micrófono silenciado"; hider.interval = 1800; hider.restart(); return; }
        if (proc.running) send("cancel");
        Shell.aiConversation = true;
        convMisses = 0;
        convProactive = false;
        convLater.restart();
    }
    function convEnd(bye): void {
        if (!conv) return;
        Shell.aiConversation = false;
        convState = ""; convLater.stop(); thinkTimer.stop(); replyTimer.stop();
        if (proc.running) send("cancel");
        Quickshell.execDetached([Paths.script("hf-ai"), "speak", bye ? "Hasta luego." : "--stop"]);
        phase = "done"; msg = "Conversación terminada"; hider.interval = 1400; hider.restart();
    }
    // Pruebas (IPC conversationFiles): cada turno lee el siguiente audio en lugar del micrófono; al acabarse, termina
    property var convFiles: []
    property bool convTest: false
    // Con Helpert hablando (y convBarge) se escucha igual con --tts: hf-dictate solo avisa («barge») si le hablas
    function convListen(): void {
        const talking = Shell.aiSpeaking;
        if (!conv || (talking && !convBarge)) return;
        if (proc.running) {
            if (kind !== "ia") convLater.restart();                        // un dictado a medias: esperar
            else if (!talking && convState === "habla") { send("tts off"); convState = "escucha"; }
            return;
        }
        if (convTest && !convFiles.length) { convEnd(false); return; }
        convState = talking ? "habla" : "escucha";
        const tts = talking ? ["--tts"] : [];
        if (convTest) { const f = convFiles[0]; convFiles = convFiles.slice(1); start("ia", ["--file", f, "--simulate-live"].concat(tts)); }
        else start("ia", tts);
    }
    // Entre turnos, un respiro: que no se oiga el final de la voz de Helpert
    Timer { id: convLater; interval: 600; onTriggered: root.convListen() }
    // Si tarda, Helpert avisa de que sigue en ello (y la respuesta lo corta al llegar)
    Timer { id: thinkTimer; interval: 4000; onTriggered: if (root.conv && root.convState === "piensa") Quickshell.execDetached([Paths.script("hf-ai"), "speak", "Un momento."]) }
    // La respuesta llegó pero no sonó (sin voz instalada, texto vacío…): se vuelve a escuchar igual
    Timer { id: replyTimer; interval: 8000; onTriggered: if (root.conv && root.convState === "habla" && !Shell.aiSpeaking) root.convListen() }
    Connections {
        target: Shell
        function onAiSpeakingChanged() {
            if (!root.conv) return;
            if (Shell.aiSpeaking) {
                if (root.convState === "escucha") { if (proc.running) root.send(root.convBarge ? "tts on" : "cancel"); root.convState = "habla"; }
                else if (root.convState === "habla" && !proc.running) root.convListen();
            } else if (root.convState === "habla") {
                if (proc.running) { root.send("tts off"); root.convState = "escucha"; }   // acabó: tu turno ya está abierto
                else convLater.restart();
            }
        }
        function onAiReplied(ok) {
            if (!root.conv || root.convState !== "piensa") return;
            thinkTimer.stop();
            root.convState = "habla";
            replyTimer.restart();
            if (Shell.aiSpeaking) root.convListen();
        }
    }
    // Sin \b: en JS (sin /u) «í» no es letra y «Sí, hazlo» no casaba
    readonly property var yesRe: /^(s[ií]|vale|ok|okey|claro|adelante|hazlo|h[aá]galo|dale|de acuerdo|perfecto|venga|por favor)(?=[\s,.;:!?¡¿]|$)/i
    readonly property var noRe: /^(no|cancela|cancelar|d[eé]jalo|mejor no|ni hablar|olv[ií]dalo)(?=[\s,.;:!?¡¿]|$)/i
    readonly property var noiseRe: /^[\s.,…!?¡¿-]*(m+-?h?m+|mhm+|hmm+|e+h+|a+h+|u+m+|o+h+|gracias|subt[ií]tulos.*|amara\.org.*|\[.*\]|\(.*\)|m[uú]sica)?[\s.,…!?¡¿-]*$/i
    readonly property var byeRe: /^(adi[oó]s|hasta luego|chao|terminar|termina|para ya|eso es todo|ya est[aá]|gracias,? eso es todo|fin de la conversaci[oó]n)[\s.!¡]*$/i

    function start(k, extra, fromKey): void {
        if (proc.running) return;
        kind = k || "dictado";
        levels = Array(12).fill(0); secs = 0; msg = ""; code = ""; latched = !fromKey && mode === "ptt";   // sin atajo: manos libres
        partial = ""; committed = ""; cmdText = ""; cmdMsg = ""; cmdOk = true; ready = false; speaking = false;
        phase = "rec";
        hider.stop(); cmdHider.stop();
        const a = [Paths.script("hf-dictate"), "record", "--mode", conv && kind === "ia" ? "continuo" : fromKey || mode !== "ptt" ? mode : "toggle"];
        if (kind === "comando") a.push("--command");
        if (fromKey) a.push("--hold");     // no escribir con las teclas del atajo aún pulsadas (released() lo suelta)
        args = a.concat(extra ?? []);
        proc.running = true;
    }
    function send(c): void { if (proc.running) proc.write(c + "\n"); }
    function stop(): void { if (proc.running && phase === "rec") { send("release"); send("stop"); } }
    function cancel(): void { if (proc.running) send("cancel"); else phase = "idle"; }
    function toggle(k): void { if (proc.running) stop(); else start(k); }
    function testFile(path, k): void { if (!proc.running) start(k || "dictado", ["--file", path, "--simulate-live"]); }

    function onEvent(j): void {
        switch (j.ev) {
        case "rec": phase = "rec"; break;
        case "ready": ready = true; break;
        case "level":
            levels = levels.slice(1).concat([j.v]);
            secs = j.t ?? secs;
            break;
        case "speech": speaking = j.on; break;
        case "barge":                           // le hablaste mientras contestaba: se calla y es tu turno
            if (conv && convState === "habla") {
                Quickshell.execDetached([Paths.script("hf-ai"), "speak", "--stop"]);
                convState = "escucha"; replyTimer.stop();
            }
            break;
        case "partial": partial = j.text; break;
        case "phrase":
            partial = "";
            if (j.text) committed = (committed + j.text).slice(-400);
            break;
        case "cmd":
            cmdText = "«" + j.text + "»"; cmdMsg = ""; partial = "";
            if (kind === "comando") phase = "cmd";
            cmdHider.stop();
            break;
        case "cmdresult":
            cmdOk = !!j.ok; cmdText = j.intent === "unknown" || !j.label ? (j.text ? "«" + j.text + "»" : cmdText) : j.label;
            cmdMsg = j.fallback === "ai" && j.ok ? "Se lo pregunté al asistente" : (j.msg || (j.ok ? "Hecho" : "No pude hacerlo"));
            if (kind === "comando") { phase = "done"; msg = cmdMsg; hider.interval = j.ok ? 2200 : 4000; hider.restart(); }
            else cmdHider.restart();
            break;
        case "transcribing": phase = "trans"; break;
        case "text": committed = j.text; break;
        case "done":
            if (kind === "ia" && conv) {        // conversación: lo dicho va al asistente y se espera su voz
                const t = committed.trim();
                phase = "idle";
                // Nada, o lo que Whisper «oye» en el ruido de fondo: cuenta como silencio, no se le pregunta nada al asistente
                if (!t || noiseRe.test(t)) {
                    if (++convMisses >= 3) convEnd(!convProactive); else convLater.restart();
                    break;
                }
                if (byeRe.test(t)) { convEnd(true); break; }
                convMisses = 0; convProactive = false;
                // Un plan esperando (las herramientas del asistente): «sí» lo aplica, «no» lo descarta
                if (Shell.aiPlanPending && (yesRe.test(t) || noRe.test(t))) {
                    Shell.aiPlanAnswer(yesRe.test(t));
                    convState = "habla";
                    replyTimer.restart();
                    break;
                }
                convState = "piensa";
                Shell.aiAskHidden(t);
                thinkTimer.restart();
                break;
            }
            if (kind === "ia") {                // hablar con el asistente: la pregunta va al panel lateral
                phase = "done"; msg = committed.trim() ? "Se lo dije a " + (Settings.get("aiName", "") || "el asistente") : "No te oí";
                // Con voz, la conversación sigue con el panel cerrado (se oye la respuesta); sin voz, hay que verla
                if (committed.trim()) Settings.get("aiVoice", false) ? Shell.aiAskHidden(committed.trim()) : Shell.open("ia", { ask: committed.trim() });
                hider.interval = 1800; hider.restart();
                break;
            }
            if (j.how === "comando") {          // solo hubo órdenes: se queda el resultado un momento
                if (kind !== "comando") { phase = "done"; msg = cmdMsg; hider.interval = 2400; hider.restart(); }
                break;
            }
            phase = "done";
            msg = j.how === "copiado" ? "Copiado: pégalo con Ctrl + V" : "Escrito";
            hider.interval = j.how === "copiado" ? 3200 : 1600; hider.restart();
            break;
        case "cancelled": phase = "idle"; break;
        case "error":
            if (j.fatal === false) break;
            if (kind === "ia" && conv) {        // en conversación, no oír nada no es un error: se sigue escuchando
                if (["silence", "empty"].includes(j.code ?? "")) {
                    phase = "idle";
                    if (++convMisses >= 3) convEnd(!convProactive); else convLater.restart();   // ~1,5 min callado: se cierra sola
                    break;
                }
                convEnd(false);
            }
            phase = "error"; msg = j.msg ?? "Error"; code = j.code ?? "";
            hider.interval = 4500; hider.restart();
            break;
        }
    }

    Process {
        id: proc
        command: root.args
        // «ia»: no escribir en la ventana (y dictationAiFix); en conversación, el turno acaba tras un silencio corto
        environment: root.kind !== "ia" ? ({}) : Object.assign({ HF_DICTATE_OUTPUT: "ninguna", HF_DICTATE_FOR: "ia" },
            root.conv ? { HF_DICTATE_SILENCE: String(Settings.get("aiConvSilence", 1.2)), HF_DICTATE_WAIT: "20", HF_DICTATE_MAX: "40",
                          HF_DICTATE_AEC: root.convBarge ? "1" : "0", HF_DICTATE_AIFIX: "0" } : {})
        stdinEnabled: true
        stdout: SplitParser { onRead: l => { try { root.onEvent(JSON.parse(l)); } catch (e) {} } }
        onExited: {
            if (["rec", "trans", "cmd"].includes(root.phase)) root.phase = "idle";
            if (root.conv && root.convState === "escucha") convLater.restart();   // terminó sin decir nada (o falló)
        }
    }
    Binding { target: Shell; property: "dictPhase"; value: root.phase }
    // Micrófono de la barra y hf:micro (Super + Alt + M): según micMode, dictar, hablar con el asistente o silenciar.
    // hf:micro-modo (Super + Shift + Alt + M) y el clic derecho del botón pasan al siguiente modo.
    // Silenciado, ningún modo funcionaría: no se cambia de modo y el botón (o el atajo) solo lo vuelve a activar.
    readonly property string micMode: Settings.get("micMode", "dictado")
    readonly property var micModes: ({ dictado: "dictado", ia: "hablar con el asistente", silencio: "silenciar" })
    function micAction(): void {
        if (micMode === "silencio" || Audio.micMuted) { if (conv) convEnd(false); Audio.toggleMic(); }
        else if (micMode === "ia") talk();
        else toggle("dictado");
    }
    function talk(): void { if (talkMode === "conversacion") convToggle(); else toggle("ia"); }
    function micCycle(): void {
        if (Audio.micMuted) { if (!proc.running) { phase = "done"; msg = "Micrófono silenciado: actívalo para cambiar de modo"; hider.interval = 1800; hider.restart(); } return; }
        const m = Object.keys(micModes), next = m[(m.indexOf(micMode) + 1) % m.length];
        Settings.set("micMode", next);
        if (!proc.running) { phase = "done"; msg = "Micrófono: " + micModes[next]; hider.interval = 1400; hider.restart(); }
    }
    Connections { target: Shell; function onDictToggle() { root.micAction(); } function onMicCycle() { root.micCycle(); } }
    property bool micHeld: false            // hf:micro pulsado en modo dictado o asistente (al soltar, released())
    Timer { id: hider; interval: 1600; onTriggered: root.phase = "idle" }
    Timer { id: cmdHider; interval: 3000; onTriggered: { root.cmdText = ""; root.cmdMsg = ""; } }

    function pressed(k): void {
        if (proc.running) {
            // Con Super + Alt pulsados, lo que se teclease serían atajos de Hyprland (Super + Alt + S manda la ventana al
            // espacio oculto…): hf-dictate no escribe hasta que released() mande «release»
            root.send("hold");
            if (root.phase === "rec") root.send("stop");
            return;
        }
        root.pressedAt = Date.now();
        root.start(k, null, true);
    }
    function released(): void {
        root.send("release");                                          // ya se puede escribir (en todos los modos)
        if (root.mode !== "ptt" || root.phase !== "rec" || root.latched) return;
        if (Date.now() - root.pressedAt < 350) root.latched = true;    // toque corto: manos libres
        else root.stop();
    }
    GlobalShortcut {
        appid: "hf"; name: "dictado"; description: "HyprFrijol: dictado por voz"
        onPressed: root.pressed("dictado")
        onReleased: root.released()
    }
    GlobalShortcut {
        appid: "hf"; name: "comando"; description: "HyprFrijol: comando de voz"
        onPressed: root.pressed("comando")
        onReleased: root.released()
    }
    GlobalShortcut {
        appid: "hf"; name: "hablar"; description: "HyprFrijol: hablar con el asistente"
        onPressed: root.talkMode === "conversacion" ? root.convToggle() : root.pressed("ia")
        onReleased: if (root.talkMode !== "conversacion") root.released()
    }
    GlobalShortcut {
        appid: "hf"; name: "micro"; description: "HyprFrijol: micrófono (lo de su modo)"
        onPressed: {
            if (root.micMode === "ia" && root.talkMode === "conversacion" && !Audio.micMuted) { root.micHeld = false; root.convToggle(); return; }
            root.micHeld = root.micMode !== "silencio" && !Audio.micMuted; if (root.micHeld) root.pressed(root.micMode === "ia" ? "ia" : "dictado"); else Audio.toggleMic();
        }
        onReleased: if (root.micHeld) root.released()
    }
    GlobalShortcut { appid: "hf"; name: "micro-modo"; description: "HyprFrijol: siguiente modo del micrófono"; onPressed: root.micCycle() }
    IpcHandler {
        target: "dictado"
        function toggle(): void { root.toggle("dictado"); }
        function talk(): void { root.talk(); }                // hablar con el asistente (hf-ai talk): según aiTalkMode
        function conversation(): void { root.convToggle(); }  // activar / desactivar la conversación por voz
        // pruebas: una conversación con estos audios (rutas separadas por comas) como turnos tuyos
        function conversationFiles(paths: string): void { if (root.conv) return; root.convFiles = paths.split(",").filter(p => p); root.convTest = true; root.convStart(); }
        function checkIn(): void { companion.visit(true); }   // modo compañero: que Helpert pase a saludar ya (pruebas)
        function companionState(): string { return companion.state(); }
        function conversationState(): string { return root.conv ? root.convState || "activa" : "apagada"; }
        function command(): void { root.toggle("comando"); }
        function micro(): void { root.micAction(); }          // lo del modo del micrófono (micMode)
        function microModo(): void { root.micCycle(); }
        function start(): void { root.start("dictado", null); }
        function stop(): void { root.stop(); }
        function cancel(): void { root.cancel(); }
        function file(path: string, kind: string): void { root.testFile(path, kind); }
        function state(): string {
            return root.phase + " · " + root.kind + (root.partial ? " · …" + root.partial : "") + (root.committed ? " · " + root.committed : "")
                + (root.cmdText ? " · orden: " + root.cmdText + (root.cmdMsg ? " → " + root.cmdMsg : "") : "") + (root.msg ? " · " + root.msg : "");
        }
    }

    // ---------- píldora (sitio y estilo del OSD) ----------
    PanelWindow {
        id: win
        readonly property bool shown: root.phase !== "idle" || root.conv
        screen: Shell.screen
        visible: shown || fade.running
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-dictado"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: OsdStack.atB; top: OsdStack.atT; left: OsdStack.atL; right: OsdStack.atR }
        margins {
            bottom: OsdStack.atB ? OsdStack.edge("abajo") : 0; top: OsdStack.atT ? OsdStack.edge("arriba") : 0
            left: OsdStack.atL ? OsdStack.edge("izquierda") : 0; right: OsdStack.atR ? OsdStack.edge("derecha") : 0
        }
        implicitWidth: 680
        implicitHeight: 42 + 40
        mask: Region { item: pill }
        Binding { target: OsdStack; property: "dictation"; value: win.shown ? pill.height : 0 }

        readonly property bool isCmd: root.kind === "comando" || root.cmdText !== ""
        readonly property color accent: root.phase === "error" || (root.cmdText && root.cmdMsg && !root.cmdOk) ? Theme.danger
                                      : root.phase === "rec" && !isCmd && !convIdle ? Theme.danger : Theme.p
        readonly property string iconName: win.convIdle ? (root.convState === "habla" ? "volume" : "ai")
                                         : root.cmdMsg ? (root.cmdOk ? "check" : "alert")
                                         : root.phase === "done" ? "check" : root.phase === "error" ? "alert"
                                         : isCmd ? "command" : "mic"
        readonly property string mmss: Math.floor(root.secs / 60) + ":" + String(Math.floor(root.secs % 60)).padStart(2, "0")
        // texto principal y secundario de la píldora
        // en conversación sin tu voz en curso (también mientras Helpert habla y se le escucha por si le interrumpes)
        readonly property bool convIdle: root.conv && (root.phase === "idle" || (root.phase === "rec" && root.convState === "habla"))
        readonly property string mainText: convIdle ? (root.convState === "piensa" ? "Pensando…" : root.convState === "habla" ? (Settings.get("aiName", "") || "Helpert") + " te responde…" : "")
            : root.cmdText !== "" && root.phase !== "error" ? root.cmdText
            : root.phase === "rec" ? (root.partial || (root.committed ? root.committed.trim().slice(-120) : ""))
            : root.phase === "trans" ? (root.partial || "Transcribiendo…")
            : root.phase === "cmd" ? root.cmdText
            : root.msg
        readonly property string hint: root.phase !== "rec" ? ""
            : !root.ready ? "Preparando el micrófono…"
            : root.kind === "comando" ? "Di una orden: «pon Walk de Foo Fighters en YouTube»"
            : root.conv ? "Te escucho…"
            : Settings.get("dictationWake", true) ? "Habla… · «" + (String(Settings.get("dictationWakeWord", "Distro")).trim() || "Distro") + ", …» para una orden"
            : "Habla…"
        readonly property string sub: root.conv && root.cmdMsg === "" ? (root.convState === "habla" && root.phase === "rec" ? "Háblale para interrumpirle · Super + Alt + H para terminar" : "Conversación · Super + Alt + H para terminar")
            : root.cmdMsg !== "" ? root.cmdMsg
            : root.phase === "cmd" ? "Haciéndolo…"
            : root.phase === "rec" && !root.partial && !root.committed && (root.latched || root.mode !== "ptt") ? (root.mode === "continuo" ? "para solo al callarte" : "pulsa otra vez para terminar")
            : ""

        Glass {
            id: pill
            kind: "panel"
            radius: Theme.panelRadius
            anchors.horizontalCenter: parent.horizontalCenter
            y: OsdStack.pillY(win.height, height, 0)
            width: Math.min(640, Math.max(260, row.implicitWidth + 32))
            height: 42
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? Theme.durIn : 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }

            RowLayout {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                width: pill.width - 32
                spacing: 10

                // icono (micrófono = dictado · ⌘ = orden) con pulso mientras habla
                Item {
                    implicitWidth: 24; implicitHeight: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 24; radius: 12
                        color: Qt.alpha(win.accent, 0.18)
                        scale: root.phase === "rec" ? 1 + Math.min(0.35, (root.levels[root.levels.length - 1] ?? 0) * 0.45) : 1
                        Behavior on scale { NumberAnimation { duration: Theme.ms(90); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    }
                    Icon { anchors.centerIn: parent; size: 14; name: win.iconName; color: win.accent }
                }
                // medidor de nivel
                Row {
                    visible: root.phase === "rec" && root.cmdText === ""
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: root.levels.length
                        Rectangle {
                            required property int index
                            readonly property real v: root.levels[index] ?? 0
                            width: 3; radius: 1.5
                            height: 3 + v * 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.t
                            opacity: 0.35 + v * 0.65
                            Behavior on height { NumberAnimation { duration: Theme.ms(70); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                        }
                    }
                }
                // puntos mientras transcribe o ejecuta
                Row {
                    visible: root.phase === "trans" || root.phase === "cmd" || (root.cmdText !== "" && root.cmdMsg === "") || (win.convIdle && root.convState === "piensa")
                    spacing: 4
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 5; height: 5; radius: 2.5
                            color: Theme.p
                            SequentialAnimation on opacity {
                                running: parent.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 160 }
                                NumberAnimation { from: 0.25; to: 1; duration: 320 }
                                NumberAnimation { from: 1; to: 0.25; duration: 320 }
                                PauseAnimation { duration: (2 - index) * 160 }
                            }
                        }
                    }
                }
                // texto: lo provisional en tenue, lo ya escrito y las órdenes en normal
                Txt {
                    id: mainTxt
                    Layout.fillWidth: true
                    Layout.maximumWidth: 460
                    weight: Font.Medium
                    elide: root.phase === "rec" || root.phase === "trans" ? Text.ElideLeft : Text.ElideRight
                    text: win.mainText || win.hint
                    color: root.phase === "error" ? Theme.danger
                         : !win.mainText || (root.partial && win.mainText === root.partial) ? Theme.tv : Theme.t
                }
                Txt {
                    visible: win.sub !== ""
                    size: 11.5; elide: Text.ElideRight
                    Layout.maximumWidth: 200
                    text: win.sub
                    color: root.cmdMsg !== "" ? (root.cmdOk ? Theme.p : Theme.danger) : Theme.tv
                }
                Txt {
                    visible: root.phase === "rec" && root.cmdText === ""
                    text: win.mmss; size: 11.5; muted: true; tabular: true
                }
                // Configurar (si falta algo)
                Rectangle {
                    visible: root.phase === "error" && ["engine", "model", "recorder", "typer"].includes(root.code)
                    implicitWidth: cfg.implicitWidth + 20; implicitHeight: 26; radius: 13
                    color: Theme.p
                    Txt { id: cfg; anchors.centerIn: parent; text: "Configurar"; size: 12; weight: Font.DemiBold; color: Theme.pText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.phase = "idle"; Shell.open("ajustesapp", "dictado"); } }
                }
                // terminar la conversación
                Rectangle {
                    visible: root.conv
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: Qt.alpha(Theme.danger, cma.containsMouse ? 0.3 : 0.18)
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 2; color: Theme.danger }
                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.convEnd(false) }
                }
                // terminar (manos libres)
                Rectangle {
                    visible: root.phase === "rec" && !root.conv && (root.latched || root.mode !== "ptt")
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: Qt.alpha(Theme.danger, sma.containsMouse ? 0.3 : 0.18)
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 2; color: Theme.danger }
                    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stop() }
                }
                // cancelar
                Rectangle {
                    visible: (root.phase === "rec" || root.phase === "trans") && !root.conv
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: xma.containsMouse ? Theme.fill2 : "transparent"
                    Icon { anchors.centerIn: parent; name: "x"; size: 12; color: Theme.tv }
                    MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                }
            }
        }
    }
}
