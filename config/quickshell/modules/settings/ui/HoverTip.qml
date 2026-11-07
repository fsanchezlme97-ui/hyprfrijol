// Etiqueta flotante sobre un control al pasar el ratón (muestras de color, iconos…).
//   Rectangle { …  MouseArea { id: ma; hoverEnabled: true }  HoverTip { shown: ma.containsMouse; text: "Azul" } }
import QtQuick
import "../../.."
import "../../../components"

Rectangle {
    id: tip
    property bool shown: false
    property string text: ""
    visible: shown && text !== ""
    anchors.bottom: parent.top
    anchors.bottomMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    width: t.implicitWidth + 12
    height: 20
    radius: Theme.r(4)
    color: Theme.s1
    border.width: 1
    border.color: Theme.ov
    z: 50
    Txt { id: t; anchors.centerIn: parent; text: tip.text; size: 11 }
}
