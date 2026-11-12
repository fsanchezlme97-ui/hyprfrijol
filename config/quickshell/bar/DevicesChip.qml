// Unidades extraíbles en la barra: solo se ve mientras hay una memoria USB, tarjeta SD o imagen montada
// (Ajustes › Almacenamiento › «Icono en la barra», devicesBarIcon). Icono USB + cuántas (si hay más de una) y,
// al pasar el cursor, el nombre. Clic: menú con la lista (abrir, expulsar, expulsar todas) — vista "w-dispositivos".
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-dispositivos"
    want: Settings.get("devicesBarIcon", true) !== false && Devices.mounted.length > 0
    readonly property string usb: '<path d="M10 2h4v4h-4z"/><path d="M8 6h8v9a4 4 0 0 1-8 0z"/><path d="M12 19v3"/>'
    implicitHeight: vertical ? vcol.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    Behavior on implicitWidth { enabled: !Theme.still && !chip.vertical; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 5
        Icon { svg: chip.usb; size: 15; color: Theme.t }
        Txt { visible: Devices.mounted.length > 1; text: String(Devices.mounted.length); tabular: true }
        Txt {
            visible: chip.hovered && Devices.mounted.length === 1
            text: Devices.mounted[0]?.name ?? ""
            Layout.maximumWidth: 160
            muted: true
        }
    }
    ColumnLayout {
        id: vcol
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 2
        Icon { Layout.alignment: Qt.AlignHCenter; svg: chip.usb; size: 15; color: Theme.t }
        Txt { visible: Devices.mounted.length > 1; Layout.alignment: Qt.AlignHCenter; text: String(Devices.mounted.length); size: 10.5; tabular: true }
    }
}
