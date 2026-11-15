// Fila que se desplaza en horizontal cuando no cabe (Apariencia › Paleta de colores y Mis temas): arrastre, rueda
// horizontal del touchpad, barra fina y flechas a los lados. La rueda vertical no se queda aquí: sigue moviendo la
// página de Ajustes. Un solo hijo (Row, Grid…).
//   HCarousel { id: car; Layout.fillWidth: true; Grid { rows: 2; flow: Grid.TopToBottom; … } }
//   car.reveal(item)   desplaza lo justo para que se vea (la paleta elegida) · car.reset()   al principio
import QtQuick
import "../../.."
import "../../../components"

Item {
    id: root
    default property alias content: flick.flickableData
    readonly property bool scrolls: flick.contentWidth > width + 1
    implicitHeight: flick.contentHeight + (scrolls ? 10 : 0)

    function reset(): void { anim.stop(); flick.contentX = 0; }
    function reveal(it: Item): void {
        if (!it || !scrolls) return;
        const x = it.mapToItem(flick.contentItem, 0, 0).x, m = 36;
        if (x - m < flick.contentX) go(x - m);
        else if (x + it.width + m > flick.contentX + width) go(x + it.width + m - width);
    }
    function go(x: real): void {
        anim.to = Math.max(0, Math.min(flick.contentWidth - width, x));
        anim.restart();
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: contentItem.childrenRect.width
        contentHeight: contentItem.childrenRect.height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.scrolls
        clip: true
        NumberAnimation on contentX { id: anim; running: false; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease }
    }
    ScrollHint { flick: flick; horizontal: true; inset: 0 }

    // Flechas: media pantalla de la fila hacia cada lado (solo si queda algo por ese lado)
    Repeater {
        model: [-1, 1]
        Rectangle {
            required property int modelData
            readonly property bool more: modelData < 0 ? flick.contentX > 1 : flick.contentX < flick.contentWidth - root.width - 1
            x: modelData < 0 ? 4 : root.width - width - 4
            y: (flick.contentHeight - height) / 2
            width: 28; height: 28; radius: 14
            visible: root.scrolls
            opacity: more ? (arrowMa.containsMouse ? 1 : 0.85) : 0
            enabled: more
            color: Theme.s3
            border.width: 1; border.color: Theme.ov
            Behavior on opacity { NumberAnimation { duration: Theme.durShort } }
            Icon { anchors.centerIn: parent; name: parent.modelData < 0 ? "chevron_left" : "chevron_right"; size: 14; color: Theme.t }
            MouseArea {
                id: arrowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(flick.contentX + parent.modelData * root.width * 0.75)
            }
        }
    }
}
