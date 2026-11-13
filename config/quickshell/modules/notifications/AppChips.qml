// Fila de filtros por app del centro de notificaciones (Recientes e Historial): «Todas» + una píldora por app, con
// cuántos avisos tiene. Una sola fila: si no caben, se desplaza en horizontal (rueda, arrastrar o la barra fina).
//   AppChips { apps: [{ key, app, n? }]; current: win.filtro; onPicked: k => win.filtro = k }
import QtQuick
import "../.."
import "../../components"

Flickable {
    id: root
    property var apps: []
    property string current: ""
    signal picked(string key)
    implicitHeight: row.implicitHeight + (contentWidth > width ? 8 : 0)
    contentWidth: row.implicitWidth
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentWidth > width
    clip: true
    // la rueda vertical también desplaza la fila
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.interactive
        onWheel: e => {
            const d = e.angleDelta.x !== 0 ? -e.angleDelta.x : -e.angleDelta.y;
            root.contentX = Math.max(0, Math.min(root.contentWidth - root.width, root.contentX + d * 0.6));
        }
    }
    ScrollHint { flick: root; horizontal: true; inset: 0 }
    Row {
        id: row
        spacing: 4
        Repeater {
            model: [{ key: "", app: "Todas" }].concat(root.apps)
            Rectangle {
                required property var modelData
                readonly property bool on: root.current === modelData.key
                implicitHeight: 22; implicitWidth: fT.implicitWidth + 16; radius: Theme.ctl(22)
                color: on ? Theme.pc : fMa.containsMouse ? Theme.fill2 : "transparent"
                border.width: on ? 0 : 1; border.color: Theme.ov
                Txt {
                    id: fT
                    anchors.centerIn: parent
                    text: parent.modelData.app + (parent.modelData.n > 1 ? " · " + parent.modelData.n : "")
                    size: 11; weight: Font.Medium; tabular: true
                    color: parent.on ? Theme.pcText : Theme.t
                }
                MouseArea {
                    id: fMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(parent.on ? "" : parent.modelData.key)
                }
            }
        }
    }
}
