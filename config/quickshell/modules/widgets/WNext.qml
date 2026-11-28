// Widget «Próxima reunión»: título, cuenta atrás (hh:mm) y «Unirse» si el evento trae enlace de videollamada.
// Datos: services/Events.qml (eventos locales y .ics de Ajustes › Fecha, hora e idioma).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

WCard {
    id: w
    readonly property var ev: Events.next
    readonly property int mins: ev ? Math.max(0, Math.round((ev.start - Time.now) / 60000)) : 0
    readonly property bool going: !!ev && ev.start <= Time.now
    readonly property string count: String(Math.floor(mins / 60)).padStart(2, "0") + ":" + String(mins % 60).padStart(2, "0")
    spacing: 4
    Txt { text: "Próxima reunión"; muted: true; size: 11.5 }
    Txt {
        visible: !w.ev
        text: "Nada por ahora"; size: 22; weight: Font.Medium
    }
    Txt {
        visible: !!w.ev
        Layout.fillWidth: true
        text: w.going ? "En curso" : w.mins >= 24 * 60 ? Events.relative(w.ev.start) : "en " + w.count + " h"
        size: 26; weight: Font.Medium; tabular: true; elide: Text.ElideRight
    }
    Txt {
        visible: !!w.ev
        Layout.fillWidth: true
        text: w.ev ? w.ev.title : ""
        weight: Font.DemiBold; elide: Text.ElideRight
    }
    Txt {
        visible: !!w.ev
        Layout.fillWidth: true
        text: w.ev ? Events.hhmm(w.ev.start) + " – " + Events.hhmm(w.ev.end) + (w.ev.where && !w.ev.link ? " · " + w.ev.where : "") : ""
        muted: true; size: 11.5; elide: Text.ElideRight
    }
    WBtn {
        visible: !!w.ev && !!w.ev.link
        Layout.topMargin: 8
        primary: w.going || w.mins <= 10
        text: "Unirse"; icon: "external"
        onClicked: { Qt.openUrlExternally(w.ev.link); Shell.close(); }
    }
    WBtn {
        visible: !w.ev
        Layout.topMargin: 8
        text: "Abrir agenda"; icon: "calendar"
        onClicked: { Shell.close(); Shell.open("agenda"); }
    }
}
