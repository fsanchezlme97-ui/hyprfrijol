// Casilla de selección de las tarjetas del Centro de aplicaciones (pulsarla marca/desmarca; el resto de la tarjeta abre la ficha).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: ck
    property bool on: false
    signal clicked()
    implicitWidth: 18; implicitHeight: 18; radius: Theme.r(4)
    color: on ? Theme.p : ckm.containsMouse ? Qt.alpha(Theme.p, 0.15) : "transparent"
    border.width: on ? 0 : 1.5
    border.color: ckm.containsMouse ? Theme.p : Theme.o
    Txt { anchors.centerIn: parent; visible: parent.on; text: "✓"; size: 11; weight: Font.Bold; color: Theme.pText }
    MouseArea { id: ckm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ck.clicked() }
}
