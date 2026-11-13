// Una opción de un plugin (config/tools/plugins.json → options[]): interruptor, número (− valor +) o lista.
//   PluginOption { opt: { key, label, type: "bool"|"int"|"choice", def, min, max, step, unit, choices }; value: …; onPicked: v => … }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Item {
    id: root
    property var opt: ({})
    property var value
    property bool separator: true
    signal picked(var value)
    readonly property var cur: value === undefined || value === null ? opt.def : value
    // [[clave, etiqueta], …] → [{ key, label }] (los arrays anidados de un var no siempre pasan Array.isArray)
    readonly property var choices: { const r = [], c = opt.choices ?? []; for (let i = 0; i < c.length; i++) r.push({ key: c[i][0], label: String(c[i][1]) }); return r; }
    readonly property bool compact: choices.length <= 3 && !choices.some(c => c.label.length > 14)
    Layout.fillWidth: true
    implicitHeight: 46
    Rectangle { visible: root.separator; width: parent.width; height: 1; color: Theme.ov }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 1
        spacing: 12
        Txt { Layout.fillWidth: true; text: root.opt.label ?? root.opt.key; weight: Font.Medium; wrapMode: Text.WordWrap; maximumLineCount: 2 }
        Sw {
            visible: root.opt.type === "bool"
            checked: !!root.cur
            onToggled: v => root.picked(v)
        }
        RowLayout {
            visible: root.opt.type === "int"
            spacing: 8
            Button {
                h: 26; text: "−"
                enabled: Number(root.cur) > (root.opt.min ?? -1e9)
                onClicked: root.picked(Math.max(root.opt.min ?? -1e9, Number(root.cur) - (root.opt.step ?? 1)))
            }
            Txt {
                Layout.preferredWidth: 54
                horizontalAlignment: Text.AlignHCenter
                text: root.cur + (root.opt.unit ? " " + root.opt.unit : "")
                tabular: true; weight: Font.DemiBold
            }
            Button {
                h: 26; text: "+"
                enabled: Number(root.cur) < (root.opt.max ?? 1e9)
                onClicked: root.picked(Math.min(root.opt.max ?? 1e9, Number(root.cur) + (root.opt.step ?? 1)))
            }
        }
        Seg {
            visible: root.opt.type === "choice" && root.compact
            fill: false
            model: root.choices
            current: root.cur
            onPicked: k => root.picked(k)
        }
        Dropdown {
            visible: root.opt.type === "choice" && !root.compact
            Layout.preferredWidth: 290
            model: root.choices
            current: root.cur
            onPicked: k => root.picked(k)
        }
    }
}
