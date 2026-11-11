// Chip ✓/+ : activo c.sc / c.onSc; inactivo transparente con borde c.o.
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string text: ""
    property bool on: false
    property bool mark: true
    property real h: 30
    signal clicked()
    implicitHeight: h
    implicitWidth: t.implicitWidth + 24
    radius: h / 2
    color: on ? Theme.selBg : ma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
    border.width: on ? 0 : 1
    border.color: Theme.o
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Txt {
        id: t
        anchors.centerIn: parent
        text: (root.mark ? (root.on ? "✓ " : "+ ") : "") + root.text
        size: 12
        weight: Font.DemiBold
        color: root.on ? Theme.selText : Theme.t
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
