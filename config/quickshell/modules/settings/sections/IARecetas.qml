// Ajustes › Asistente de IA › Recetas (pestaña de ui/AiTabs.qml; under: "ia" en SettingsApp): instrucciones
// guardadas que se aplican a la selección, el portapapeles, la pantalla o una imagen (scripts/hf-ai recipes ·
// recipe <id> · recipe-save · recipe-remove; las propias en ~/.local/share/hyprfrijol/ai-recetas.json).
// Salen en Spotlight por su nombre (grupo «recetas» de Ajustes › Productividad › Spotlight).
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
    AiTabs { current: "iarecetas" }

    readonly property var inputs: [["seleccion", "Selección"], ["portapapeles", "Portapapeles"], ["pantalla", "Pantalla"], ["imagen", "Imagen copiada"], ["nada", "Nada"]]
    readonly property var outputs: [["panel", "Panel lateral"], ["copiar", "Copiar"], ["reemplazar", "Reemplazar la selección"]]
    function label(l, k) { return (l.find(x => x[0] === k) ?? [k, k])[1]; }

    property var list: []
    property string msg: ""
    property string newIn: "seleccion"
    property string newOut: "copiar"
    function reload(): void { lister.running = false; lister.running = true; }
    function run(args): void { job.command = [Paths.script("hf-ai")].concat(args); job.running = true; }
    Process {
        id: lister
        running: true
        command: [Paths.script("hf-ai"), "recipes"]
        stdout: StdioCollector { onStreamFinished: { try { root.list = JSON.parse(text); } catch (e) { root.list = []; } } }
    }
    Process {
        id: job
        stdout: StdioCollector {
            onStreamFinished: {
                try { const j = JSON.parse(text); root.msg = j.error ?? ""; if (!j.error) { nameField.text = ""; promptField.text = ""; } }
                catch (e) { root.msg = ""; }
            }
        }
        onExited: root.reload()
    }

    Section {
        Layout.fillWidth: true
        title: "Recetas"
        headerRight: Mono { text: root.list.length + " recetas" }
        Txt {
            Layout.fillWidth: true
            text: "Una instrucción que se aplica de un golpe: escribe su nombre en Spotlight (por ejemplo «Corregir») con el texto "
                + "seleccionado. Lo de las apps privadas no se lee y los datos sensibles se ocultan, como en el panel."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Repeater {
            model: root.list
            RowLayout {
                id: rr
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { Layout.fillWidth: true; text: rr.modelData.name; elide: Text.ElideRight }
                    Txt {
                        Layout.fillWidth: true
                        text: root.label(root.inputs, rr.modelData.input) + "  →  " + root.label(root.outputs, rr.modelData.output) + " · " + rr.modelData.prompt
                        muted: true; size: 11; elide: Text.ElideRight
                    }
                }
                Button { text: "Probar"; h: 26; onClicked: Quickshell.execDetached([Paths.script("hf-ai"), "recipe", rr.modelData.id]) }
                Button {
                    visible: rr.modelData.own === true
                    kind: "link"; text: "Borrar"
                    onClicked: root.run(["recipe-remove", rr.modelData.id])
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Nueva receta"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: nameField; Layout.preferredWidth: 200; h: 30; icon: ""; placeholder: "Nombre"; input.maximumLength: 40 }
            Field { id: promptField; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Instrucción, p. ej. «Conviértelo en una lista de puntos»"; input.maximumLength: 1000 }
        }
        LabeledRow {
            label: "Toma"
            labelWidth: 80
            Seg { model: root.inputs; current: root.newIn; onPicked: k => root.newIn = k }
        }
        LabeledRow {
            label: "Y"
            labelWidth: 80
            Seg { model: root.outputs; current: root.newOut; onPicked: k => root.newOut = k }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Txt {
                Layout.fillWidth: true
                text: root.msg || (root.newOut === "panel" ? "El panel puede proponer acciones (crear una tarea, un evento, un tema…) con su tarjeta para aplicarlas."
                                                           : "El resultado queda en el portapapeles" + (root.newOut === "reemplazar" ? " y se pega sobre la selección." : "."))
                color: root.msg ? Theme.danger : Theme.tv
                size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
            Button {
                kind: "primary"; text: "Guardar"
                enabled: !job.running && nameField.text.trim() !== "" && promptField.text.trim() !== ""
                onClicked: root.run(["recipe-save", JSON.stringify({ name: nameField.text, prompt: promptField.text, input: root.newIn, output: root.newOut })])
            }
        }
    }
}
