// Botón de tarjeta de widget (28 px, fondo fill2)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked()
    Layout.fillWidth: true
    Layout.preferredHeight: 28
    implicitWidth: row.implicitWidth + 20
    implicitHeight: 28
    radius: Theme.ctl(28)
    color: primary ? Theme.p : danger && ma.containsMouse ? Qt.alpha(Theme.danger, 0.22) : ma.containsMouse ? Qt.alpha(Theme.t, 0.14) : Theme.fill2
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { visible: b.icon !== ""; name: b.icon; size: 13; color: b.primary ? Theme.pText : b.danger ? Theme.danger : Theme.t; anchors.verticalCenter: parent.verticalCenter }
        Txt { visible: b.text !== ""; text: b.text; color: b.primary ? Theme.pText : b.danger ? Theme.danger : Theme.t; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: b.enabled; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
