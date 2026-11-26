// Indicador de privacidad: aparece cuando una app usa el micrófono o cuando se está viendo tu pantalla (grabación,
// videollamada, escritorio remoto: services/ScreenShare.qml).
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

Rectangle {
    readonly property bool mic: Audio.micUsers.length > 0
    readonly property bool screen: ScreenShare.active
    visible: mic || screen
    implicitHeight: 22
    implicitWidth: r.implicitWidth + 16
    radius: Theme.r(11)
    color: Qt.alpha(Theme.ter, 0.16)
    RowLayout {
        id: r
        anchors.centerIn: parent
        spacing: 4
        Rectangle { width: 6; height: 6; radius: 3; color: Theme.ter }
        Txt { text: [mic ? "Micrófono" : "", screen ? "Pantalla" : ""].filter(x => x).join(" · "); size: 11.5; weight: Font.Medium }
    }
    Accessible.role: Accessible.Button
    Accessible.name: screen ? (mic ? "Se usan el micrófono y la pantalla" : "Se está viendo tu pantalla") : "Una app usa el micrófono"
    // con la pantalla compartida lleva a Privacidad, donde se ve qué app es
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: screen ? Shell.open("ajustesapp", "privacidad") : Shell.toggle("ajustes") }
}
