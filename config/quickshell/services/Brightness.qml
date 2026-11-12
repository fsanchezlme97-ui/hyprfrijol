pragma Singleton
// Brillo de la pantalla (brightnessctl). value 0–1; available = hay retroiluminación.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property real value: 0
    property bool available: false
    property int max: 1
    function set(v: real): void {
        v = Math.round(Math.max(0.01, Math.min(1, v)) * 100) / 100;   // en % enteros, como lo que se lee después
        value = v;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }
    function refresh(): void { reader.running = true; }
    // Sin pantalla con retroiluminación (PC de escritorio) basta con mirar al arrancar: no se sondea cada 10 s
    property bool checked: false
    Timer { interval: 10000; running: root.available || !root.checked; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Process {
        id: reader
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                root.available = f.length >= 5;
                root.checked = true;
                // en % enteros, igual que set(): con decimales sueltos el valor «cambiaba» solo y salía el OSD
                if (root.available) { root.value = Math.round(parseInt(f[2]) / parseInt(f[4]) * 100) / 100; root.max = parseInt(f[4]); }
            }
        }
    }
}
