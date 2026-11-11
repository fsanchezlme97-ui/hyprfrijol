// Ajustes › Productividad › Portapapeles (pestaña de ui/ProdTabs.qml; under: "enfoque" en SettingsApp):
// pegar al elegir (clipboardAutoPaste), vaciar al iniciar sesión (clipboardClearOnLogin → autostart.lua), lo último
// copiado en Spotlight (spotlightClipRecent), tamaño (clipMaxItems) y caducidad (clipExpireDays) que aplica
// scripts/hf-clip store, y las apps privadas (privateApps, la lista del asistente: lo copiado en ellas no se guarda).
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
    ProdTabs { current: "portapapeles" }

    Section {
        Layout.fillWidth: true
        title: "Historial"
        headerRight: Mono { text: "Super + V · cliphist" }
        LabeledRow {
            label: "Guardar hasta"; labelWidth: 140
            hint: "lo fijado no cuenta"
            Seg { model: [[100, "100"], [250, "250"], [750, "750"], [2000, "2000"]]; current: Settings.get("clipMaxItems", 750); onPicked: k => Settings.set("clipMaxItems", k) }
        }
        LabeledRow {
            label: "Borrar lo copiado tras"; labelWidth: 140
            Seg { model: [[1, "1 día"], [7, "7 días"], [30, "30 días"], [0, "Nunca"]]; current: Settings.get("clipExpireDays", 0); onPicked: k => Settings.set("clipExpireDays", k) }
        }
        SwRow { label: "Vaciar el portapapeles al iniciar sesión"; sub: "los elementos fijados se conservan"; key: "clipboardClearOnLogin"; def: false }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Txt { Layout.fillWidth: true; text: "Borrar ahora todo lo que no esté fijado"; muted: true; size: 11.5 }
            ConfirmButton { h: 28; text: "Vaciar"; confirmText: "¿Vaciar el historial? Sí"; onConfirmed: Clip.wipe() }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Al usarlo"
        SwRow { separator: false; label: "Pegar al elegir del portapapeles"; sub: "SUPER + V · escribe el elemento en la ventana activa"; key: "clipboardAutoPaste"; def: true }
        SwRow { label: "Lo último copiado en Spotlight"; sub: "3 elementos al abrirlo vacío · escribe : para todo el historial"; key: "spotlightClipRecent"; def: true }
        LinkRow {
            label: "Apps privadas"
            value: Settings.get("privateApps", []).length + " apps · no se guarda lo que copies en ellas"
            section: "iaprivacidad"; sectionLabel: "Asistente de IA"; target: "Apps privadas"
        }
    }
}
