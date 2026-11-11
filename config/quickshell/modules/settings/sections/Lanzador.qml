// Ajustes › Productividad › Spotlight (pestaña de ui/ProdTabs.qml; under: "enfoque" en SettingsApp): grupos que
// salen al buscar sin prefijo (spotlightGroups), su orden (spotlightOrder: [] = por relevancia), el buscador web
// de «!» (webSearch: duckduckgo · google · brave · kagi · startpage o una URL con %s) y la lista de prefijos.
// Lo lee modules/spotlight/Spotlight.qml (groupOn, engine).
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
    ProdTabs { current: "spotlight" }

    readonly property var all: [
        { key: "apps", label: "Apps y web apps", sub: "lo instalado y las web apps del Centro de aplicaciones" },
        { key: "acciones", label: "Acciones", sub: "bloquear, captura, pomodoro, portapapeles, emojis…" },
        { key: "ventanas", label: "Ventanas abiertas", sub: "a partir de dos letras" },
        { key: "calculadora", label: "Calculadora", sub: "al escribir una operación (con = siempre)" },
        { key: "recetas", label: "Recetas del asistente", sub: "Resumir, Traducir, Corregir… (Ajustes › Asistente de IA › Recetas)" },
        { key: "ia", label: "Preguntar a la IA", sub: "fila al final (con ? siempre)" },
        { key: "web", label: "Buscar en la web", sub: "fila al final (con ! siempre)" }
    ]
    readonly property var shown: { const g = Settings.get("spotlightGroups", null); return Array.isArray(g) ? g : all.map(x => x.key); }
    readonly property var order: { const o = Settings.get("spotlightOrder", []); return Array.isArray(o) ? o : []; }
    readonly property var movable: ["apps", "acciones", "ventanas", "recetas"]
    readonly property var listed: order.length ? order.filter(k => movable.includes(k)).concat(movable.filter(k => !order.includes(k))) : movable
    readonly property string ws: String(Settings.get("webSearch", "duckduckgo"))
    readonly property bool custom: !["duckduckgo", "google", "brave", "kagi", "startpage"].includes(ws)
    function move(k, d) {
        const l = listed.slice(), i = l.indexOf(k), j = i + d;
        if (j < 0 || j >= l.length) return;
        l.splice(i, 1); l.splice(j, 0, k);
        Settings.set("spotlightOrder", l);
    }

    Section {
        Layout.fillWidth: true
        title: "Qué sale al buscar"
        headerRight: Mono { text: "sin prefijo" }
        Repeater {
            model: root.all
            SwRow {
                required property var modelData
                required property int index
                separator: index > 0
                label: modelData.label
                sub: modelData.sub
                checked: root.shown.includes(modelData.key)
                onToggled: v => Settings.set("spotlightGroups", v ? root.shown.concat([modelData.key]) : root.shown.filter(k => k !== modelData.key))
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Orden de los grupos"
        LabeledRow {
            label: "Ordenar"; labelWidth: 120
            Seg {
                model: [["rel", "Por relevancia"], ["fijo", "En este orden"]]
                current: root.order.length ? "fijo" : "rel"
                onPicked: k => Settings.set("spotlightOrder", k === "fijo" ? root.movable : [])
            }
        }
        Repeater {
            model: root.order.length ? root.listed : []
            RowLayout {
                id: gr
                required property string modelData
                required property int index
                Layout.fillWidth: true
                spacing: 8
                Txt { text: (gr.index + 1) + "."; muted: true; tabular: true }
                Txt { Layout.fillWidth: true; text: root.all.find(x => x.key === gr.modelData)?.label ?? gr.modelData }
                Button { text: "Subir"; h: 26; enabled: gr.index > 0; onClicked: root.move(gr.modelData, -1) }
                Button { text: "Bajar"; h: 26; enabled: gr.index < root.listed.length - 1; onClicked: root.move(gr.modelData, 1) }
            }
        }
        Txt {
            Layout.fillWidth: true
            text: "La calculadora sale arriba al escribir una operación; la IA y la web, siempre al final."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Buscador web"
        LabeledRow {
            label: "Buscar con"; labelWidth: 120
            Seg {
                model: [["duckduckgo", "DuckDuckGo"], ["google", "Google"], ["brave", "Brave"], ["kagi", "Kagi"], ["startpage", "Startpage"], ["otro", "Otro"]]
                current: root.custom ? "otro" : root.ws
                onPicked: k => { if (k === "otro") Qt.callLater(() => urlField.focusInput()); else Settings.set("webSearch", k); }
            }
        }
        LabeledRow {
            label: "Dirección"; labelWidth: 120
            hint: "%s = lo que buscas"
            Field {
                id: urlField
                Layout.fillWidth: true
                icon: "globe"
                placeholder: "https://ejemplo.org/buscar?q=%s"
                text: root.custom ? root.ws : ""
                onAccepted: { const v = text.trim(); if (/^https?:\/\/\S+%s/.test(v)) Settings.set("webSearch", v); }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Prefijos"
        headerRight: Mono { text: "Super + Espacio" }
        Repeater {
            model: [[">", "comando en la terminal"], ["=", "calcular (unidades, monedas, husos)"], ["?", "preguntar a la IA"], ["@", "ventanas abiertas"],
                    ["/", "archivos de tu carpeta personal"], [":", "historial del portapapeles"], [";", "emojis"], ["!", "buscar en la web"], ["+", "nueva tarea"]]
            Kv { required property var modelData; k: modelData[0]; v: modelData[1] }
        }
    }
}
