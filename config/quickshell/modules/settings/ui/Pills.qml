// Fila de "pastillas" numéricas (Esquinas 0/6/10/16/24…): activa c.p / c.onP, resto c.s4.
//   Pills { model: [0, 6, 10]; current: 6; onPicked: v => … }   (o [["k","Etiqueta"],…])
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

RowLayout {
    id: root
    property var model: []
    property var current
    property real h: 30
    property bool fill: true
    signal picked(var key)
    spacing: 6
    Repeater {
        model: root.model.map(m => Array.isArray(m) ? { key: m[0], label: m[1] } : { key: m, label: String(m) })
        Rectangle {
            id: pill
            required property var modelData
            readonly property bool on: root.current === modelData.key
            Layout.fillWidth: root.fill
            implicitWidth: t.implicitWidth + 22
            implicitHeight: root.h
            radius: Theme.ctl(root.h)
            color: on ? Theme.p : Theme.s4
            Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.t; opacity: ma.containsMouse && !pill.on ? 0.06 : 0 }
            Txt { id: t; anchors.centerIn: parent; text: pill.modelData.label; tabular: true; size: 12; weight: Font.DemiBold; color: pill.on ? Theme.pText : Theme.t }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(pill.modelData.key) }
        }
    }
}
