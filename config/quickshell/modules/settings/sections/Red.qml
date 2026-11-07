// Ajustes › Red — Wi-Fi (Net / nmcli), cortafuegos (ufw/firewalld), punto de acceso, conexión medida, DNS,
// VPN de NetworkManager de cualquier tipo (scripts/hf-vpn: WireGuard, OpenVPN, OpenConnect, L2TP, IKEv2…)
// y VPN en malla (Tailscale, ZeroTier).
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
    property string activeCon: ""
    property bool metered: false
    property string fw: ""           // "ufw" | "firewalld" | ""
    property bool fwOn: false
    property bool hotspot: false
    property string dns: "auto"
    property string pwFor: ""

    function refresh() { info.running = false; info.running = true; }
    Component.onCompleted: Net.scan()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
    Process {
        id: info
        running: true
        command: ["sh", "-c", "c=$(nmcli -t -f NAME,TYPE connection show --active | grep -vE ':(loopback|bridge|tun|wireguard|vpn)' | head -1 | cut -d: -f1); echo \"con:$c\"; "
            + "[ -n \"$c\" ] && echo \"met:$(nmcli -g connection.metered connection show \"$c\")\" && echo \"dns:$(nmcli -g ipv4.dns connection show \"$c\")\"; "
            + "nmcli -t -f NAME connection show --active | grep -qi hotspot && echo hot:yes; "
            + "if command -v ufw >/dev/null; then echo fw:ufw; systemctl is-active -q ufw && echo fwon:yes; elif command -v firewall-cmd >/dev/null; then echo fw:firewalld; systemctl is-active -q firewalld && echo fwon:yes; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.activeCon = (l.find(x => x.startsWith("con:")) ?? "con:").slice(4);
                root.metered = /yes/.test(l.find(x => x.startsWith("met:")) ?? "");
                const d = (l.find(x => x.startsWith("dns:")) ?? "dns:").slice(4);
                root.dns = !d ? "auto" : d.startsWith("1.1.1.1") ? "cf" : d.startsWith("9.9.9.9") ? "q9" : "custom";
                if (root.dns === "custom") customDns.text = d;
                root.hotspot = l.includes("hot:yes");
                root.fw = (l.find(x => x.startsWith("fw:")) ?? "fw:").slice(3);
                root.fwOn = l.includes("fwon:yes");
            }
        }
    }
    function setDns(k) {
        if (!activeCon) return;
        const v = k === "cf" ? "1.1.1.1 1.0.0.1" : k === "q9" ? "9.9.9.9 149.112.112.112" : k === "custom" ? customDns.text.trim() : "";
        Quickshell.execDetached(["sh", "-c", "nmcli connection modify \"$0\" ipv4.dns \"$1\" ipv4.ignore-auto-dns " + (v ? "yes" : "no") + " && nmcli connection up \"$0\"", activeCon, v]);
        dns = k;
        later.restart();
    }
    Timer { id: later; interval: 2500; onTriggered: { root.refresh(); Net.refresh(); vpn.refresh(); } }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            id: wifi
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Wi-Fi"
            headerRight: Sw { checked: Net.wifiEnabled; onToggled: v => { Net.setWifi(v); if (v) Net.scan(); } }
            Repeater {
                model: Net.wifiEnabled ? Net.networks.slice(0, 9) : []
                ColumnLayout {
                    id: nw
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Theme.r(6)
                        color: nw.modelData.active ? Theme.pc : ma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 12
                            Row {   // barras de señal
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 3; height: 4 + index * 3
                                        anchors.bottom: parent.bottom
                                        radius: 1
                                        color: nw.modelData.signal > index * 25 ? (nw.modelData.active ? Theme.pcText : Theme.t) : Theme.o
                                        opacity: nw.modelData.signal > index * 25 ? 1 : 0.4
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Txt { Layout.fillWidth: true; text: nw.modelData.ssid; weight: nw.modelData.active ? Font.DemiBold : Font.Normal; color: nw.modelData.active ? Theme.pcText : Theme.t }
                                Txt { visible: nw.modelData.active; text: "Conectada · " + nw.modelData.signal + " %"; size: 11.5; color: Theme.pcText; opacity: 0.8 }
                            }
                            Txt { text: nw.modelData.secure ? "Protegida" : "Abierta"; size: 11.5; color: nw.modelData.active ? Theme.pcText : Theme.tv }
                        }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (nw.modelData.active) Quickshell.execDetached(["nmcli", "connection", "down", "id", nw.modelData.ssid]);
                                else if (nw.modelData.secure) { root.pwFor = root.pwFor === nw.modelData.ssid ? "" : nw.modelData.ssid; Net.connect(nw.modelData.ssid, ""); }
                                else Net.connect(nw.modelData.ssid, "");
                                later.restart();
                            }
                        }
                    }
                    Field {
                        visible: root.pwFor === nw.modelData.ssid
                        Layout.fillWidth: true
                        icon: "lock"
                        placeholder: "Contraseña de «" + nw.modelData.ssid + "» (si no está guardada) · Enter"
                        input.echoMode: TextInput.Password
                        onAccepted: { Net.connect(nw.modelData.ssid, text); text = ""; root.pwFor = ""; }
                    }
                }
            }
            Txt { visible: !Net.wifiEnabled; muted: true; text: "Wi-Fi desactivado" }
            Txt { visible: Net.wifiEnabled && Net.networks.length === 0; muted: true; text: "Buscando redes…" }
            RowLayout {
                spacing: 4
                Button { kind: "link"; text: "+ Red oculta"; onClicked: Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && nm-connection-editor --create --type=802-11-wireless || " + Pkg.terminal + " -e nmtui-connect"]) }
                Txt { text: "·"; color: Theme.p }
                Button { kind: "link"; text: "Compartir con código QR"; onClicked: Pkg.runInTerminal("nmcli device wifi show-password", "Compartir Wi-Fi") }
                Txt { text: "·"; color: Theme.p }
                Button { kind: "link"; text: "Buscar de nuevo"; onClicked: Net.scan() }
            }
        }
        ColumnLayout {
            id: side
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                SwRow {
                    separator: false
                    label: "Cortafuegos"
                    sub: root.fw === "ufw" ? "ufw · bloquea conexiones entrantes no permitidas" : root.fw === "firewalld" ? "firewalld" : "ni ufw ni firewalld instalados"
                    enabled: root.fw !== ""
                    checked: root.fwOn
                    onToggled: v => { Quickshell.execDetached(["pkexec", "sh", "-c", root.fw === "ufw" ? (v ? "systemctl enable --now ufw && ufw --force enable" : "ufw disable && systemctl disable --now ufw") : (v ? "systemctl enable --now firewalld" : "systemctl disable --now firewalld")]); later.restart(); }
                }
                SwRow {
                    label: "Compartir conexión"; sub: "punto de acceso Wi-Fi con el nombre de tu equipo"
                    checked: root.hotspot
                    onToggled: v => { Quickshell.execDetached(v ? ["sh", "-c", "nmcli device wifi hotspot ssid \"$(hostname)-hl\" password \"$(head -c 6 /dev/urandom | base64 | tr -dc a-zA-Z0-9 | head -c 10)\" && nmcli device wifi show-password | notify-send -a Red 'Punto de acceso activo' \"$(cat)\""] : ["sh", "-c", "nmcli connection down Hotspot"]); later.restart(); }
                }
                SwRow {
                    label: "Conexión medida"; sub: "pausa actualizaciones y sincronización · " + (root.activeCon || "sin conexión")
                    enabled: root.activeCon !== ""
                    checked: root.metered
                    onToggled: v => { Quickshell.execDetached(["nmcli", "connection", "modify", root.activeCon, "connection.metered", v ? "yes" : "no"]); root.metered = v; }
                }
            }
            Section {
                Layout.fillWidth: true
                title: "DNS"
                Seg {
                    Layout.fillWidth: true
                    model: [["auto", "Automático"], ["cf", "Cloudflare"], ["q9", "Quad9"], ["custom", "Propio"]]
                    current: root.dns
                    onPicked: k => { if (k === "custom") { root.dns = "custom"; customDns.focusInput(); } else root.setDns(k); }
                }
                Field { id: customDns; visible: root.dns === "custom"; Layout.fillWidth: true; icon: ""; placeholder: "Servidores separados por espacios · Enter para aplicar"; onAccepted: root.setDns("custom") }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                    text: (root.dns === "auto" ? "Usa el DNS que da tu router." : root.dns === "cf" ? "1.1.1.1 · rápido y privado." : root.dns === "q9" ? "9.9.9.9 · bloquea dominios maliciosos." : "Tus propios servidores.")
                        + (root.activeCon ? " Se aplica a «" + root.activeCon + "»." : "")
                }
            }
        }
    }

    VpnSection { id: vpn; Layout.fillWidth: true }
    MeshSection { Layout.fillWidth: true }

    // ---------- VPN (scripts/hf-vpn) ----------
    component VpnSection: Section {
        id: vs
        title: "VPN"
        readonly property string cmd: Paths.script("hf-vpn")
        property var conns: []          // hf-vpn list
        property var types: []          // hf-vpn plugins (sin el editor)
        property bool editor: false     // nm-connection-editor instalado
        property string editorPkg: "nm-connection-editor"
        property bool adding: false
        property string addType: ""
        property string busy: ""        // uuid que está conectando/desconectando
        property string confirmDel: ""
        property string msg: ""
        readonly property var cur: types.find(t => t.key === addType) ?? null
        readonly property var kindLabel: ({ wireguard: "WireGuard", openvpn: "OpenVPN", openconnect: "OpenConnect", fortisslvpn: "Fortinet SSL",
            l2tp: "L2TP/IPsec", strongswan: "IPsec IKEv2", pptp: "PPTP", sstp: "SSTP", vpnc: "Cisco VPNC", libreswan: "IPsec (Libreswan)" })
        readonly property var protoLabel: ({ anyconnect: "Cisco AnyConnect", gp: "GlobalProtect", pulse: "Pulse Secure", nc: "Juniper", fortinet: "Fortinet", f5: "F5", array: "Array" })

        function refresh() { listProc.running = false; listProc.running = true; }
        function reloadTypes() { plugProc.running = false; plugProc.running = true; }
        function run(args, then) { act.command = [cmd].concat(args); act.then = then ?? ""; act.running = true; }

        Timer { interval: 5000; running: true; repeat: true; onTriggered: vs.refresh() }
        Timer { id: soon; interval: 1500; onTriggered: { vs.busy = ""; vs.refresh(); } }
        Timer { id: typesLater; interval: 12000; repeat: true; property int left: 0; onTriggered: { vs.reloadTypes(); if (--left <= 0) stop(); } }
        Process {
            id: listProc
            running: true
            command: [vs.cmd, "list"]
            stdout: StdioCollector { onStreamFinished: vs.conns = text.split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(Boolean) }
        }
        Process {
            id: plugProc
            running: true
            command: [vs.cmd, "plugins"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const all = text.split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(Boolean);
                    const ed = all.find(t => t.key === "editor");
                    vs.editor = !!ed?.installed; vs.editorPkg = ed?.pkg ?? "nm-connection-editor";
                    vs.types = all.filter(t => t.key !== "editor");
                }
            }
        }
        Process {
            id: act
            property string then: ""
            stdout: StdioCollector { id: actOut }
            stderr: StdioCollector { id: actErr }
            onExited: code => {
                vs.msg = code === 0 ? (act.then || "") : (actErr.text || actOut.text).trim().split("\n").pop();
                if (code === 0 && act.then) { vs.adding = false; vs.addType = ""; }
                soon.restart();
            }
        }
        function install(key) {
            Pkg.runInTerminal(cmd + " install " + key, "Instalar VPN");
            typesLater.left = 10; typesLater.restart();
        }

        headerRight: [
            Button { text: "Importar archivo…"; onClicked: vs.run(["import"], "VPN importada") },
            Button { kind: vs.adding ? "outline" : "primary"; text: vs.adding ? "Cancelar" : "+ Añadir VPN"; onClicked: { vs.adding = !vs.adding; vs.addType = ""; vs.msg = ""; } }
        ]

        // ---------- conexiones ----------
        Txt {
            visible: vs.conns.length === 0 && !vs.adding
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            muted: true
            text: "No tienes ninguna VPN. Importa el archivo que te dio tu proveedor o tu empresa (.ovpn de OpenVPN, .conf de WireGuard, .pcf de Cisco…) o añádela a mano por tipo."
        }
        Repeater {
            model: vs.conns
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: modelData.active
                readonly property bool working: vs.busy === modelData.uuid
                Layout.fillWidth: true
                implicitHeight: 52
                Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.ov }
                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    spacing: 12
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34
                        radius: Theme.r(8)
                        color: row.on ? Theme.pc : Theme.s4
                        Icon { anchors.centerIn: parent; name: row.modelData.type === "wireguard" ? "key" : "shield"; size: 16; color: row.on ? Theme.pcText : Theme.tv }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: row.modelData.name; weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            muted: true; size: 11.5
                            text: (row.modelData.proto ? (vs.protoLabel[row.modelData.proto] ?? row.modelData.proto) : (vs.kindLabel[row.modelData.kind] ?? row.modelData.kind))
                                + " · " + (row.working ? (row.on ? "desconectando…" : "conectando…") : row.on ? "conectada" + (row.modelData.device ? " · " + row.modelData.device : "") : "desconectada")
                        }
                    }
                    Button { kind: "link"; text: "Editar"; onClicked: vs.run(["edit", row.modelData.uuid]) }
                    Txt { text: "·"; color: Theme.p }
                    Button {
                        kind: "link"
                        text: vs.confirmDel === row.modelData.uuid ? "¿Seguro? Eliminar" : "Eliminar"
                        onClicked: {
                            if (vs.confirmDel !== row.modelData.uuid) { vs.confirmDel = row.modelData.uuid; return; }
                            vs.confirmDel = ""; vs.run(["delete", row.modelData.uuid]);
                        }
                    }
                    Sw {
                        Layout.leftMargin: 6
                        checked: row.on
                        enabled: !row.working
                        onToggled: v => { vs.busy = row.modelData.uuid; vs.run([v ? "up" : "down", row.modelData.uuid]); }
                    }
                }
            }
        }
        Txt { visible: vs.msg !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.p; text: vs.msg }

        // ---------- añadir ----------
        ColumnLayout {
            visible: vs.adding
            Layout.fillWidth: true
            spacing: 10
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov; visible: vs.conns.length > 0 }
            Txt { text: "Tipo de VPN"; muted: true; size: 11.5 }
            GridLayout {
                Layout.fillWidth: true
                columns: vs.width > 760 ? 4 : 3
                columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: vs.types
                    Card {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        h: 60
                        title: modelData.label
                        sub: modelData.installed ? modelData.desc : "Sin instalar · falta el plugin" + (modelData.aur ? " (AUR)" : "")
                        selected: vs.addType === modelData.key
                        onClicked: { vs.addType = modelData.key; vs.msg = ""; nameF.text = ""; hostF.text = ""; userF.text = ""; }
                    }
                }
            }

            // tipo elegido sin plugin → instalar
            RowLayout {
                visible: vs.cur !== null && !vs.cur.installed
                Layout.fillWidth: true
                spacing: 10
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: vs.cur ? "Para conectarte a una VPN " + vs.cur.label + " hace falta el plugin de NetworkManager «" + vs.cur.pkg + "»"
                        + (vs.cur.aur ? ", que está en AUR." : ".") + (vs.editor ? "" : " También se instala el editor de conexiones.") : ""
                }
                Button { kind: "primary"; text: "Instalar"; onClicked: vs.install(vs.cur.key) }
            }

            // WireGuard: importar o editor
            RowLayout {
                visible: vs.cur !== null && vs.cur.installed && vs.cur.key === "wireguard"
                Layout.fillWidth: true
                spacing: 10
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Lo normal es importar el .conf que te da tu servidor (o tu proveedor: Mullvad, Proton, tu router…). También puedes crearla a mano." }
                Button { kind: "primary"; text: "Importar .conf…"; onClicked: vs.run(["import", "", "wireguard"], "VPN importada") }
                Button { text: vs.editor ? "Crear a mano" : "Instalar editor"; onClicked: vs.editor ? vs.run(["create", "wireguard"]) : vs.install("editor") }
            }

            // resto: formulario rápido
            ColumnLayout {
                visible: vs.cur !== null && vs.cur.installed && vs.cur.key !== "wireguard"
                Layout.fillWidth: true
                spacing: 8
                LabeledRow { label: "Nombre"; Field { id: nameF; icon: ""; placeholder: vs.cur ? "VPN " + vs.cur.label : "" } }
                LabeledRow { label: "Servidor"; Field { id: hostF; icon: ""; placeholder: "vpn.empresa.com o dirección IP" } }
                LabeledRow { label: "Usuario"; Field { id: userF; icon: ""; placeholder: "opcional · la contraseña se pide al conectar" } }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 130
                    spacing: 10
                    Button {
                        kind: "primary"; text: "Crear"
                        enabled: hostF.text.trim() !== ""
                        onClicked: vs.run(["add", vs.cur.key, nameF.text.trim() || nameF.placeholder, hostF.text.trim(), userF.text.trim()], "VPN creada · edítala para certificados u otras opciones")
                    }
                    Button { kind: "link"; text: vs.editor ? "Opciones avanzadas en el editor" : "Instalar el editor para más opciones"; onClicked: vs.editor ? vs.run(["create", vs.cur.key]) : vs.install("editor") }
                    Item { Layout.fillWidth: true }
                }
            }
            Txt {
                visible: vs.addType === ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                text: "Todas usan NetworkManager, así que también funcionan con nmcli y se pueden conectar solas al arrancar (opción del editor). OpenConnect cubre AnyConnect, GlobalProtect, Pulse y Fortinet."
            }
        }
    }

    // ---------- VPN en malla ----------
    component MeshSection: Section {
        id: ms
        title: "VPN en malla"
        headerRight: Mono { text: "tailscale · zerotier-cli" }
        readonly property string cmd: Paths.script("hf-vpn")
        property var ts: ({ installed: false })
        property var zt: ({ installed: false, networks: [] })
        property bool tsBusy: false

        function refresh() { mesh.running = false; mesh.running = true; }
        function term(args, title) { Pkg.runInTerminal(cmd + " " + args, title); later.restart(); }
        Timer { interval: 8000; running: true; repeat: true; onTriggered: ms.refresh() }
        Timer { id: later; interval: 6000; repeat: true; property int n: 0; onTriggered: { ms.refresh(); if (++n > 8) { n = 0; stop(); } } }
        Process {
            id: mesh
            running: true
            command: [ms.cmd, "mesh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    for (const l of text.split("\n").filter(Boolean)) {
                        try { const j = JSON.parse(l); if (j.key === "tailscale") ms.ts = j; else ms.zt = j; } catch (e) {}
                    }
                    ms.tsBusy = false;
                }
            }
        }

        // ---------- Tailscale ----------
        InfoRow {
            id: tsRow
            separator: false
            label: "Tailscale"
            glyph: "TS"
            readonly property string st: ms.ts.state ?? ""
            lit: st === "Running"
            sub: !ms.ts.installed ? "Red privada entre tus equipos, sin abrir puertos · WireGuard por debajo"
                : ms.ts.service !== "active" ? "El servicio tailscaled está detenido"
                : st === "Running" ? "Conectado · " + ms.ts.ip + (ms.ts.network ? " · " + ms.ts.network : "") + " · " + (ms.ts.peers || 0) + " equipos en línea"
                : st === "NeedsLogin" || st === "NoState" ? "Falta iniciar sesión con tu cuenta"
                : st === "Starting" ? "Conectando…" : "Desconectado"
            Button { visible: !ms.ts.installed; kind: "primary"; text: "Instalar"; onClicked: ms.term("install tailscale", "Instalar Tailscale") }
            Button { visible: ms.ts.installed && ms.ts.service !== "active"; text: "Activar servicio"; onClicked: { Pkg.runInTerminal("sudo systemctl enable --now tailscaled && sudo tailscale set --operator=$USER", "Tailscale"); later.restart(); } }
            Button { visible: ms.ts.installed && ms.ts.service === "active" && (tsRow.st === "NeedsLogin" || tsRow.st === "NoState"); kind: "primary"; text: "Iniciar sesión"; onClicked: ms.term("tailscale up", "Tailscale") }
            Button { visible: ms.ts.installed && ms.ts.service === "active"; kind: "link"; text: "Equipos"; onClicked: Quickshell.execDetached([ms.cmd, "tailscale", "admin"]) }
            Sw {
                visible: ms.ts.installed && ms.ts.service === "active" && ["Running", "Stopped", "Starting"].includes(tsRow.st)
                checked: tsRow.st === "Running" || tsRow.st === "Starting"
                enabled: !ms.tsBusy
                onToggled: v => { ms.tsBusy = true; Quickshell.execDetached([ms.cmd, "tailscale", v ? "up" : "down"]); later.restart(); }
            }
        }
        // Nodo de salida: sacar todo el tráfico a Internet por otro equipo de la red (tailscale set --exit-node)
        RowLayout {
            visible: tsRow.st === "Running" && (ms.ts.exitNodes ?? []).length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 46
            spacing: 10
            Txt { Layout.fillWidth: true; text: "Nodo de salida"; size: 12.5; weight: Font.Medium }
            Txt { visible: !!ms.ts.exitNode; text: "el tráfico sale por " + ms.ts.exitNode; muted: true; size: 11.5 }
            Dropdown {
                Layout.preferredWidth: 220
                model: [["none", "Ninguno (conexión directa)"]].concat((ms.ts.exitNodes ?? []).map(n => [n.ip, n.name + (n.online ? "" : " · desconectado")]))
                current: ((ms.ts.exitNodes ?? []).find(n => n.active) ?? { ip: "none" }).ip
                onPicked: k => { ms.tsBusy = true; Quickshell.execDetached([ms.cmd, "tailscale", "exit", k]); later.restart(); }
            }
        }

        // ---------- ZeroTier ----------
        InfoRow {
            id: ztRow
            label: "ZeroTier"
            glyph: "ZT"
            readonly property var nets: ms.zt.networks ?? []
            lit: ms.zt.state === "ONLINE" && nets.some(n => n.status === "OK")
            sub: !ms.zt.installed ? "Redes virtuales de nivel 2 entre equipos · con tu propio controlador o my.zerotier.com"
                : ms.zt.service !== "active" ? "El servicio zerotier-one está detenido"
                : ms.zt.state === "NOAUTH" ? "Tu usuario no puede leer el estado (falta el token de zerotier-cli)"
                : (ms.zt.state === "ONLINE" ? "En línea" : "Sin conexión") + " · " + (nets.length === 1 ? "1 red" : nets.length + " redes")
            Button { visible: !ms.zt.installed; kind: "primary"; text: "Instalar"; onClicked: ms.term("install zerotier", "Instalar ZeroTier") }
            Button { visible: ms.zt.installed && ms.zt.service !== "active"; text: "Activar servicio"; onClicked: { Pkg.runInTerminal("sudo systemctl enable --now zerotier-one", "ZeroTier"); later.restart(); } }
            Button {
                visible: ms.zt.installed && ms.zt.service === "active" && ms.zt.state === "NOAUTH"
                text: "Dar permiso"
                onClicked: { Pkg.runInTerminal("sudo install -m 600 -o $USER /var/lib/zerotier-one/authtoken.secret ~/.zeroTierOneAuthToken", "ZeroTier"); later.restart(); }
            }
        }
        Repeater {
            model: ms.zt.service === "active" ? ztRow.nets : []
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 46
                spacing: 10
                Mono { text: modelData.id }
                Txt { Layout.fillWidth: true; text: (modelData.name || "sin nombre") + " · " + (modelData.status === "OK" ? (modelData.ip || "conectada") : modelData.status === "ACCESS_DENIED" ? "falta autorizarte en el controlador" : modelData.status.toLowerCase()); size: 12 }
                Button { kind: "link"; text: "Salir"; onClicked: ms.term("zerotier leave " + modelData.id, "ZeroTier") }
            }
        }
        RowLayout {
            visible: ms.zt.installed && ms.zt.service === "active"
            Layout.fillWidth: true
            Layout.leftMargin: 46
            spacing: 8
            Field { id: ztId; Layout.fillWidth: true; icon: ""; placeholder: "ID de red (16 caracteres) · Enter para unirte"; onAccepted: join() ; function join() { if (/^[0-9a-f]{16}$/i.test(text.trim())) { ms.term("zerotier join " + text.trim(), "ZeroTier"); text = ""; } } }
            Button { text: "Unirse"; enabled: /^[0-9a-f]{16}$/i.test(ztId.text.trim()); onClicked: ztId.join() }
        }
    }
}
