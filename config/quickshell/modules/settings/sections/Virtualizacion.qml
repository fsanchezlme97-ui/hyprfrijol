// Ajustes › Máquinas virtuales — requisitos (KVM, libvirt, grupo), Cockpit + cockpit-machines para crear y
// probar máquinas desde el navegador, GNOME Boxes y virt-manager como alternativas, lista de máquinas
// (virsh) y contenedores (Podman, Distrobox, BoxBuddy). Lógica en scripts/hf-vm.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    // app: true → la app «Máquinas virtuales» (modules/apps): tus máquinas y contenedores. En Ajustes, lo que hay que
    // instalar y activar, y un botón para abrir la app.
    property bool app: false
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    readonly property string cmd: Paths.script("hf-vm")
    readonly property string cockpitUrl: Settings.get("cockpitUrl", "https://localhost:9090")
    property var st: ({})
    property var vms: []
    property var boxes: []
    property bool loaded: false
    property string busy: ""
    // "enabled/active", "disabled/inactive"… (systemctl is-enabled / is-active)
    function unitOn(u) { return /^enabled|\/active$/.test(u ?? ""); }
    readonly property bool socketOn: unitOn(st.libvirtd) || unitOn(st.virtqemud)
    readonly property bool cockpitOn: unitOn(st.cockpitSocket)
    readonly property bool cockpitReady: !!st.cockpit && !!st.cockpitMachines

    function refresh() { stProc.running = false; stProc.running = true; vmProc.running = false; vmProc.running = true; ctProc.running = false; ctProc.running = true; }
    function term(args, title) { Pkg.runInTerminal(cmd + " " + args, title); later.n = 0; later.restart(); }
    function lines(t) { return t.split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(Boolean); }
    Timer { interval: 6000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { id: later; interval: 5000; repeat: true; property int n: 0; onTriggered: { root.refresh(); if (++n > 24) { n = 0; stop(); } } }
    Process { id: stProc; running: true; command: [root.cmd, "status"]; stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text); root.loaded = true; } catch (e) {} } } }
    Process { id: vmProc; running: true; command: [root.cmd, "list"]; stdout: StdioCollector { onStreamFinished: { root.vms = root.lines(text); root.busy = ""; } } }
    Process { id: ctProc; running: true; command: [root.cmd, "containers"]; stdout: StdioCollector { onStreamFinished: root.boxes = root.lines(text) } }
    Process { id: act; onExited: root.refresh() }
    function run(args) { act.command = [cmd].concat(args); act.running = true; }

    // Fila de requisito: ✓ / ! + texto + acción opcional
    component Check: Item {
        id: ck
        property bool ok: false
        property bool warn: false
        property string label: ""
        property string sub: ""
        property bool separator: true
        default property alias trailing: tr.data
        Layout.fillWidth: true
        implicitHeight: 46
        Rectangle { visible: ck.separator; width: parent.width; height: 1; color: Theme.ov }
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: 1
            spacing: 12
            Rectangle {
                implicitWidth: 22; implicitHeight: 22; radius: 11
                color: ck.ok ? Theme.p : "transparent"
                border.width: ck.ok ? 0 : 1.5
                border.color: ck.warn ? Theme.p : Theme.o
                Icon { anchors.centerIn: parent; visible: ck.ok; name: "check"; size: 13; stroke: 2.4; color: Theme.pText }
                Txt { anchors.centerIn: parent; visible: !ck.ok; text: ck.warn ? "!" : ""; weight: Font.Bold; size: 12; color: Theme.p }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt { Layout.fillWidth: true; text: ck.label; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; visible: ck.sub !== ""; text: ck.sub; muted: true; size: 11.5 }
            }
            Row { id: tr; spacing: 8; Layout.alignment: Qt.AlignVCenter }
        }
    }

    // ================= izquierda =================
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1.3
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            visible: !root.app
            Layout.fillWidth: true
            title: "Tus máquinas y contenedores"
            headerRight: Button { kind: "primary"; text: "Abrir Máquinas virtuales"; onClicked: Shell.open("maquinas") }
            Txt {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 12
                text: (root.vms.length === 1 ? "1 máquina" : root.vms.length + " máquinas") + " · "
                    + (root.boxes.length === 1 ? "1 contenedor" : root.boxes.length + " contenedores")
                    + ". Encender, apagar y crear contenedores está en su propia app (también en el menú de apps y en Spotlight)."
            }
        }
        Section {
            visible: !root.app
            Layout.fillWidth: true
            title: "Cockpit y libvirt"
            headerRight: [
                Button { visible: root.cockpitReady; text: "Abrir Cockpit"; kind: "primary"; onClicked: Qt.openUrlExternally(root.cockpitUrl) },
                Button { visible: root.loaded && !root.cockpitReady; kind: "primary"; text: "Instalar Cockpit + Máquinas"; onClicked: root.term("install cockpit", "Cockpit y máquinas virtuales") }
            ]
            Txt {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 12
                text: "Cockpit es un panel web para crear y probar máquinas virtuales desde una ISO (con UEFI y TPM para Windows 11), ver su pantalla, hacer instantáneas y gestionar contenedores. Se abre en el navegador en " + root.cockpitUrl.replace(/^https?:\/\//, "") + " y entras con tu usuario."
            }
            Check {
                separator: false
                ok: !!root.st.kvm && root.st.cpu !== "none"
                warn: !ok
                label: "Virtualización por hardware"
                sub: !root.loaded ? "Comprobando…" : root.st.cpu === "none" ? "Tu procesador no la anuncia: actívala en la BIOS/UEFI (SVM en AMD, VT-x en Intel)"
                    : (root.st.cpu === "svm" ? "AMD-V" : "Intel VT-x") + (root.st.kvm ? " · /dev/kvm listo" : " · falta el módulo kvm") + (/^(1|Y)$/.test(root.st.nested ?? "") ? " · anidada" : "")
            }
            Check {
                ok: !!root.st.libvirt && !!root.st.qemu
                label: "QEMU y libvirt"
                sub: ok ? "instalados" : "el motor de las máquinas (lo instala Cockpit o virt-manager)"
            }
            Check {
                id: libv
                visible: !!root.st.libvirt
                ok: root.socketOn
                warn: !ok
                label: "Servicio libvirt"
                sub: [["virtqemud.socket", root.st.virtqemud], ["libvirtd.socket", root.st.libvirtd]].filter(u => u[1]).map(u => u[0] + " " + (/\/active$/.test(u[1]) ? "activo" : /^enabled/.test(u[1]) ? "activado" : "desactivado")).join(" · ")
                Button { visible: !libv.ok; text: "Activar"; onClicked: root.term("enable libvirt", "libvirt") }
            }
            Check {
                visible: !!root.st.libvirt
                ok: !!root.st.groupNow
                warn: !ok
                label: "Tu usuario en el grupo libvirt"
                sub: root.st.groupNow ? "puedes gestionar las máquinas del sistema sin contraseña" : root.st.groupDb ? "añadido · cierra la sesión y vuelve a entrar" : "sin él, cada acción pide contraseña"
                Button { visible: !root.st.groupDb; text: "Añadirme"; onClicked: root.term("enable group", "Grupo libvirt") }
            }
            Check {
                ok: root.cockpitReady && root.cockpitOn
                warn: !!root.st.cockpit && !ok
                label: "Cockpit + Máquinas"
                sub: !root.st.cockpit ? "cockpit, cockpit-machines y cockpit-podman" : !root.st.cockpitMachines ? "falta cockpit-machines" : root.cockpitOn ? "cockpit.socket activo · " + root.cockpitUrl : "cockpit.socket desactivado"
                Button { visible: !!root.st.cockpit && !root.cockpitOn; text: "Activar"; onClicked: root.term("enable cockpit", "Cockpit") }
            }
            Txt {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                text: "La instalación abre una terminal con los comandos (" + (Pkg.family === "arch" ? "pacman" : Pkg.family === "debian" ? "apt" : Pkg.family === "fedora" ? "dnf" : "zypper")
                    + ") para que los veas y confirmes: paquetes, activar cockpit.socket y libvirt, añadirte al grupo libvirt y la red «default» de las máquinas."
            }
        }
        Section {
            visible: root.app
            Layout.fillWidth: true
            title: "Tus máquinas"
            headerRight: Mono { text: "virsh list --all" }
            Txt {
                visible: root.vms.length === 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true
                text: !root.st.libvirt ? "Cuando instales libvirt, aquí verás tus máquinas para encenderlas, apagarlas o abrir su pantalla."
                    : !root.st.groupNow ? "No hay máquinas de tu usuario. Las del sistema (las de Cockpit y virt-manager) aparecen cuando estés en el grupo libvirt."
                    : "Aún no tienes máquinas. Créalas en Cockpit (Máquinas virtuales › Crear), virt-manager o GNOME Boxes."
            }
            Repeater {
                model: root.vms
                InfoRow {
                    id: vr
                    required property var modelData
                    required property int index
                    readonly property bool up: modelData.state === "running" || modelData.state === "en ejecución" || modelData.state === "paused" || modelData.state === "pausado"
                    separator: index > 0
                    icon: "monitor"
                    lit: up
                    label: modelData.name
                    sub: (root.busy === modelData.name ? "…" : ({ "running": "encendida", "shut off": "apagada", "paused": "en pausa", "crashed": "se cerró con error", "pmsuspended": "suspendida" })[modelData.state] ?? modelData.state)
                        + " · " + (modelData.uri === "qemu:///session" ? "de tu usuario" : "del sistema")
                    Button { visible: vr.up; kind: "link"; text: "Forzar apagado"; onClicked: { root.busy = vr.modelData.name; root.run(["destroy", vr.modelData.name, vr.modelData.uri]); } }
                    Button { visible: vr.up; text: "Pantalla"; onClicked: Quickshell.execDetached([root.cmd, "console", vr.modelData.name, vr.modelData.uri]) }
                    Button {
                        kind: vr.up ? "outline" : "primary"
                        text: vr.up ? "Apagar" : "Encender"
                        onClicked: { root.busy = vr.modelData.name; root.run([vr.up ? "shutdown" : "start", vr.modelData.name, vr.modelData.uri]); }
                    }
                }
            }
        }
    }

    // ================= derecha =================
    ColumnLayout {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            visible: !root.app
            Layout.fillWidth: true
            title: "Otras apps"
            InfoRow {
                separator: false
                label: "GNOME Boxes"; glyph: "B"; lit: !!root.st.boxes
                sub: "La más sencilla: elige una ISO y listo"
                Button { visible: !!root.st.boxes; kind: "outline"; h: 26; text: "Abrir"; onClicked: Quickshell.execDetached(["sh", "-c", "command -v gnome-boxes >/dev/null && exec gnome-boxes || exec flatpak run org.gnome.Boxes"]) }
                Button { visible: root.loaded && !root.st.boxes; text: "Instalar"; onClicked: root.term("install boxes", "GNOME Boxes") }
            }
            InfoRow {
                label: "virt-manager"; glyph: "VM"; lit: !!root.st.virtManager
                sub: "Completo: redes, discos, USB y PCI"
                Button { visible: !!root.st.virtManager; kind: "outline"; h: 26; text: "Abrir"; onClicked: Quickshell.execDetached(["virt-manager"]) }
                Button { visible: root.loaded && !root.st.virtManager; text: "Instalar"; onClicked: root.term("install virtmanager", "virt-manager") }
            }
            InfoRow {
                label: "Visor remoto"; glyph: "▣"; lit: !!root.st.viewer
                sub: "virt-viewer · la pantalla de cada máquina"
                Button { visible: root.loaded && !root.st.viewer; text: "Instalar"; onClicked: root.term("install viewer", "virt-viewer") }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Contenedores"
            headerRight: Mono { text: "podman · distrobox" }
            InfoRow {
                separator: false
                label: "Podman + Distrobox"; glyph: "▤"; lit: !!root.st.podman && !!root.st.distrobox
                sub: root.st.podman && root.st.distrobox ? "Otras distros integradas en tu escritorio" : "Apps de otras distros sin salir de la tuya"
                Button { visible: root.loaded && !(root.st.podman && root.st.distrobox); text: "Instalar"; onClicked: root.term("install containers", "Podman y Distrobox") }
            }
            InfoRow {
                label: "BoxBuddy"; glyph: "BB"; lit: !!root.st.boxbuddy
                sub: "Gestiona Distrobox con interfaz"
                Button { visible: !!root.st.boxbuddy; kind: "outline"; h: 26; text: "Abrir"; onClicked: Quickshell.execDetached(["sh", "-c", "command -v boxbuddy-rs >/dev/null && exec boxbuddy-rs || exec flatpak run io.github.dvlv.boxbuddyrs"]) }
                Button { visible: root.loaded && !root.st.boxbuddy; text: "Instalar"; onClicked: root.term("install boxbuddy", "BoxBuddy") }
            }
            Repeater {
                model: root.app ? root.boxes : []        // la lista, solo en la app
                InfoRow {
                    id: br
                    required property var modelData
                    readonly property bool up: modelData.state === "running"
                    glyph: modelData.distrobox ? "DB" : "C"
                    lit: up
                    label: modelData.name
                    sub: modelData.image.replace(/^.*\//, "") + " · " + (({ running: "en marcha", exited: "detenido", created: "creado", paused: "en pausa", stopped: "detenido" })[modelData.state] ?? modelData.state)
                    Button { visible: br.modelData.distrobox; text: "Entrar"; onClicked: Quickshell.execDetached([root.cmd, "box", "enter", br.modelData.name]) }
                    Button { visible: br.up; kind: "link"; text: "Detener"; onClicked: root.run(["box", "stop", br.modelData.name]) }
                }
            }
            ColumnLayout {
                visible: !!root.st.distrobox && root.app
                Layout.fillWidth: true
                spacing: 8
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                Txt { text: "Nuevo contenedor"; muted: true; size: 11.5 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Dropdown {
                        id: img
                        Layout.preferredWidth: 150
                        model: [["registry.fedoraproject.org/fedora-toolbox:latest", "Fedora"], ["quay.io/toolbx/ubuntu-toolbox:24.04", "Ubuntu 24.04"],
                            ["quay.io/toolbx-images/debian-toolbox:12", "Debian 12"], ["quay.io/toolbx/arch-toolbox:latest", "Arch Linux"],
                            ["registry.opensuse.org/opensuse/distrobox:latest", "openSUSE"]]
                        current: model[0][0]
                        onPicked: k => current = k
                    }
                    Field { id: boxName; Layout.fillWidth: true; icon: ""; placeholder: "nombre" }
                    Button {
                        kind: "primary"; text: "Crear"
                        enabled: /^[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(boxName.text.trim())
                        onClicked: { root.term("box create " + boxName.text.trim() + " " + img.current, "Distrobox"); boxName.text = ""; }
                    }
                }
            }
        }
    }
}
