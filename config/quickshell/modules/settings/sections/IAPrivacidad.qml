// Ajustes › Asistente de IA › Privacidad (pestaña de ui/AiTabs.qml; under: "ia" en SettingsApp):
//  · filtro de secretos (aiRedactSecrets → scripts/hf-ai redact: claves, tokens, contraseñas y tarjetas fuera del
//    contexto que se envía; el panel avisa «Se ocultó 1 dato sensible»)
//  · apps privadas (privateApps → hf-ai is_private: con una delante no se lee su ventana, título, pantalla ni
//    portapapeles; la misma lista sirve al portapapeles)
//  · historial del panel (aiHistory, aiHistoryDays → hf-ai prune_history; ~/.local/share/hyprfrijol/ai)
//  · registro de acciones: `hf-ai log` (lo que aún se puede deshacer, ~/.cache/hyprfrijol/undo) y `hf-ai undo <id>`
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
    AiTabs { current: "iaprivacidad" }

    Section {
        Layout.fillWidth: true
        title: "Lo que se envía"
        SwRow {
            separator: false
            label: "Ocultar datos sensibles"
            sub: "claves de API, tokens, claves privadas, contraseñas y tarjetas del portapapeles, la pantalla y las consultas"
            key: "aiRedactSecrets"; def: true
        }
        Txt {
            Layout.fillWidth: true
            text: "Se quitan antes de mandar nada al proveedor y el panel avisa cuando ha ocultado algo. Lo que escribes tú no se toca."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
    }

    // privateApps: sin valor en settings.json, hf-ai usa su lista PRIVATE_APPS (la misma que este grupo)
    Section {
        Layout.fillWidth: true
        title: "Apps privadas"
        FloatApps {
            Layout.fillWidth: true
            settingKey: "privateApps"
            intro: "Mientras una de estas apps está delante, el asistente no lee su ventana ni su título, no mira la pantalla "
                + "y no toca el portapapeles. Añade tu banco, tu correo o lo que no quieras que vea."
            groups: [
                { key: "claves", label: "Gestores de contraseñas", sub: "KeePassXC, Bitwarden, 1Password, Contraseñas de GNOME, KWallet, Enpass, Proton Pass",
                  classes: ["keepassxc", "bitwarden", "1password", "seahorse", "kwalletmanager", "enpass", "proton pass"] }
            ]
            onApply: l => Settings.set("privateApps", l)
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Historial"
        headerRight: Button {
            text: "Abrir la carpeta"; kind: "outline"; h: 26
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", Paths.home + "/.local/share/hyprfrijol/ai"])
        }
        SwRow { separator: false; label: "Guardar historial de conversaciones"; sub: "~/.local/share/hyprfrijol/ai · se busca desde el panel"; key: "aiHistory"; def: true }
        LabeledRow {
            label: "Guardar durante"
            labelWidth: 140
            enabled: Settings.get("aiHistory", true) === true
            Seg {
                model: [[7, "7 días"], [30, "30 días"], [90, "90 días"], [0, "Siempre"]]
                current: Settings.get("aiHistoryDays", 30)
                onPicked: k => Settings.set("aiHistoryDays", k)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Txt { Layout.fillWidth: true; text: "Borrar todas las conversaciones guardadas"; muted: true; size: 11.5 }
            ConfirmButton {
                h: 28
                text: "Borrar todo"
                confirmText: "¿Borrar el historial? Sí"
                onConfirmed: Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.json', "sh", Paths.home + "/.local/share/hyprfrijol/ai"])
            }
        }
    }

    // Registro de acciones: cada cambio aplicado deja un registro para deshacerlo; Deshacer lo consume
    property var log: []
    property string logMsg: ""
    function reload(): void { logProc.running = false; logProc.running = true; }
    Process {
        id: logProc
        running: true
        command: [Paths.script("hf-ai"), "log"]
        stdout: StdioCollector { onStreamFinished: { try { root.log = JSON.parse(text); } catch (e) { root.log = []; } } }
    }
    Process {
        id: undoProc
        property string uid: ""
        command: [Paths.script("hf-ai"), "undo", uid]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.logMsg = j.error ?? "Deshecho."; } catch (e) { root.logMsg = ""; } } }
        onExited: root.reload()
    }
    Section {
        Layout.fillWidth: true
        title: "Registro de acciones"
        headerRight: Button { text: "Actualizar"; kind: "outline"; h: 26; onClicked: root.reload() }
        Txt {
            Layout.fillWidth: true
            text: root.log.length
                ? "Lo que el asistente cambió y aún puedes deshacer, lo más reciente arriba." + (root.logMsg ? " " + root.logMsg : "")
                : "Nada que deshacer. Aquí aparece lo que el asistente cambie en el escritorio (ajustes, fondo, ventanas…)."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Repeater {
            model: root.log
            RowLayout {
                id: lr
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Txt { text: lr.modelData.time; muted: true; size: 11; font.family: Theme.mono }
                Txt { Layout.fillWidth: true; text: (lr.modelData.labels ?? []).join(" · ") || "Cambio"; elide: Text.ElideRight }
                Button {
                    text: "Deshacer"; h: 26
                    enabled: !undoProc.running
                    onClicked: { undoProc.uid = lr.modelData.id; undoProc.running = true; }
                }
            }
        }
    }
}
