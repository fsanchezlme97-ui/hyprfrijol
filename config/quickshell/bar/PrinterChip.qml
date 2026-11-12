// Impresora 3D en la barra (Ajustes › Barra › Widgets en la barra: «impresora»; solo si está configurada).
// Imprimiendo: icono + barrita de progreso + % (y lo que queda al pasar el cursor); si no, el estado.
// Clic: ventana de la impresora (trabajo, temperaturas, cámara y pausa).
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-impresora"
    want: Printer.configured
    readonly property color dot: !Printer.online ? Theme.ov : Printer.state === "error" ? Theme.danger
                               : Printer.state === "paused" ? Theme.ter : Printer.busy ? Theme.p : Theme.tv
    implicitHeight: vertical ? vcol.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    Behavior on implicitWidth { enabled: !Theme.still && !chip.vertical; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
    Component.onCompleted: Printer.users++
    Component.onDestruction: Printer.users--
    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 5
        Item {
            implicitWidth: 15; implicitHeight: 15
            Icon { anchors.centerIn: parent; name: "printer"; color: Theme.t; opacity: Printer.online ? 1 : 0.55 }
            Rectangle { width: 6; height: 6; radius: 3; color: chip.dot; border.width: 1; border.color: Theme.glass
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: -1; bottomMargin: -1 } }
        }
        Rectangle {
            visible: Printer.busy
            Layout.preferredWidth: 30; Layout.preferredHeight: 4
            radius: Theme.r(2); color: Theme.fill2
            Progress { anchors.fill: parent; value: Printer.progress; period: 5000; busy: false; track: "transparent"; color: Printer.state === "paused" ? Theme.ter : Theme.p }
        }
        Txt {
            text: Printer.busy ? Math.round(Printer.progress * 100) + " %" : !Printer.online ? "sin conexión" : Printer.stateText
            tabular: true
            muted: !Printer.busy
        }
        Txt {
            visible: Printer.busy && (chip.hovered || chip.open) && Printer.left >= 0
            text: "· " + Printer.dur(Printer.left)
            muted: true; tabular: true
        }
    }
    ColumnLayout {
        id: vcol
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 2
        Icon { Layout.alignment: Qt.AlignHCenter; name: "printer"; color: Theme.t; opacity: Printer.online ? 1 : 0.55 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: Printer.busy ? Math.round(Printer.progress * 100) + "%" : "●"; color: Printer.busy ? Theme.t : chip.dot; size: 10.5; tabular: true }
    }
}
