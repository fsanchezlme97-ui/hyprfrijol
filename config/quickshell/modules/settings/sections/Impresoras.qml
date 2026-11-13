// Ajustes › Impresoras y escáneres — impresoras de CUPS (lpstat), predeterminada (lpoptions -d, por usuario),
// página de prueba, pausar/reanudar y quitar (pkexec), cola de trabajos con cancelar, añadir impresora
// (system-config-printer o la web de CUPS), escáneres (SANE: scanimage -L) e instalación de lo que falte.
// (La impresora 3D de los widgets es otra cosa: services/Printer.qml, Ajustes › Escritorio.)
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
    // app: true → la app «Cola de impresión» (modules/apps): solo los trabajos. En Ajustes, impresoras y escáneres.
    property bool app: false
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property bool cups: false           // lpstat instalado
    property string svc: ""             // estado de cups.socket / cups.service
    property var printers: []           // [{ name, state, enabled, model, uri, info }]
    property string def: ""
    property var jobs: []               // [{ id, printer, user, size, when }]
    property var has: ({})
    property string open: ""
    property var scanners: []           // [{ dev, name }]
    property bool scanning: false
    property var picked: ({})           // paquetes elegidos para instalar

    function refresh() { probe.running = false; probe.running = true; }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: if (!probe.running) root.refresh() }
    Timer { id: later; interval: 1200; onTriggered: root.refresh() }
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "export LC_ALL=C; command -v lpstat >/dev/null && echo has:cups; "
            + "echo svc:$(systemctl is-active cups.socket 2>/dev/null)/$(systemctl is-active cups.service 2>/dev/null); "
            + "for b in system-config-printer simple-scan scanimage skanlite skanpage; do command -v $b >/dev/null && echo has:$b; done; "
            + "command -v lpstat >/dev/null || exit 0; "
            + "timeout 4 lpstat -d 2>/dev/null | sed -n 's/^system default destination: /def:/p'; "
            + "timeout 4 lpstat -p 2>/dev/null | grep '^printer ' | while read -r _ n rest; do "
            + "  m=$(timeout 2 lpoptions -p \"$n\" 2>/dev/null | grep -o \"printer-make-and-model=\\('[^']*'\\|[^ ]*\\)\" | cut -d= -f2- | tr -d \"'\"); "
            + "  i=$(timeout 2 lpoptions -p \"$n\" 2>/dev/null | grep -o \"printer-info=\\('[^']*'\\|[^ ]*\\)\" | cut -d= -f2- | tr -d \"'\"); "
            + "  u=$(timeout 2 lpstat -v \"$n\" 2>/dev/null | sed 's/^device for [^:]*: //'); "
            + "  case \"$rest\" in *disabled*) en=no;; *) en=yes;; esac; case \"$rest\" in *printing*) st=printing;; *idle*) st=idle;; *) st=other;; esac; "
            + "  printf 'p\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$n\" \"$st\" \"$en\" \"$m\" \"$u\" \"$i\"; done; "
            + "timeout 4 lpstat -o 2>/dev/null | awk '{ id=$1; u=$2; s=$3; $1=$2=$3=\"\"; sub(/^ +/, \"\"); printf \"j\\t%s\\t%s\\t%s\\t%s\\n\", id, u, s, $0 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const h = {}; l.filter(x => x.startsWith("has:")).forEach(x => h[x.slice(4)] = true);
                root.has = h; root.cups = !!h.cups;
                root.svc = (l.find(x => x.startsWith("svc:")) ?? "svc:").slice(4);
                root.def = (l.find(x => x.startsWith("def:")) ?? "def:").slice(4).trim();
                root.printers = l.filter(x => x.startsWith("p\t")).map(x => { const f = x.split("\t"); return { name: f[1], state: f[2], enabled: f[3] === "yes", model: f[4], uri: f[5], info: f[6] }; });
                root.jobs = l.filter(x => x.startsWith("j\t")).map(x => { const f = x.split("\t"); const i = f[1].lastIndexOf("-"); return { id: f[1], printer: f[1].slice(0, i), user: f[2], size: Number(f[3]), when: f[4] }; });
            }
        }
    }
    function scan() { scanning = true; scanProc.running = false; scanProc.running = true; }
    Process {
        id: scanProc
        command: ["sh", "-c", "command -v scanimage >/dev/null || exit 0; timeout 25 scanimage -f '%d\\t%v %m\\n' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanners = text.split("\n").filter(Boolean).map(x => { const f = x.split("\t"); return { dev: f[0], name: (f[1] || f[0]).trim() }; });
                root.scanning = false;
            }
        }
    }
    readonly property bool svcOn: svc.split("/").includes("active")
    function kind(uri) { return /^(ipp|ipps|http|https|dnssd|socket|lpd|smb):/.test(uri) ? "red" : /^usb:/.test(uri) ? "USB" : /^cups-pdf:/.test(uri) ? "PDF" : ""; }
    function addPrinter() {
        if (has["system-config-printer"]) Quickshell.execDetached(["system-config-printer"]);
        else Qt.openUrlExternally("http://localhost:631/admin");
    }
    function stateText(p) {
        return !p.enabled ? "En pausa" : p.state === "idle" ? "Lista" : p.state === "printing" ? "Imprimiendo" : "Ocupada";
    }
    function sizeText(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"; }

    readonly property var pkgs: [
        ["cups", "CUPS", "el servicio de impresión"],
        ["cups-pdf", "Impresora PDF", "«imprime» a un archivo PDF"],
        ["system-config-printer", "Configurador", "añadir y ajustar impresoras"],
        ["gutenprint", "Controladores", "Canon, Epson y muchas más"],
        ["hplip", "HP", "controladores y herramientas de HP"],
        ["nss-mdns", "Impresoras de red", "encuentra impresoras Wi-Fi (Avahi)"],
        ["sane", "SANE", "acceso a escáneres"],
        ["simple-scan", "Escaneo", "app sencilla para escanear"]
    ]
    readonly property var missing: pkgs.filter(p => !Pkg.isInstalled(p[0]))

    // ---------- impresoras ----------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1.2
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            visible: !root.app
            Layout.fillWidth: true
            title: "Impresoras"
            headerRight: Button { visible: root.cups; kind: "primary"; text: "Añadir impresora"; enabled: root.svcOn; onClicked: root.addPrinter() }
            ColumnLayout {
                visible: !root.cups || !root.svcOn
                Layout.fillWidth: true
                spacing: 8
                Txt {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: !root.cups ? "CUPS, el sistema de impresión, no está instalado. Instálalo para usar impresoras."
                        : "El servicio de impresión (CUPS) está detenido."
                }
                RowLayout {
                    spacing: 8
                    Button {
                        visible: !root.cups
                        kind: "primary"; text: "Instalar CUPS"
                        onClicked: Pkg.runInTerminal(Pkg.commands([{ src: "Repos", pkg: "cups cups-pdf system-config-printer" }], { snapshot: false }).join(" && ") + " && sudo systemctl enable --now cups.socket", "Impresoras")
                    }
                    Button {
                        visible: root.cups && !root.svcOn
                        kind: "primary"; text: "Activar CUPS"
                        onClicked: { Quickshell.execDetached(["pkexec", "systemctl", "enable", "--now", "cups.socket", "cups.service"]); later.restart(); }
                    }
                }
                Mono { tech: true; Layout.fillWidth: true; text: "cups.socket / cups.service: " + (root.svc || "…") }
            }
            Txt {
                visible: root.cups && root.svcOn && root.printers.length === 0
                Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap
                text: "No hay impresoras. Las impresoras de red suelen aparecer solas (IPP Everywhere); si no, pulsa «Añadir impresora»."
            }
            Repeater {
                model: root.printers
                ColumnLayout {
                    id: pr
                    required property var modelData
                    required property int index
                    readonly property bool expanded: root.open === modelData.name
                    readonly property bool isDef: root.def === modelData.name
                    Layout.fillWidth: true
                    spacing: 0
                    Rectangle { visible: pr.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: Theme.r(6)
                        color: prm.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4; anchors.rightMargin: 4
                            spacing: 12
                            Rectangle {
                                implicitWidth: 34; implicitHeight: 34; radius: Theme.ctl(34)
                                color: pr.isDef ? Theme.pc : Theme.s4
                                Icon { anchors.centerIn: parent; name: root.kind(pr.modelData.uri) === "PDF" ? "file" : "printer"; size: 16; color: pr.isDef ? Theme.pcText : Theme.tv }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Txt { Layout.maximumWidth: pr.width - 190; text: pr.modelData.info || pr.modelData.name; weight: Font.DemiBold }
                                    Rectangle {
                                        visible: pr.isDef
                                        implicitHeight: 18; implicitWidth: dl.implicitWidth + 14; radius: Theme.ctl(18)
                                        color: Theme.sc
                                        Txt { id: dl; anchors.centerIn: parent; text: "Predeterminada"; size: 10.5; weight: Font.DemiBold; color: Theme.scText }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                Txt { Layout.fillWidth: true; muted: true; size: 11.5; text: [root.stateText(pr.modelData), pr.modelData.model, root.kind(pr.modelData.uri)].filter(Boolean).join(" · ") }
                            }
                            Icon { name: pr.expanded ? "chevron_up" : "chevron_down"; size: 14; color: Theme.tv }
                        }
                        MouseArea { id: prm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = pr.expanded ? "" : pr.modelData.name }
                    }
                    ColumnLayout {
                        visible: pr.expanded
                        Layout.fillWidth: true
                        Layout.leftMargin: 50
                        Layout.bottomMargin: 12
                        spacing: 8
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Button {
                                visible: !pr.isDef
                                text: "Usar como predeterminada"
                                onClicked: { Quickshell.execDetached(["lpoptions", "-d", pr.modelData.name]); later.restart(); }
                            }
                            Button {
                                text: "Imprimir página de prueba"
                                onClicked: { Quickshell.execDetached(["sh", "-c", "lp -d \"$1\" -t 'Página de prueba' /usr/share/cups/data/testprint", "sh", pr.modelData.name]); later.restart(); }
                            }
                            Button {
                                text: pr.modelData.enabled ? "Pausar" : "Reanudar"
                                onClicked: { Quickshell.execDetached(["pkexec", pr.modelData.enabled ? "cupsdisable" : "cupsenable", pr.modelData.name]); later.restart(); }
                            }
                            Button {
                                text: "Opciones…"
                                onClicked: root.has["system-config-printer"] ? Quickshell.execDetached(["system-config-printer"]) : Qt.openUrlExternally("http://localhost:631/printers/" + encodeURIComponent(pr.modelData.name))
                            }
                            ConfirmButton {
                                text: "Quitar"
                                confirmText: "¿Quitar «" + (pr.modelData.info || pr.modelData.name) + "»? Sí"
                                onConfirmed: { Quickshell.execDetached(["pkexec", "lpadmin", "-x", pr.modelData.name]); root.open = ""; later.restart(); }
                            }
                        }
                        Mono { Layout.fillWidth: true; text: pr.modelData.name + " · " + (pr.modelData.uri || "sin URI") }
                    }
                }
            }
            Txt {
                visible: root.cups
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "La predeterminada se guarda para tu usuario (lpoptions). Pausar y quitar piden tu contraseña."
            }
        }
        Section {
            visible: root.cups && !root.app
            Layout.fillWidth: true
            title: "Cola de impresión"
            headerRight: Button { text: "Ver la cola"; onClicked: Shell.open("impresion") }
            Txt { muted: true; text: root.jobs.length ? (root.jobs.length === 1 ? "1 trabajo pendiente" : root.jobs.length + " trabajos pendientes") : "No hay trabajos pendientes." }
        }
        Section {
            visible: root.app
            Layout.fillWidth: true
            title: "Trabajos"
            headerRight: Button {
                visible: root.jobs.length > 1
                kind: "link"; text: "Cancelar todos los míos"
                onClicked: { Quickshell.execDetached(["sh", "-c", "cancel -u \"$USER\""]); later.restart(); }
            }
            Txt { visible: root.jobs.length === 0; muted: true; text: root.cups ? "No hay trabajos pendientes." : "No está instalado el sistema de impresión (CUPS): Ajustes › Impresoras y escáneres." }
            Repeater {
                model: root.jobs
                RowLayout {
                    id: jr
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 12
                    Txt { Layout.preferredWidth: 26; text: "#" + jr.modelData.id.slice(jr.modelData.id.lastIndexOf("-") + 1); tabular: true; weight: Font.DemiBold }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: (root.printers.find(p => p.name === jr.modelData.printer)?.info || jr.modelData.printer) + " · " + root.sizeText(jr.modelData.size) }
                        Txt { Layout.fillWidth: true; muted: true; size: 11; text: jr.modelData.user + " · " + jr.modelData.when }
                    }
                    Button { text: "Cancelar"; onClicked: { Quickshell.execDetached(["cancel", jr.modelData.id]); later.restart(); } }
                }
            }
        }
    }

    // ---------- escáneres y programas ----------
    ColumnLayout {
        id: right
        visible: !root.app
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Escáneres"
            headerRight: Button {
                text: root.scanning ? "Buscando…" : "Buscar"
                enabled: !root.scanning && !!root.has.scanimage
                onClicked: root.scan()
            }
            Txt {
                visible: !root.has.scanimage
                Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap
                text: "Instala SANE para usar escáneres (abajo, en «Programas y controladores»)."
            }
            Txt {
                visible: !!root.has.scanimage && root.scanners.length === 0
                Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap
                text: root.scanning ? "Buscando escáneres (puede tardar unos segundos)…" : "Pulsa Buscar con el escáner conectado y encendido."
            }
            Repeater {
                model: root.scanners
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Icon { name: "image"; size: 16; color: Theme.tv }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: parent.parent.modelData.name; weight: Font.Medium }
                        Mono { Layout.fillWidth: true; text: parent.parent.modelData.dev }
                    }
                }
            }
            RowLayout {
                visible: !!(root.has["simple-scan"] || root.has.skanlite || root.has.skanpage)
                spacing: 8
                Button {
                    kind: "primary"; text: "Escanear un documento"
                    onClicked: Quickshell.execDetached([root.has["simple-scan"] ? "simple-scan" : root.has.skanpage ? "skanpage" : "skanlite"])
                }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Programas y controladores"
            headerRight: Mono { text: root.missing.length ? root.missing.length + " sin instalar" : "todo instalado" }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.pkgs
                    Chip {
                        required property var modelData
                        readonly property bool inst: Pkg.isInstalled(modelData[0])
                        text: modelData[1]
                        on: inst || !!root.picked[modelData[0]]
                        opacity: inst ? 0.6 : 1
                        onClicked: {
                            if (inst) return;
                            const p = Object.assign({}, root.picked);
                            if (p[modelData[0]]) delete p[modelData[0]]; else p[modelData[0]] = true;
                            root.picked = p;
                        }
                    }
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: root.pkgs.filter(p => !!root.picked[p[0]]).map(p => p[1] + ": " + p[2]).join(" · ") || "Marca lo que quieras instalar. Lo ya instalado aparece atenuado."
            }
            RowLayout {
                spacing: 8
                Button {
                    kind: "primary"
                    text: "Instalar seleccionados"
                    enabled: Object.keys(root.picked).length > 0
                    onClicked: {
                        const names = Object.keys(root.picked);
                        let cmd = Pkg.commands([{ src: "Repos", pkg: names.join(" ") }], { snapshot: false }).join(" && ");
                        if (names.includes("cups")) cmd += " && sudo systemctl enable --now cups.socket";
                        if (names.includes("nss-mdns")) cmd += " && sudo systemctl enable --now avahi-daemon && echo 'Para descubrir impresoras .local añade mdns_minimal [NOTFOUND=return] a hosts en /etc/nsswitch.conf (ver wiki de Arch: Avahi)'";
                        Pkg.runInTerminal(cmd, "Impresoras y escáneres");
                        root.picked = {};
                    }
                }
                Button { text: "Comprobar de nuevo"; onClicked: { Pkg.refresh(); root.refresh(); } }
            }
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Web de administración de CUPS: http://localhost:631"
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("http://localhost:631") }
        }
    }
}
