// Compatibilidad con Omarchy · qs.Ui.OverlayWindow: ventana a pantalla completa en la capa Overlay con el
// teclado en exclusiva, en la pantalla con el foco. Se maneja con «shown» (no con visible).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: window
    property bool shown: false
    property int shownLayer: WlrLayer.Overlay
    property int shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    property var targetScreen: null
    readonly property var targetMonitor: targetScreen ? Hyprland.monitors.values.find(m => m.name === targetScreen.name) ?? null : null
    readonly property bool contentReady: shown && !!targetScreen
    readonly property bool contentRevealed: contentReady
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }
    onShownChanged: targetScreen = shown ? focusedScreen() : null
    visible: shown && !!targetScreen
    screen: targetScreen
    anchors { top: true; left: true; bottom: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: shownLayer
    WlrLayershell.keyboardFocus: shown ? shownKeyboardFocus : WlrKeyboardFocus.None
    WlrLayershell.namespace: "hf-omarchy-overlay"
}
