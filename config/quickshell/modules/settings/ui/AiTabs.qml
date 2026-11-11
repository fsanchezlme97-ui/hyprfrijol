// Pestañas de Ajustes › Asistente de IA: la IA (sections/IA.qml), su privacidad (IAPrivacidad.qml), las recetas
// (IARecetas.qml), el dictado (Dictado.qml) y el panel lateral (Panel.qml) son una sola entrada de la lista; cada una sigue siendo su propia
// sección por dentro (búsqueda, enlaces «ajustesapp dictado»), marcada con under: "ia" en SettingsApp.
//   AiTabs { current: "ia" | "iaprivacidad" | "iarecetas" | "dictado" | "panel" }
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["ia", "Asistente"], ["iaprivacidad", "Privacidad"], ["iarecetas", "Recetas"], ["dictado", "Dictado"], ["panel", "Panel lateral y PiP"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
