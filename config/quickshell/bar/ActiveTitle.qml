// Título de la ventana activa (barra horizontal). Se recorta por caracteres (maxChars) y, además, por ancho
// con «…» (el ancho máximo lo pone BarH para no pisar la onda central).
import QtQuick
import Quickshell.Hyprland
import ".."
import "../components"

Txt {
    property int maxChars: 70
    readonly property string full: (Hyprland.activeToplevel?.title ?? "").replace(/\s+/g, " ").trim()
    text: full.length > maxChars ? full.slice(0, maxChars - 1).replace(/\s+$/, "") + "…" : full
    muted: true
}
