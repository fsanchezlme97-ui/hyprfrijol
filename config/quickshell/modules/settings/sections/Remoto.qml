// Ajustes › Escritorio remoto — conexiones guardadas (remoteHosts: RDP, VNC, SSH, SPICE) y compartir este escritorio
// por VNC (wayvnc) o por RDP (hypr-rdp: entrar desde Windows con mstsc). Lógica en scripts/hf-remote. RDP «Automático»: Remmina (el más compatible con Windows) › FreeRDP 3
// (el más rápido, sin interfaz) › GNOME Conexiones (sencillo, sin puerta de enlace).
// Las contraseñas nunca van a settings.json: el cliente las pide o se guardan en el llavero (secret-tool).
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
    // app: true → la app «Conexiones remotas» (modules/apps): solo las conexiones. En Ajustes, el resto y un botón.
    property bool app: false
    readonly property string cmd: Paths.script("hf-remote")
    readonly property var hosts: Settings.get("remoteHosts", [])
    property var cl: ({ freerdp: "", remmina: false, remminaRdp: false, rdpAuto: "", connections: false, vncviewer: false, remoteviewer: false, secret: false, wayvnc: false })
    readonly property var clientName: ({ remmina: "Remmina", freerdp: "FreeRDP", connections: "Conexiones" })
    property var srv: ({ installed: false, running: false, auth: false, ips: [], port: 5900, clients: 0, firewall: "" })
    property var rdp: ({ installed: false, running: false, password: false, listen: "tailscale", addr: "", port: 3389, output: "", user: "", tailscale: false, firewall: "" })
    // Escuchar en la red exige contraseña: sin ella hf-remote se queda en 127.0.0.1 (ver scripts/hf-remote)
    readonly property bool wantsNet: Settings.get("vncListen", "127.0.0.1") !== "127.0.0.1"
    readonly property bool onNet: wantsNet && srv.auth
    property bool pendingNet: false     // pidió «Toda la red» sin contraseña: se aplica cuando la ponga
    onSrvChanged: if (pendingNet && srv.auth) { pendingNet = false; Settings.set("vncListen", "0.0.0.0"); if (srv.running) Quickshell.execDetached([cmd, "server", "restart"]); }
    function askPassword() { Pkg.runInTerminal(root.cmd + " server auth \"$USER\"", "Contraseña de VNC"); later.restart(); }
    property var secrets: ({})          // nombre → hay contraseña en el llavero
    property int editing: -2            // -2 nada · -1 nueva · n editar hosts[n]
    property string confirmDel: ""
    property var form: ({})
    readonly property var protoName: ({ rdp: "RDP", vnc: "VNC", ssh: "SSH", spice: "SPICE" })
    readonly property var defPort: ({ rdp: 3389, vnc: 5900, ssh: 22, spice: 5900 })

    function refresh() { clProc.running = false; clProc.running = true; srvProc.running = false; srvProc.running = true; secProc.running = false; secProc.running = true; }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: { srvProc.running = false; srvProc.running = true; rdpProc.running = false; rdpProc.running = true; adProc.running = false; adProc.running = true; } }
    Timer { id: later; interval: 5000; repeat: true; property int n: 0; onTriggered: { root.refresh(); if (++n > 10) { n = 0; stop(); } } }
    Process { id: clProc; running: true; command: [root.cmd, "clients"]; stdout: StdioCollector { onStreamFinished: { try { root.cl = JSON.parse(text); } catch (e) {} } } }
    Process { id: srvProc; running: true; command: [root.cmd, "server", "status"]; stdout: StdioCollector { onStreamFinished: { try { root.srv = JSON.parse(text); } catch (e) {} } } }
    Process { id: rdpProc; running: !root.app; command: [root.cmd, "rdp", "status"]; stdout: StdioCollector { onStreamFinished: { try { root.rdp = JSON.parse(text); } catch (e) {} } } }
    property var ad: ({})
    Process { id: adProc; running: !root.app; command: [root.cmd, "rustdesk", "status"]; stdout: StdioCollector { onStreamFinished: { try { root.ad = JSON.parse(text); } catch (e) {} } } }
    function rdpRestart() { if (root.rdp.running) Quickshell.execDetached([root.cmd, "rdp", "restart"]); later.restart(); }
    Process {
        id: secProc
        running: true
        command: ["sh", "-c", "command -v secret-tool >/dev/null || exit 0; for n in \"$@\"; do { secret-tool lookup service hyprfrijol-remote host \"$n\" || secret-tool lookup service hypr-liquid-remote host \"$n\"; } >/dev/null 2>&1 && echo \"$n\"; done", "sh"].concat(root.hosts.map(h => h.name))
        stdout: StdioCollector { onStreamFinished: { const o = {}; text.split("\n").filter(Boolean).forEach(n => o[n] = true); root.secrets = o; } }
    }

    // Comando de instalación según la distro (Pkg.family): { arch, debian, fedora, suse, flatpak }
    function install(p, title) {
        const f = Pkg.family;
        let c = p[f] ? (f === "arch" ? (Pkg.aur ? Pkg.aur + " -S --needed " : "sudo pacman -S --needed ") : f === "debian" ? "sudo apt install " : f === "fedora" ? "sudo dnf install " : "sudo zypper install ") + p[f] : "";
        if (!c && p.flatpak) c = "flatpak install -y flathub " + p.flatpak;
        Pkg.runInTerminal(c || "echo 'No sé instalarlo en esta distro'", title);
        later.restart();
    }
    function startEdit(i) {
        const h = i >= 0 ? root.hosts[i] : { name: "", proto: "rdp", host: "", port: null, user: "", domain: "", opts: { dynamicRes: true, sound: true, clipboard: true } };
        form = JSON.parse(JSON.stringify(h));
        form.opts = form.opts ?? {};
        editing = i;
        nameF.text = form.name ?? ""; hostF.text = form.host ?? ""; portF.text = form.port ? String(form.port) : "";
        userF.text = form.user ?? ""; domF.text = form.domain ?? ""; gwF.text = form.opts.gateway ?? "";
    }
    function setForm(k, v) { const f = Object.assign({}, form); f[k] = v; form = f; }
    function setOpt(k, v) { const f = Object.assign({}, form); f.opts = Object.assign({}, f.opts ?? {}); f.opts[k] = v; form = f; }
    function save() {
        const h = Object.assign({}, form);
        h.host = hostF.text.trim(); if (!h.host) return;
        h.name = nameF.text.trim() || h.host;
        h.port = parseInt(portF.text) || null;
        h.user = userF.text.trim(); h.domain = h.proto === "rdp" ? domF.text.trim() : "";
        h.opts = Object.assign({}, h.opts ?? {});
        if (h.proto === "rdp" && gwF.text.trim()) h.opts.gateway = gwF.text.trim(); else delete h.opts.gateway;
        const list = root.hosts.slice();
        if (editing >= 0) list[editing] = h; else list.push(h);
        Settings.set("remoteHosts", list);
        editing = -2;
    }
    function remove(i) { const list = root.hosts.slice(); list.splice(i, 1); Settings.set("remoteHosts", list); }
    function quick(t) {
        t = t.trim(); if (!t) return;
        Quickshell.execDetached([cmd, "connect", t.includes("://") ? t : "rdp://" + t]);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        // ================= izquierda: conectarse =================
        ColumnLayout {
            id: left
            visible: root.app
            Layout.fillWidth: true
            Layout.preferredWidth: 1.3
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                title: "Conectarse a otro equipo"
                headerRight: Button { kind: root.editing === -1 ? "outline" : "primary"; text: root.editing === -1 ? "Cancelar" : "+ Nueva conexión"; onClicked: root.editing === -1 ? root.editing = -2 : root.startEdit(-1) }
                Field {
                    id: quickF
                    Layout.fillWidth: true
                    icon: "external"
                    placeholder: "Conexión rápida: equipo o rdp://usuario@equipo, vnc://, ssh:// · Enter"
                    onAccepted: { root.quick(text); text = ""; }
                }
                Txt {
                    visible: root.hosts.length === 0 && root.editing === -2
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true
                    text: "Guarda los equipos a los que te conectas a menudo: Windows por RDP, otro Linux o un Mac por VNC, servidores por SSH y máquinas virtuales por SPICE."
                }
                Repeater {
                    model: root.hosts
                    InfoRow {
                        id: hr
                        required property var modelData
                        required property int index
                        label: modelData.name
                        glyph: root.protoName[modelData.proto] ?? "?"
                        sub: (modelData.user ? (modelData.domain ? modelData.domain + "\\" : "") + modelData.user + "@" : "") + modelData.host
                            + (modelData.port ? ":" + modelData.port : "")
                            + (modelData.proto === "rdp" && modelData.opts?.gateway ? " · vía " + modelData.opts.gateway : "")
                            + (root.secrets[modelData.name] ? " · contraseña en el llavero" : "")
                        Button { kind: "link"; text: "Editar"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.startEdit(hr.index) }
                        Txt { text: "·"; color: Theme.p; anchors.verticalCenter: parent.verticalCenter }
                        Button {
                            kind: "link"; anchors.verticalCenter: parent.verticalCenter
                            text: root.confirmDel === hr.modelData.name ? "¿Seguro? Eliminar" : "Eliminar"
                            onClicked: { if (root.confirmDel !== hr.modelData.name) root.confirmDel = hr.modelData.name; else { root.confirmDel = ""; root.remove(hr.index); } }
                        }
                        Button { kind: "primary"; text: "Conectar"; onClicked: Quickshell.execDetached([root.cmd, "connect", hr.modelData.name]) }
                    }
                }

                // ---------- formulario ----------
                ColumnLayout {
                    visible: root.editing > -2
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                    Txt { text: root.editing === -1 ? "Nueva conexión" : "Editar «" + (root.form.name ?? "") + "»"; weight: Font.DemiBold }
                    LabeledRow {
                        label: "Protocolo"
                        Seg {
                            model: [["rdp", "RDP"], ["vnc", "VNC"], ["ssh", "SSH"], ["spice", "SPICE"]]
                            current: root.form.proto ?? "rdp"
                            onPicked: k => root.setForm("proto", k)
                        }
                    }
                    LabeledRow { label: "Nombre"; Field { id: nameF; icon: ""; placeholder: "Oficina, PC del salón…" } }
                    LabeledRow {
                        label: "Equipo"
                        RowLayout {
                            spacing: 8
                            Field { id: hostF; Layout.fillWidth: true; icon: ""; placeholder: "nombre o dirección IP" }
                            Field { id: portF; Layout.preferredWidth: 90; icon: ""; placeholder: String(root.defPort[root.form.proto ?? "rdp"]); input.validator: IntValidator { bottom: 1; top: 65535 } }
                        }
                    }
                    LabeledRow {
                        label: "Usuario"
                        RowLayout {
                            spacing: 8
                            Field { id: userF; Layout.fillWidth: true; icon: ""; placeholder: root.form.proto === "vnc" ? "normalmente no hace falta" : "usuario" }
                            Field { id: domF; visible: root.form.proto === "rdp"; Layout.preferredWidth: 150; icon: ""; placeholder: "dominio (opcional)" }
                        }
                    }
                    LabeledRow {
                        visible: root.form.proto === "rdp"
                        label: "Puerta de enlace"
                        Field { id: gwF; icon: ""; placeholder: "RD Gateway, p. ej. gw.empresa.com (opcional)" }
                    }
                    LabeledRow {
                        visible: root.form.proto === "rdp" || root.form.proto === "vnc"
                        label: "Opciones"
                        Flow {
                            spacing: 6
                            Repeater {
                                model: root.form.proto === "rdp"
                                    ? [["fullscreen", "Pantalla completa", false], ["multimon", "Varias pantallas", false], ["dynamicRes", "Ajustar resolución", true], ["sound", "Sonido", true], ["clipboard", "Portapapeles", true], ["drives", "Carpeta personal", false]]
                                    : [["fullscreen", "Pantalla completa", false]]
                                Chip {
                                    required property var modelData
                                    text: modelData[1]
                                    on: (root.form.opts ?? {})[modelData[0]] ?? modelData[2]
                                    onClicked: root.setOpt(modelData[0], !on)
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 130
                        spacing: 10
                        Button { kind: "primary"; text: "Guardar"; enabled: hostF.text.trim() !== ""; onClicked: root.save() }
                        Button { text: "Cancelar"; onClicked: root.editing = -2 }
                        Item { Layout.fillWidth: true }
                        Button {
                            visible: root.cl.secret && root.form.proto !== "ssh" && (nameF.text.trim() || hostF.text.trim()) !== ""
                            kind: "link"
                            text: root.secrets[nameF.text.trim() || hostF.text.trim()] ? "Cambiar la contraseña guardada" : "Guardar contraseña en el llavero"
                            onClicked: { Pkg.runInTerminal(root.cmd + " secret set " + JSON.stringify(nameF.text.trim() || hostF.text.trim()), "Contraseña"); later.restart(); }
                        }
                    }
                    Txt {
                        Layout.fillWidth: true; Layout.leftMargin: 130; wrapMode: Text.WordWrap; muted: true; size: 11.5
                        text: "La contraseña no se guarda en los ajustes: si no está en el llavero, la pide el cliente al conectar."
                            + (root.form.proto === "rdp" ? " El certificado del equipo se acepta la primera vez y se vigila después (/cert:tofu)." : "")
                    }
                }
            }
        }

        // ================= derecha: clientes =================
        ColumnLayout {
            id: right
            visible: !root.app
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                title: "Conexiones guardadas"
                headerRight: Button { kind: "primary"; text: "Abrir Conexiones remotas"; onClicked: Shell.open("remoto") }
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 12
                    text: (root.hosts.length ? (root.hosts.length === 1 ? "1 conexión guardada" : root.hosts.length + " conexiones guardadas") : "Ninguna conexión guardada")
                        + ". Conectarse, añadir y editar está en su propia app (también en el menú de apps y en Spotlight)."
                }
            }
            Section {
                Layout.fillWidth: true
                title: "Clientes"
                InfoRow {
                    separator: false
                    label: "Remmina"; glyph: "R"; lit: root.cl.remmina && root.cl.remminaRdp
                    badge: "Recomendado para Windows"; badgeStrong: true
                    sub: !root.cl.remmina ? "RD Gateway, varias pantallas, carpetas, impresoras, sonido y NLA"
                        : root.cl.remminaRdp ? "Instalado · RD Gateway, varias pantallas, carpetas y sonido"
                        : "Instalado sin el plugin RDP: no conecta con Windows"
                    Button { visible: root.cl.remmina && root.cl.remminaRdp; kind: "link"; text: "Abrir"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["sh", "-c", "command -v remmina >/dev/null && exec remmina || exec flatpak run org.remmina.Remmina"]) }
                    Button {
                        visible: !root.cl.remmina || !root.cl.remminaRdp; text: root.cl.remmina ? "Instalar plugin" : "Instalar"
                        onClicked: root.install({ arch: "remmina freerdp libvncserver", debian: "remmina remmina-plugin-rdp remmina-plugin-vnc", fedora: "remmina remmina-plugins-rdp remmina-plugins-vnc", suse: "remmina remmina-plugin-rdp remmina-plugin-vnc", flatpak: "org.remmina.Remmina" }, "Remmina")
                    }
                }
                InfoRow {
                    label: "Conexiones"; glyph: "G"; lit: root.cl.connections
                    badge: "La más sencilla; sin puerta de enlace"
                    sub: root.cl.connections ? "Instalado · RDP y VNC básicos, la interfaz más limpia" : "El cliente de GNOME: RDP y VNC básicos, sin RD Gateway"
                    Button { visible: root.cl.connections; kind: "link"; text: "Abrir"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["gnome-connections"]) }
                    Button { visible: !root.cl.connections; text: "Instalar"; onClicked: root.install({ arch: "gnome-connections", debian: "gnome-connections", fedora: "gnome-connections", suse: "gnome-connections", flatpak: "org.gnome.Connections" }, "Conexiones") }
                }
                InfoRow {
                    label: "FreeRDP 3"; glyph: "RDP"; lit: root.cl.freerdp !== ""
                    badge: "Más rápido; sin interfaz"
                    sub: root.cl.freerdp ? root.cl.freerdp + " · se abre desde tus conexiones" : "El motor de Remmina, sin ventana propia"
                    Button { visible: !root.cl.freerdp; text: "Instalar"; onClicked: root.install({ arch: "freerdp", debian: "freerdp3-sdl", fedora: "freerdp", suse: "freerdp" }, "FreeRDP") }
                }
                InfoRow {
                    label: "TigerVNC"; glyph: "VNC"; lit: root.cl.vncviewer
                    badge: "Solo VNC (no Windows)"
                    sub: root.cl.vncviewer ? "vncviewer · el visor VNC más compatible" : "Visor VNC ligero para Linux, Mac y Raspberry Pi"
                    Button { visible: !root.cl.vncviewer; text: "Instalar"; onClicked: root.install({ arch: "tigervnc", debian: "tigervnc-viewer", fedora: "tigervnc", suse: "tigervnc" }, "TigerVNC") }
                }
                LabeledRow {
                    label: "Usar para RDP"
                    Dropdown {
                        model: [["auto", "Automático" + (root.cl.rdpAuto ? " · " + root.clientName[root.cl.rdpAuto] : "")], ["remmina", "Remmina"], ["freerdp", "FreeRDP"], ["connections", "Conexiones"]]
                        current: Settings.get("remoteClient", "auto")
                        onPicked: k => Settings.set("remoteClient", k)
                    }
                }
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                    text: "Automático usa Remmina, luego FreeRDP y luego Conexiones. Si guardaste la contraseña en el llavero se usa FreeRDP, que la recibe sin pedirla."
                }
            }
        }
    }

    // ================= compartir este escritorio =================
    Section {
        visible: !root.app
        Layout.fillWidth: true
        title: "Compartir este escritorio"
        headerRight: Mono { text: "wayvnc" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 10
                SwRow {
                    separator: false
                    label: "Compartir por VNC"
                    sub: !root.srv.installed ? "Instala wayvnc para compartir la pantalla"
                        : root.srv.running ? (root.srv.clients > 0 ? (root.srv.clients === 1 ? "1 persona conectada" : root.srv.clients + " personas conectadas") : "Esperando conexiones") : "Desactivado"
                    enabled: root.srv.installed
                    checked: root.srv.running
                    onToggled: v => { Quickshell.execDetached([root.cmd, "server", v ? "start" : "stop"]); later.restart(); }
                    trailing: Button { visible: !root.srv.installed; text: "Instalar"; onClicked: root.install({ arch: "wayvnc", debian: "wayvnc", fedora: "wayvnc", suse: "wayvnc" }, "wayvnc") }
                }
                SwRow {
                    label: "Pedir usuario y contraseña"
                    sub: root.srv.auth ? "Cifrado con TLS y RSA-AES · ~/.config/wayvnc" : "Sin contraseña solo se comparte en este equipo"
                    checked: root.srv.auth
                    enabled: root.srv.installed
                    onToggled: v => {
                        if (v) { root.askPassword(); return; }
                        // Sin contraseña no se escucha en la red
                        root.pendingNet = false;
                        Settings.set("vncListen", "127.0.0.1");
                        Quickshell.execDetached([root.cmd, "server", "noauth"]); later.restart();
                    }
                }
                LabeledRow {
                    label: "Escuchar en"
                    Seg {
                        model: [["0.0.0.0", root.srv.auth ? "Toda la red" : "Toda la red · pide contraseña"], ["127.0.0.1", "Solo este equipo"]]
                        current: root.onNet || root.pendingNet ? "0.0.0.0" : "127.0.0.1"
                        onPicked: k => {
                            if (k === "0.0.0.0" && !root.srv.auth) { root.pendingNet = true; return; }
                            root.pendingNet = false;
                            if (k === Settings.get("vncListen", "127.0.0.1")) return;
                            Settings.set("vncListen", k);
                            if (root.srv.running) { Quickshell.execDetached([root.cmd, "server", "restart"]); later.restart(); }
                        }
                    }
                }
                // «Toda la red» sin contraseña: primero hay que ponerla
                Rectangle {
                    visible: root.pendingNet && !root.srv.auth
                    Layout.fillWidth: true
                    implicitHeight: warnCol.implicitHeight + 24
                    radius: Theme.r(8)
                    color: Theme.selBg
                    border.width: 1
                    border.color: Theme.ov
                    ColumnLayout {
                        id: warnCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Txt {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 12; weight: Font.DemiBold; color: Theme.selText
                            text: "Para compartir con toda la red, pon antes una contraseña"
                        }
                        Txt {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.selText; opacity: 0.8
                            text: "Sin ella cualquiera en tu red podría ver y controlar tu escritorio. Al guardarla, VNC pasará a escuchar en la red con cifrado TLS."
                        }
                        RowLayout {
                            spacing: 8
                            Button { text: "Poner contraseña"; kind: "primary"; onClicked: root.askPassword() }
                            Button { text: "Cancelar"; onClicked: root.pendingNet = false }
                        }
                    }
                }
                LabeledRow {
                    visible: Quickshell.screens.length > 1
                    label: "Pantalla"
                    Dropdown {
                        model: [["", "La principal"]].concat(Quickshell.screens.map(s => [s.name, s.name + " · " + s.width + "×" + s.height]))
                        current: Settings.get("vncOutput", "")
                        onPicked: k => Settings.set("vncOutput", k)
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 8
                Repeater {
                    model: !root.onNet ? [{ dev: "local", ip: "127.0.0.1" }] : root.srv.ips
                    Kv {
                        required property var modelData
                        k: "Conéctate a"
                        v: modelData.ip + ":" + root.srv.port + "  (" + modelData.dev + ")"
                        mono: true
                    }
                }
                Kv { k: "Nombre del equipo"; v: root.srv.host ?? ""; mono: true }
                RowLayout {
                    visible: root.srv.firewall === "ufw" && root.onNet
                    Layout.fillWidth: true
                    spacing: 10
                    Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; muted: true; text: "El cortafuegos (ufw) bloquea el puerto " + root.srv.port + " si no lo abres." }
                    Button { text: "Abrir el puerto"; onClicked: Pkg.runInTerminal("sudo ufw allow " + root.srv.port + "/tcp comment 'VNC HyprFrijol'", "Cortafuegos") }
                }
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                    text: "Solo este equipo: para entrar desde fuera con un túnel cifrado (ssh -L 5900:localhost:5900 tu-equipo)."
                    visible: !root.onNet
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Txt {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                text: "Para vídeo y juegos con poca latencia: Sunshine + Moonlight."
            }
            Button {
                text: "Instalar Sunshine"
                onClicked: root.install({ arch: "sunshine", flatpak: "dev.lizardbyte.app.Sunshine" }, "Sunshine")
            }
        }
    }

    // ================= entrar desde Windows (RDP) =================
    Section {
        visible: !root.app
        Layout.fillWidth: true
        title: "Entrar desde Windows (RDP)"
        headerRight: Mono { text: "hypr-rdp" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 10
                SwRow {
                    separator: false
                    label: "Compartir por RDP"
                    sub: !root.rdp.installed ? "Instala hypr-rdp para entrar desde «Conexión a Escritorio remoto» de Windows"
                        : !root.rdp.password ? "Pon antes una contraseña"
                        : root.rdp.running ? "Esperando conexiones · se activa al iniciar sesión"
                        : root.rdp.listen === "tailscale" && !root.rdp.addr ? "Tailscale no está conectado" : "Desactivado"
                    enabled: root.rdp.installed && root.rdp.password
                    checked: root.rdp.running
                    onToggled: v => { Settings.set("rdpServer", v); Quickshell.execDetached([root.cmd, "rdp", v ? "start" : "stop"]); later.restart(); }
                    trailing: Button { visible: !root.rdp.installed; text: "Instalar"; onClicked: root.install({ arch: "hypr-rdp" }, "hypr-rdp") }
                }
                LabeledRow {
                    label: "Contraseña"
                    Button {
                        text: root.rdp.password ? "Cambiar" : "Poner contraseña"
                        kind: root.rdp.password ? "outline" : "primary"
                        onClicked: { Pkg.runInTerminal(root.cmd + " rdp password", "Contraseña de RDP"); later.restart(); }
                    }
                }
                LabeledRow {
                    label: "Escuchar en"
                    Seg {
                        model: [["tailscale", "Solo Tailscale"], ["red", "Toda la red"], ["local", "Solo este equipo"]]
                        current: root.rdp.listen
                        onPicked: k => { Settings.set("rdpListen", k); root.rdpRestart(); }
                    }
                }
                LabeledRow {
                    label: "Pantalla"
                    Dropdown {
                        model: [["", "La principal"]].concat(Quickshell.screens.map(s => [s.name, s.name + " · " + s.width + "×" + s.height]))
                            .concat([["virtual", "Una pantalla nueva para la conexión"]])
                        current: Settings.get("rdpOutput", "")
                        onPicked: k => { Settings.set("rdpOutput", k); root.rdpRestart(); }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 8
                Kv { k: "Conéctate a"; v: root.rdp.addr ? root.rdp.addr + ":" + root.rdp.port : "—"; mono: true }
                Kv { k: "Usuario"; v: root.rdp.user; mono: true }
                Kv { visible: !!root.rdp.output; k: "Se ve"; v: root.rdp.output; mono: true }
                RowLayout {
                    visible: root.rdp.firewall === "ufw" && root.rdp.listen !== "local"
                    Layout.fillWidth: true
                    spacing: 10
                    Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; muted: true; text: "Si no conecta, el cortafuegos (ufw) puede estar cerrando el puerto " + root.rdp.port + "." }
                    Button {
                        text: "Abrir el puerto"
                        onClicked: Pkg.runInTerminal("sudo ufw allow " + (root.rdp.listen === "tailscale" ? "in on tailscale0 to any port " + root.rdp.port + " proto tcp" : root.rdp.port + "/tcp")
                                                     + " comment 'RDP HyprFrijol'", "Cortafuegos")
                    }
                }
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                    text: "En Windows: «Conexión a Escritorio remoto» (mstsc), escribe la dirección de arriba y entra con tu usuario y la contraseña de RDP. La primera vez acepta el aviso del certificado. Ves y manejas esta misma sesión, no otra aparte."
                }
            }
        }
    }

    // ================= entrar con RustDesk =================
    Section {
        visible: !root.app
        Layout.fillWidth: true
        title: "Entrar con RustDesk"
        headerRight: Mono { text: "RustDesk · portal RemoteDesktop" }
        SwRow {
            separator: false
            label: "RustDesk"
            sub: !root.ad.installed ? "Como AnyDesk, también desde el móvil; sin instalar (AUR: rustdesk-bin)"
                : !root.ad.service ? "Instalado · su servicio no está en marcha"
                : "Esperando conexiones" + (root.ad.id ? " · ID " + root.ad.id : "")
            enabled: false
            checked: !!root.ad.service
            trailing: Button {
                visible: !root.ad.installed || !root.ad.service
                text: root.ad.installed ? "Activar" : "Instalar"
                onClicked: { Pkg.runInTerminal(root.ad.installed ? "sudo systemctl enable --now rustdesk" : (Pkg.aur || "paru") + " -S --needed rustdesk-bin && sudo systemctl enable --now rustdesk", "RustDesk"); later.restart(); }
            }
        }
        SwRow {
            label: "Portal de control remoto"
            sub: root.ad.portal ? "Activo: RustDesk puede ver y manejar esta sesión"
                : "Hyprland aún no lo trae: se instala su portal con la parte de control remoto (PR #448)"
            enabled: false
            checked: !!root.ad.portal
            trailing: Button {
                visible: !root.ad.portal
                text: "Instalar"
                onClicked: { Pkg.runInTerminal(root.cmd + " rustdesk portal", "Portal de control remoto"); later.restart(); }
            }
        }
        Kv { visible: !!root.ad.id; k: "ID de este equipo"; v: root.ad.id ?? ""; mono: true }
        Txt {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
            text: "Pon una contraseña permanente en RustDesk › Ajustes › Seguridad. La primera vez que entres, alguien tiene que aceptar en este equipo la pantalla y el control marcando «recordar»; después entras sin que nadie acepte. AnyDesk no acepta conexiones entrantes en Wayland: para eso, RustDesk o RDP."
        }
    }
}
