// Compatibilidad con Omarchy · qs.Ui.KeyboardPanel: el panel de un widget de barra que recibe el teclado
// (focusTarget toma el foco al abrir; Esc lo gestiona el plugin con PanelKeyCatcher). Ver PopupCard.
import QtQuick
import qs.Commons

PopupCard {
    id: root
    property real drawnHeight: contentHeight
    property bool heightLive: false
    property bool popoutSwitching: false
    property bool popoutSwitchClosing: false
    property bool focusPrimed: false
    property Item focusTarget: null
    property Component content: null
    property bool contentRequested: false
    readonly property Item loadedContent: contentLoader.item
    readonly property real loadedContentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
    readonly property real morph: 1
    function ensureContent() { contentRequested = true; }
    function beginFocusPrime() { focusPrimed = true; }
    function publishCard() {}
    takesKeyboard: true
    onOpenChanged: if (open) { contentRequested = true; Qt.callLater(() => { if (root.focusTarget) root.focusTarget.forceActiveFocus(); }); }
    Loader {
        id: contentLoader
        anchors.fill: parent
        active: root.content !== null && (root.open || root.contentRequested)
        sourceComponent: root.content
    }
}
