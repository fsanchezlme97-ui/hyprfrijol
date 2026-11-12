// Control segmentado de Ajustes: borde c.o, segmento activo c.sc / c.onSc.
//   Seg { model: [["a","Uno"],["b","Dos"]]; current: "a"; pill: true; onPicked: k => … }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property var model: []
    property var current
    property bool pill: false
    property real h: 30
    property real textSize: 12
    property bool fill: true
    property bool tabular: false          // cifras de ancho fijo (Pills: «4 px», «125 %»)
    signal picked(var key)
    // Teclado: Tab llega al grupo (anillo de foco) y las flechas cambian de opción
    property bool focusable: true
    activeFocusOnTab: focusable
    Keys.onPressed: e => {
        const i = items.findIndex(it => it.key === current);
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
            const n = items.length;
            if (n) root.picked(items[((i < 0 ? 0 : i) + (e.key === Qt.Key_Right ? 1 : -1) + n) % n].key);
            e.accepted = true;
        }
    }
    implicitHeight: h
    Layout.maximumWidth: fill ? Number.POSITIVE_INFINITY : implicitWidth   // fill: false = tan ancho como sus etiquetas
    // ancho natural = suma de las etiquetas (no del reparto, que depende del ancho: sería un bucle)
    implicitWidth: { let w = 0; for (let i = 0; i < rep.count; i++) w += rep.itemAt(i)?.implicitWidth ?? 0; return w + 2; }
    radius: pill || Theme.pill ? h / 2 : Theme.r(6)
    color: "transparent"
    border.width: 1
    border.color: Theme.o
    clip: !activeFocus
    // anillo de foco del grupo entero
    Rectangle {
        visible: root.activeFocus
        anchors.fill: parent
        anchors.margins: -(Theme.focusWidth + 1)
        radius: root.radius + Theme.focusWidth + 1
        color: "transparent"
        border.width: Theme.focusWidth
        border.color: Theme.focusRing
    }
    readonly property var items: model.map(m => Array.isArray(m) ? { key: m[0], label: m[1] } : (typeof m === "object" ? m : { key: m, label: String(m) }))
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0
        Repeater {
            id: rep
            model: root.items
            Rectangle {
                id: seg
                required property var modelData
                required property int index
                readonly property bool on: root.current === modelData.key
                Layout.fillWidth: root.fill
                Layout.fillHeight: true
                // Todos los segmentos igual de anchos; uno con la etiqueta más larga solo crece lo que necesita
                Layout.preferredWidth: root.fill ? Math.max(implicitWidth, (root.width - 2) / root.items.length) : implicitWidth
                Layout.minimumWidth: Math.min(implicitWidth, lbl.implicitWidth + 12)
                implicitWidth: lbl.implicitWidth + 24
                radius: root.pill || Theme.pill ? height / 2 : Theme.r(5)
                color: on ? Theme.segThumb : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                StateLayer { radius: seg.radius; hovered: ma.containsMouse && !seg.on; pressed: ma.pressed }
                Rectangle {   // separador entre segmentos
                    visible: seg.index > 0 && !seg.on && root.current !== root.items[seg.index - 1]?.key && !root.pill && !Theme.pill
                    width: 1; height: parent.height; color: Theme.ov
                }
                Txt {
                    id: lbl
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    horizontalAlignment: Text.AlignHCenter
                    text: seg.modelData.label
                    size: root.textSize
                    tabular: root.tabular
                    color: seg.on ? Theme.segText : Theme.t
                    weight: Font.DemiBold
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(seg.modelData.key) }
            }
        }
    }
}
