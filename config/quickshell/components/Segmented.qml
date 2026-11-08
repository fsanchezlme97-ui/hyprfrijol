// Control segmentado (Trabajo · 3D · Personal · Juego / Ahorro · Equilibrado · Rendimiento del diseño).
//   Segmented { model: [{ key: "a", label: "A" }, …]; current: "a"; onPicked: k => … }
// La marca de selección se desliza entre opciones. Material la pinta con el contenedor primario.
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property var model: []
    property string current: ""
    property real h: 32
    signal picked(string key)
    implicitHeight: h
    implicitWidth: row.implicitWidth + 6
    radius: Theme.ctl(h)
    color: Theme.fill2
    readonly property int idx: { for (let i = 0; i < model.length; i++) if (model[i].key === current) return i; return -1; }
    readonly property Item sel: idx >= 0 && rep.count > idx ? rep.itemAt(idx) : null
    readonly property bool material: Theme.tonalSel   // Material y Suave: marca con el contenedor primario

    Rectangle {   // marca deslizante
        visible: root.sel !== null
        x: root.sel ? row.x + root.sel.x : 0
        y: row.y
        width: root.sel ? root.sel.width : 0
        height: row.height
        radius: Theme.ctl(height)
        color: Theme.segThumb
        border.width: Theme.glassy || Theme.chroma ? 1 : 0
        border.color: Theme.border
        Behavior on x { NumberAnimation { duration: Theme.dur + 80; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeIn } }
        Behavior on width { NumberAnimation { duration: Theme.dur + 80; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeIn } }
    }
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2
        Repeater {
            id: rep
            model: root.model
            Item {
                required property var modelData
                readonly property bool on: root.current === modelData.key
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: lbl.implicitWidth + 20
                Txt {
                    id: lbl
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: parent.on ? Theme.segText : Theme.tv
                    weight: parent.on ? Font.DemiBold : Font.Medium
                    Behavior on color { ColorAnimation { duration: Theme.dur } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(parent.modelData.key)
                }
            }
        }
    }
}
