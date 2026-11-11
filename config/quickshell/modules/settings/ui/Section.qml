// Tarjeta de sección de la app de Ajustes (c.s3, radio 6, relleno 14, separación 10) con título de 15 px.
//   Section { title: "Estilo visual"; extra: Component { … } ; …contenido… }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string title: ""
    property alias headerRight: rightSlot.data
    property real pad: 14
    property real gap: 10
    default property alias content: col.data
    implicitHeight: col.implicitHeight + pad * 2
    implicitWidth: 300
    radius: Theme.r(7)
    color: Theme.card
    border.width: Theme.cardBorder
    border.color: Theme.border
    ColumnLayout {
        id: col
        x: root.pad; y: root.pad
        width: root.width - root.pad * 2
        spacing: root.gap
        RowLayout {
            visible: root.title !== "" || rightSlot.children.length > 0
            Layout.fillWidth: true
            Layout.minimumHeight: 22
            spacing: 8
            Txt {
                text: root.title
                size: 15
                weight: Font.DemiBold
                font.letterSpacing: -0.07
                Layout.fillWidth: true
            }
            Row { id: rightSlot; spacing: 8 }
        }
    }
}
