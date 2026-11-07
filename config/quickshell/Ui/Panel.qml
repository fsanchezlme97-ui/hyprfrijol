// Compatibilidad con Omarchy · qs.Ui.Panel: widget de barra con su panel emergente (botón + KeyboardPanel).
// Lleva el estado abierto (PanelController) y su destino IPC (open/close/show/hide/toggle).
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})
    property string fixedEdge: "center"
    property string ipcTarget: ""
    property bool manageIpc: true
    property alias controller: panelController
    property bool popoutSwitching: false
    property bool popoutSwitchClosing: false
    readonly property bool opened: panelController.open
    readonly property color barForeground: bar ? bar.barForeground : Commons.Color.foreground
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

    function open() { panelController.show(); }
    function close() { panelController.hide(); }
    function closeForPopoutSwitch() { popoutSwitchClosing = true; close(); Qt.callLater(() => popoutSwitchClosing = false); }
    function toggle() { opened ? close() : open(); }
    function switchPanel(direction) { return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(root, direction) : false; }
    function setting(name, fallback) { const v = settings ? settings[name] : undefined; return v === undefined || v === null ? fallback : v; }

    PanelController { id: panelController }
    ShellIpc {
        target: root.manageIpc ? root.ipcTarget : ""
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function show(): void { root.open(); }
        function hide(): void { root.close(); }
        function toggle(): void { root.toggle(); }
    }
}
