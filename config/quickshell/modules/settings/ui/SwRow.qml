// Fila con interruptor: título (600) + subtítulo y separador superior c.ov.
//   SwRow { label: "Animaciones"; sub: "animations:enabled"; mono: true; checked: …; onToggled: v => … }
//   o con key: "animado" → lee/escribe Settings directamente.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Item {
    id: root
    property string label: ""
    property string sub: ""
    property bool mono: false
    property string key: ""
    property bool def: false
    property bool checked: key !== "" ? !!Settings.get(key, def) : false
    property bool enabled: true
    property bool separator: true
    property alias trailing: extra.data
    signal toggled(bool value)
    Layout.fillWidth: true
    implicitHeight: sub !== "" ? 48 : 46
    Rectangle { visible: root.separator; width: parent.width; height: 1; color: Theme.ov }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 1
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: root.label; weight: Font.DemiBold; opacity: root.enabled ? 1 : 0.6 }
            Txt {
                Layout.fillWidth: true
                visible: root.sub !== ""
                text: root.sub
                muted: true
                size: root.mono ? 11 : 11.5
                font.family: root.mono ? Theme.mono : Theme.font
            }
        }
        Row { id: extra; spacing: 8; Layout.alignment: Qt.AlignVCenter }
        Sw {
            checked: root.checked
            enabled: root.enabled
            onToggled: v => { if (root.key !== "") Settings.set(root.key, v); root.toggled(v); }
        }
    }
}
