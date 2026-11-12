// Modo compañero (Ajustes › Asistente de IA, aiCompanion, apagado por defecto): de vez en cuando Helpert mira la pantalla
// (hf-ai peek → ~/.cache/hyprfrijol/capturas_tmp_ai) y empieza él la conversación por voz: ofrece ayuda, pregunta cómo
// vas o comenta lo que ve, como un amigo. Si no ve nada que decir (SKIP) no dice nada.
//
// Cuándo (un repaso por minuto, sin medir nada más que /proc/loadavg y /proc/meminfo):
//   · Nunca: bloqueado, «no molestar», ausente (3 min sin tocar nada), pantalla completa (juegos, vídeos),
//     micrófono en uso por otra app (llamadas), micrófono silenciado, pomodoro de foco, modo sin distracciones,
//     ya hablando o dictando, ni en los primeros 15 min de la sesión.
//   · Equipo muy cargado (CPU por núcleo > 0,9 o < 10 % de memoria libre) 3 min seguidos: avisa y ofrece ayuda
//     (como mucho cada 20 min).
//   · 60 min seguidos de actividad sin un descanso (10 min sin tocar nada cuenta como descanso): propone parar.
//   · Si no, una visita cada aiCompanionFreq (poco 90 · normal 45 · a menudo 20 min, ±20 % al azar). Con mucho
//     abierto (8 ventanas o más) o el equipo trabajando (> 0,7 por núcleo) espera 1,5 veces más: estás ocupado.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../services"

Item {
    id: root
    property bool busy: false                    // dictando (Dictado.qml)
    signal visiting()                            // Dictado.companionTalk(): la conversación espera a Helpert
    readonly property bool on: Settings.get("aiCompanion", false) === true
    readonly property real base: ({ poco: 90, normal: 45, amenudo: 20 })[Settings.get("aiCompanionFreq", "normal")] ?? 45

    IdleMonitor { id: idle; enabled: root.on; timeout: 180; respectInhibitors: true }

    property real started: Date.now()
    property real lastVisit: Date.now()          // la primera, no antes de 15 min (ver gate)
    property int streak: 0                       // minutos seguidos con actividad
    property int idleMin: 0
    property int hotMin: 0                       // minutos seguidos con el equipo muy cargado
    property real lastHot: 0
    property real jitter: 0.8 + Math.random() * 0.4
    property real load: 0                        // carga por núcleo (1 min)
    property real memFree: 1                     // fracción de memoria disponible

    readonly property var focused: HyprClients.clients.find(c => c.focusHistoryID === 0) ?? null
    function interval(): real {
        const crowded = HyprClients.clients.filter(c => c.workspace?.id > 0).length >= 8 || load > 0.7;
        return base * (crowded ? 1.5 : 1) * jitter * 60000;
    }
    // Por qué no ahora ("" = puede)
    function gate(): string {
        if (!on) return "apagado";
        if (Shell.locked) return "bloqueado";
        if (Notifs.dnd) return "no molestar";
        if (idle.isIdle) return "ausente";
        if (Shell.aiConversation || Shell.aiSpeaking || busy) return "ya hablando";
        if (Audio.micMuted) return "micrófono silenciado";
        if (Audio.micUsers.length > 0) return "micrófono en uso";
        if ((focused?.fullscreen ?? 0) > 0) return "pantalla completa";
        if (Pomodoro.running && Pomodoro.mode === "foco") return "pomodoro";
        if (Shell.focusMode) return "sin distracciones";
        if (Date.now() - started < 15 * 60000) return "recién empezada la sesión";
        return "";
    }
    function state(): string {
        const g = gate();
        return (g || "lista") + " · próxima en " + Math.max(0, Math.round((lastVisit + interval() - Date.now()) / 60000)) + " min"
             + " · " + streak + " min seguidos · carga " + load.toFixed(2) + " · memoria libre " + Math.round(memFree * 100) + " %";
    }

    Timer {
        interval: 60000; repeat: true; running: root.on
        onTriggered: { stats.running = false; stats.running = true; }
    }
    Process {
        id: stats
        command: ["sh", "-c", "cat /proc/loadavg; nproc; grep -E '^Mem(Total|Available):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const n = Math.max(1, parseInt(l[1]) || 1);
                root.load = (parseFloat(l[0]) || 0) / n;
                const kb = k => parseInt((l.find(x => x.startsWith(k)) ?? "").replace(/\D+/g, "")) || 0;
                root.memFree = kb("MemTotal") > 0 ? kb("MemAvailable") / kb("MemTotal") : 1;
                root.tick();
            }
        }
    }
    function tick(): void {
        if (idle.isIdle) { if (++idleMin >= 10) streak = 0; } else { idleMin = 0; streak++; }
        hotMin = load > 0.9 || memFree < 0.1 ? hotMin + 1 : 0;
        if (gate() !== "") return;
        const since = Date.now() - lastVisit, app = focused ? HyprClients.appName(focused.class) || focused.class : "";
        if (hotMin >= 3 && Date.now() - lastHot > 20 * 60000) {
            lastHot = Date.now();
            visit(false, "El equipo va muy cargado (carga " + load.toFixed(2) + " por núcleo, " + Math.round(memFree * 100)
                         + " % de memoria libre). Si en la pantalla se ve qué lo causa, dilo y ofrece ayuda para aliviarlo.");
        } else if (streak >= 60 && since > base * 60000) {
            visit(false, "Llevo " + streak + " minutos seguidos frente al equipo sin un descanso.");
        } else if (since > interval() && streak >= 10) {
            visit(false, "Visita de rutina." + (app ? " Ahora uso " + app + "." : ""));
        }
    }
    // now = a petición (IPC dictado checkIn): sin esperar a que toque, pero con la misma privacidad
    property string why: ""
    function visit(now, reason): void {
        if (now && (Shell.aiConversation || busy)) return;
        why = reason || "Te pidieron pasar a saludar ahora.";
        lastVisit = Date.now(); jitter = 0.8 + Math.random() * 0.4;
        if (Settings.get("aiCompanionLook", true) === false) { go(""); return; }
        peek.running = true;
    }
    Connections { target: Shell; function onAiCompanionNow() { root.visit(true, ""); } }
    function go(image): void { root.visiting(); Shell.aiCheckIn(why, image); }
    Process {
        id: peek
        command: [Paths.script("hf-ai"), "peek"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = {};
                try { j = JSON.parse(text); } catch (e) {}
                if (j.path) root.go(j.path);
                else root.lastVisit = Date.now() - root.interval() + 10 * 60000;   // app privada a la vista…: en 10 min
            }
        }
    }
}
