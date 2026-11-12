// Pestañas de Ajustes › Asistente de IA: Inicio (sections/IAInicio.qml, la entrada de la lista), proveedor, modelos,
// permisos y personalidad (IA.qml, «iaproveedor»), su privacidad (IAPrivacidad.qml), las recetas
// (IARecetas.qml), el dictado (Dictado.qml) y el panel lateral (Panel.qml) son una sola entrada de la lista; cada una sigue siendo su propia
// sección por dentro (búsqueda, enlaces «ajustesapp dictado»), marcada con under: "ia" en SettingsApp.
//   AiTabs { current: "ia" | "iaproveedor" | "iaprivacidad" | "iarecetas" | "iaintegraciones" | "dictado" | "panel" }
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["ia", "Inicio"], ["iaproveedor", "Proveedor y permisos"], ["iaprivacidad", "Privacidad"], ["iarecetas", "Recetas"], ["iaintegraciones", "Integraciones"], ["dictado", "Dictado"], ["panel", "Panel lateral y PiP"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
