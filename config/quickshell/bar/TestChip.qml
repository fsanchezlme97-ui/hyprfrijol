// Sesión de prueba (dev/try.sh) en marcha: su ventana anidada (clase aquamarine) vive escondida en special:hftry para
// no quitarte el foco. Este indicador solo aparece mientras haya una; clic: verla u ocultarla.
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: chip
    property bool vertical: false
    readonly property int count: HyprClients.clients.filter(c => c.class === "aquamarine").length
    readonly property bool want: count > 0
    readonly property bool showing: HyprClients.monitors.some(m => m.specialWorkspace?.name === "special:hftry")
    implicitWidth: 26
    implicitHeight: vertical ? 26 : 22
    radius: Theme.r(7)
    color: showing ? Theme.p : ma.containsMouse ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    Icon { anchors.centerIn: parent; name: "code"; size: 15; color: chip.showing ? Theme.pText : Theme.t; opacity: chip.showing ? 1 : 0.8 }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.dispatch('hl.dsp.workspace.toggle_special("hftry")')
    }
    BarTip {
        target: ma
        text: (chip.count > 1 ? chip.count + " sesiones de prueba" : "Sesión de prueba en marcha") + " · clic para " + (chip.showing ? "ocultarla" : "verla")
    }
}
