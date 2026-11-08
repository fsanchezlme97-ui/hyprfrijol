// Interruptor (ajustes).  Toggle { checked: …; onToggled: v => … }
// Material: pulgar que crece al activarse (M3); el resto: pulgar fijo con desplazamiento elástico.
import QtQuick
import ".."

Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 36
    implicitHeight: 20
    radius: height / 2
    color: checked ? Theme.p : Theme.fill2
    border.width: checked ? 0 : (Theme.estilo === "flat" ? 2 : 1)
    border.color: Theme.estilo === "flat" ? Theme.o : Theme.ov
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    Rectangle {
        id: thumb
        readonly property real d: Theme.estilo === "flat" ? (root.checked ? 14 : 10) + (ma.pressed ? 2 : 0) : 14
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : (Theme.estilo === "flat" ? 5 : 3)
        color: root.checked ? Theme.pText : (Theme.estilo === "flat" ? Theme.o : Theme.tv)
        Behavior on x { NumberAnimation { duration: Theme.dur + 60; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Behavior on width { NumberAnimation { duration: 160 } }
        Behavior on color { ColorAnimation { duration: Theme.dur } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
