// Pestañas de Ajustes › Plugins: los de Hyprland (hyprpm, sections/Plugins.qml) y los de Omarchy (hf-plugin,
// sections/PluginsOmarchy.qml) viven en una sola entrada de la lista; «omarchy» sigue siendo su propia sección por
// dentro (búsqueda, enlaces «ajustesapp omarchy»), marcada con under: "plugins" en SettingsApp.
//   PluginsTabs { current: "plugins" | "omarchy" }
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["plugins", "Hyprland (hyprpm)"], ["omarchy", "Omarchy"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
