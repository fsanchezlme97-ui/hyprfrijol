// Ajustes › Accesibilidad — preajustes (alto contraste, texto grande), Orca, alto contraste (hf-apply:
// fix_contrast + estilo sin vidrio), reducir transparencia/movimiento, lupa (cursor:zoom_factor),
// cursor grande, filtros de color (decoration:screen_shader, config/apply/shaders), teclado en pantalla,
// subtítulos en vivo y audio mono (PipeWire). Lo que Hyprland aún no permite aparece desactivado.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    property var has: ({})
    property bool orcaOn: false
    property bool oskOn: false
    property bool monoOn: false
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "for b in orca wvkbd-mobintl squeekboard livecaptions nerd-dictation pactl; do command -v $b >/dev/null && echo has:$b; done; "
            + "flatpak list --app --columns=application 2>/dev/null | grep -q LiveCaptions && echo has:livecaptions-flatpak; "
            + "pgrep -x orca >/dev/null && echo on:orca; (pgrep -x wvkbd-mobintl || pgrep -x squeekboard) >/dev/null && echo on:osk; pactl list short sinks 2>/dev/null | grep -q hf-mono && echo on:mono"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {}; text.split("\n").filter(x => x.startsWith("has:")).forEach(x => h[x.slice(4)] = true); root.has = h;
                root.orcaOn = text.includes("on:orca"); root.oskOn = text.includes("on:osk"); root.monoOn = text.includes("on:mono");
            }
        }
    }
    Timer { id: reprobe; interval: 1500; onTriggered: { probe.running = false; probe.running = true; } }
    readonly property string osk: has["wvkbd-mobintl"] ? "wvkbd-mobintl" : has["squeekboard"] ? "squeekboard" : ""
    readonly property bool hcOn: Settings.get("highContrast", false) && Settings.get("reduceTransparency", false)
    readonly property bool bigTextOn: Settings.get("fontScale", 1) >= 1.25

    // Preajustes de un clic (sirven igual con Material y con Aurora)
    Section {
        Layout.fillWidth: true
        title: "Preajustes"
        headerRight: Mono { text: "highContrast · reduceTransparency · fontScale" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Card {
                Layout.preferredWidth: 1
                title: "Alto contraste" + (root.hcOn ? " · activado" : "")
                sub: "Texto a 7:1, bordes marcados y sin transparencias"
                selected: root.hcOn
                onClicked: Settings.setMany({ highContrast: !root.hcOn, reduceTransparency: !root.hcOn })
            }
            Card {
                Layout.preferredWidth: 1
                title: "Texto grande" + (root.bigTextOn ? " · activado" : "")
                sub: root.bigTextOn ? "Texto ×" + String(Settings.get("fontScale", 1)).replace(".", ",") + " · pulsa para volver al tamaño normal" : "Todo el texto del shell (y de GTK) un 25 % mayor"
                selected: root.bigTextOn
                onClicked: Settings.set("fontScale", root.bigTextOn ? 1 : 1.25)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Visión"
            SwRow {
                separator: false
                label: "Lector de pantalla"; sub: root.has.orca ? "Orca · Super + Alt + S" : "instala orca"
                enabled: !!root.has.orca
                checked: root.orcaOn
                onToggled: v => { Settings.set("screenReader", v); Quickshell.execDetached(["sh", "-c", v ? "setsid orca --replace >/dev/null 2>&1 &" : "pkill -x orca"]); root.orcaOn = v; }
            }
            SwRow { label: "Alto contraste"; sub: "texto a 7:1, bordes marcados y sin vidrio"; key: "highContrast" }
            SwRow { label: "Reducir transparencia"; sub: Settings.get("highContrast", false) ? "ya incluido en alto contraste" : "el vidrio de Aurora pasa a superficies sólidas"; key: "reduceTransparency" }
            SwRow { label: "Reducir movimiento"; sub: "sin fondos animados ni rebotes"; key: "reduceMotion" }
            SwRow {
                label: "Lupa"; sub: "Super + + y Super + − · sigue al cursor"
                key: "magnifier"
            }
            SwRow { label: "Cursor grande"; sub: Settings.get("bigCursor", false) ? "48 px" : "24 px"; key: "bigCursor"; onToggled: v => Quickshell.execDetached(["sh", "-c", "hyprctl setcursor \"${XCURSOR_THEME:-default}\" " + (v ? 48 : 24)]) }
            Txt { text: "Filtro de color"; muted: true; Layout.topMargin: 4 }
            Seg {
                Layout.fillWidth: true
                pill: true
                model: [["ninguno", "Ninguno"], ["protanopia", "Protanopía"], ["deuteranopia", "Deuteranopía"], ["tritanopia", "Tritanopía"], ["grises", "Grises"]]
                current: Settings.get("colorFilter", "ninguno")
                onPicked: k => Settings.set("colorFilter", k)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                title: "Teclado, ratón y voz"
                SwRow {
                    separator: false
                    label: "Teclado en pantalla"; sub: root.osk ? root.osk : "instala wvkbd o squeekboard"
                    enabled: root.osk !== ""
                    checked: root.oskOn
                    onToggled: v => { Quickshell.execDetached(["sh", "-c", v ? "setsid " + root.osk + " >/dev/null 2>&1 &" : "pkill -f '^(/usr/bin/)?(wvkbd|squeekboard)'"]); root.oskOn = v; Settings.set("osk", v); }
                }
                SwRow { label: "Teclas especiales"; sub: "Hyprland aún no admite teclas especiales (AccessX)"; enabled: false }
                SwRow { label: "Teclas lentas"; sub: "Hyprland aún no admite teclas lentas"; enabled: false }
                LinkRow {
                    readonly property int d: Settings.get("kbRepeatDelay", 400)
                    label: "Retardo de repetición"; value: (d >= 600 ? "Largo" : d <= 250 ? "Corto" : "Medio") + " · " + d + " ms"
                    section: "teclado"; sectionLabel: "Teclado y atajos"
                }
                LinkRow { label: "Dictado por voz"; value: "Super + Alt + D"; section: "dictado"; sectionLabel: "Dictado"; target: "Motor de reconocimiento" }
            }
            Section {
                Layout.fillWidth: true
                title: "Audición"
                SwRow {
                    separator: false
                    label: "Subtítulos en vivo"; sub: root.has.livecaptions || root.has["livecaptions-flatpak"] ? "Live Captions · para cualquier audio · local" : "instala Live Captions (Flathub)"
                    enabled: !!(root.has.livecaptions || root.has["livecaptions-flatpak"])
                    onToggled: v => { if (v) Quickshell.execDetached(["sh", "-c", root.has.livecaptions ? "livecaptions" : "flatpak run com.github.abb128.LiveCaptions"]); }
                }
                SwRow { label: "Alertas visuales"; sub: "la barra parpadea en vez de sonar"; key: "visualBell" }
                SwRow {
                    label: "Audio mono"; sub: "mismo sonido en ambos oídos"
                    enabled: !!root.has.pactl
                    checked: root.monoOn
                    onToggled: v => {
                        Quickshell.execDetached(["sh", "-c", v
                            ? "m=$(pactl get-default-sink); pactl load-module module-remap-sink sink_name=hf-mono sink_properties=device.description=Mono master=$m channels=2 channel_map=mono,mono >/dev/null && pactl set-default-sink hf-mono"
                            : "for i in $(pactl list short modules | awk '/sink_name=hf-mono/{print $1}'); do pactl unload-module $i; done"]);
                        root.monoOn = v; Settings.set("monoAudio", v); reprobe.restart();
                    }
                }
            }
            Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Atajo rápido: Super + Alt + A abre este menú desde cualquier lugar." }
        }
    }
}
