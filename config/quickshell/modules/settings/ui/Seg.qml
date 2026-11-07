// Control segmentado de Ajustes: borde c.o, segmento activo c.sc / c.onSc.
//   Seg { model: [["a","Uno"],["b","Dos"]]; current: "a"; pill: true; onPicked: k => … }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property var model: []
    property var current
    property bool pill: false
    property real h: 30
    property real textSize: 12
    property bool fill: true
    signal picked(var key)
    implicitHeight: h
    implicitWidth: row.implicitWidth + 2
    radius: pill || Theme.pill ? h / 2 : Theme.r(6)
    color: "transparent"
    border.width: 1
    border.color: Theme.o
    clip: true
    readonly property var items: model.map(m => Array.isArray(m) ? { key: m[0], label: m[1] } : (typeof m === "object" ? m : { key: m, label: String(m) }))
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0
        Repeater {
            model: root.items
            Rectangle {
                id: seg
                required property var modelData
                required property int index
                readonly property bool on: root.current === modelData.key
                Layout.fillWidth: root.fill
                Layout.fillHeight: true
                implicitWidth: lbl.implicitWidth + 24
                radius: root.pill || Theme.pill ? height / 2 : Theme.r(5)
                color: on ? (Theme.tonalSel ? Theme.pc : Theme.selBg) : ma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur } }
                Rectangle {   // separador entre segmentos
                    visible: seg.index > 0 && !seg.on && root.current !== root.items[seg.index - 1]?.key && !root.pill && !Theme.pill
                    width: 1; height: parent.height; color: Theme.ov
                }
                Txt {
                    id: lbl
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    horizontalAlignment: Text.AlignHCenter
                    text: seg.modelData.label
                    size: root.textSize
                    color: seg.on ? (Theme.tonalSel ? Theme.pcText : Theme.selText) : Theme.t
                    weight: Font.DemiBold
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(seg.modelData.key) }
            }
        }
    }
}
