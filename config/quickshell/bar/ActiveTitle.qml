// Título de la ventana activa de la pantalla de esta barra (barra horizontal): la última enfocada en su espacio
// visible, así cada pantalla dice qué tiene delante aunque el foco esté en otra. Se recorta por caracteres
// (maxChars) y, además, por ancho con «…» (el ancho máximo lo pone BarH para no pisar la onda central).
import QtQuick
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"

Txt {
    property int maxChars: 70
    property string screenName: ""
    readonly property string full: {
        const m = HyprClients.monitorByName(screenName);
        if (!m) return (Hyprland.activeToplevel?.title ?? "").replace(/\s+/g, " ").trim();
        const c = HyprClients.onWorkspace(m.activeWorkspace?.id).reduce((a, w) => !a || w.focusHistoryID < a.focusHistoryID ? w : a, null);
        return (c?.title ?? "").replace(/\s+/g, " ").trim();
    }
    text: full.length > maxChars ? full.slice(0, maxChars - 1).replace(/\s+$/, "") + "…" : full
    muted: true
}
