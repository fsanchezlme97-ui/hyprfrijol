// Ajustes › Productividad › Agenda y alarmas (pestaña de ui/ProdTabs.qml; under: "enfoque" en SettingsApp):
// calendarios .ics (calendarIcs, ui/IcsCalendars.qml), semana contraída (calendarCollapsed) y alarmas
// (alarms → services/Alarms.qml, las mismas de la ventana del pomodoro). El primer día de la semana y los relojes
// del mundo siguen en Fecha, hora e idioma.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    ProdTabs { current: "agenda" }

    Section {
        Layout.fillWidth: true
        title: "Agenda"
        headerRight: Mono { text: "Super + C · reloj de la barra" }
        SwRow { separator: false; label: "Ver solo la semana"; sub: "la agenda muestra la semana del día elegido en vez del mes"; key: "calendarCollapsed"; def: false }
        LinkRow { label: "Primer día de la semana y relojes del mundo"; section: "fecha"; sectionLabel: "Fecha, hora e idioma"; target: "Relojes del mundo" }
    }

    IcsCalendars { Layout.fillWidth: true }

    Section {
        Layout.fillWidth: true
        title: "Alarmas"
        headerRight: Mono { text: Alarms.count ? Alarms.count + (Alarms.count === 1 ? " alarma" : " alarmas") : "también en la ventana del pomodoro" }
        Repeater {
            model: Alarms.list
            RowLayout {
                id: al
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 10
                Txt { text: Alarms.hhmm(al.modelData); weight: Font.DemiBold; tabular: true; size: 15; opacity: al.modelData.on ? 1 : 0.5 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: al.modelData.label || "Alarma"; elide: Text.ElideRight }
                    Txt { text: Alarms.daysText(al.modelData); muted: true; size: 11 }
                }
                Sw { checked: !!al.modelData.on; onToggled: Alarms.toggle(al.modelData.id) }
                Button { text: "Quitar"; h: 26; onClicked: Alarms.remove(al.modelData.id) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: aTime; Layout.preferredWidth: 90; h: 30; icon: "clock"; placeholder: "07:30"; onAccepted: aAdd.clicked() }
            Field { id: aLabel; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Etiqueta (opcional)"; onAccepted: aAdd.clicked() }
            Seg { id: aDays; model: [["una", "Una vez"], ["laborables", "L–V"], ["todos", "Todos"]]; current: "una"; onPicked: k => current = k }
            Button {
                id: aAdd
                text: "Añadir"
                readonly property var hm: /^(\d{1,2})[:.h]?(\d{2})$/.exec(aTime.text.trim())
                enabled: !!hm && +hm[1] < 24 && +hm[2] < 60
                onClicked: {
                    if (!enabled) return;
                    Alarms.add(+hm[1], +hm[2], aLabel.text, { una: [], laborables: [1, 2, 3, 4, 5], todos: [1, 2, 3, 4, 5, 6, 7] }[aDays.current]);
                    aTime.text = aLabel.text = "";
                }
            }
        }
    }
}
