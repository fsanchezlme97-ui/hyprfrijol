// Ajustes › Asistente de IA › Inicio: la entrada de la sección. Estado en una línea (proveedor · modelo · si responde,
// de `hf-ai status`), «Probar conexión» (`hf-ai test`), un resumen de lo que más importa con enlace a la pestaña donde
// se cambia, y los atajos. Sin contador de uso ni de tokens: cada proveedor lo informa distinto (decisión del plan).
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
    AiTabs { current: "ia" }

    readonly property string prov: Settings.get("aiProvider", "claude-code")
    readonly property var provNames: ({ "claude-code": "Claude Code", gemini: "Gemini", ollama: "Ollama",
                                        "openai-compatible": "API compatible con OpenAI", mock: "Prueba", off: "Apagado" })
    readonly property bool localOnly: Settings.get("aiLocalOnly", false) === true
    readonly property string aiName: String(Settings.get("aiName", "") ?? "").trim()
    property var st: null              // hf-ai status
    property int recipeCount: -1
    property string testMsg: ""
    property bool testOk: false

    Process {
        id: stat
        running: true
        command: [Paths.script("hf-ai"), "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text); } catch (e) { root.st = null; } } }
    }
    // el estado cambia al tocar el proveedor o el modelo en otra pestaña
    Connections {
        target: Settings
        function onDataChanged() { statT.restart(); }
    }
    Timer { id: statT; interval: 700; onTriggered: { stat.running = false; stat.running = true; } }
    Process {
        running: true
        command: [Paths.script("hf-ai"), "recipes"]
        stdout: StdioCollector { onStreamFinished: { try { root.recipeCount = (JSON.parse(text) ?? []).length; } catch (e) {} } }
    }
    Process {
        id: tester
        command: [Paths.script("hf-ai"), "test"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.testOk = !!j.ok; root.testMsg = j.text; } catch (e) { root.testOk = false; root.testMsg = "No se pudo probar"; } } }
    }

    // «Gemini · gemini-flash-latest · listo»
    readonly property string effProv: localOnly && prov !== "off" ? "ollama" : prov
    readonly property string modelTxt: {
        if (localOnly && prov !== "ollama") return Settings.get("aiFallbackProvider", "") === "ollama" ? (Settings.get("aiFallbackModel", "") || "gemma4:e4b") : "gemma4:e4b";
        return st?.model || ({ "claude-code": "predeterminado", ollama: "gemma4:e4b", "openai-compatible": "gpt-4o-mini" })[prov] || "";
    }
    readonly property bool ready: prov !== "off" && !!st?.available
    readonly property string stateTxt: prov === "off" ? "apagado" : st === null ? "comprobando…" : st.available ? "listo" : (st.hint || "no disponible").toLowerCase()
    readonly property string line: prov === "off" ? "El asistente está apagado"
        : [provNames[effProv] ?? effProv, modelTxt, stateTxt].filter(Boolean).join(" · ")

    Section {
        Layout.fillWidth: true
        title: "Estado"
        headerRight: Mono { text: "hf-ai status · hf-ai test" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: Theme.r(12)
                color: root.ready ? Theme.pc : Theme.fill2
                Icon { anchors.centerIn: parent; name: "ai"; size: 21; color: root.ready ? Theme.pcText : Theme.tv }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { Layout.fillWidth: true; text: root.aiName || "Tu asistente"; size: 16; weight: Font.DemiBold }
                Txt {
                    Layout.fillWidth: true
                    text: root.line + (root.localOnly ? " · solo en este equipo" : "")
                    color: root.ready ? Theme.p : root.prov === "off" || root.st === null ? Theme.tv : Theme.ter
                    weight: Font.Medium
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
            }
            Button {
                visible: root.prov !== "off"
                text: tester.running ? "Probando…" : "Probar conexión"
                enabled: !tester.running
                onClicked: { root.testMsg = ""; tester.running = true; }
            }
            Button {
                visible: root.prov === "off" || (root.st !== null && !root.st.available)
                kind: "primary"
                text: root.prov === "off" ? "Elegir proveedor" : "Configurar"
                onClicked: Shell.open("ajustesapp", "iaproveedor")
            }
        }
        Txt {
            visible: root.testMsg !== ""
            Layout.fillWidth: true
            size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 3
            color: root.testOk ? Theme.p : Theme.ter
            text: root.testMsg
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 3
            Layout.alignment: Qt.AlignTop
            title: "Resumen"
            gap: 0
            LinkRow {
                separator: false
                label: "Proveedor y modelo"; section: "iaproveedor"; sectionLabel: "Proveedor y permisos"; target: "Proveedor"
                value: root.prov === "off" ? "Apagado" : (root.provNames[root.prov] ?? root.prov)
            }
            LinkRow {
                label: "Respaldo si no responde"; section: "iaproveedor"; sectionLabel: "Proveedor y permisos"; target: "Modelos"
                value: { const f = Settings.get("aiFallbackProvider", ""); return f ? (root.provNames[f] ?? f) : "Sin respaldo"; }
            }
            LinkRow {
                label: "Solo en este equipo"; section: "iaproveedor"; sectionLabel: "Proveedor y permisos"; target: "Modelos"
                value: root.localOnly ? "Sí" : "No"
            }
            LinkRow {
                label: "Confirmar antes de aplicar cambios"; section: "iaproveedor"; sectionLabel: "Proveedor y permisos"
                value: Settings.get("aiConfirm", true) !== false ? "Sí" : "No"
            }
            LinkRow {
                label: "Ocultar datos sensibles"; section: "iaprivacidad"; sectionLabel: "Privacidad"
                value: Settings.get("aiRedactSecrets", true) !== false ? "Activado" : "Apagado"
            }
            LinkRow {
                label: "Apps privadas"; section: "iaprivacidad"; sectionLabel: "Privacidad"
                value: { const l = Settings.get("privateApps", null); return Array.isArray(l) ? (l.length === 1 ? "1 app" : l.length + " apps") : "Gestores de contraseñas"; }
            }
            LinkRow {
                label: "Historial de conversaciones"; section: "iaprivacidad"; sectionLabel: "Privacidad"; target: "Guardar historial de conversaciones"
                value: {
                    if (Settings.get("aiHistory", true) !== true) return "No se guarda";
                    const d = Number(Settings.get("aiHistoryDays", 0)) || 0;
                    return d > 0 ? d + " días" : "Siempre";
                }
            }
            LinkRow {
                label: "Servidores MCP"; section: "iaintegraciones"; sectionLabel: "Integraciones"; target: "Servidores MCP para el asistente"
                value: { const l = (Settings.get("aiMcpServers", []) ?? []).filter(x => x.enabled === true).length; return l === 0 ? "Ninguno" : l === 1 ? "1 aprobado" : l + " aprobados"; }
            }
            LinkRow {
                label: "Recetas"; section: "iarecetas"; sectionLabel: "Recetas"; target: "Recetas"
                value: root.recipeCount < 0 ? "" : root.recipeCount === 1 ? "1 receta" : root.recipeCount + " recetas"
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            Layout.alignment: Qt.AlignTop
            title: "Atajos"
            gap: 0
            Repeater {
                model: [
                    ["Abrir el panel del asistente", "Super + A"],
                    ["Preguntar sobre la ventana activa", "Super + Ctrl + A"],
                    ["Hablar con el asistente", "Super + Alt + H"],
                    ["Dictar en cualquier app", "Super + Alt + D"],
                    ["Preguntar desde Spotlight", "?"],
                ]
                Item {
                    id: sc
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 41
                    Rectangle { visible: sc.index > 0; width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        Txt { Layout.fillWidth: true; text: sc.modelData[0]; muted: true; elide: Text.ElideRight }
                        Kbd { text: sc.modelData[1] }
                    }
                }
            }
        }
    }
}
