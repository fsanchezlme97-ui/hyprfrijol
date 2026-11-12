// Widgets (clima, sistema, impresora 3D…) como ventanas flotantes, no sobre el escritorio:
// - Cada chip de la barra (bar/WeatherChip, StatsChip, PrinterChip) abre su ventana pegada a él:
//   vistas "w-clima", "w-sistema", "w-impresora" (ChipPopup). Cuáles hay en la barra: Ajustes › Barra ›
//   Ajustes › Widgets de la barra (módulos «clima», «recursos», «impresora» de barModules).
// - Vista "widgets" (Super + G): todos los widgets juntos en un panel flotante junto a la barra, con
//   «Editar widgets» para elegir cuáles y en qué orden (ajuste "widgets").
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"

Scope {
    WeatherPopup {}
    SystemPopup {}
    PrinterPopup {}
    PomodoroPopup {}

    Overlay {
        id: all
        view: "widgets"
        morphs: true                // se transforma desde/hacia el panel que estaba abierto (components/Morph)
        place: "bottom-right"
        panelWidth: 336
        panelHeight: Math.min(colLoader.implicitHeight, 9999)
        Flickable {
            id: fl
            anchors.fill: parent
            contentHeight: colLoader.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            clip: true
            Loader {
                id: colLoader
                active: all.shown || all.visible
                width: fl.width
                sourceComponent: WidgetColumn {
                    width: fl.width
                    onCloseRequested: Shell.close()
                }
            }
        }
    }
}
