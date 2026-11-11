// Mosaico de ajustes rápidos (Wi-Fi, Bluetooth, No molestar…) como en el diseño: 2 columnas, 44 px.
//   Tile { icon: "wifi"; label: "Wi-Fi"; sub: "[Red]"; on: true; onClicked: …; onRightClicked: … }
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    signal clicked()
    signal rightClicked()
    implicitHeight: 44
    radius: Theme.pill ? Math.min(height / 2, Theme.r(11)) : Theme.r(8)
    color: on ? Theme.fillOn : Theme.fill2
    scale: Theme.estilo !== "flat" && mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutBack; easing.overshoot: 2 } }
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    readonly property color fg: on ? Theme.fillOnText : Theme.t
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Theme.light ? "#000000" : "#FFFFFF"
        opacity: mouse.containsMouse ? 0.06 : 0
    }
    Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: root.fg }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10
        Icon { name: root.icon; color: root.fg; size: 15 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: root.label; color: root.fg; weight: Font.DemiBold; size: 12.5 }
            Txt { Layout.fillWidth: true; visible: root.sub !== ""; text: root.sub; color: root.fg; opacity: 0.78; size: 11.5 }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: m => rip.burst(m.x, m.y)
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
