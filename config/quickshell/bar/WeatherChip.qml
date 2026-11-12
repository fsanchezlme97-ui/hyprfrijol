// Clima en la barra (Ajustes › Barra › Widgets en la barra: «clima»): icono + temperatura; al pasar el cursor
// (o siempre, con barWeatherText) se despliega el estado del cielo. Clic: ventana del clima (previsión por
// horas y de 3 días). En la barra vertical, icono y grados apilados.
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-clima"
    want: Weather.ready || Weather.err !== ""
    readonly property bool showText: Settings.get("barWeatherText", false) === true || hovered || open
    implicitHeight: vertical ? col.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    Behavior on implicitWidth { enabled: !Theme.still && !chip.vertical; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
    clip: true
    UseCounter { target: Weather; active: chip.visible }
    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.verticalCenter: parent.verticalCenter
        x: 7
        spacing: 5
        Icon { name: Weather.ready ? Weather.icon : "cloud"; color: Theme.t; opacity: Weather.ready ? 1 : 0.5 }
        Txt { text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"; weight: Font.DemiBold; tabular: true }
        Txt {
            id: desc
            readonly property string full: Weather.ready ? Weather.desc : ""
            text: full
            muted: true
            Layout.preferredWidth: chip.showText && full !== "" ? implicitWidth : 0
            opacity: chip.showText ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        }
    }
    ColumnLayout {
        id: col
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 1
        Icon { Layout.alignment: Qt.AlignHCenter; name: Weather.ready ? Weather.icon : "cloud"; color: Theme.t }
        Txt { Layout.alignment: Qt.AlignHCenter; text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"; size: 11; weight: Font.DemiBold; tabular: true }
    }
}
