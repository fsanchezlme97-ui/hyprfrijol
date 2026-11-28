// Widget «Calendario»: el mes (lunes primero), hoy marcado y un punto en los días con eventos (services/Events.qml).
// ‹ › cambian de mes; pulsar un día abre la agenda.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

WCard {
    id: w
    property date month: new Date(Time.now.getFullYear(), Time.now.getMonth(), 1)
    readonly property var es: Qt.locale("es_ES")
    readonly property int offset: (month.getDay() + 6) % 7
    readonly property int count: Math.ceil((offset + new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()) / 7) * 7
    function shift(d): void { month = new Date(month.getFullYear(), month.getMonth() + d, 1); }
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Txt { Layout.fillWidth: true; text: { const t = w.es.toString(w.month, "MMMM yyyy"); return t.charAt(0).toUpperCase() + t.slice(1); } weight: Font.DemiBold }
        IconBtn { icon: "chevron_left"; tooltip: "Mes anterior"; onClicked: w.shift(-1) }
        IconBtn { icon: "chevron_right"; tooltip: "Mes siguiente"; onClicked: w.shift(1) }
    }
    Grid {
        Layout.fillWidth: true
        columns: 7
        readonly property real cell: width / 7
        Repeater {
            model: ["L", "M", "X", "J", "V", "S", "D"]
            Txt { required property string modelData; width: parent.cell; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; size: 11 }
        }
        Repeater {
            model: w.count
            Item {
                id: cell
                required property int index
                readonly property date d: new Date(w.month.getFullYear(), w.month.getMonth(), 1 - w.offset + index)
                readonly property bool inMonth: d.getMonth() === w.month.getMonth()
                readonly property bool today: d.toDateString() === Time.now.toDateString()
                width: parent.cell; height: 28
                Rectangle { visible: cell.today; anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: Theme.p }
                Txt {
                    anchors.centerIn: parent; text: cell.d.getDate(); size: 12; tabular: true
                    weight: cell.today ? Font.DemiBold : Font.Normal
                    color: cell.today ? Theme.pText : cell.inMonth ? Theme.t : Theme.tv
                    opacity: cell.inMonth ? 1 : 0.5
                }
                Rectangle {
                    visible: Events.hasDay(cell.d) && !cell.today
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                    width: 4; height: 4; radius: 2; color: Theme.p
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Shell.close(); Shell.open("agenda"); } }
            }
        }
    }
}
