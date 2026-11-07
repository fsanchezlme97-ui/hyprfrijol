// Compatibilidad con Omarchy · qs.Ui.PopupCard: tarjeta emergente pegada a un elemento de la barra.
//   PopupCard { anchorItem: boton; bar: root.bar; open: …; contentWidth: …; contentHeight: …; …contenido… }
// En hyprfrijol es un PopupWindow anclado al elemento (el compositor lo coloca junto a la barra, en el lado que
// toque según su posición) con el fondo de los paneles del tema. KeyboardPanel es lo mismo con el teclado.
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../"

PopupWindow {
    id: root
    required property Item anchorItem
    required property QtObject bar
    property var owner: null
    property int margin: Style.gapsOut
    property int padding: Style.spacing.popupPadding
    property int contentWidth: Style.space(280)
    property int contentHeight: Style.space(200)
    property color borderColor: Commons.Color.popups.border
    property var borderSpec: Border.flat(borderColor, 1)
    property bool open: false
    property bool centerOnBar: false
    property string triggerMode: "click"
    property bool takesKeyboard: false
    readonly property var coordinatorKey: owner || root
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property var popupScreen: anchorWindow ? anchorWindow.screen : null
    readonly property bool containsMouse: cardHover.hovered
    readonly property real screenW: popupScreen ? popupScreen.width : 0
    readonly property real screenH: popupScreen ? popupScreen.height : 0
    readonly property real barThickness: bar ? bar.barSize : 0
    readonly property real availableCardWidth: screenW > 0 ? Math.max(0, screenW - margin * 2 - padding * 2) : 0
    readonly property real availableCardHeight: screenH > 0 ? Math.max(0, screenH - barThickness - margin * 3 - padding * 2) : 0
    readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
    readonly property string barPos: bar ? bar.position : "bottom"
    default property alias cardContent: contentHolder.data

    function fittedContentWidth(w, cap) { let v = Math.max(0, Math.ceil(Number(w) || 0)); if (cap !== undefined && cap > 0) v = Math.min(v, cap); return availableCardWidth > 0 ? Math.min(v, availableCardWidth) : v; }
    function fittedContentHeight(h, cap) { let v = Math.max(0, Math.ceil(Number(h) || 0)); if (cap !== undefined && cap > 0) v = Math.min(v, cap); return availableCardHeight > 0 ? Math.min(v, availableCardHeight) : v; }
    function cappedContentHeight(h) { return availableCardHeight > 0 ? Math.min(h, availableCardHeight) : h; }
    function close() { if (owner && typeof owner.close === "function") owner.close(); else open = false; }

    anchor.item: anchorItem
    anchor.rect: Qt.rect(-margin, -margin, (anchorItem ? anchorItem.width : 0) + margin * 2, (anchorItem ? anchorItem.height : 0) + margin * 2)
    anchor.edges: barPos === "top" ? Edges.Bottom : barPos === "left" ? Edges.Right : barPos === "right" ? Edges.Left : Edges.Top
    anchor.gravity: anchor.edges
    grabFocus: takesKeyboard
    visible: open && !!anchorWindow && anchorWindow.visible
    color: "transparent"
    implicitWidth: Math.max(1, contentWidth + padding * 2)
    implicitHeight: Math.max(1, contentHeight + padding * 2)
    onVisibleChanged: if (!visible && open) Qt.callLater(() => { if (root.open && !root.visible) root.close(); })

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Theme.winSolid
        border.color: Theme.ov
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
        HoverHandler { id: cardHover }
        Item {
            id: contentHolder
            x: root.padding
            y: root.padding
            width: root.contentWidth
            height: root.contentHeight
        }
    }
}
