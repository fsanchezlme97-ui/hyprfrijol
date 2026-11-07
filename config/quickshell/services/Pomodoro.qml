pragma Singleton
// Pomodoro de la barra (por defecto 25 min foco / 5 descanso / 15 descanso largo cada 4 rondas), como en el diseño.
// Ajustes › Enfoque (y la ventana del chip, vista "w-pomodoro"): pomodoroFocus, pomodoroBreak, pomodoroLong,
//   pomodoroCycles, focusAutoBreak (encadena descanso y foco sin parar; si no, se pausa al terminar cada
//   bloque), focusSound (sonido «complete» al terminar cada bloque).
//   toggle() iniciar/pausar · reset() vuelve al primer foco · skip() pasa al siguiente bloque
//   adjust(±min) cambia el bloque actual (parado: rueda sobre el chip) · setMode("foco"|"descanso"|"largo")
// Al terminar cada bloque: notificación (con «Empezar» si no se encadenan) y sonido.
// IPC:  qs … ipc call pomodoro toggle | reset | skip | start <min> | pause | status
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property bool running: false
    property string mode: "foco"                 // "foco" | "descanso" | "largo"
    readonly property int focusMin: Settings.get("pomodoroFocus", 25)
    readonly property int breakMin: Settings.get("pomodoroBreak", 5)
    readonly property int longMin: Settings.get("pomodoroLong", 15)
    readonly property int cycles: Math.max(1, Settings.get("pomodoroCycles", 4))
    readonly property bool autoNext: Settings.get("focusAutoBreak", true)
    readonly property bool sound: Settings.get("focusSound", true) && Settings.get("systemSounds", true) !== false
    property int total: focusMin * 60            // duración del bloque actual (s); cambia con adjust()
    property int left: total
    property int done: 0                         // rondas de foco completadas en este ciclo (0 – cycles)
    property int today: 0                        // focos completados desde que arrancó el shell
    readonly property real progress: total > 0 ? Math.max(0, Math.min(1, 1 - left / total)) : 0
    readonly property string time: String(Math.floor(left / 60)).padStart(2, "0") + ":" + String(left % 60).padStart(2, "0")
    readonly property string label: labelOf(mode)
    readonly property bool active: running || left !== total
    // Bloque sin empezar: si cambian los minutos en Ajustes, el contador se ajusta
    property bool fresh: true

    function labelOf(m: string): string { return m === "foco" ? "Foco" : m === "largo" ? "Descanso largo" : "Descanso"; }
    function minutesOf(m: string): int { return m === "foco" ? focusMin : m === "largo" ? longMin : breakMin; }
    function load(m: string): void { mode = m; total = minutesOf(m) * 60; left = total; fresh = true; }
    function toggle(): void { running = !running; }
    function pause(): void { running = false; }
    function reset(): void { running = false; done = 0; load("foco"); }
    function start(min: int): void { mode = "foco"; total = (min > 0 ? min : focusMin) * 60; left = total; running = true; }
    function setMode(m: string): void { if (m !== mode || !running) { const r = running; load(m); running = r; } }
    // ±min al bloque actual (mínimo 1 min, máximo 3 h)
    function adjust(min: int): void {
        const nl = Math.max(60, Math.min(10800, left + min * 60));
        total = Math.max(60, total + (nl - left));
        left = nl;
        fresh = false;
    }
    // Pasa al siguiente bloque sin avisar (un foco saltado no cuenta como ronda)
    function skip(): void { next(false); }

    onRunningChanged: if (running) fresh = false
    onFocusMinChanged: if (fresh && !running && mode === "foco") load(mode)
    onBreakMinChanged: if (fresh && !running && mode === "descanso") load(mode)
    onLongMinChanged: if (fresh && !running && mode === "largo") load(mode)

    function next(finished: bool): void {
        let n;
        if (mode === "foco") {
            if (finished) { done = Math.min(cycles, done + 1); today++; }
            n = done >= cycles ? "largo" : "descanso";
        } else {
            if (mode === "largo") done = 0;
            n = "foco";
        }
        const keep = running && (finished ? autoNext : true);
        load(n);
        running = keep;
        if (!finished) return;
        if (sound)
            Quickshell.execDetached(["sh", "-c",
                "canberra-gtk-play -i complete 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"]);
        const title = n === "foco" ? "A concentrarse" : n === "largo" ? "Descanso largo" : "¡Bloque terminado! Toca descansar";
        const body = minutesOf(n) + " min" + (n === "foco" ? " de foco" : " de descanso")
                   + (n !== "foco" ? " · ronda " + done + " de " + cycles : "")
                   + (autoNext ? "" : " · pulsa «Empezar»");
        // Sin encadenar: la notificación lleva «Empezar», que arranca el bloque por IPC
        const qs = "qs -p '" + Paths.root + "/config/quickshell' ipc call pomodoro";
        Quickshell.execDetached(autoNext
            ? ["notify-send", "-a", "Pomodoro", "-i", "chronometer", title, body]
            : ["sh", "-c", 'a=$(notify-send -a Pomodoro -i chronometer -A start=Empezar "$1" "$2"); [ "$a" = start ] && ' + qs + ' resume', "sh", title, body]);
    }

    Timer {
        interval: 1000; repeat: true; running: root.running
        onTriggered: {
            if (root.left > 1) { root.left--; return; }
            root.next(true);
        }
    }
    IpcHandler {
        target: "pomodoro"
        function toggle(): void { root.toggle(); }
        function reset(): void { root.reset(); }
        function skip(): void { root.skip(); }
        function pause(): void { root.pause(); }
        function resume(): void { root.running = true; }
        function start(min: int): void { root.start(min); }
        function status(): string { return root.label + " " + root.time + (root.running ? "" : " (en pausa)") + " · ronda " + root.done + "/" + root.cycles; }
    }
}
