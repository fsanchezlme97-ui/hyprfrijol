// Ajustes › Asistente de IA › Integraciones: el servidor MCP de HyprFrijol (scripts/hf-mcp, para usar el escritorio
// desde Claude u otro cliente: comando para añadirlo y sus herramientas, de `hf-ai tools`) y los servidores MCP del
// usuario que puede usar el asistente (aiMcpServers: [{id, name, command | url, authEnv, enabled, autoRead}]). Cada
// servidor se aprueba aparte (enabled); al añadirlo o con «Comprobar», `hf-ai mcp check <id>` lee sus herramientas.
// Todo se confirma en el panel viendo los argumentos, salvo las de solo lectura de un servidor con «Consultar sin
// preguntar» (autoRead). Las claves van en variables de entorno (authEnv), no aquí; por URL, solo https.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    AiTabs { current: "iaintegraciones" }

    readonly property var servers: Settings.get("aiMcpServers", []) ?? []
    readonly property bool localOnly: Settings.get("aiLocalOnly", false) === true
    property var info: ({})            // hf-ai mcp list → { id: { tools, checked, error } }
    property var ownTools: []          // hf-ai tools
    property string checking: ""
    property string msg: ""
    property bool msgErr: false
    readonly property string addCmd: "claude mcp add hyprfrijol -- " + Paths.root + "/scripts/hf-mcp"

    function reload() { lister.running = false; lister.running = true; }
    Process {
        id: lister
        running: true
        command: [Paths.script("hf-ai"), "mcp", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text), m = {};
                    for (const s of j.servers ?? []) m[s.id] = s;
                    root.info = m;
                } catch (e) {}
            }
        }
    }
    Process {
        running: true
        command: [Paths.script("hf-ai"), "tools"]
        stdout: StdioCollector { onStreamFinished: { try { root.ownTools = JSON.parse(text) ?? []; } catch (e) {} } }
    }
    function check(id) {
        checking = id;
        checker.command = [Paths.script("hf-ai"), "mcp", "check", id];
        checker.running = true;
    }
    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.msgErr = !j.ok;
                    root.msg = j.ok ? (j.tools.length === 1 ? "1 herramienta" : j.tools.length + " herramientas") + " encontradas." : j.error;
                } catch (e) { root.msgErr = true; root.msg = "No se pudo comprobar."; }
                root.checking = "";
                root.reload();
            }
        }
    }
    function slug(t) {
        return String(t).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "servidor";
    }
    function add() {
        const name = nameF.text.trim(), where = whereF.text.trim();
        if (!name || !where) return;
        let id = slug(name), n = 2;
        while (servers.some(s => s.id === id)) id = slug(name) + "-" + n++;
        const isUrl = /^https?:\/\//.test(where);
        const srv = Object.assign({ id: id, name: name, enabled: false }, isUrl ? { url: where } : { command: where },
                                  envF.text.trim() ? { authEnv: envF.text.trim() } : {});
        Settings.set("aiMcpServers", servers.concat([srv]));
        nameF.text = ""; whereF.text = ""; envF.text = "";
        Qt.callLater(() => root.check(id));
    }
    function setEnabled(id, on) { Settings.set("aiMcpServers", servers.map(s => s.id === id ? Object.assign({}, s, { enabled: on }) : s)); }
    function setAutoRead(id, on) { Settings.set("aiMcpServers", servers.map(s => s.id === id ? Object.assign({}, s, { autoRead: on }) : s)); }
    function remove(id) { Settings.set("aiMcpServers", servers.filter(s => s.id !== id)); }

    Section {
        Layout.fillWidth: true
        title: "Servidores MCP para el asistente"
        headerRight: Mono { tech: true; text: "hf-ai mcp" }
        Txt {
            Layout.fillWidth: true
            text: "Conecta herramientas de fuera (calendario, GitHub, notas, archivos…) con servidores MCP. Cada uno se aprueba aparte: "
                + "hasta que lo actives, el asistente no lo ve. Cada vez que quiera usar una herramienta te enseña lo que va a mandar "
                + "y te pide confirmación; lo que cambia algo no se puede deshacer desde aquí."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Txt {
            visible: root.localOnly
            Layout.fillWidth: true
            text: "Con «Solo en este equipo» activado el asistente no usa ningún servidor externo."
            color: Theme.ter; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }

        Repeater {
            model: root.servers
            ColumnLayout {
                id: sv
                required property var modelData
                required property int index
                readonly property var st: root.info[modelData.id] ?? {}
                readonly property var tools: st.tools ?? []
                readonly property int nRead: tools.filter(t => t.readOnly).length
                Layout.fillWidth: true
                spacing: 6
                Rectangle { visible: sv.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: sv.modelData.name || sv.modelData.id; weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: sv.modelData.url || sv.modelData.command || ""
                            size: 11; muted: true; font.family: Theme.mono; elide: Text.ElideMiddle
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: root.checking === sv.modelData.id ? "Comprobando…"
                                : sv.st.urlProblem ? sv.st.urlProblem
                                : sv.st.error ? "No responde: " + sv.st.error
                                : !sv.st.checked ? "Sin comprobar"
                                : (sv.tools.length === 1 ? "1 herramienta" : sv.tools.length + " herramientas")
                                  + (sv.tools.length ? " · " + sv.nRead + " de solo lectura" : "")
                                  + (sv.modelData.authEnv ? " · clave en $" + sv.modelData.authEnv : "")
                            size: 11.5
                            color: sv.st.error || sv.st.urlProblem ? Theme.ter : sv.modelData.enabled ? Theme.p : Theme.tv
                            wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                    }
                    Button { text: "Comprobar"; enabled: root.checking === ""; onClicked: root.check(sv.modelData.id) }
                    Button { kind: "link"; text: "Quitar"; onClicked: root.remove(sv.modelData.id) }
                    Sw {
                        checked: sv.modelData.enabled === true
                        enabled: !root.localOnly
                        onToggled: v => root.setEnabled(sv.modelData.id, v)
                    }
                }
                // Consultas de solo lectura sin confirmar: opción del usuario (readOnlyHint lo declara el servidor)
                RowLayout {
                    visible: sv.modelData.enabled === true && sv.nRead > 0
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: "Consultar sin preguntar"; size: 12 }
                        Txt {
                            Layout.fillWidth: true
                            text: (sv.nRead === 1 ? "Usa su herramienta de solo lectura" : "Usa sus " + sv.nRead + " herramientas de solo lectura")
                                + " sin confirmar, salvo cuando ya ha leído datos "
                                + "en esa respuesta. Que sean de solo lectura lo dice el propio servidor: actívalo solo si te fías de él."
                            muted: true; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                    }
                    Sw {
                        checked: sv.modelData.autoRead === true
                        enabled: !root.localOnly
                        onToggled: v => root.setAutoRead(sv.modelData.id, v)
                    }
                }
                // Sus herramientas: las que cambian algo, marcadas
                Flow {
                    visible: sv.tools.length > 0
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: sv.tools.slice(0, 40)
                        Rectangle {
                            required property var modelData
                            implicitHeight: 20
                            implicitWidth: tl.implicitWidth + 14
                            radius: Theme.r(5)
                            color: modelData.readOnly ? Theme.fill2 : Qt.alpha(Theme.ter, 0.16)
                            Txt { id: tl; anchors.centerIn: parent; text: (modelData.title || modelData.name) + (modelData.readOnly ? "" : " · cambia"); size: 10.5 }
                            MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true }
                            HoverTip { shown: tma.containsMouse && text !== ""; text: parent.modelData.description ?? "" }
                        }
                    }
                }
            }
        }
        Txt {
            visible: root.servers.length === 0
            Layout.fillWidth: true
            text: "Aún no has añadido ninguno."
            muted: true; size: 11.5
        }

        // Añadir
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: nameF; Layout.preferredWidth: 150; h: 30; icon: ""; placeholder: "Nombre" }
            Field {
                id: whereF
                Layout.fillWidth: true; h: 30; icon: ""
                placeholder: "Comando (npx -y @modelcontextprotocol/server-…) o dirección https://…"
                onAccepted: root.add()
            }
            Field { id: envF; Layout.preferredWidth: 150; h: 30; icon: ""; placeholder: "Variable de la clave" }
            Button { kind: "primary"; text: "Añadir"; enabled: nameF.text.trim() !== "" && whereF.text.trim() !== ""; onClicked: root.add() }
        }
        Txt {
            Layout.fillWidth: true
            text: root.msg !== "" ? root.msg
                : "Se añade sin permiso: actívalo con su interruptor cuando hayas visto sus herramientas. La clave (si la pide) se lee de "
                  + "esa variable de entorno; nunca se guarda en los ajustes."
            color: root.msgErr ? Theme.ter : Theme.tv
            size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Usar HyprFrijol desde Claude"
        headerRight: Mono { tech: true; text: "hf-mcp" }
        Txt {
            Layout.fillWidth: true
            text: "El servidor MCP de HyprFrijol deja que Claude Code, Claude Desktop u otro cliente MCP use tu escritorio con las mismas "
                + "herramientas y permisos que el asistente. Para añadirlo a Claude Code:"
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.r(6)
                color: Theme.fill2
                Txt { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; text: root.addCmd; font.family: Theme.mono; size: 11.5; elide: Text.ElideMiddle }
            }
            Button {
                text: copied.running ? "Copiado" : "Copiar"
                onClicked: { Quickshell.execDetached(["wl-copy", "--", root.addCmd]); copied.restart(); }
            }
            Timer { id: copied; interval: 1500 }
        }
        Txt {
            visible: root.ownTools.length > 0
            Layout.fillWidth: true
            text: root.ownTools.length + " herramientas: " + root.ownTools.filter(t => !t.approval).length + " de consulta y "
                + root.ownTools.filter(t => t.approval).length + " que cambian algo (el cliente te pide permiso para esas)."
            size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Flow {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: root.ownTools
                Rectangle {
                    required property var modelData
                    implicitHeight: 20
                    implicitWidth: ot.implicitWidth + 14
                    radius: Theme.r(5)
                    color: modelData.approval ? Qt.alpha(Theme.ter, 0.16) : Theme.fill2
                    Txt { id: ot; anchors.centerIn: parent; text: parent.modelData.name; size: 10.5; font.family: Theme.mono }
                    MouseArea { id: oma; anchors.fill: parent; hoverEnabled: true }
                    HoverTip { shown: oma.containsMouse && text !== ""; text: parent.modelData.description ?? "" }
                }
            }
        }
    }

    // ---------- «Seguir en…» del panel (aiHandoff · aiHandoffCmd · aiHandoffLabel; hf-ai handoff-targets) ----------
    property var hoTargets: []
    property var hoCurrent: null
    readonly property string hoMode: Settings.get("aiHandoff", "auto")
    readonly property string hoKey: hoMode + "|" + Settings.get("aiHandoffCmd", "") + "|" + Settings.get("aiHandoffLabel", "")
    onHoKeyChanged: { hoProc.running = false; hoProc.running = true; }
    Process {
        id: hoProc
        running: true
        command: [Paths.script("hf-ai"), "handoff-targets"]
        stdout: StdioCollector {
            onStreamFinished: { try { const j = JSON.parse(text); root.hoTargets = j.targets; root.hoCurrent = j.current; } catch (e) {} }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Seguir la conversación en…"
        headerRight: Mono { text: root.hoCurrent ? "botón «Seguir en " + root.hoCurrent.label + "»" : "sin botón" }
        Txt {
            Layout.fillWidth: true
            text: "El botón del panel lleva la conversación y el contexto que elegiste a otra herramienta de IA. Las de terminal "
                + "(Claude Code, Codex, Gemini CLI…) la reciben como mensaje; las de ventana (T3 Code, Claude Desktop, Cursor, Zed) "
                + "se abren con la conversación en el portapapeles. Para cualquier otra, escribe su orden."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        LabeledRow {
            label: "Herramienta"; labelWidth: 120
            Dropdown {
                model: [["auto", "Automática"], ["off", "Ninguna (sin botón)"]]
                    .concat(root.hoTargets.map(t => [t.id, t.label]))
                    .concat([["custom", "Otra (escribe su orden)"]])
                current: root.hoMode
                onPicked: k => Settings.set("aiHandoff", k)
            }
        }
        Txt {
            visible: root.hoMode === "auto"
            Layout.fillWidth: true
            text: (root.hoCurrent ? "Ahora: " + root.hoCurrent.label + ". " : "No hay ninguna instalada. ")
                + "Automática usa la de tu proveedor si la tienes; si no, la primera instalada."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        LabeledRow {
            visible: root.hoMode === "custom"
            label: "Orden"; labelWidth: 120
            hint: "{prompt} = el texto · {file} = un .md"
            Field {
                Layout.fillWidth: true
                placeholder: "kitty -e mi-agente --prompt {prompt}"
                text: Settings.get("aiHandoffCmd", "")
                onAccepted: Settings.set("aiHandoffCmd", text.trim())
            }
        }
        LabeledRow {
            visible: root.hoMode === "custom"
            label: "Nombre"; labelWidth: 120
            Field {
                Layout.fillWidth: true
                placeholder: "Mi agente"
                text: Settings.get("aiHandoffLabel", "")
                onAccepted: Settings.set("aiHandoffLabel", text.trim())
            }
        }
    }
}
