// Muestra del movimiento elegido (Ajustes › Apariencia › Movimiento): una ventana que aparece con la curva de
// entrada (Theme.easeIn, con rebote en «Fluido») y un indicador que cambia de espacio con Theme.ease.
// Usa las duraciones del tema (ya divididas por la velocidad). Se reproduce al cambiar el preajuste y al pulsar.
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string preset: Theme.motionPreset
    property int step: 0
    implicitHeight: 92
    radius: Theme.r(8)
    color: Theme.s4
    clip: true

    function play() { root.step = (root.step + 1) % 3; card.shown = false; again.restart(); }
    onPresetChanged: play()
    Connections { target: Theme; function onDurInChanged() { root.play(); } }
    Timer { id: again; interval: Math.max(60, Theme.durOut + 40); onTriggered: card.shown = true }

    // Tres «espacios» y el indicador que se desliza entre ellos
    Row {
        id: ws
        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
        spacing: 8
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 34; height: 22; radius: Theme.r(4)
                color: Qt.alpha(Theme.t, 0.07)
                border.width: 1; border.color: Qt.alpha(Theme.t, 0.08)
            }
        }
    }
    Rectangle {
        x: ws.x + root.step * 40 - 1; y: ws.y - 1
        width: 36; height: 24; radius: Theme.r(5)
        color: "transparent"; border.width: 2; border.color: Theme.p
        Behavior on x { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }

    // La «ventana» que aparece
    Rectangle {
        id: card
        property bool shown: true
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        width: Math.min(150, root.width * 0.42); height: 62
        radius: Theme.r(7)
        color: Theme.s1
        border.width: 1; border.color: Qt.alpha(Theme.p, 0.4)
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.82
        Behavior on opacity { NumberAnimation { duration: card.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: card.shown ? Theme.ease : Theme.easeOut } }
        Behavior on scale { NumberAnimation { duration: card.shown ? Theme.durIn : Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: card.shown ? Theme.easeIn : Theme.easeOut } }
        Column {
            anchors { left: parent.left; top: parent.top; margins: 12 }
            spacing: 8
            Rectangle { width: 60; height: 6; radius: 3; color: Theme.t; opacity: 0.75 }
            Rectangle { width: card.width - 20; height: 5; radius: 2.5; color: Theme.tv; opacity: 0.45 }
            Rectangle { width: 40; height: 14; radius: Theme.ctl(14); color: Theme.p }
        }
    }

    Txt {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        text: Theme.still ? "Sin animaciones" : Theme.durIn + " ms al abrir · " + Theme.durOut + " ms al cerrar"
        size: 11; muted: true
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.play() }
}
