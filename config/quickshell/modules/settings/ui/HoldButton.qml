// Botón para acciones destructivas: hay que mantenerlo pulsado (~0,8 s). Un relleno rojo avanza de izquierda a
// derecha y, al llegar al final, emite confirmed(); soltar antes lo cancela. También con Enter o Espacio mantenidos.
// Un clic corto enseña «Mantén pulsado»; con el puntero encima también.
//   HoldButton { text: "Borrar"; onConfirmed: … }
import QtQuick
import QtQuick.Effects
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string text: ""
    // enabled: el de Item
    property real h: 30
    property int holdMs: 800
    property real progress: 0
    property bool hintOn: false
    property double pressedAt: 0
    signal confirmed()

    function press() {
        if (!enabled || fill.running) return;
        back.stop(); progress = 0; pressedAt = Date.now(); fill.start();
    }
    function release() {
        if (!fill.running) return;
        fill.stop();
        if (Date.now() - pressedAt < 300) { hintOn = true; hintTimer.restart(); }
        back.start();
    }

    implicitHeight: h
    implicitWidth: t.implicitWidth + 26
    radius: Theme.ctl(h)
    opacity: enabled ? 1 : 0.45
    color: "transparent"
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? Theme.p : Qt.alpha(Theme.danger, 0.6)
    activeFocusOnTab: true
    Keys.onPressed: e => { if (!e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.press(); e.accepted = true; } }
    Keys.onReleased: e => { if (!e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { root.release(); e.accepted = true; } }

    NumberAnimation {
        id: fill; target: root; property: "progress"; from: 0; to: 1; duration: root.holdMs
        onFinished: if (root.progress >= 1) { root.confirmed(); root.progress = 0; }
    }
    NumberAnimation { id: back; target: root; property: "progress"; to: 0; duration: Theme.durShort }
    Timer { id: hintTimer; interval: 1600; onTriggered: root.hintOn = false }

    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.danger; opacity: ma.containsMouse && root.enabled && root.progress === 0 ? 0.1 : 0 }
    // Máscara redondeada: el relleno solo existe mientras avanza
    Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: root.progress > 0; Rectangle { anchors.fill: parent; radius: root.radius } }
    Item {
        anchors.fill: parent
        visible: root.progress > 0
        layer.enabled: root.progress > 0
        layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Rectangle { width: parent.width * root.progress; height: parent.height; color: Qt.alpha(Theme.danger, 0.38) }
    }
    Txt { id: t; anchors.centerIn: parent; text: root.text; size: 12.5; weight: Font.Medium; color: Theme.danger }
    HoverTip { shown: (ma.containsMouse && root.progress === 0) || root.hintOn; text: "Mantén pulsado" }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: { root.forceActiveFocus(); root.press(); }
        onReleased: root.release()
        onCanceled: root.release()
    }
}
