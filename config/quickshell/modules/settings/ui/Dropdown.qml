// Desplegable: muestra el valor actual y abre una lista (con búsqueda si hay muchas opciones).
//   Dropdown { model: [["k","Etiqueta"],…]; current: "k"; onPicked: k => … }
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property var model: []
    property var current
    property string placeholder: "Elegir…"
    property bool flat: false
    property bool alignLeft: false
    property real h: 32
    property real popupWidth: Math.max(width, 240)
    property bool searchable: items.length > 12
    property bool fontPreview: false     // la clave es una familia tipográfica: cada opción se ve con su letra
    signal picked(var key)
    readonly property var items: model.map(m => Array.isArray(m) ? { key: m[0], label: m[1] } : (typeof m === "object" ? m : { key: m, label: String(m) }))
    readonly property string currentLabel: (items.find(i => i.key === current) ?? { label: current !== undefined && current !== null && current !== "" ? String(current) : placeholder }).label
    implicitHeight: h
    implicitWidth: lbl.implicitWidth + 40
    radius: Theme.r(6)
    color: flat ? "transparent" : Theme.s4
    border.width: flat ? 0 : 1
    border.color: Theme.ov
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.flat ? 0 : 10
        anchors.rightMargin: root.flat ? 0 : 8
        spacing: 6
        Txt { id: lbl; Layout.fillWidth: true; text: root.currentLabel; weight: Font.Medium; font.family: root.fontPreview && root.current ? root.current : Theme.font; horizontalAlignment: root.flat && !root.alignLeft ? Text.AlignRight : Text.AlignLeft }
        Txt { text: "▾"; muted: true; size: 11 }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { search.text = ""; pop.open(); if (root.searchable) search.input.forceActiveFocus(); } }
    Popup {
        id: pop
        y: root.height + 4
        x: root.flat && !root.alignLeft ? root.width - width : 0
        width: root.popupWidth
        height: Math.min(320, list.contentHeight + (root.searchable ? 44 : 0) + 10)
        padding: 5
        background: Rectangle { color: Theme.s1; radius: Theme.r(8); border.width: 1; border.color: Theme.ov }
        ColumnLayout {
            anchors.fill: parent
            spacing: 4
            Field { id: search; visible: root.searchable; Layout.fillWidth: true; placeholder: "Buscar…"; h: 32 }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                model: { const q = search.text.toLowerCase(); return q ? root.items.filter(i => i.label.toLowerCase().includes(q) || String(i.key).toLowerCase().includes(q)) : root.items; }
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 30
                    radius: Theme.r(5)
                    color: root.current === modelData.key ? Theme.selBg : im.containsMouse ? Qt.alpha(Theme.t, 0.06) : "transparent"
                    Txt { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; text: parent.modelData.label; color: root.current === parent.modelData.key ? Theme.selText : Theme.t; font.family: root.fontPreview ? parent.modelData.key : Theme.font }
                    MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(parent.modelData.key); pop.close(); } }
                }
            }
        }
    }
}
