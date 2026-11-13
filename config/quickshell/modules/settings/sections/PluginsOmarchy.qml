// Ajustes › Plugins de Omarchy — capa de compatibilidad con los plugins y temas de la shell de Omarchy.
// Todo el trabajo lo hace scripts/hf-plugin (añadir, validar, activar, quitar, «probado», importar colors.toml);
// aquí se enseña su estado (services/OmarchyPlugins.qml) y se pide confirmación antes de lo que ejecuta código:
// añadir no ejecuta nada; activar enseña el origen y avisa de que es código sin aislar.
// Ajustes: omarchyPlugins (interruptor general) y omarchyBarSlot (hueco de los widgets en la barra).
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
    PluginsTabs { current: "omarchy" }   // Hyprland | Omarchy (una sola entrada en la lista)

    property string msg: ""
    property bool msgBad: false
    property string confirmId: ""           // plugin cuya activación se está confirmando
    property string removeId: ""            // plugin cuya eliminación se está confirmando
    property string addSrc: ""              // origen que se está confirmando para añadir
    property string busy: ""
    property var themes: ({})
    readonly property var list: OmarchyPlugins.plugins
    readonly property int nOn: list.filter(p => p.enabled).length
    readonly property var kindNames: ({ "bar-widget": "Widget de barra", panel: "Panel", overlay: "Superposición", menu: "Menú", service: "Servicio", bar: "Barra completa" })
    readonly property bool isGit: /^(https?:\/\/|ssh:\/\/|git:\/\/|git@)/.test(addSrc)

    function say(t, bad) { msg = t; msgBad = !!bad; }
    function run(args, what) {
        if (runner.running) return;
        busy = what;
        runner.command = [Paths.script("hf-plugin")].concat(args).concat(["--yes"]);
        runner.what = what;
        runner.running = true;
    }
    function sourceText(p) {
        const s = p.source ?? {};
        return s.type === "git" ? "git · " + s.where + (s.commit ? " @ " + s.commit.slice(0, 8) : "")
             : s.type === "local" ? "carpeta · " + s.where : "copiado a mano · " + p.dir;
    }
    Process {
        id: runner
        property string what: ""
        stdout: StdioCollector { id: outC }
        stderr: StdioCollector { id: errC }
        onExited: code => {
            const out = (errC.text.trim() || outC.text.trim()).split("\n").filter(l => l && !/^Los plugins de Omarchy son código|hacer tu usuario|^Origen:|^Plugin:/.test(l)).slice(-3).join(" ");
            root.say(code === 0 ? (out || "Hecho.") : out.replace(/^hf-plugin: /, ""), code !== 0);
            root.busy = "";
            OmarchyPlugins.refresh();
            themeLister.running = true;
        }
    }
    Process {
        id: themeLister
        running: true
        command: [Paths.script("hf-plugin"), "themes", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.themes = JSON.parse(text || "{}"); } catch (e) { root.themes = {}; } } }
    }

    // ---------- aviso / resultado ----------
    Rectangle {
        visible: root.msg !== ""
        Layout.fillWidth: true
        implicitHeight: msgRow.implicitHeight + 16
        radius: Theme.r(6)
        color: root.msgBad ? Qt.alpha(Theme.danger, 0.14) : Theme.selBg
        RowLayout {
            id: msgRow
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
            Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.msg; color: root.msgBad ? Theme.danger : Theme.selText; weight: Font.Medium }
            Button { h: 26; kind: "link"; text: "✕"; onClicked: root.msg = "" }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Plugins de Omarchy"
        headerRight: [
            Button { h: 28; text: "Volver a leer"; onClicked: { OmarchyPlugins.refresh(); themeLister.running = true; } }
        ]
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Carga los plugins de la shell de Omarchy (Quickshell): widgets de barra, paneles, superposiciones, menús y servicios. "
                + "Las barras completas no están soportadas. Usan qs.Commons y qs.Ui de Omarchy, que aquí se traducen al tema de HyprFrijol. "
                + (root.list.length ? root.nOn + (root.nOn === 1 ? " activado" : " activados") + " de " + root.list.length + "." : "Aún no hay ninguno.")
        }
        SwRow {
            label: "Cargar los plugins de Omarchy"
            sub: "Si lo apagas, no se carga ninguno (siguen instalados)"
            key: "omarchyPlugins"; def: true
        }
        LabeledRow {
            label: "Widgets en la barra"
            hint: "dónde van los widgets de barra de los plugins"
            Seg {
                model: [["izquierda", "Tras los espacios"], ["derecha", "Junto a la bandeja"]]
                current: Settings.get("omarchyBarSlot", "derecha")
                fill: false; pill: true
                onPicked: k => Settings.set("omarchyBarSlot", k)
            }
        }
    }

    // ---------- añadir ----------
    Section {
        Layout.fillWidth: true
        title: "Añadir un plugin"
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Una URL de git (se clona en ~/.local/share/hyprfrijol/plugins/<id>) o una carpeta con su manifest.json. Se comprueba el manifiesto y se deja desactivado: al añadirlo no se ejecuta nada. Catálogo: plugins.omarchy.org."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: srcField; Layout.fillWidth: true; icon: "globe"; placeholder: "https://github.com/autor/plugin.git  o  ~/carpeta/del/plugin" }
            Button { kind: "primary"; text: "Añadir…"; enabled: srcField.text.trim() !== "" && !runner.running; onClicked: root.addSrc = srcField.text.trim() }
        }
        Rectangle {
            visible: root.addSrc !== ""
            Layout.fillWidth: true
            implicitHeight: addBox.implicitHeight + 20
            radius: Theme.r(6)
            color: Qt.alpha(Theme.danger, 0.10)
            border.width: 1; border.color: Qt.alpha(Theme.danger, 0.4)
            ColumnLayout {
                id: addBox
                anchors.fill: parent; anchors.margins: 10
                spacing: 6
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; weight: Font.DemiBold; text: root.isGit ? "¿Clonar este repositorio?" : "¿Copiar esta carpeta?" }
                Mono { Layout.fillWidth: true; text: root.addSrc; wrapMode: Text.WrapAnywhere }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; text: "Los plugins son código sin aislar: al activarlos se ejecutan dentro de la shell con todo lo que puede hacer tu usuario. Añadirlo solo copia los archivos; léelo antes de activarlo." }
                RowLayout {
                    spacing: 8
                    Button { kind: "primary"; text: root.isGit ? "Clonar" : "Copiar"; onClicked: { root.run(["add", root.addSrc], "add"); root.addSrc = ""; srcField.text = ""; } }
                    Button { text: "Cancelar"; onClicked: root.addSrc = "" }
                }
            }
        }
    }

    // ---------- instalados ----------
    Section {
        Layout.fillWidth: true
        title: "Instalados"
        visible: root.list.length > 0
        Repeater {
            model: root.list
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var p: modelData
                readonly property string err: OmarchyPlugins.errors[p.id] ?? ""
                readonly property bool viewKind: OmarchyPlugins.isView(p)
                Layout.fillWidth: true
                spacing: 6
                Rectangle { visible: row.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Txt { text: row.p.name; weight: Font.DemiBold; size: 13 }
                            Txt { text: row.p.version ? "v" + row.p.version : ""; muted: true; size: 11 }
                            Chip { h: 22; mark: false; on: row.p.tested === "probado"; text: row.p.tested === "probado" ? "Probado" + (row.p.testedBy === "tú" ? " (tú)" : "") : "No probado" }
                            Chip { h: 22; mark: false; visible: !row.p.valid; on: true; text: "No válido" }
                            Chip { h: 22; mark: false; visible: row.p.valid && !row.p.supported; on: true; text: "Sin soporte" }
                            Chip { h: 22; mark: false; visible: row.err !== ""; on: true; text: "Error al cargar" }
                        }
                        Mono { text: row.p.id + " · " + row.p.kinds.map(k => root.kindNames[k] ?? k).join(" + ") + (row.p.author ? " · " + row.p.author : "") }
                        Txt { Layout.fillWidth: true; visible: row.p.description !== ""; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: row.p.description; textFormat: Text.PlainText }
                        Txt { Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WrapAnywhere; text: "Origen: " + root.sourceText(row.p); textFormat: Text.PlainText }
                        Txt { Layout.fillWidth: true; visible: row.p.unsupportedKinds.length > 0 && row.p.supported; size: 11; muted: true; wrapMode: Text.WordWrap; text: "Se ignora: " + row.p.unsupportedKinds.map(k => root.kindNames[k] ?? k).join(", ") + " (no soportado)." }
                        Txt { Layout.fillWidth: true; visible: row.p.errors.length > 0 || row.err !== ""; size: 11; color: Theme.danger; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: row.p.errors.concat(row.err ? [row.err] : []).join("\n") }
                    }
                    Sw {
                        checked: row.p.enabled
                        enabled: row.p.supported && !runner.running
                        onToggled: v => { if (v) root.confirmId = row.p.id; else { root.confirmId = ""; root.run(["disable", row.p.id], "disable"); } }
                    }
                }
                // Confirmación antes de activar: origen + aviso
                Rectangle {
                    visible: root.confirmId === row.p.id
                    Layout.fillWidth: true
                    implicitHeight: cBox.implicitHeight + 20
                    radius: Theme.r(6)
                    color: Qt.alpha(Theme.danger, 0.10)
                    border.width: 1; border.color: Qt.alpha(Theme.danger, 0.4)
                    ColumnLayout {
                        id: cBox
                        anchors.fill: parent; anchors.margins: 10
                        spacing: 6
                        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; weight: Font.DemiBold; text: "¿Activar «" + row.p.name + "»?"; textFormat: Text.PlainText }
                        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; text: "Es código sin aislar: se ejecutará dentro de la shell con acceso a tus archivos, la red y tus programas. " + (row.p.tested === "probado" ? "Está marcado como probado en HyprFrijol." : "No está probado en HyprFrijol: puede fallar o verse distinto que en Omarchy.") }
                        Mono { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; text: root.sourceText(row.p) + "\n" + row.p.dir }
                        RowLayout {
                            spacing: 8
                            Button { kind: "primary"; text: "Activar"; onClicked: { root.run(["enable", row.p.id], "enable"); root.confirmId = ""; } }
                            Button { text: "Cancelar"; onClicked: root.confirmId = "" }
                        }
                    }
                }
                RowLayout {
                    spacing: 8
                    visible: row.p.valid
                    Chip { h: 26; visible: row.p.kinds.includes("bar-widget") && row.p.enabled; text: "En la barra"; on: row.p.inBar; onClicked: root.run(["bar", row.p.id, row.p.inBar ? "off" : "on"], "bar") }
                    Button { h: 26; visible: row.p.enabled && (row.viewKind || row.p.kinds.includes("bar-widget")); text: "Abrir"; onClicked: { OmarchyPlugins.summon(row.p.id, ""); } }
                    Button { h: 26; text: row.p.tested === "probado" && row.p.testedBy === "tú" ? "Quitar «probado»" : "Marcar como probado"; visible: row.p.testedBy !== "hyprfrijol"; onClicked: root.run(["mark", row.p.id, row.p.tested === "probado" ? "no-probado" : "probado"], "mark") }
                    Item { Layout.fillWidth: true }
                    Button { h: 26; kind: "link"; text: root.removeId === row.p.id ? "¿Borrar su carpeta? Sí, quitar" : "Quitar"; onClicked: { if (root.removeId === row.p.id) { root.run(["remove", row.p.id], "remove"); root.removeId = ""; } else root.removeId = row.p.id; } }
                }
            }
        }
    }

    // ---------- temas ----------
    Section {
        Layout.fillWidth: true
        title: "Temas de Omarchy"
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Importa el colors.toml de un tema de Omarchy (archivo, carpeta del tema o URL de git) como una paleta más de Ajustes › Apariencia (grupo «Importadas»). Se guarda en ~/.config/hyprfrijol/palettes-user.json."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: themeField; Layout.fillWidth: true; icon: "palette"; placeholder: "~/temas/mi-tema/colors.toml  o  https://github.com/autor/omarchy-tema.git" }
            Button { kind: "primary"; text: "Importar"; enabled: themeField.text.trim() !== "" && !runner.running; onClicked: { root.run(["theme", themeField.text.trim()], "theme"); themeField.text = ""; } }
        }
        Repeater {
            model: Object.keys(root.themes)
            RowLayout {
                required property string modelData
                readonly property var t: root.themes[modelData]
                Layout.fillWidth: true
                spacing: 8
                Row {
                    spacing: 3
                    Repeater { model: [t.bg, t.s3, t.p, t.ter, t.t]; Rectangle { required property var modelData; width: 14; height: 14; radius: 7; color: modelData; border.width: 1; border.color: Theme.ov } }
                }
                Txt { text: t.name; weight: Font.Medium; textFormat: Text.PlainText }
                Txt { text: t.light ? "claro" : "oscuro"; muted: true; size: 11 }
                Item { Layout.fillWidth: true }
                Button { h: 26; kind: Settings.get("palette", "") === modelData && Settings.get("colorMode", "auto") === "elegir" ? "primary" : "outline"; text: "Usar"; onClicked: Settings.setMany({ colorMode: "elegir", palette: modelData }) }
                Button { h: 26; kind: "link"; text: "Quitar"; onClicked: root.run(["theme-remove", modelData], "theme-remove") }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Desde la terminal"
        Mono { tech: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "hf-plugin add <url|carpeta> · list · enable <id> · disable <id> · remove <id>\nhf-plugin summon <id> [payload]   (= omarchy-shell shell summon)\nqs -p " + Paths.root.replace(Paths.home, "~") + "/config/quickshell ipc call shell open omarchy:<id>\nhf-plugin theme <colors.toml|carpeta|url> [--apply]" }
    }
}
