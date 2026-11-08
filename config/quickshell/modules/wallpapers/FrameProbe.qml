// Sonda de fotogramas del selector de fondos (solo con HF_PROBE_OPEN=1; si no, no hace nada).
// Mientras mide, fuerza un fotograma por ciclo (FrameAnimation) para que cada salto sea un atasco de verdad y no
// una pantalla quieta. Escribe en `qs log`:
//   [probe] fondos:nav frames=118 maxGap=18ms p95=17ms slow20=0 slow33=0
// Mide al abrir (open), al cerrar (close) y al navegar por IPC (la misma ruta que ← → y la rueda):
//   qs ipc call fondosprobe nav <pasos> <ms entre pasos> <1|-1>
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io

Item {
    id: p
    property var target                 // el selector (step(d))
    property bool shown
    readonly property bool on: Quickshell.env("HF_PROBE_OPEN") === "1"
    property string tag: ""
    property real last: 0
    property int frames: 0
    property real maxGap: 0
    property var gaps: []
    // Además: delegados creados (miniaturas que se rehacen) y latencia de la vista previa (paso → imagen lista)
    property int created: 0
    property real asked: 0
    property var lat: []
    function delegateCreated(): void { if (tag !== "") created++; }
    function previewAsked(): void { if (tag !== "" && asked === 0) asked = Date.now(); }
    function previewReady(): void { if (tag !== "" && asked > 0) { lat.push(Date.now() - asked); asked = 0; } }
    width: 1; height: 1

    function begin(t: string, ms: int): void {
        if (!on) return;
        if (tag !== "") report();
        tag = t; last = 0; frames = 0; maxGap = 0; gaps = []; created = 0; asked = 0; lat = [];
        endT.interval = ms; endT.restart();
    }
    function report(): void {
        const g = gaps.slice().sort((a, b) => a - b);
        const p95 = g.length ? g[Math.min(g.length - 1, Math.floor(g.length * 0.95))] : 0;
        console.info("[probe] fondos:" + tag + " frames=" + frames + " maxGap=" + maxGap + "ms p95=" + p95
                     + "ms slow20=" + g.filter(x => x > 20).length + " slow33=" + g.filter(x => x > 33).length
                     + " created=" + created + " previewLat=" + (lat.length ? Math.round(lat.reduce((a, b) => a + b, 0) / lat.length) + "/" + Math.max(...lat) : "-") + "ms");
        tag = "";
    }
    onShownChanged: if (on) begin(shown ? "open" : "close", shown ? 500 : 320)

    FrameAnimation { running: p.tag !== ""; onTriggered: dot.rotation = (dot.rotation + 7) % 360 }
    Rectangle { id: dot; width: 1; height: 1; color: "black"; opacity: 0.02 }
    Connections {
        target: p.on && p.tag !== "" ? p.Window.window : null
        function onFrameSwapped() {
            const now = Date.now();
            if (p.frames > 0) { const g = now - p.last; p.maxGap = Math.max(p.maxGap, g); p.gaps.push(g); }
            p.last = now; p.frames++;
        }
    }
    Timer { id: endT; onTriggered: if (p.tag !== "") p.report() }
    Timer {
        id: navT
        property int left: 0
        property int dir: 1
        repeat: true
        onTriggered: { p.target.step(dir); if (--left <= 0) { stop(); endT.interval = 400; endT.restart(); } }
    }
    IpcHandler {
        target: "fondosprobe"
        enabled: p.on
        function nav(n: int, ms: int, dir: int): void {
            p.begin("nav" + ms, n * ms + 600);
            navT.left = n; navT.dir = dir; navT.interval = ms; navT.restart();
        }
        // Para comprobar el teclado y la pantalla elegida desde fuera
        function state(): string {
            const t = p.target;
            return JSON.stringify({ sel: t.sel, count: t.count, name: t.cur ? t.cur.name : "", path: t.cur ? t.cur.path : "",
                                    searching: t.searching ?? false, query: t.query ?? "", monitor: t.monitor });
        }
        function monitor(name: string): void { p.target.monitor = name; }
    }
}
