// Barra de desplazamiento fina con los colores del tema para cualquier Flickable (solo se ve si no cabe).
//   ScrollHint { flick: lista }                          — vertical, pegada a la derecha de la lista
//   ScrollHint { flick: fila; horizontal: true }         — horizontal, pegada abajo
// Se puede arrastrar. Se cuelga sola del propio Flickable (fuera de su contenido), así que puede declararse
// en cualquier sitio, también dentro de un Layout o del Flickable, sin ocupar hueco.
import QtQuick
import ".."

Rectangle {
    id: bar
    required property Flickable flick
    property bool horizontal: false
    property real inset: 2                   // separación del borde
    readonly property bool needed: horizontal ? flick.contentWidth > flick.width + 1 : flick.contentHeight > flick.height + 1
    readonly property real track: horizontal ? flick.width : flick.height
    readonly property real thick: ma.containsMouse || ma.pressed ? 5 : 3
    parent: flick
    visible: needed
    z: 10
    x: horizontal ? flick.visibleArea.xPosition * track : flick.width - width - inset
    y: horizontal ? flick.height - height - inset : flick.visibleArea.yPosition * track
    width: horizontal ? Math.max(24, flick.visibleArea.widthRatio * track) : thick
    height: horizontal ? thick : Math.max(24, flick.visibleArea.heightRatio * track)
    radius: thick / 2
    color: Theme.t
    opacity: ma.containsMouse || ma.pressed || flick.moving ? 0.45 : 0.22
    Behavior on opacity { NumberAnimation { duration: 140 } }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real grab: 0
        property real start: 0
        onPressed: m => {
            const p = mapToItem(null, m.x, m.y);
            grab = bar.horizontal ? p.x : p.y;
            start = bar.horizontal ? bar.flick.contentX : bar.flick.contentY;
        }
        onPositionChanged: m => {
            if (!pressed) return;
            const p = mapToItem(null, m.x, m.y);
            if (bar.horizontal) {
                const d = (p.x - grab) / Math.max(0.01, bar.flick.visibleArea.widthRatio);
                bar.flick.contentX = Math.max(0, Math.min(bar.flick.contentWidth - bar.flick.width, start + d));
            } else {
                const d = (p.y - grab) / Math.max(0.01, bar.flick.visibleArea.heightRatio);
                bar.flick.contentY = Math.max(0, Math.min(bar.flick.contentHeight - bar.flick.height, start + d));
            }
        }
    }
}
