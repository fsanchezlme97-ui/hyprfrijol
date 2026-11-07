// Sonda de apertura (solo con HF_PROBE_OPEN=1 en el entorno de Quickshell; si no, no hace nada): mide desde
// Shell.open()/Shell.stamp() hasta el primer fotograma de la ventana y los saltos de fotogramas durante la
// animación de entrada (450 ms). Sale en `qs log` como:
//   [probe] spotlight visible=38ms frames=27 maxGap=21ms slow=0
// Va dentro de la ventana que se mide: OpenProbe { name: "spotlight"; shown: win.shown }
import QtQuick
import QtQuick.Window
import Quickshell
import ".."

Item {
    id: p
    property string name
    property bool shown
    readonly property bool on: Quickshell.env("HF_PROBE_OPEN") === "1"
    property real t0: 0
    property real first: 0
    property real last: 0
    property int frames: 0
    property real maxGap: 0
    property int slow: 0
    function begin(): void {
        const now = Date.now();
        t0 = Shell.openedAt > 0 && now - Shell.openedAt < 5000 ? Shell.openedAt : now;
        first = 0; last = 0; frames = 0; maxGap = 0; slow = 0;
    }
    onShownChanged: if (on && shown) begin()
    Component.onCompleted: if (on && shown) begin()
    Connections {
        target: p.on && p.t0 > 0 ? p.Window.window : null
        function onFrameSwapped() {
            const now = Date.now();
            if (p.frames === 0) p.first = now;
            else { const g = now - p.last; p.maxGap = Math.max(p.maxGap, g); if (g > 25) p.slow++; }
            p.last = now; p.frames++;
            if (p.frames === 1) report.restart();
        }
    }
    Timer {
        id: report
        interval: 450
        onTriggered: {
            console.info("[probe] " + p.name + " visible=" + (p.first - p.t0) + "ms frames=" + p.frames + " maxGap=" + p.maxGap + "ms slow=" + p.slow);
            p.t0 = 0;
        }
    }
}
