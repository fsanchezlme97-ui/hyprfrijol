// Ajustes › Bluetooth — adaptador (encendido, visible, nombre con bluetoothctl system-alias), dispositivos
// emparejados (batería, conectar/desconectar, confiar, bloquear, enviar archivo, olvidar) y búsqueda de
// dispositivos nuevos con emparejamiento (Quickshell.Bluetooth; si el dispositivo pide PIN/código, se empareja
// en una terminal con el agente de bluetoothctl). Sin adaptador: estado del servicio, rfkill e instalación.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property var ad: Bt.adapter
    property bool weScan: false
    property string open: ""            // dirección del dispositivo desplegado
    property var sys: ({ svc: "", enabled: "", hw: false, soft: false, hard: false, bluez: true, sendto: "" })
    readonly property string sendto: sys.sendto ?? ""

    function probe() { probeProc.running = false; probeProc.running = true; }
    Process {
        id: probeProc
        running: true
        command: ["sh", "-c", "echo svc:$(systemctl is-active bluetooth 2>/dev/null); echo en:$(systemctl is-enabled bluetooth 2>/dev/null); "
            + "ls /sys/class/bluetooth 2>/dev/null | grep -q . && echo hw:yes; "
            + "rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' && echo rf:soft; rfkill list bluetooth 2>/dev/null | grep -q 'Hard blocked: yes' && echo rf:hard; "
            + "command -v bluetoothctl >/dev/null && echo has:bluez; for b in bluetooth-sendto blueman-sendto; do command -v $b >/dev/null && { echo send:$b; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n"), g = p => (l.find(x => x.startsWith(p)) ?? p).slice(p.length);
                root.sys = { svc: g("svc:"), enabled: g("en:"), hw: l.includes("hw:yes"), soft: l.includes("rf:soft"), hard: l.includes("rf:hard"), bluez: l.includes("has:bluez"), sendto: g("send:") };
            }
        }
    }
    Timer { id: reprobe; interval: 2500; onTriggered: root.probe() }

    function scan(on) {
        if (!ad) return;
        ad.discovering = on;
        weScan = on;
    }
    Component.onDestruction: if (weScan && ad) ad.discovering = false
    Timer { interval: 60000; running: root.weScan; onTriggered: root.scan(false) }   // no dejar la búsqueda encendida

    function pairInTerminal(addr) {
        Pkg.runInTerminal("bluetoothctl --agent KeyboardDisplay pair " + addr + " && bluetoothctl trust " + addr + " && bluetoothctl connect " + addr, "Emparejar Bluetooth");
    }
    function sendFile(addr) {
        if (sendto === "bluetooth-sendto") Quickshell.execDetached(["bluetooth-sendto", "--device=" + addr]);
        else if (sendto === "blueman-sendto") Quickshell.execDetached(["blueman-sendto", "--device=" + addr]);
    }
    function statusOf(d) {
        const st = d.state === BluetoothDeviceState.Connecting ? "Conectando…" : d.state === BluetoothDeviceState.Disconnecting ? "Desconectando…"
                 : d.connected ? "Conectado" : d.pairing ? "Emparejando…" : "Sin conectar";
        return st + (d.batteryAvailable ? " · batería " + Math.round(d.battery * 100) + " %" : "") + (d.blocked ? " · bloqueado" : "");
    }

    // ---------- sin adaptador ----------
    Section {
        visible: !Bt.available
        Layout.fillWidth: true
        title: "Bluetooth no disponible"
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: !root.sys.bluez ? "BlueZ (la pila Bluetooth de Linux) no está instalado."
                : root.sys.svc !== "active" ? "El servicio Bluetooth está detenido" + (root.sys.enabled === "enabled" ? "." : " y no arranca con el equipo.")
                : root.sys.hard ? "El Bluetooth está apagado por un interruptor del equipo o de la BIOS."
                : root.sys.soft ? "El Bluetooth está bloqueado por software (modo avión)."
                : "No se encontró ningún adaptador Bluetooth en este equipo."
        }
        Txt {
            visible: root.sys.bluez && root.sys.svc !== "active" && !root.sys.hw
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Tampoco se detecta hardware Bluetooth (/sys/class/bluetooth vacío). Si usas un adaptador USB, conéctalo y vuelve a comprobar."
        }
        RowLayout {
            spacing: 8
            Button {
                visible: !root.sys.bluez
                kind: "primary"; text: "Instalar BlueZ"
                onClicked: { Pkg.runInTerminal("sudo pacman -S --needed bluez bluez-utils && sudo systemctl enable --now bluetooth", "Bluetooth"); reprobe.restart(); }
            }
            Button {
                visible: root.sys.bluez && root.sys.svc !== "active"
                kind: "primary"; text: "Activar el servicio Bluetooth"
                onClicked: { Quickshell.execDetached(["pkexec", "systemctl", "enable", "--now", "bluetooth.service"]); reprobe.restart(); }
            }
            Button {
                visible: root.sys.soft && !root.sys.hard
                text: "Desbloquear (rfkill)"
                onClicked: { Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]); reprobe.restart(); }
            }
            Button { text: "Comprobar de nuevo"; onClicked: root.probe() }
        }
        Mono { Layout.fillWidth: true; text: "bluetooth.service: " + (root.sys.svc || "…") + " · " + (root.sys.enabled || "…") + " · adaptador: " + (root.sys.hw ? "sí" : "no") }
    }

    // ---------- con adaptador ----------
    RowLayout {
        visible: Bt.available
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                title: "Este equipo"
                headerRight: Sw { checked: Bt.enabled; onToggled: v => Bt.setEnabled(v) }
                LabeledRow {
                    label: "Nombre visible"; labelWidth: 120
                    Field {
                        id: nameField
                        icon: ""
                        h: 32
                        text: root.ad?.name ?? ""
                        placeholder: "Nombre del equipo · Enter para guardar"
                        onAccepted: { const n = text.trim(); if (n) Quickshell.execDetached(["bluetoothctl", "system-alias", n]); }
                    }
                }
                SwRow {
                    label: "Visible para otros dispositivos"
                    sub: root.ad?.discoverable ? "Otros equipos pueden encontrarte como «" + (root.ad?.name ?? "") + "»" : "Solo los dispositivos emparejados te ven"
                    enabled: Bt.enabled
                    checked: root.ad?.discoverable ?? false
                    onToggled: v => { if (root.ad) root.ad.discoverable = v; }
                }
                SwRow {
                    label: "Aceptar emparejamientos"
                    sub: "Permite que un dispositivo nuevo se empareje contigo"
                    enabled: Bt.enabled
                    checked: root.ad?.pairable ?? false
                    onToggled: v => { if (root.ad) root.ad.pairable = v; }
                }
                Mono { Layout.fillWidth: true; text: (root.ad?.adapterId ?? "") + " · " + (root.ad ? BluetoothAdapterState.toString(root.ad.state) : "") }
            }
            Section {
                Layout.fillWidth: true
                title: "Mis dispositivos"
                headerRight: Mono { text: Bt.paired.length + " emparejados" }
                Txt { visible: Bt.paired.length === 0; muted: true; text: "Aún no has emparejado ningún dispositivo." }
                Repeater {
                    model: Bt.paired
                    ColumnLayout {
                        id: pd
                        required property var modelData
                        required property int index
                        readonly property bool expanded: root.open === modelData.address
                        Layout.fillWidth: true
                        spacing: 0
                        Rectangle { visible: pd.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: Theme.r(6)
                            color: pm.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4; anchors.rightMargin: 4
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 34; implicitHeight: 34; radius: Theme.ctl(34)
                                    color: pd.modelData.connected ? Theme.pc : Theme.s4
                                    Icon { anchors.centerIn: parent; name: Bt.iconFor(pd.modelData); size: 16; color: pd.modelData.connected ? Theme.pcText : Theme.tv }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Txt { Layout.fillWidth: true; text: pd.modelData.name || pd.modelData.address; weight: Font.DemiBold }
                                    Txt { Layout.fillWidth: true; text: Bt.kindText(pd.modelData) + " · " + root.statusOf(pd.modelData); muted: true; size: 11.5 }
                                }
                                Button {
                                    text: pd.modelData.connected ? "Desconectar" : "Conectar"
                                    kind: pd.modelData.connected ? "outline" : "primary"
                                    enabled: Bt.enabled && pd.modelData.state !== BluetoothDeviceState.Connecting && pd.modelData.state !== BluetoothDeviceState.Disconnecting
                                    onClicked: pd.modelData.connected ? pd.modelData.disconnect() : pd.modelData.connect()
                                }
                                Icon { name: pd.expanded ? "chevron_up" : "chevron_down"; size: 14; color: Theme.tv }
                            }
                            MouseArea {
                                id: pm
                                anchors.fill: parent
                                anchors.rightMargin: 150
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.open = pd.expanded ? "" : pd.modelData.address
                            }
                        }
                        ColumnLayout {
                            visible: pd.expanded
                            Layout.fillWidth: true
                            Layout.leftMargin: 50
                            Layout.bottomMargin: 8
                            spacing: 0
                            SwRow { separator: false; label: "De confianza"; sub: "se conecta solo, sin pedir permiso"; checked: pd.modelData.trusted; onToggled: v => pd.modelData.trusted = v }
                            SwRow { label: "Bloquear"; sub: "rechaza cualquier conexión de este dispositivo"; checked: pd.modelData.blocked; onToggled: v => pd.modelData.blocked = v }
                            RowLayout {
                                Layout.topMargin: 8
                                spacing: 8
                                Button {
                                    visible: root.sendto !== ""
                                    text: "Enviar archivo…"
                                    enabled: pd.modelData.connected || /phone|computer/.test(pd.modelData.icon)
                                    onClicked: root.sendFile(pd.modelData.address)
                                }
                                ConfirmButton {
                                    text: "Olvidar"
                                    confirmText: "¿Olvidar «" + (pd.modelData.name || pd.modelData.address) + "»? Sí"
                                    onConfirmed: { root.open = ""; pd.modelData.forget(); }
                                }
                                Item { Layout.fillWidth: true }
                                Mono { text: pd.modelData.address }
                            }
                        }
                    }
                }
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Añadir un dispositivo"
            headerRight: Button {
                kind: root.ad?.discovering ? "outline" : "primary"
                text: root.ad?.discovering ? "Detener" : "Buscar"
                enabled: Bt.enabled
                onClicked: root.scan(!root.ad?.discovering)
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: !Bt.enabled ? "Enciende el Bluetooth para buscar dispositivos."
                    : root.ad?.discovering ? "Buscando… Pon el dispositivo en modo emparejamiento (suele ser mantener pulsado el botón de encendido o de Bluetooth)."
                    : "Pulsa Buscar y pon el dispositivo en modo emparejamiento."
            }
            Repeater {
                model: Bt.enabled ? Bt.discovered : []
                Rectangle {
                    id: nd
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Theme.r(6)
                    color: Theme.glassy ? Qt.alpha(Theme.t, 0.03) : Theme.s4
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: 12
                        Icon { name: Bt.iconFor(nd.modelData); size: 16; color: Theme.tv }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt { Layout.fillWidth: true; text: nd.modelData.deviceName; weight: Font.Medium }
                            Txt { Layout.fillWidth: true; text: nd.modelData.pairing ? "Emparejando… acepta en el dispositivo si te lo pide" : Bt.kindText(nd.modelData) + " · " + nd.modelData.address; muted: true; size: 11 }
                        }
                        Button {
                            visible: nd.modelData.pairing
                            text: "Cancelar"
                            onClicked: nd.modelData.cancelPair()
                        }
                        Button {
                            visible: !nd.modelData.pairing
                            kind: "primary"
                            text: "Emparejar"
                            onClicked: nd.modelData.pair()
                        }
                    }
                    // al terminar de emparejar: confiar y conectar
                    Connections {
                        target: nd.modelData
                        function onPairedChanged() { if (nd.modelData.paired) { nd.modelData.trusted = true; nd.modelData.connect(); } }
                    }
                }
            }
            Txt {
                visible: Bt.enabled && root.ad?.discovering && Bt.discovered.length === 0
                muted: true; text: "Aún no aparece nada…"
            }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 1; color: Theme.ov }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "¿El dispositivo pide un PIN o confirmar un código (teclados, algunos teléfonos)? Empareja en una terminal: bluetoothctl te mostrará el código."
            }
            RowLayout {
                spacing: 8
                Repeater {
                    model: Bt.enabled ? Bt.discovered.slice(0, 2) : []
                    Button {
                        required property var modelData
                        kind: "link"
                        text: "Emparejar «" + modelData.deviceName + "» en terminal"
                        onClicked: root.pairInTerminal(modelData.address)
                    }
                }
                Button {
                    visible: !Bt.enabled || Bt.discovered.length === 0
                    kind: "link"
                    text: "Abrir bluetoothctl"
                    onClicked: Pkg.runInTerminal("bluetoothctl --agent KeyboardDisplay", "Bluetooth")
                }
            }
        }
    }
}
