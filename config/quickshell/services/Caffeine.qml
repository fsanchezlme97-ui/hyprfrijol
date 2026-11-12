pragma Singleton
// Modo cafeína: la pantalla no se atenúa, no se bloquea ni se apaga y el equipo no se suspende por
// inactividad. Lo hace scripts/hf-caffeine (cerrojo «idle» de systemd-inhibit, que respeta hypridle), en un
// proceso aparte atado a la sesión: sigue activo si el shell se reinicia y se suelta al cerrar la sesión.
//   Caffeine.on · Caffeine.until (ms epoch; 0 = sin límite) · Caffeine.left (texto «45 min») · toggle() · set(on, min)
// Desde: mosaico de Ajustes rápidos, indicador de la barra (módulo «cafeina» de barModules), atajo
// Super + Alt + C → hl.dsp.global("hf:cafeina") (aviso en pantalla) e IPC: qs … ipc call caffeine toggle|on|off|status
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

Singleton {
    id: root
    property bool on: false
    property real until: 0
    property bool known: false
    readonly property string left: {
        if (!on || until <= 0) return "";
        const m = Math.max(1, Math.round((until - Time.now.getTime()) / 60000));
        return m >= 60 ? Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : m + " min";
    }
    // Se cambió a mano (atajo, barra, Ajustes rápidos): el OSD lo enseña
    signal changedByUser()

    function refresh(): void { st.running = false; st.running = true; }
    function set(v: bool, min: int): void {
        on = v; until = v && min > 0 ? Date.now() + min * 60000 : 0;   // al momento; el script lo confirma
        run.command = [Paths.script("hf-caffeine"), v ? "on" : "off"].concat(v && min > 0 ? [String(min)] : []);
        run.running = false; run.running = true;
        changedByUser();
    }
    function toggle(): void { set(!on, 0); }

    Process {
        id: st
        running: true
        command: [Paths.script("hf-caffeine"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                root.on = f[0] === "on";
                root.until = root.on && Number(f[1]) > 0 ? Number(f[1]) * 1000 : 0;
                root.known = true;
            }
        }
    }
    Process { id: run; onExited: root.refresh() }
    // Fuera del shell (terminal, asistente) hf-caffeine avisa por IPC («caffeine sync»): no hace falta sondear.
    // Con minutos, se mira justo cuando se acaban; por si acaso, cada 5 min mientras esté puesta.
    Timer { interval: Math.max(1000, root.until - Date.now() + 6000); running: root.on && root.until > 0; onTriggered: root.refresh() }
    Timer { interval: 300000; running: root.on; repeat: true; onTriggered: root.refresh() }

    GlobalShortcut {
        appid: "hf"; name: "cafeina"; description: "HyprFrijol: modo cafeína (no apagar la pantalla)"
        onPressed: root.toggle()
    }
    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.toggle(); }
        function on(min: int): void { root.set(true, min); }
        function off(): void { root.set(false, 0); }
        function sync(): void { root.refresh(); }
        function status(): string { return root.on ? "on" + (root.left ? " · " + root.left : "") : "off"; }
    }
}
