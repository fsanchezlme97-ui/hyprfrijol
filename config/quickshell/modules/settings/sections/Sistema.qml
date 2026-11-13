// Ajustes › Sistema y recuperación — puntos de restauración (snapper list, solo lectura), kernels instalados,
// actualizaciones (updatesMode…), copia de /home, exportar/importar tus ajustes (settings.json) y enlace a
// Apps predeterminadas e inicio; Diagnóstico, Actualizaciones de HyprFrijol y Modo seguro (ui/Mantenimiento.qml).
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
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var snaps: []
    property string snapErr: ""
    property int sel: -1
    property var kernels: []
    property string running: ""
    property var has: ({})
    property bool app: false        // ventana «Puntos de restauración» (modules/apps): solo la lista de puntos

    function loadSnaps() { snapProc.running = false; snapProc.running = true; }
    Process {
        id: snapProc
        running: true
        command: ["sh", "-c", "command -v snapper >/dev/null || { echo NOSNAPPER; exit; }; snapper --jsonout -c root list 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("NOSNAPPER")) { root.snapErr = "Snapper no está instalado."; return; }
                try {
                    const j = JSON.parse(text);
                    root.snaps = (j.root ?? []).filter(s => s.number > 0).reverse().slice(0, 40);
                    root.snapErr = "";
                    if (root.snaps.length && root.sel < 0) root.sel = root.snaps[0].number;
                } catch (e) { root.snapErr = text.trim() || "No se pudo leer"; }
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "uname -r; pacman -Qq 2>/dev/null | grep -E '^linux(-[a-z0-9]+)*$' | grep -vE 'headers|firmware|api|docs|tools'; "
            + "for p in snap-pac fwupd btrfs-assistant pika-backup deja-dup limine-snapper-sync flatpak; do (pacman -Qq $p || command -v $p) >/dev/null 2>&1 && echo has:$p; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").filter(Boolean);
                root.running = l[0] ?? "";
                root.kernels = l.slice(1).filter(x => !x.startsWith("has:"));
                const h = {}; l.filter(x => x.startsWith("has:")).forEach(x => h[x.slice(4)] = true); root.has = h;
            }
        }
    }
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1.25
        Layout.alignment: Qt.AlignTop
        spacing: 12
        // En Ajustes, solo el resumen; la lista con crear y ver cambios es la app «Puntos de restauración»
        Section {
            visible: !root.app
            Layout.fillWidth: true
            title: "Puntos de restauración"
            headerRight: Button { text: "Abrir Puntos de restauración"; h: 26; onClicked: Shell.open("restauracion") }
            Txt {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: root.snapErr !== "" ? (root.snapErr === "Sin permisos." ? "Tu usuario no puede leer los puntos de restauración de snapper." : root.snapErr)
                    : root.snaps.length ? root.snaps.length + (root.snaps.length === 1 ? " punto" : " puntos") + " · el último: #" + root.snaps[0].number + (root.snaps[0].description ? " (" + root.snaps[0].description + ")" : "")
                    : "Aún no hay puntos de restauración"
                muted: root.snapErr !== ""
            }
        }
        Section {
            visible: root.app
            Layout.fillWidth: true
            title: "Puntos de restauración"
            headerRight: Button { kind: "primary"; text: "Crear ahora"; enabled: root.snapErr !== "Snapper no está instalado."; onClicked: { Pkg.runInTerminal("sudo snapper -c root create -c number -d 'Manual desde Ajustes'", "Punto de restauración"); refreshT.restart(); } }
            RowLayout {
                visible: root.snapErr === ""
                Layout.fillWidth: true
                Layout.leftMargin: 8; Layout.rightMargin: 8
                spacing: 12
                Txt { Layout.preferredWidth: 40; text: "N.º"; muted: true; size: 11.5 }
                Txt { Layout.preferredWidth: 110; text: "Fecha"; muted: true; size: 11.5 }
                Txt { Layout.fillWidth: true; text: "Descripción"; muted: true; size: 11.5 }
                Txt { Layout.preferredWidth: 54; text: "Tipo"; muted: true; size: 11.5 }
            }
            Repeater {
                model: root.snaps.slice(0, 8)
                Rectangle {
                    id: sr
                    required property var modelData
                    readonly property bool on: root.sel === modelData.number
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Theme.r(6)
                    color: on ? Theme.selBg : sm.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
                    function when(d) {
                        const t = new Date(String(d).replace(" ", "T")); if (isNaN(t)) return d;
                        const now = new Date(), days = Math.floor((new Date(now.toDateString()) - new Date(t.toDateString())) / 864e5);
                        const hm = Qt.formatTime(t, "HH:mm");
                        return days === 0 ? "hoy " + hm : days === 1 ? "ayer " + hm : days < 7 ? Qt.locale("es_ES").toString(t, "ddd").replace(".", "") + " " + hm : Qt.formatDate(t, "dd/MM/yy");
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 12
                        Txt { Layout.preferredWidth: 40; text: "#" + sr.modelData.number; weight: Font.DemiBold; tabular: true; color: sr.on ? Theme.selText : Theme.t }
                        Txt { Layout.preferredWidth: 110; text: sr.when(sr.modelData.date); color: sr.on ? Theme.selText : Theme.tv; tabular: true }
                        Txt { Layout.fillWidth: true; text: sr.modelData.description || "—"; color: sr.on ? Theme.selText : Theme.t }
                        Txt { Layout.preferredWidth: 54; text: sr.modelData.type === "single" ? "manual" : sr.modelData.type; size: 11.5; color: sr.on ? Theme.selText : Theme.tv }
                    }
                    MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sel = sr.modelData.number }
                }
            }
            ColumnLayout {
                visible: root.snapErr !== ""
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.snapErr === "Sin permisos." ? "Tu usuario no puede leer los puntos de restauración de snapper." : root.snapErr }
                Button {
                    visible: root.snapErr === "Sin permisos."
                    text: "Permitir que mi usuario los vea"
                    onClicked: { Pkg.runInTerminal("sudo snapper -c root set-config ALLOW_USERS=\"$USER\" SYNC_ACL=yes", "snapper"); refreshT.restart(); }
                }
            }
            Timer { id: refreshT; interval: 8000; onTriggered: root.loadSnaps() }
            RowLayout {
                spacing: 8
                Button {
                    text: "Ver cambios de #" + (root.sel > 0 ? root.sel : "…")
                    enabled: root.sel > 0
                    onClicked: Pkg.runInTerminal("snapper -c root status " + (root.sel - 1) + ".." + root.sel + " | less", "Cambios")
                }
                Button { visible: !!root.has["btrfs-assistant"]; text: "Restaurar archivos…"; onClicked: Quickshell.execDetached(["sh", "-c", "btrfs-assistant-launcher || btrfs-assistant"]) }
                Button { text: "Actualizar"; onClicked: root.loadSnaps() }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "Snapper " + (root.has["snap-pac"] ? "+ snap-pac crean" : "crea") + " un punto antes y después de cada actualización"
                    + (root.has["limine-snapper-sync"] ? ", y aparecen en el menú de arranque de Limine." : ".")
                    + " Un punto de restauración no reemplaza una copia de seguridad: vive en el mismo disco."
            }
        }
        Section {
            visible: !root.app
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Txt { Layout.fillWidth: true; text: "Copia de seguridad de /home"; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; muted: true; size: 11.5; text: root.has["pika-backup"] ? "Pika Backup · cifrada y programada" : root.has["deja-dup"] ? "Déjà Dup" : "Sin herramienta de copias · te recomendamos Pika Backup" }
                }
                Button {
                    text: root.has["pika-backup"] || root.has["deja-dup"] ? "Configurar" : "Instalar Pika Backup"
                    onClicked: root.has["pika-backup"] ? Quickshell.execDetached(["pika-backup"]) : root.has["deja-dup"] ? Quickshell.execDetached(["deja-dup"]) : Shell.open("herramientas", "pika")
                }
            }
        }
        // Diagnóstico (hf-doctor), Actualizaciones de HyprFrijol (hf-update) y Modo seguro (hf-safe) → ui/Mantenimiento.qml
        Mantenimiento { Layout.fillWidth: true; visible: !root.app }
    }
    ColumnLayout {
        id: right
        visible: !root.app
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Kernel"
            headerRight: Mono { tech: true; text: "uname -r → " + root.running }
            // Solo informa: el kernel se elige en el menú de arranque, no aquí
            Txt { visible: root.kernels.length > 0; text: "Instalados: " + root.kernels.join(" · "); muted: true; size: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            SwRow {
                visible: Pkg.family === "arch"
                label: "Mantener un kernel LTS de respaldo"; sub: "aparece como opción en el arranque"
                checked: root.kernels.some(k => /lts/.test(k))
                enabled: !root.kernels.some(k => /lts/.test(k))
                onToggled: v => { if (v) Pkg.runInTerminal("sudo pacman -S --needed " + (root.kernels.some(k => /cachyos/.test(k)) ? "linux-cachyos-lts linux-cachyos-lts-headers" : "linux-lts linux-lts-headers"), "Kernel LTS"); }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Actualizaciones"
            Seg {
                Layout.fillWidth: true
                model: [["auto", "Automáticas"], ["avisar", "Avisar"], ["manual", "Manual"]]
                current: Settings.get("updatesMode", "avisar")
                onPicked: k => Settings.set("updatesMode", k)
            }
            SwRow {
                visible: Pkg.family === "arch"
                label: "Punto de restauración en cada instalación"; sub: root.has["snap-pac"] ? "snap-pac instalado" : "instala snap-pac (también al instalar o quitar paquetes a mano)"
                checked: !!root.has["snap-pac"]; enabled: !root.has["snap-pac"]
                onToggled: v => { if (v) Pkg.runInTerminal("sudo pacman -S --needed snap-pac", "snap-pac"); }
            }
            SwRow { label: "Punto de restauración antes de actualizar"; sub: "snapper · se puede volver atrás desde el arranque"; key: "updatesSnapshot"; def: true }
            SwRow { label: "Incluir Flatpak"; sub: "flatpak update"; mono: true; key: "updatesFlatpak"; def: true; enabled: !!root.has["flatpak"] }
            SwRow { label: "Firmware"; sub: root.has["fwupd"] ? "fwupdmgr" : "instala fwupd"; mono: true; key: "updatesFirmware"; def: true; enabled: !!root.has["fwupd"] }
        }
        // ---------- copia de los ajustes (~/.config/hyprfrijol/settings.json) → services/SettingsIO.qml ----------
        Section {
            Layout.fillWidth: true
            title: "Tus ajustes"
            headerRight: Mono { tech: true; text: "settings.json" }
            InfoRow {
                separator: false
                label: "Exportar ajustes"; sub: "una copia de settings.json, en Documentos"; icon: "upload"
                Button { text: "Exportar…"; enabled: !SettingsIO.busy; onClicked: SettingsIO.exportFile() }
            }
            InfoRow {
                label: "Importar ajustes"; sub: "se mezclan con los actuales · se puede deshacer"; icon: "download"
                Button { text: "Importar…"; enabled: !SettingsIO.busy; onClicked: SettingsIO.importFile() }
            }
            Txt {
                visible: SettingsIO.msg !== ""
                Layout.fillWidth: true
                text: SettingsIO.msg
                size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: SettingsIO.bad ? Theme.danger : Theme.tv
            }
        }
        Section {
            visible: !root.app
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Txt { Layout.fillWidth: true; text: "Apps predeterminadas e inicio"; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; muted: true; size: 11.5; text: "Navegador, correo, fotos, PDF e inicio de sesión" }
                }
                Button { text: "Abrir"; onClicked: Shell.open("ajustesapp", "predeterminadas") }
            }
        }
    }
}
