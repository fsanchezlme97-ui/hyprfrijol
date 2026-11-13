// Ajustes › Sonido — salida y entrada predeterminadas (PipeWire), volumen del micrófono, supresión de ruido
// (EasyEffects), cambio automático a auriculares (Daemons.qml), volumen por app (streams de PipeWire; listas
// compartidas con los ajustes rápidos: components/AudioDevices.qml y AudioStreams.qml), balance,
// sobreamplificar (overAmplify → Audio.maxVolume y 60-binds.py), perfil de cada tarjeta (pactl set-card-profile,
// p. ej. A2DP / manos libres) y sonidos del sistema (systemSounds + gsettings org.gnome.desktop.sound).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, rightCol.implicitHeight)
    property bool hasEasy: false
    property bool easyOn: false
    Process {
        running: true
        command: ["sh", "-c", "command -v easyeffects >/dev/null && echo has; pgrep -x easyeffects >/dev/null && echo on"]
        stdout: StdioCollector { onStreamFinished: { root.hasEasy = text.includes("has"); root.easyOn = text.includes("on"); } }
    }
    // tarjetas con más de un perfil útil (pactl -f json list cards); perfiles como { key, label } (las listas
    // anidadas dentro de un property var vuelven como QVariantList y el Dropdown no las reconoce como pares)
    property var cards: []
    function loadCards() { cardProc.running = false; cardProc.running = true; }
    Process {
        id: cardProc
        running: true
        command: ["sh", "-c", "pactl -f json list cards 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cards = JSON.parse(text).map(c => ({
                        name: c.name, active: c.active_profile,
                        label: c.properties?.["device.description"] ?? c.properties?.["device.product.name"] ?? c.name,
                        bt: String(c.name).startsWith("bluez"),
                        profiles: Object.keys(c.profiles ?? {}).map(k => ({ k: k, p: c.profiles[k] }))
                            .filter(e => (e.p.available && e.k !== "off" && e.k !== "pro-audio") || e.k === c.active_profile)
                            .sort((a, b) => b.p.priority - a.p.priority).map(e => ({ key: e.k, label: root.profName(e.k, String(e.p.description ?? e.k)) }))
                    })).filter(c => c.profiles.length > 1 || c.bt);
                } catch (e) { root.cards = []; }
            }
        }
    }
    Timer { id: cardsLater; interval: 1200; onTriggered: root.loadCards() }
    function profName(k, d) {
        return /a2dp/.test(k) ? "Alta calidad (A2DP)" + (/sbc|aac|ldac|aptx/i.test(d) ? " · " + d.replace(/.*\(|\).*/g, "") : "")
             : /headset|hfp|hsp/.test(k) ? "Manos libres (micrófono, menos calidad)" : k === "off" ? "Apagada" : d;
    }

    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Salida"
            headerRight: Txt { text: Math.round(Audio.volume * 100) + " %"; muted: true; tabular: true }
            AudioDevices { Layout.fillWidth: true; output: true }
            SliderBar { Layout.fillWidth: true; icon: "volume"; value: Audio.volume; to: Audio.maxVolume; onMoved: v => Audio.setVolume(v) }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Txt { text: "Balance"; muted: true; Layout.preferredWidth: 60 }
                Txt { text: "I"; muted: true; size: 11; weight: Font.DemiBold }
                Item {
                    id: bal
                    Layout.fillWidth: true
                    implicitHeight: 22
                    opacity: Audio.volumes.length === 2 ? 1 : 0.4
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.s4 }
                    Rectangle { anchors.centerIn: parent; width: 2; height: 12; color: Theme.o }
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: (Audio.balance + 1) / 2 * (bal.width - width)
                        color: Theme.p
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: Audio.volumes.length === 2
                        cursorShape: Qt.PointingHandCursor
                        function upd(x) { let b = x / width * 2 - 1; if (Math.abs(b) < 0.06) b = 0; Audio.setBalance(b); }
                        onPressed: m => upd(m.x)
                        onPositionChanged: m => { if (pressed) upd(m.x); }
                        onDoubleClicked: Audio.setBalance(0)
                    }
                }
                Txt { text: "D"; muted: true; size: 11; weight: Font.DemiBold }
            }
            SwRow {
                label: "Sobreamplificar"; sub: "permite subir hasta el 150 % · puede distorsionar"
                key: "overAmplify"; def: false
                onToggled: v => { if (!v && Audio.volume > 1) Audio.setVolume(1); }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Entrada"
            AudioDevices { Layout.fillWidth: true; output: false }
            // nivel del micrófono (barras, como el diseño): arrastra para ajustar
            Item {
                Layout.fillWidth: true
                implicitHeight: 14
                Row {
                    anchors.fill: parent
                    spacing: 4
                    Repeater {
                        model: 26
                        Rectangle {
                            required property int index
                            readonly property bool lit: index / 26 < Audio.micVolume && !Audio.micMuted
                            width: (parent.width - 25 * 3) / 26
                            height: 6 + ((index * 7) % 5) * 1.6
                            anchors.bottom: parent.bottom
                            radius: 2
                            color: lit ? Theme.p : Theme.s4
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    function upd(x) { Audio.setMic(Math.max(0, Math.min(1, x / width))); }
                    onPressed: m => upd(m.x)
                    onPositionChanged: m => { if (pressed) upd(m.x); }
                }
            }
            SwRow {
                label: "Supresión de ruido"
                sub: root.hasEasy ? "EasyEffects · ideal para videollamadas" : "instala EasyEffects desde el Centro de aplicaciones"
                enabled: root.hasEasy
                checked: root.easyOn
                onToggled: v => { Quickshell.execDetached(["sh", "-c", v ? "setsid easyeffects --gapplication-service >/dev/null 2>&1 &" : "easyeffects -q"]); root.easyOn = v; Settings.set("noiseSuppression", v); }
            }
            SwRow { label: "Cambiar a auriculares al conectarlos"; sub: "Bluetooth y USB pasan a ser la salida"; key: "audioAutoSwitch"; def: true }
            SwRow { label: "Silenciar el micrófono"; checked: Audio.micMuted; onToggled: Audio.toggleMic() }
        }
    }
    ColumnLayout {
    id: rightCol
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    spacing: 12
    Section {
        id: apps
        Layout.fillWidth: true
        title: "Volumen por app"
        AudioStreams { Layout.fillWidth: true }
        Item { Layout.fillHeight: true; implicitHeight: 8 }
        Txt { muted: true; size: 11.5; text: "Toca una barra para ajustar · PipeWire + WirePlumber" }
    }
    Section {
        Layout.fillWidth: true
        title: "Perfiles de los dispositivos"
        headerRight: Button { kind: "outline"; h: 26; text: "Actualizar"; onClicked: root.loadCards() }
        Txt { visible: root.cards.length === 0; Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap; text: "Ningún dispositivo tiene perfiles para elegir." }
        Repeater {
            model: root.cards
            LabeledRow {
                id: cr
                required property var modelData
                label: modelData.label; labelWidth: 150
                hint: modelData.bt ? "Bluetooth" : ""
                Dropdown {
                    model: cr.modelData.profiles
                    current: cr.modelData.active
                    popupWidth: 300
                    onPicked: k => { Quickshell.execDetached(["pactl", "set-card-profile", cr.modelData.name, k]); cardsLater.restart(); }
                }
            }
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "En auriculares Bluetooth: «Alta calidad» para música; «Manos libres» activa su micrófono para llamadas."
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Sonidos del sistema"
        SwRow {
            separator: false
            label: "Sonidos del sistema"; sub: "avisos, pomodoro y sonidos de las apps (tema freedesktop)"
            key: "systemSounds"; def: true
            onToggled: v => Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.sound", "event-sounds", v ? "true" : "false"])
        }
        RowLayout {
            spacing: 4
            Button { kind: "outline"; h: 26; text: "Probar"; onClicked: Quickshell.execDetached(["sh", "-c", "canberra-gtk-play -i bell 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/bell.oga"]) }
            Txt { text: "·"; color: Theme.p }
            Button { kind: "link"; text: "Sonido de las notificaciones"; onClicked: Shell.open("ajustesapp", "notificaciones") }
        }
    }
    }
}
