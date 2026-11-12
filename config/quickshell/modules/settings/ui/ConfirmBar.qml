// Barra «¿Se ve bien?» de Ajustes (services/Confirm.qml): cuenta atrás + Mantener / Deshacer.
//   ConfirmBar { anchors.bottom: …; anchors.horizontalCenter: … }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"

Rectangle {
    id: root
    visible: opacity > 0
    opacity: Confirm.active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    implicitWidth: Math.min(620, row.implicitWidth + 32)
    implicitHeight: 52
    radius: Theme.r(10)
    color: Theme.glassy ? Theme.s1 : Theme.s4
    border.width: 1
    border.color: Theme.glassy ? Theme.border : Theme.ov
    clip: true
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 10
        spacing: 10
        Icon { name: "monitor"; size: 16; color: Theme.p }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: "¿Se ve bien? Se deshace en " + Confirm.left + " s"; weight: Font.DemiBold; color: Theme.p; tabular: true }
            Txt { Layout.fillWidth: true; text: Confirm.label; muted: true; size: 11.5 }
        }
        Button { kind: "primary"; text: "Mantener"; onClicked: Confirm.keep() }
        Button { text: "Deshacer"; onClicked: Confirm.revert() }
    }
    // progreso de la cuenta atrás
    Rectangle {
        anchors.bottom: parent.bottom
        height: 2
        color: Theme.p
        width: parent.width * (Confirm.total > 0 ? Confirm.left / Confirm.total : 0)
        Behavior on width { NumberAnimation { duration: Theme.ms(1000); easing.type: Easing.Linear } }   // segundo a segundo, sin tirones
    }
}
