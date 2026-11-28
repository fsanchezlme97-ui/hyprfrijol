// Widget «Zonas horarias»: hasta tres relojes del mundo (ajuste worldClocks; Ajustes › Fecha, hora e idioma).
// Quien lo crea suma y quita WorldClock.users (el servicio solo mide mientras alguien enseña horas).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

WCard {
    id: w
    spacing: 8
    Component.onCompleted: WorldClock.users++
    Component.onDestruction: WorldClock.users--
    Txt { text: "Zonas horarias"; muted: true; size: 11.5 }
    Txt {
        visible: WorldClock.clocks.length === 0
        Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 12
        text: "Añade ciudades en Ajustes › Fecha, hora e idioma."
    }
    Repeater {
        model: WorldClock.clocks.slice(0, 3)
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Txt { Layout.fillWidth: true; text: modelData.name; weight: Font.Medium; elide: Text.ElideRight }
                Txt { text: modelData.diff + (modelData.day ? " · " + modelData.day : ""); muted: true; size: 11 }
            }
            Txt { text: modelData.time; size: 22; weight: Font.Medium; tabular: true }
        }
    }
}
