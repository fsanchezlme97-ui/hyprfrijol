// Color de acento (Ajustes › Apariencia): automático según la paleta, colores extraídos de la paleta actual,
// blanco siempre disponible, o un color personalizado. Sustituye al primario (p, pc…) en todo el tema
// (hf-apply apply_accent; el contraste del texto sobre él se calcula solo).
//   AccentPicker { }   → Settings "accent" = "" | "#RRGGBB"
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

ColumnLayout {
    id: root
    spacing: 8
    readonly property string accent: Settings.get("accent", "") ?? ""
    // Colores compatibles con el tema actual: primario, terciario y los colores del terminal
    readonly property var themeColors: {
        const base = [Theme.p, Theme.ter];
        const ansi = Theme.ansi || [];
        const out = [];
        for (const c of base.concat(ansi.slice(1, 7))) {
            const hex = root.hex(c);
            if (hex && !out.includes(hex)) out.push(hex);
        }
        return out.slice(0, 8);
    }
    readonly property bool custom: accent !== "" && accent.toUpperCase() !== "#FFFFFF" && !root.themeColors.includes(accent.toUpperCase())
    property bool editing: false
    function valid(h) { return /^#[0-9a-fA-F]{6}$/.test(h); }
    function hex(c) {
        const h = n => Math.round(n * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b).toUpperCase();
    }
    function pick(h) { Settings.set("accent", h); }

    Flow {
        Layout.fillWidth: true
        spacing: 4
        // Automático: el de la paleta
        Rectangle {
            width: 21; height: 21; radius: 10.5
            color: "transparent"
            border.width: root.accent === "" ? 2 : 1
            border.color: root.accent === "" ? Theme.t : Theme.ov
            Rectangle {
                anchors.centerIn: parent; width: 14; height: 14; radius: 7
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.5; color: Theme.p }
                    GradientStop { position: 0.501; color: Theme.ter }
                }
            }
            MouseArea { id: autoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick("") }
            HoverTip { shown: autoMa.containsMouse; text: "Automático según la paleta" }
        }
        // Blanco siempre
        Rectangle {
            id: whiteSw
            readonly property bool on: root.accent.toUpperCase() === "#FFFFFF"
            width: 21; height: 21; radius: 10.5
            color: "#FFFFFF"
            border.width: on ? 2 : 1
            border.color: on ? Theme.t : Theme.ov
            Icon { anchors.centerIn: parent; visible: whiteSw.on; name: "check"; size: 12; color: "#1A1A1A" }
            MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick("#FFFFFF") }
            HoverTip { shown: wma.containsMouse; text: "Blanco" }
        }
        // Colores de la paleta actual
        Repeater {
            model: root.themeColors
            Rectangle {
                id: sw
                required property color modelData
                readonly property bool on: root.accent.toUpperCase() === root.hex(modelData)
                width: 21; height: 21; radius: 10.5
                color: modelData
                border.width: on ? 2 : 0
                border.color: Theme.t
                Icon { anchors.centerIn: parent; visible: sw.on; name: "check"; size: 12; color: "#1A1A1A" }
                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(root.hex(modelData)) }
                HoverTip { shown: sma.containsMouse; text: "Del tema" }
            }
        }
        // Personalizado
        Rectangle {
            width: 21; height: 21; radius: 10.5
            color: root.custom ? root.accent : "transparent"
            border.width: root.custom || root.editing ? 2 : 1
            border.color: root.custom || root.editing ? Theme.t : Theme.o
            Icon { anchors.centerIn: parent; visible: !root.custom; name: "plus"; size: 12; color: Theme.tv }
            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editing = !root.editing }
            HoverTip { shown: cma.containsMouse; text: "Personalizado" }
        }
    }
    // Personalizado: tira de tonos + código hexadecimal
    ColumnLayout {
        visible: root.editing
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            id: hues
            Layout.fillWidth: true
            implicitHeight: 18
            radius: 9
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.64, 1) }
                GradientStop { position: 0.17; color: Qt.hsla(0.17, 0.7, 0.64, 1) }
                GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.7, 0.64, 1) }
                GradientStop { position: 0.5; color: Qt.hsla(0.5, 0.7, 0.64, 1) }
                GradientStop { position: 0.67; color: Qt.hsla(0.67, 0.7, 0.64, 1) }
                GradientStop { position: 0.83; color: Qt.hsla(0.83, 0.7, 0.64, 1) }
                GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.64, 1) }
            }
            function at(x) {
                const c = Qt.hsla(Math.max(0, Math.min(0.999, x / width)), 0.7, 0.64, 1);
                const h = n => Math.round(n * 255).toString(16).padStart(2, "0");
                return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                onClicked: m => { hex.text = hues.at(m.x); root.pick(hex.text); }
            }
        }
        RowLayout {
            spacing: 8
            Rectangle { implicitWidth: 30; implicitHeight: 30; radius: Theme.ctl(30); color: root.valid(hex.text) ? hex.text : "transparent"; border.width: 1; border.color: Theme.ov }
            Field {
                id: hex
                Layout.preferredWidth: 130
                icon: ""
                placeholder: "#RRGGBB"
                text: root.accent
                onAccepted: { const v = text.trim(); const h = v.startsWith("#") ? v : "#" + v; if (root.valid(h)) root.pick(h.toUpperCase()); }
            }
            Button { text: "Aplicar"; enabled: root.valid(hex.text.trim().startsWith("#") ? hex.text.trim() : "#" + hex.text.trim()); onClicked: hex.accepted() }
            Item { Layout.fillWidth: true }
        }
    }
}
