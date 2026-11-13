// Ajustes › Almacenamiento — unidades extraíbles (memorias USB, tarjetas SD: services/Devices ← scripts/hf-devices),
// discos internos con su espacio (hf-devices list --all), qué pasa al conectar una (devicesAutomount,
// devicesOpenOnPlug, devicesNotify), icono de la barra (devicesBarIcon), GNOME Discos, y las descargas
// (scripts/hf-download): carpeta por tipo (downloadsVideoPath/AudioPath/ImagePath/FilePath; vacía = la de XDG),
// formatos (downloadsVideoFormat, downloadsAudioFormat), a la vez (downloadsParallel), aviso (downloadsNotify), reanudar al iniciar sesión (downloadsResume),
// historial (downloadsHistory) e indicador de la barra (downloadsBarIcon).
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
    property var internal: []          // discos internos montados (hf-devices list --json --all)
    property var tools: ({})           // hf-download tools
    property bool hasDisks: false

    function refresh(): void { disks.running = false; disks.running = true; }
    Timer { interval: 10000; running: Shell.settingsSeen; repeat: true; onRunningChanged: if (running) triggered(); onTriggered: root.refresh() }
    Process {
        id: disks
        running: true
        command: [Paths.script("hf-devices"), "list", "--json", "--all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text).filter(d => !d.removable && d.mounted);
                    const seen = {};
                    root.internal = all.filter(d => { const k = d.dev; if (seen[k]) return false; seen[k] = true; return true; })
                        .sort((a, b) => a.mountpoint.length - b.mountpoint.length);
                } catch (e) {}
            }
        }
    }
    Process {
        id: tl
        running: true
        command: ["sh", "-c", Paths.script("hf-download") + " tools; command -v gnome-disks >/dev/null && echo disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                try { root.tools = JSON.parse(l[0]); } catch (e) {}
                root.hasDisks = l.includes("disks");
            }
        }
    }
    Timer { id: toolsLater; interval: 20000; repeat: true; property int n: 0; onTriggered: { tl.running = false; tl.running = true; if (++n > 9) { stop(); n = 0; } } }
    // gallery-dl no está en los repos oficiales de Arch: solo en AUR (con yay/paru)
    readonly property var aurOnly: ["gallery-dl"]
    function install(pkgs, title): void { Pkg.install(pkgs.map(p => ({ src: aurOnly.includes(p) ? "AUR" : "Repos", pkg: p })), title); toolsLater.restart(); }

    component UsageBar: Rectangle {
        property real used: 0
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Theme.fill2
        Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.used)); height: parent.height; radius: 3; color: parent.used > 0.9 ? Theme.danger : Theme.p }
    }
    component DiskRow: ColumnLayout {
        id: dr
        property var d: ({})
        property bool removable: false
        readonly property real used: d.size > 0 && d.avail !== null && d.avail !== undefined ? 1 - d.avail / d.size : 0
        Layout.fillWidth: true
        spacing: 4
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt { Layout.fillWidth: true; text: dr.d.name + (dr.removable ? "" : dr.d.mountpoint === "/" ? " · sistema" : ""); weight: Font.DemiBold }
                Txt {
                    Layout.fillWidth: true
                    text: (dr.d.mounted ? dr.d.mountpoint + " · " : "sin montar · ") + (dr.d.fstype ?? "") + (dr.removable ? " · " + Devices.kindName(dr.d.kind) : "")
                    muted: true; size: 11; font.family: Theme.mono
                }
            }
            Txt {
                visible: dr.d.mounted
                text: Devices.human(dr.d.avail) + " libres de " + Devices.human(dr.d.size)
                muted: true; size: 11.5; tabular: true
            }
            Button {
                visible: dr.removable
                text: dr.d.mounted ? "Abrir" : "Montar"
                h: 26
                onClicked: Devices.open(dr.d.dev)
            }
            Button {
                visible: dr.removable
                text: Devices.busy === dr.d.dev ? "Expulsando…" : "Expulsar"
                h: 26
                enabled: Devices.busy === ""
                onClicked: Devices.eject(dr.d.dev)
            }
        }
        UsageBar { visible: dr.d.mounted; used: dr.used }
    }

    // ------------------------------------------------------------------ izquierda: unidades y discos
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1.15
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Unidades extraíbles"
            // La lista con Abrir y Expulsar es la del icono de la barra (w-dispositivos): aquí solo cuántas hay
            headerRight: Button {
                visible: Devices.list.length > 0
                text: "Ver las unidades"; h: 26
                onClicked: Shell.open("w-dispositivos")
            }
            Txt {
                Layout.fillWidth: true
                text: Devices.list.length === 0
                    ? "Conecta una memoria USB o una tarjeta SD: saldrá un aviso con «Abrir» y «Expulsar», y un icono en la barra."
                    : Devices.list.length === 1 ? "Hay una unidad conectada: «" + (Devices.list[0].label || Devices.list[0].name || "sin nombre") + "»."
                    : "Hay " + Devices.list.length + " unidades conectadas."
                muted: Devices.list.length === 0; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Al conectar una unidad"
            SwRow { separator: false; label: "Montar automáticamente"; sub: "memorias USB y tarjetas, en /run/media (udisks2)"; key: "devicesAutomount"; def: true }
            SwRow { label: "Abrir al conectar"; sub: "abre la carpeta en el gestor de archivos"; key: "devicesOpenOnPlug"; def: false }
            SwRow { label: "Aviso con «Abrir» y «Expulsar»"; sub: "notificación al conectarla"; key: "devicesNotify"; def: true }
            SwRow { label: "Icono en la barra"; sub: "solo mientras haya alguna montada"; key: "devicesBarIcon"; def: true }
        }
        Section {
            Layout.fillWidth: true
            title: "Discos internos"
            headerRight: Button {
                text: root.hasDisks ? "Abrir GNOME Discos" : "Instalar GNOME Discos"
                h: 26
                onClicked: root.hasDisks ? Devices.openDisks() : root.install(["gnome-disk-utility"], "GNOME Discos")
            }
            Repeater {
                model: root.internal
                DiskRow { required property var modelData; d: modelData }
            }
            Txt {
                Layout.fillWidth: true
                text: "Formatear, particionar o comprobar la salud de un disco: GNOME Discos. Desde aquí los internos no se desmontan ni se expulsan."
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
    }

    // ------------------------------------------------------------------ derecha: descargas
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Descargas"
            headerRight: Button { text: "Ver la cola"; h: 26; onClicked: Shell.open("w-descargas") }
            Txt {
                Layout.fillWidth: true
                text: "Pega un enlace en el indicador de la barra o escribe «descargar <dirección>» en Spotlight. Vídeo y audio con yt-dlp, galerías con gallery-dl y archivos con aria2c; la herramienta se elige sola."
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
            Repeater {
                model: [["yt-dlp", "yt-dlp", "vídeo y audio"], ["gallery-dl", "gallery-dl", "álbumes de imágenes (Pinterest, Instagram, Reddit, wallhaven…) · opcional"], ["aria2c", "aria2", "archivos grandes, por varias conexiones · opcional"], ["ffmpeg", "ffmpeg", "convertir a mp3/opus"]]
                RowLayout {
                    required property var modelData
                    readonly property bool ok: !!root.tools[modelData[0]]
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: parent.ok ? Theme.p : Theme.ov }
                    Txt { text: parent.modelData[0]; weight: Font.DemiBold; font.family: Theme.mono; size: 12 }
                    Txt { Layout.fillWidth: true; text: parent.ok ? parent.modelData[2] : "no instalado · " + parent.modelData[2]; muted: true; size: 11.5 }
                    Button { visible: !parent.ok; text: "Instalar"; h: 24; onClicked: root.install([parent.modelData[1]], "Descargas (" + parent.modelData[1] + ")") }
                }
            }
            LabeledRow {
                label: "Vídeo"; labelWidth: 90
                Seg {
                    h: 28
                    model: [["best", "La mejor"], ["1080", "1080p"], ["720", "720p"], ["480", "480p"]]
                    current: Settings.get("downloadsVideoFormat", "best")
                    onPicked: k => Settings.set("downloadsVideoFormat", k)
                }
            }
            LabeledRow {
                label: "Audio"; labelWidth: 90
                Seg {
                    h: 28
                    model: [["mp3", "MP3"], ["opus", "Opus"], ["m4a", "M4A"]]
                    current: Settings.get("downloadsAudioFormat", "mp3")
                    onPicked: k => Settings.set("downloadsAudioFormat", k)
                }
            }
            LabeledRow {
                label: "A la vez"; labelWidth: 90
                Pills { model: [1, 2, 3, 4]; current: Settings.get("downloadsParallel", 2); onPicked: v => Settings.set("downloadsParallel", v) }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Carpetas"
            Repeater {
                model: [["downloadsVideoPath", "Vídeos", "Vídeos (XDG)"], ["downloadsAudioPath", "Música", "Música (XDG)"],
                        ["downloadsImagePath", "Imágenes", "Imágenes (XDG)"], ["downloadsFilePath", "Archivos", "Descargas (XDG)"]]
                LabeledRow {
                    id: fr
                    required property var modelData
                    label: modelData[1]; labelWidth: 90
                    Field {
                        h: 28
                        icon: "folder"
                        textSize: 12
                        placeholder: fr.modelData[2]
                        text: Settings.get(fr.modelData[0], "")
                        onAccepted: Settings.set(fr.modelData[0], text.trim())
                        input.onActiveFocusChanged: if (!input.activeFocus && text.trim() !== Settings.get(fr.modelData[0], "")) Settings.set(fr.modelData[0], text.trim())
                    }
                }
            }
            Txt { Layout.fillWidth: true; text: "Vacía = la carpeta de tu usuario para ese tipo. Admite ~/…"; muted: true; size: 11 }
        }
        Section {
            Layout.fillWidth: true
            title: "Avisos y privacidad"
            SwRow { label: "Avisar al terminar"; sub: "con «Abrir carpeta»"; key: "downloadsNotify"; def: true }
            SwRow { separator: false; label: "Reanudar al iniciar sesión"; sub: "las que quedaron a medias al apagar o cerrar la sesión"; key: "downloadsResume"; def: true }
            SwRow { label: "Indicador en la barra"; sub: "número de descargas y progreso, solo mientras hay alguna"; key: "downloadsBarIcon"; def: true }
            SwRow { label: "Guardar el historial"; sub: "si lo apagas, las terminadas se quitan de la lista al acabar"; key: "downloadsHistory"; def: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt {
                    Layout.fillWidth: true
                    text: "Las direcciones solo se guardan en tu equipo (~/.local/state/hyprfrijol/downloads): cada descarga habla solo con su web, y la IA las ve solo si la dejas consultar el escritorio (Ajustes › IA)."
                    muted: true; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
                Button { text: "Borrar historial"; h: 26; onClicked: Downloads.clear() }
            }
        }
    }
}
