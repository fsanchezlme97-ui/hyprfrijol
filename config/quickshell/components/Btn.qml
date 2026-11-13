// Botón del diseño. kinds: "primary" (fondo p), "tonal" (fill2), "ghost" (transparente), "outline"
//   Btn { text: "Abrir"; kind: "primary"; icon: "check"; hint: "↵"; onClicked: … }
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string iconSvg: ""
    property string hint: ""
    property string kind: "tonal"
    property bool active: false
    // enabled: el de Item (antes se redeclaraba y tapaba al de Qt; mismo valor por defecto)
    property real h: 30
    property real padX: 12
    property real textSize: 12.5
    property bool focusable: true
    signal clicked()
    // Teclado: se llega con Tab (anillo de foco) y se pulsa con Intro o Espacio
    activeFocusOnTab: focusable
    Keys.onPressed: e => { if (root.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.clicked(); e.accepted = true; } }

    readonly property color fg: kind === "primary" || active ? Theme.pText : Theme.t
    implicitHeight: h
    implicitWidth: row.implicitWidth + padX * 2
    radius: Theme.ctl(h)
    Behavior on scale { NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    opacity: enabled ? 1 : Theme.stDisabled
    color: kind === "primary" || active ? Theme.p : kind === "tonal" ? Theme.fill2 : "transparent"
    border.width: kind === "outline" ? 1 : 0
    border.color: Theme.ov
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    StateLayer { radius: root.radius; hovered: mouse.containsMouse && root.enabled; pressed: mouse.pressed && root.enabled; focused: root.activeFocus }
    Ripple { id: rip; anchors.fill: parent; radius: root.radius; color: root.fg }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon { visible: root.icon !== "" || root.iconSvg !== ""; name: root.icon; svg: root.iconSvg; color: root.fg }
        Txt { visible: root.text !== ""; text: root.text; color: root.fg; size: root.textSize; weight: Font.DemiBold }
        Txt { visible: root.hint !== ""; text: root.hint; color: root.fg; opacity: 0.7; size: 11 }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: m => { if (root.enabled) rip.burst(m.x, m.y); }
        onClicked: if (root.enabled) root.clicked()
    }
}
