// Indicador de privacidad: aparece cuando una app usa el micrófono (o la pantalla se comparte).
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

Rectangle {
    readonly property int mic: Audio.micUsers.length
    visible: mic > 0
    implicitHeight: 22
    implicitWidth: r.implicitWidth + 16
    radius: Theme.r(11)
    color: Qt.alpha(Theme.ter, 0.16)
    RowLayout {
        id: r
        anchors.centerIn: parent
        spacing: 4
        Rectangle { width: 6; height: 6; radius: 3; color: Theme.ter }
        Txt { text: "Micrófono"; size: 11.5; weight: Font.Medium }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: Shell.toggle("ajustes") }
}
