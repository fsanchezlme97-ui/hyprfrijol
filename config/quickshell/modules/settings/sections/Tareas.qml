// Ajustes › Productividad › Tareas (pestaña de ui/ProdTabs.qml; under: "enfoque" en SettingsApp): la lista de
// services/Tasks.qml (~/.local/share/hyprfrijol/tasks.json) entera, para añadir, marcar, borrar y limpiar las hechas.
// También se crean con «+texto» en Spotlight, el «+» de la agenda y el asistente.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    ProdTabs { current: "tareas" }
    // Pendientes por fecha (las sin fecha al final) y después las hechas
    readonly property var sorted: Tasks.list.slice().sort((a, b) => (a.done - b.done) || String(a.due || "9").localeCompare(String(b.due || "9")) || a.created - b.created)

    Section {
        Layout.fillWidth: true
        title: "Tareas"
        headerRight: Button { visible: Tasks.list.some(t => t.done); text: "Borrar las hechas"; h: 26; onClicked: Tasks.clearDone() }
        Txt {
            Layout.fillWidth: true
            text: "Una lista sencilla con fecha opcional. Salen en la agenda (Super + C): hoy, las vencidas y las sin fecha; otro día, las que vencen ese día. "
                + "También se añaden escribiendo +texto en Spotlight («+llamar al banco mañana») o pidiéndoselo al asistente."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: tText; Layout.fillWidth: true; h: 30; icon: "check"; placeholder: "Qué hay que hacer"; onAccepted: tAdd.clicked() }
            Field { id: tDue; Layout.preferredWidth: 150; h: 30; icon: "calendar"; placeholder: "AAAA-MM-DD"; onAccepted: tAdd.clicked() }
            Button {
                id: tAdd
                text: "Añadir"
                enabled: tText.text.trim() !== "" && (tDue.text.trim() === "" || /^\d{4}-\d{2}-\d{2}$/.test(tDue.text.trim()))
                onClicked: { if (!enabled) return; Tasks.add(tText.text, tDue.text.trim()); tText.text = tDue.text = ""; }
            }
        }
        Repeater {
            model: root.sorted
            RowLayout {
                id: tk
                required property var modelData
                readonly property bool late: !modelData.done && !!modelData.due && modelData.due < Tasks.today
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: Theme.r(4)
                    color: tk.modelData.done ? Theme.p : "transparent"
                    border.width: tk.modelData.done ? 0 : 1.5
                    border.color: tk.late ? Theme.danger : Theme.o
                    Icon { anchors.centerIn: parent; visible: tk.modelData.done; name: "check"; size: 12; color: Theme.pText }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Tasks.toggle(tk.modelData.id) }
                }
                Txt {
                    Layout.fillWidth: true
                    text: tk.modelData.text
                    color: tk.modelData.done ? Theme.tv : Theme.t
                    font.strikeout: tk.modelData.done
                    elide: Text.ElideRight
                }
                Txt { visible: !!tk.modelData.due; text: (tk.late ? "vencida · " : "") + (tk.modelData.due ?? ""); size: 11; tabular: true; color: tk.late ? Theme.danger : Theme.tv }
                Button { text: "Borrar"; h: 26; onClicked: Tasks.remove(tk.modelData.id) }
            }
        }
    }
}
