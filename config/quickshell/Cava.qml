pragma Singleton
// Una sola instancia de cava para todas las barras: entrega `count` valores 0–1 a 30 fps.
// Se detiene sola tras unos segundos de silencio sin música (ahorra CPU) y vuelve al sonar algo.
import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Singleton {
    id: root
    readonly property int count: 48
    property var bars: Array(count).fill(0)
    property bool paused: false
    property int users: 0                         // barras que muestran la onda (si 0, no hace falta cava)
    readonly property bool active: !paused && users > 0 && (Media.playing || Shell.aiSpeaking || !silent)
    property bool silent: false

    Process {
        running: root.active
        command: Paths.reaper.concat(["cava", "-p", Paths.root + "/config/cava/hf-bar.conf"])
        stdout: SplitParser {
            onRead: data => {
                const v = data.split(";");
                const out = new Array(root.count);
                let any = false;
                for (let i = 0; i < root.count; i++) {
                    const n = Number(v[i]) / 1000;
                    out[i] = n > 0 ? n : 0;
                    if (n > 0.015) any = true;
                }
                root.bars = out;
                if (any) { quiet.restart(); root.probing = false; relisten.interval = 15000; }
                root.silent = false;
            }
        }
        // Al arrancar también cuenta el silencio: si no suena nada, nunca llegaba un valor > 0 que pusiera en marcha
        // `quiet` y cava seguía a 60 fps para siempre (≈5 % de CPU en reposo con el shell redibujando la onda)
        onRunningChanged: if (running) quiet.restart(); else root.bars = Array(root.count).fill(0)
    }
    // 6 s sin sonido y sin reproductor activo → pausa (2,5 s si solo era una escucha de comprobación)
    property bool probing: false
    Timer { id: quiet; interval: root.probing ? 2500 : 6000; onTriggered: if (!Media.playing && !Shell.aiSpeaking) root.silent = true }
    // En pausa por silencio, se vuelve a escuchar de vez en cuando (sonido que no viene de un reproductor MPRIS: juegos,
    // llamadas…). Cada escucha sin sonido espacia la siguiente (15 → 30 → 60 s): cava pasa ~4 % del tiempo encendido
    Timer {
        id: relisten
        running: root.silent && root.users > 0; interval: 15000; repeat: true
        onTriggered: {
            root.probing = true;
            root.silent = false;
            quiet.restart();
            interval = Math.min(60000, interval * 2);
        }
    }
    // La voz del asistente (hf-ai speak) no es un reproductor MPRIS: se escucha mientras suena
    Connections { target: Shell; function onAiSpeakingChanged() { if (Shell.aiSpeaking) { root.silent = false; root.probing = false; } } }
    Connections { target: Media; function onPlayingChanged() { if (Media.playing) { root.silent = false; root.probing = false; relisten.interval = 15000; } } }
}
