pragma Singleton
// Gato bongo (módulo «bongo» de barModules): da golpecitos con la pata izquierda o derecha cada vez que escribes.
// scripts/hf-bongo lee el teclado y solo dice con qué mano tocaría (L/R), nunca qué tecla: no guarda nada.
//   Bongo.users++ / -- al mostrarse u ocultarse el chip (el lector solo corre mientras hay alguno y no duerme)
//   Bongo.left / Bongo.right (pata abajo) · Bongo.count (golpes desde que arrancó el shell) · Bongo.kpm (por minuto)
//   Bongo.asleep (Settings «bongoSleep»: clic en el chip) · Bongo.problem ("" | "noperm" | "nokbd")
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property int users: 0
    readonly property bool asleep: Settings.get("bongoSleep", false)
    property bool left: false
    property bool right: false
    property int count: 0
    property string problem: ""
    property var stamps: []          // golpes de los últimos 60 s (para el ritmo)
    property int kpm: 0
    readonly property bool typing: left || right || idle.running
    function toggleSleep(): void { Settings.set("bongoSleep", !asleep); }

    function hit(side: string): void {
        if (side === "L") { left = true; lt.restart(); }
        else { right = true; rt.restart(); }
        count++;
        idle.restart();
        const now = Date.now();
        stamps = stamps.filter(t => now - t < 60000).concat([now]);
        kpm = stamps.length;
    }

    Process {
        id: proc
        running: root.users > 0 && !root.asleep
        command: [Paths.script("hf-bongo")]
        stdout: SplitParser {
            onRead: l => {
                const s = l.trim();
                if (s === "L" || s === "R") { root.problem = ""; root.hit(s); }
                else if (s === "noperm" || s === "nokbd") root.problem = s;
            }
        }
        onRunningChanged: if (!running) { root.left = false; root.right = false; }
    }
    // la pata vuelve arriba enseguida, como un golpe de tambor
    Timer { id: lt; interval: 110; onTriggered: root.left = false }
    Timer { id: rt; interval: 110; onTriggered: root.right = false }
    // «escribiendo» un rato tras la última tecla (los ojos se quedan abiertos)
    Timer { id: idle; interval: 2500 }
    // el ritmo baja solo cuando dejas de escribir
    Timer {
        running: root.kpm > 0
        interval: 5000; repeat: true
        onTriggered: { const now = Date.now(); root.stamps = root.stamps.filter(t => now - t < 60000); root.kpm = root.stamps.length; }
    }
}
