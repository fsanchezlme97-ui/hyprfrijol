// Ajustes › Escritorio y gestos › «Espacios ocultos con nombre» (ajuste "scratchpads" → config/apply/55-scratchpads.py;
// la sección, que guarda, está en sections/Escritorio.qml). Hasta cuatro, en orden: Super + F1 … F4.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 8
    property var pads: []
    signal apply(var list)
    function change(i: int, patch: var): void { apply(pads.map((p, n) => n === i ? Object.assign({}, p, patch) : p)); }

    Txt {
        Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "Un espacio que aparece encima y se esconde con su atajo: la música, el chat, las notas… Las apps que le pongas "
            + "abren dentro sin molestar. Super + Mayús + F1…F4 envía allí la ventana activa. (Aparte del de Super + S.)"
    }
    Repeater {
        // por número: así escribir en un nombre no rehace las filas
        model: root.pads.length
        Expander {
            id: pad
            required property int index
            readonly property var info: root.pads[index] ?? ({})
            title: (info.name || "Espacio " + (index + 1)) + " · Super + F" + (index + 1)
            subtitle: (info.apps ?? []).length ? (info.apps ?? []).join(", ") : "sin apps asignadas"
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field {
                    Layout.fillWidth: true; h: 30; icon: ""
                    text: pad.info.name ?? ""
                    placeholder: "Nombre (Intro para guardar)"
                    onAccepted: root.change(pad.index, { name: text.trim() })
                }
                Button { text: "Quitar"; onClicked: root.apply(root.pads.filter((_, n) => n !== pad.index)) }
            }
            FloatApps {
                Layout.fillWidth: true
                list: pad.info.apps ?? []
                groups: []
                intro: "Apps que abren en este espacio."
                onApply: l => root.change(pad.index, { apps: l })
            }
        }
    }
    Button {
        visible: root.pads.length < 4
        text: "Añadir un espacio"
        onClicked: root.apply(root.pads.concat([{ name: ["Música", "Chat", "Notas", "Extra"][root.pads.length], apps: [] }]))
    }
}
