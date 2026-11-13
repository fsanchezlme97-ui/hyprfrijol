// Ajustes › Escritorio y gestos › Nombres de los espacios: nombre ("wsNames" = {"1": "Trabajo"}) e icono o emoji
// opcional ("wsIcons" = {"1": "💼"}) de los espacios 1–10. Los usan la barra (bar/Workspaces.qml, si
// "wsBarNames") y la vista general (modules/overview/Overview.qml).
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"

Section {
    id: root
    title: "Nombres de los espacios"
    readonly property var names: Settings.get("wsNames", ({})) ?? ({})
    readonly property var icons: Settings.get("wsIcons", ({})) ?? ({})
    // Guarda un valor (vacío = se borra la clave)
    function put(key, n, v) {
        const o = Object.assign({}, key === "wsNames" ? names : icons), k = String(n), t = String(v ?? "").trim();
        if ((o[k] ?? "") === t) return;
        if (t) o[k] = t; else delete o[k];
        Settings.set(key, o);
    }
    headerRight: Button {
        kind: "link"; text: "Borrar todos"
        visible: Object.keys(root.names).length + Object.keys(root.icons).length > 0
        onClicked: Settings.setMany({ wsNames: {}, wsIcons: {} })
    }

    SwRow {
        separator: false
        label: "Mostrar los nombres en la barra"
        sub: "si no, la barra muestra solo el número (o el icono)"
        key: "wsBarNames"; def: true
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 16
        rowSpacing: 8
        Repeater {
            model: 10
            RowLayout {
                id: ws
                required property int index
                readonly property int n: index + 1
                // en columnas: 1–5 a la izquierda, 6–10 a la derecha
                Layout.row: index % 5
                Layout.column: Math.floor(index / 5)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 8
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6)
                    color: Theme.selBg
                    Txt { anchors.centerIn: parent; text: WsLabel.style === "puntos" ? ws.n : WsLabel.numeral(ws.n); font.family: WsLabel.font; weight: Font.DemiBold; tabular: true; color: Theme.selText; size: text.length > 2 ? 10 : 12.5 }
                }
                Field {
                    id: ic
                    Layout.preferredWidth: 58
                    h: 30
                    icon: ""
                    placeholder: "icono"
                    text: root.icons[String(ws.n)] ?? ""
                    input.maximumLength: 4
                    input.horizontalAlignment: TextInput.AlignHCenter
                    Connections { target: ic.input; function onEditingFinished() { root.put("wsIcons", ws.n, ic.text); } }
                }
                Field {
                    id: nm
                    Layout.fillWidth: true
                    h: 30
                    icon: ""
                    placeholder: "Espacio " + ws.n
                    text: root.names[String(ws.n)] ?? ""
                    input.maximumLength: 24
                    Connections { target: nm.input; function onEditingFinished() { root.put("wsNames", ws.n, nm.text); } }
                }
                // si cambian desde fuera (Borrar todos, importar ajustes…), refrescar los campos
                Connections {
                    target: root
                    function onNamesChanged() { if (!nm.input.activeFocus) nm.text = root.names[String(ws.n)] ?? ""; }
                    function onIconsChanged() { if (!ic.input.activeFocus) ic.text = root.icons[String(ws.n)] ?? ""; }
                }
            }
        }
    }
    Txt {
        Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
        text: "Pulsa Intro o cambia de campo para guardar. Puedes pegar un emoji (Super + . abre el selector) como icono."
    }
}
