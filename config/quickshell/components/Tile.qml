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
    property bool focusable: true
    signal clicked()
    signal rightClicked()
    // Teclado: se llega con Tab (anillo de foco) y se pulsa con Intro o Espacio
    activeFocusOnTab: focusable
    Keys.onPressed: e => { if (root.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.clicked(); e.accepted = true; } }
    implicitHeight: 44
    radius: Theme.pill ? Math.min(height / 2, Theme.r(11)) : Theme.inner(Theme.panelRadius, 12)   // en paneles con margen 12
    color: on ? Theme.fillOn : Theme.fill2
    opacity: enabled ? 1 : Theme.stDisabled
    Behavior on scale { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    readonly property color fg: on ? Theme.fillOnText : Theme.t
    StateLayer { radius: root.radius; hovered: mouse.containsMouse; pressed: mouse.pressed; focused: root.activeFocus }
    Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: root.fg }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
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
