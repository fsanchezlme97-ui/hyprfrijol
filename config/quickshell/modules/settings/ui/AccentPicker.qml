// Color de acento (Ajustes › Apariencia): el de la paleta o uno elegido, que sustituye al principal (p, pc…)
// en todo el tema (hf-apply apply_accent; el contraste del texto sobre él se calcula solo).
//   AccentPicker { }   → Settings "accent" = "" | "#RRGGBB"
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

ColumnLayout {
    id: root
    spacing: 8
    readonly property string accent: Settings.get("accent", "") ?? ""
    readonly property var presets: [
        ["#7AA2F7", "Azul"], ["#5CC8E0", "Cian"], ["#4FB8A0", "Verde azulado"], ["#8BC273", "Verde"],
        ["#D8C35A", "Lima"], ["#F2B84B", "Ámbar"], ["#F28C4B", "Naranja"], ["#EE6B6B", "Rojo"],
        ["#F07AAE", "Rosa"], ["#C38AF0", "Violeta"], ["#9A8CF2", "Índigo"], ["#9AA5B4", "Gris"]
    ]
    readonly property bool custom: accent !== "" && !presets.some(p => p[0].toUpperCase() === accent.toUpperCase())
    property bool editing: false
    function valid(h) { return /^#[0-9a-fA-F]{6}$/.test(h); }
    function pick(h) { Settings.set("accent", h); }

    Flow {
        Layout.fillWidth: true
        spacing: 6
        // De la paleta
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
            HoverTip { shown: autoMa.containsMouse; text: "El de la paleta" }
        }
        Repeater {
            model: root.presets
            Rectangle {
                id: sw
                required property var modelData
                readonly property bool on: root.accent.toUpperCase() === modelData[0].toUpperCase()
                width: 21; height: 21; radius: 10.5
                color: modelData[0]
                border.width: on ? 2 : 0
                border.color: Theme.t
                Icon { anchors.centerIn: parent; visible: sw.on; name: "check"; size: 12; color: "#1A1A1A" }
                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(sw.modelData[0]) }
                HoverTip { shown: sma.containsMouse; text: sw.modelData[1] }
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
        spacing: 6
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
