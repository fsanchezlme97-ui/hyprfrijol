// Compatibilidad con Omarchy · qs.Ui.PanelController: estado abierto/cerrado de un panel.
import QtQuick

QtObject {
    property bool open: false
    function toggle() { open = !open; }
    function show() { if (!open) open = true; }
    function hide() { open = false; }
}
