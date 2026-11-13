// Etiqueta a la izquierda (ancho fijo, c.tv) + control a la derecha.
//   LabeledRow { label: "Suspender tras"; Seg { … } }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

RowLayout {
    id: root
    property string label: ""
    property real labelWidth: 120
    property string hint: ""
    default property alias content: slot.data
    Layout.fillWidth: true
    spacing: 10
    ColumnLayout {
        Layout.preferredWidth: root.labelWidth
        Layout.maximumWidth: root.labelWidth
        spacing: 0
        Txt { Layout.fillWidth: true; text: root.label; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        // letra de código solo para claves («misc:vrr»); una explicación va en la letra normal y en dos líneas si hace falta
        Txt { Layout.fillWidth: true; visible: root.hint !== "" && (!/^[\w:.\-\/]+$/.test(root.hint) || Settings.get("settingsTech", false) === true); text: root.hint; muted: true; size: 10.5; wrapMode: Text.WordWrap; maximumLineCount: 2
              font.family: /^[\w:.\-\/]+$/.test(root.hint) ? Theme.mono : Theme.font }
    }
    Item {
        id: slot
        Layout.fillWidth: true
        implicitHeight: children.length ? children[0].implicitHeight : 0
        onChildrenChanged: { for (const ch of children) ch.width = Qt.binding(() => slot.width); }
    }
}
