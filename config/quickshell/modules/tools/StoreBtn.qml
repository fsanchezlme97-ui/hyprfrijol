// Botón pequeño de las tarjetas del Centro de aplicaciones (Abrir / Instalar / Desinstalar / Actualizar).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: mb
    property string text: ""
    property bool danger: false
    property bool primary: false
    signal clicked()
    implicitWidth: mt.implicitWidth + 16
    implicitHeight: 22
    radius: Theme.ctl(22)
    color: primary ? Theme.p : mbm.containsMouse ? Qt.alpha(Theme.t, 0.07) : "transparent"
    border.width: primary ? 0 : 1
    border.color: danger && mbm.containsMouse ? Theme.danger : Theme.ov
    Txt { id: mt; anchors.centerIn: parent; text: mb.text; size: 11; weight: Font.DemiBold; color: mb.primary ? Theme.pText : mb.danger ? Theme.danger : Theme.t }
    MouseArea { id: mbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mb.clicked() }
}
