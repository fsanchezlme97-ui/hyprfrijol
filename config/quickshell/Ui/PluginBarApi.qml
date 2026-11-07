// Compatibilidad con Omarchy · qs.Ui.PluginBarApi: lo que un widget de barra ve como «bar».
// La barra de hyprfrijol (bar/OmarchySlot.qml) crea uno por widget y rellena los _callbacks.
import QtQuick

QtObject {
    id: api
    property string pluginId: ""
    property string moduleName: ""
    property var shell: null
    property color foreground: "transparent"
    property color barForeground: "transparent"
    property color background: "transparent"
    property color urgent: "transparent"
    property string fontFamily: ""
    property string position: "bottom"
    property bool vertical: false
    property int barSize: 32
    property bool transparent: false
    property bool foregroundAnimationEnabled: true
    property bool centerSectionRevealHeld: false
    property bool traySectionDragActive: false
    property bool traySectionPopoutOpen: false
    readonly property bool centerHoverRevealSuppressed: false
    property var activePopout: null
    property var clickTargets: []
    property var layoutConfig: ({})
    readonly property var foreignPopoutMarker: ({ foreign: true })
    property var _showTooltip: null
    property var _hideTooltip: null
    property var _moduleWidgets: null
    property var _run: null
    function setCenterHoverRevealSuppressed(v) {}
    function showTooltip(target, text) { if (_showTooltip) _showTooltip(target, String(text ?? "")); }
    function hideTooltip(target) { if (_hideTooltip) _hideTooltip(target); }
    function registerClickTarget(t) {}
    function unregisterClickTarget(t) {}
    function requestPopout(owner) { activePopout = owner; }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null; }
    function notePopoutCard(card) {}
    function popoutCardFor(owner) { return null; }
    function switchPanelFrom(owner, direction) { return false; }
    function targetBelongsToWindow(target, window) { return false; }
    function moduleWidgets(id) { return _moduleWidgets ? _moduleWidgets(String(id ?? "")) : []; }
    function run(command) { if (_run) _run(String(command ?? "")); }
}
