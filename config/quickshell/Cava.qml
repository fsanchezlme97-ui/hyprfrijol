pragma Singleton
// Una sola instancia de cava para todas las barras: entrega `count` valores 0–1 a 60 fps.
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
    readonly property bool active: !paused && users > 0 && (Media.playing || !silent)
    property bool silent: false

    Process {
        running: root.active
        command: ["cava", "-p", Paths.root + "/config/cava/hf-bar.conf"]
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
                if (any) quiet.restart();
                root.silent = false;
            }
        }
        onRunningChanged: if (!running) root.bars = Array(root.count).fill(0)
    }
    // 6 s sin sonido y sin reproductor activo → pausa
    Timer { id: quiet; interval: 6000; onTriggered: if (!Media.playing) root.silent = true }
    // En pausa por silencio, se vuelve a escuchar de vez en cuando (sonido que no viene de un reproductor MPRIS)
    Timer { running: root.silent && root.users > 0; interval: 15000; repeat: true; onTriggered: { root.silent = false; quiet.restart(); } }
    Connections { target: Media; function onPlayingChanged() { if (Media.playing) root.silent = false; } }
}
