// OSD (diseño: píldora 42 px centrada abajo): volumen, brillo, Bloq Mayús, micrófono y modo de ventanas
// (Super + Mayús + Espacio: los tres modos con el elegido resaltado; services/WinMode.qml).
// Se muestra solo al cambiar el valor (no al arrancar). Desde fuera:
//   qs -p <repo>/config/quickshell ipc call osd popup volumen|brillo|mayus|micro
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: win
    property string kind: ""          // "volumen" | "brillo" | "mayus" | "micro" | "ventanas"
    property string winMode: ""       // modo recién elegido (kind "ventanas")
    property bool shown: false
    property bool caps: false
    property bool ready: false        // ignora los cambios de los primeros segundos

    function show(k) {
        if (!ready || Shell.view === "bloqueo") return;
        kind = k; shown = true; hider.restart();
    }

    screen: Shell.screen
    visible: shown || fadeAnim.running
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Posición (Ajustes › Notificaciones y avisos → osdPos): abajo · arriba · centro · izquierda · derecha ·
    // inf-der · sup-der; osdOffset = distancia en px al borde (o a la barra, si está en ese borde). La geometría
    // es la de services/OsdStack.qml, compartida con la píldora del dictado: si las dos se ven, el OSD se aparta.
    readonly property bool atB: OsdStack.atB
    readonly property bool atT: OsdStack.atT
    readonly property bool atL: OsdStack.atL
    readonly property bool atR: OsdStack.atR
    readonly property real stackRoom: 70          // sitio para apartarse de la píldora del dictado (42 + 8 + aire)
    anchors { bottom: atB; top: atT; left: atL; right: atR }
    margins { bottom: atB ? OsdStack.edge("abajo") : 0; top: atT ? OsdStack.edge("arriba") : 0; left: atL ? OsdStack.edge("izquierda") : 0; right: atR ? OsdStack.edge("derecha") : 0 }
    implicitWidth: pill.width + 40
    implicitHeight: 42 + 40 + (atT || atB ? stackRoom : 2 * stackRoom)
    mask: Region {}

    readonly property real level: kind === "volumen" ? Audio.volume : kind === "brillo" ? Brightness.value : 0
    readonly property bool hasBar: kind === "volumen" || kind === "brillo"
    readonly property string iconName: kind === "volumen" ? (Audio.muted || Audio.volume === 0 ? "volume" : Audio.volume < 0.34 ? "volume_low" : "volume_high")
                                     : kind === "brillo" ? "sun" : kind === "mayus" ? "caps" : kind === "ventanas" ? "" : kind === "cafeina" ? "coffee" : "mic_off"
    readonly property string label: kind === "volumen" ? (Audio.muted ? "Silencio" : Math.round(Audio.volume * 100) + " %")
                                  : kind === "brillo" ? Math.round(Brightness.value * 100) + " %"
                                  : kind === "mayus" ? (caps ? "Bloq Mayús activado" : "Bloq Mayús desactivado")
                                  : kind === "ventanas" ? (WinMode.labels[winMode] ?? "") + " · " + (WinMode.hints[winMode] ?? "")
                                  : kind === "cafeina" ? (Caffeine.on ? "Cafeína activada · la pantalla no se apagará" : "Cafeína desactivada")
                                  : Audio.micMuted ? "Micrófono silenciado" : "Micrófono activado"

    Glass {
        id: pill
        kind: "panel"
        radius: Theme.panelRadius
        anchors.horizontalCenter: parent.horizontalCenter
        y: OsdStack.pillY(win.height, height, OsdStack.push)
        Behavior on y { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
        width: Math.max(260, row.implicitWidth + 32)
        height: 42
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { id: fadeAnim; duration: win.shown ? Theme.durIn : 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 12
            Icon { visible: win.iconName !== ""; name: win.iconName; size: 17; color: win.kind === "micro" && Audio.micMuted ? Theme.danger : Theme.t }
            // Modo de ventanas: los tres, el elegido en c.p
            Row {
                visible: win.kind === "ventanas"
                spacing: 4
                Repeater {
                    model: WinMode.modes
                    Rectangle {
                        required property string modelData
                        readonly property bool sel: modelData === win.winMode
                        width: 26; height: 26; radius: 8
                        color: sel ? Theme.p : "transparent"
                        Icon { anchors.centerIn: parent; name: WinMode.icons[parent.modelData]; size: 15; color: parent.sel ? Theme.pText : Theme.tv }
                    }
                }
            }
            Rectangle {
                visible: win.hasBar
                implicitWidth: 150; implicitHeight: 4; radius: 2
                color: Theme.fill2
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, win.level))
                    height: parent.height; radius: 2
                    color: win.kind === "volumen" && Audio.muted ? Theme.o : Theme.p
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            Txt {
                text: win.label
                weight: Font.Medium; tabular: true
                Layout.minimumWidth: win.hasBar ? 38 : 0
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Timer { id: hider; interval: 1600; onTriggered: win.shown = false }
    Timer { running: true; interval: 2000; onTriggered: win.ready = true }

    // Disparadores
    Connections {
        target: Audio
        function onVolumeChanged() { win.show("volumen"); }
        function onMutedChanged() { win.show("volumen"); }
        function onMicMutedChanged() { win.show("micro"); }
    }
    Connections {
        target: WinMode
        function onAnnounced(m) { win.winMode = m; win.ready = true; win.show("ventanas"); }
    }
    Connections {
        target: Caffeine
        function onChangedByUser() { win.ready = true; win.show("cafeina"); }
    }
    Connections {
        target: Brightness
        function onValueChanged() { if (Brightness.available) win.show("brillo"); }
    }
    // Bloq Mayús: LED del teclado en /sys/class/leds/*::capslock
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.trim() !== "" && text.trim() !== "0";
                if (on !== win.caps) { win.caps = on; win.show("mayus"); }
            }
        }
    }
    Timer { running: true; repeat: true; interval: 300; onTriggered: capsProc.running = true }

    IpcHandler {
        target: "osd"
        function popup(kind: string): void { if (kind === "brillo") Brightness.refresh(); win.ready = true; win.show(kind); }
    }
}
