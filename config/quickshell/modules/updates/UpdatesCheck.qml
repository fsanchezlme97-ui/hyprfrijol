// Comprobación de actualizaciones en segundo plano (updatesMode, ver Updates.qml): a los 5 min de entrar y cada 6 h
// ejecuta `hf-updates check` y avisa si hay más que la última vez. Siempre cargado; la vista «actualizaciones»
// (Updates.qml) se carga al abrirla y lee el resultado con `hf-updates cached`.
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Scope {
    id: root
    readonly property string mode: Settings.get("updatesMode", "avisar")
    property int lastNotified: -1
    Timer {
        id: bgTimer
        running: root.mode !== "manual"
        interval: 5 * 60 * 1000
        repeat: true
        onTriggered: { interval = 6 * 3600 * 1000; if (Shell.view !== "actualizaciones") { bgCheck.running = false; bgCheck.running = true; } }
    }
    Process {
        id: bgCheck
        command: [Paths.script("hf-updates"), "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text) || {}; } catch (e) { return; }
                if (root.mode === "auto" && (r.flatpak ?? []).length) Quickshell.execDetached([Paths.script("hf-updates"), "flatpak"]);
                const n = (r.total ?? 0) - (root.mode === "auto" ? (r.flatpak ?? []).length : 0);
                if (n > 0 && n > root.lastNotified && Shell.view !== "actualizaciones")
                    Quickshell.execDetached(["sh", "-c",
                        '[ "$(notify-send -a Actualizaciones -i system-software-update -A open=Ver "$1" "$2")" = open ] && qs -p "$3" ipc call shell open actualizaciones',
                        "sh", n === 1 ? "1 actualización disponible" : n + " actualizaciones disponibles", r.has?.snapper ? "Con punto de restauración antes de instalar" : "Abre el centro de actualizaciones",
                        Paths.root + "/config/quickshell"]);
                root.lastNotified = n;
            }
        }
    }
}
