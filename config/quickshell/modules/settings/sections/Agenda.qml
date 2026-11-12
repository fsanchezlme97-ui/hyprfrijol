// Ajustes › Productividad › Agenda (pestaña de ui/ProdTabs.qml; under: "enfoque" en SettingsApp): calendarios .ics
// (calendarIcs, ui/IcsCalendars.qml) y semana contraída (calendarCollapsed). Las alarmas se gestionan en su ventana
// (la del pomodoro, Shell.open("w-pomodoro", "alarmas")); aquí solo el botón para abrirla. El primer día de la semana y los relojes
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
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Txt {
                Layout.fillWidth: true
                text: (Alarms.count ? (Alarms.count === 1 ? "Tienes 1 alarma. " : "Tienes " + Alarms.count + " alarmas. ") : "")
                    + "Se crean y se cambian en su ventana, junto al pomodoro y el temporizador."
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
            Button { text: "Abrir alarmas"; h: 28; onClicked: Shell.open("w-pomodoro", "alarmas") }
        }
    }
}
