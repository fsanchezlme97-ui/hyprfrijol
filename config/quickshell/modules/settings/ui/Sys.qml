// Ejecuta un comando y devuelve su salida (texto) — para leer el estado del sistema.
//   Sys { id: kern; cmd: ["uname", "-r"]; onDone: out => … }   kern.run()
import QtQuick
import Quickshell.Io

Process {
    id: root
    property var cmd: []
    property string out: ""
    property bool auto: true
    signal done(string out)
    command: cmd
    function run(): void { running = false; running = true; }
    stdout: StdioCollector { onStreamFinished: { root.out = text; root.done(text); } }
    Component.onCompleted: if (auto && cmd.length) running = true
}
