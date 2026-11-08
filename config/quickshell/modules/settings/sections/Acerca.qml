// Ajustes › Acerca del sistema — nombre del equipo (hostnamectl), distro, kernel, versiones de Hyprland y
// Quickshell, hardware; sincronizar/exportar el perfil de escritorio (~/.config/hyprfrijol).
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
    implicitHeight: Math.max(info.implicitHeight, sync.implicitHeight)
    property var sys: ({})
    property bool renaming: false
    property string syncMsg: ""
    Process {
        id: probe
        running: true
        command: ["sh", "-c", ". /etc/os-release; echo \"distro=$PRETTY_NAME\"; echo \"kernel=$(uname -r)\"; echo \"host=$(cat /etc/hostname 2>/dev/null || hostname)\"; "
            + "echo \"hypr=$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"version\",\"\"))' 2>/dev/null)\"; "
            + "echo \"qs=$(qs --version 2>/dev/null | head -1 | awk '{print $2}')\"; "
            + "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //; s/([^)]*)//g; s/  */ /g') · $(nproc) hilos\"; "
            + "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed -E 's/.*: //; s/ \\(rev.*//; s/.*\\[([^]]+)\\]$/\\1/' | head -2 | paste -sd '+' | sed 's/+/ + /g')\"; "
            + "echo \"mem=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1048576}' /proc/meminfo)\"; "
            + "echo \"disk=$(df -h / | awk 'NR==2{print $2\" · \"$5\" usado\"}') · $(findmnt -no FSTYPE /)\"; "
            + "echo \"updated=$(grep -a 'starting full system upgrade' /var/log/pacman.log 2>/dev/null | tail -1 | cut -c2-17)\"; "
            + "echo \"git=$(git -C ~/.config/hyprfrijol remote get-url origin 2>/dev/null)\"; echo \"gitrepo=$([ -d ~/.config/hyprfrijol/.git ] && echo si)\"; "
            // versión de HyprFrijol: la más nueva del CHANGELOG (o, si no está, la etiqueta de git)
            + "r=\"$0\"; v=$(grep -m1 -o '^## \\[[0-9.]*\\]' \"$r/CHANGELOG.md\" 2>/dev/null | tr -d '#[] '); [ -n \"$v\" ] || v=$(git -C \"$r\" describe --tags --abbrev=0 2>/dev/null); echo \"hf=${v#v}\"", Paths.root]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                text.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
                root.sys = o;
            }
        }
    }
    function fmtDate(s) { if (!s) return "—"; const d = new Date(s.replace(" ", "T")); return isNaN(d) ? s : Qt.locale("es_ES").toString(d, "d MMM yyyy · HH:mm"); }
    readonly property string report: "Sistema: " + (sys.distro ?? "") + "\nKernel: " + (sys.kernel ?? "") + "\nEscritorio: Hyprland " + (sys.hypr ?? "") + " + Quickshell " + (sys.qs ?? "") + " (HyprFrijol " + (sys.hf ?? "") + ")"
        + "\nProcesador: " + (sys.cpu ?? "") + "\nGráficos: " + (sys.gpu ?? "") + "\nMemoria: " + (sys.mem ?? "") + "\nAlmacenamiento: " + (sys.disk ?? "")
        + "\nEstilo: " + Theme.estilo + " · " + Theme.paletteName

    Section {
        id: info
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        pad: 18
        // Logo de HyprFrijol (assets/brand): letras blancas en tema oscuro; en claro, la tarjeta oscura del README
        Image {
            id: logo
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * (Theme.light ? 500 / 1400 : 256 / 920))
            Layout.maximumHeight: 150
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            source: "file://" + Paths.assets + "/brand/" + (Theme.light ? "logo-card.png" : "logo-wide.png")
            sourceSize.width: 920
            asynchronous: true
            smooth: true; mipmap: true
            visible: status === Image.Ready
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            text: root.sys.hf ? "Versión " + root.sys.hf : ""
            muted: true; size: 11.5; tabular: true
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 14
            Rectangle {
                implicitWidth: 52; implicitHeight: 52; radius: Theme.r(10); color: Theme.pc
                Icon { anchors.centerIn: parent; name: "monitor"; size: 26; color: Theme.pcText }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Txt { visible: !root.renaming; text: root.sys.host ?? "…"; size: 19; weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.renaming = true; hostField.text = root.sys.host ?? ""; hostField.focusInput(); } } }
                Field {
                    id: hostField
                    visible: root.renaming
                    Layout.fillWidth: true
                    icon: ""
                    placeholder: "nombre-del-equipo · Enter"
                    onAccepted: {
                        const n = text.trim().toLowerCase().replace(/[^a-z0-9-]/g, "-");
                        if (n) Quickshell.execDetached(["hostnamectl", "set-hostname", n]);
                        root.renaming = false; refresh.restart();
                    }
                }
                Txt { text: root.renaming ? "Solo letras, números y guiones" : "Toca para renombrar"; muted: true; size: 11.5 }
            }
        }
        Kv { k: "Sistema"; v: root.sys.distro ?? "…" }
        Kv { k: "Kernel"; v: root.sys.kernel ?? "…" }
        Kv { k: "Escritorio"; v: "HyprFrijol " + (root.sys.hf ?? "") + " · Hyprland " + (root.sys.hypr ?? "") }
        Kv { k: "Quickshell"; v: root.sys.qs ?? "…" }
        Kv { k: "Procesador"; v: root.sys.cpu ?? "…" }
        Kv { k: "Gráficos"; v: root.sys.gpu ?? "…" }
        Kv { k: "Memoria"; v: root.sys.mem ?? "…" }
        Kv { k: "Almacenamiento"; v: root.sys.disk ?? "…" }
        Kv { k: "Actualizado"; v: root.fmtDate(root.sys.updated) }
        Timer { id: refresh; interval: 1500; onTriggered: { probe.running = false; probe.running = true; } }
        RowLayout {
            Layout.topMargin: 6
            spacing: 8
            Button { text: "Copiar información"; onClicked: { Quickshell.execDetached(["wl-copy", root.report]); copied.restart(); } }
            Button { text: "Informe para soporte"; onClicked: Pkg.runInTerminal("{ echo '" + root.report.replace(/'/g, "") + "'; echo; hyprctl version; echo; journalctl --user -b -p warning -n 60 --no-pager; } | tee ~/hyprfrijol-informe.txt", "Informe para soporte") }
            Txt { visible: copied.running; text: "Copiado ✓"; color: Theme.p; size: 11.5 }
            Timer { id: copied; interval: 1800 }
        }
    }
    Section {
        id: sync
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        title: "Sincronizar tu escritorio"
        readonly property string method: Settings.get("syncMethod", "git")
        Txt { Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap; text: "Guarda estilo, colores, fondos, atajos, barra y lista de apps para llevarlos a otro equipo o restaurarlos." }
        Seg {
            Layout.fillWidth: true
            model: [["git", "Git"], ["sync", "Syncthing"], ["file", "Archivo"]]
            current: sync.method
            onPicked: k => Settings.set("syncMethod", k)
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: sync.method === "git" ? (root.sys.git ? "Repositorio: " + root.sys.git : "Repositorio git privado en ~/.config/hyprfrijol · historial de cambios y vuelta atrás.")
                : sync.method === "sync" ? "Comparte ~/.config/hyprfrijol con Syncthing entre tus equipos."
                : "Un .tar con tu perfil que puedes copiar a mano."
        }
        LabeledRow {
            visible: sync.method === "git"
            label: "Remoto"; labelWidth: 70
            Field { icon: ""; text: root.sys.git ?? ""; placeholder: "git@github.com:tu-usuario/escritorio.git · Enter"; onAccepted: { Quickshell.execDetached(["sh", "-c", "cd ~/.config/hyprfrijol && { [ -d .git ] || git init -q; } && { git remote set-url origin \"$0\" 2>/dev/null || git remote add origin \"$0\"; }", text.trim()]); refresh.restart(); } }
        }
        SwRow { label: "Sincronizar automáticamente"; sub: "al cambiar un ajuste (cada 10 min como mucho)"; key: "syncAuto" }
        SwRow { label: "Incluir lista de apps instaladas"; sub: "pacman -Qqe y flatpak list"; key: "syncApps"; def: true }
        SwRow { label: "Incluir fondos de pantalla"; key: "syncWallpapers"; def: false }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button {
                Layout.fillWidth: true
                kind: "primary"
                text: "Sincronizar ahora"
                enabled: sync.method === "git"
                onClicked: {
                    const apps = Settings.get("syncApps", true) ? "pacman -Qqe > apps-pacman.txt; command -v flatpak >/dev/null && flatpak list --app --columns=application > apps-flatpak.txt; " : "";
                    const walls = Settings.get("syncWallpapers", false) ? "mkdir -p fondos; cp -u \"$(xdg-user-dir PICTURES)\"/Wallpapers/* \"$(xdg-user-dir PICTURES)\"/Fondos/* fondos/ 2>/dev/null; " : "";
                    syncProc.command = ["sh", "-c", "cd ~/.config/hyprfrijol && { [ -d .git ] || git init -q; } && " + apps + walls
                        + "git add -A && { git commit -qm \"hyprfrijol: $(date '+%F %T')\" || true; } && { git remote get-url origin >/dev/null 2>&1 && git push -q -u origin HEAD 2>&1 && echo OK-PUSH || echo OK-LOCAL; }"];
                    syncProc.running = true;
                }
            }
            Button {
                Layout.fillWidth: true
                text: "Exportar perfil (.tar)"
                onClicked: { syncProc.command = ["sh", "-c", "f=\"$HOME/hyprfrijol-perfil-$(date +%F).tar.gz\"; tar czf \"$f\" -C \"$HOME/.config\" hyprfrijol && echo \"EXPORT $f\""]; syncProc.running = true; }
            }
        }
        Process {
            id: syncProc
            stdout: StdioCollector {
                onStreamFinished: root.syncMsg = text.includes("OK-PUSH") ? "Sincronizado con " + (root.sys.git ?? "el remoto") + " ✓"
                    : text.includes("OK-LOCAL") ? "Guardado en el historial local (añade un remoto para subirlo)"
                    : text.includes("EXPORT") ? "Exportado: " + text.trim().split(" ").slice(1).join(" ") : (text.trim() || "No se pudo sincronizar")
            }
        }
        Mono { Layout.fillWidth: true; text: "En otro equipo: git clone <remoto> ~/.config/hyprfrijol && hf-apply"; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: root.syncMsg || "No incluye contraseñas ni llaves." }
    }
}
