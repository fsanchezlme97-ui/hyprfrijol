// Avisos emergentes (design «Notificaciones»): pila de 340 px abajo a la derecha, sobre la barra
// (arriba si la barra está arriba). Clic → acción por defecto · × o arrastrar a un lado → descartar ·
// respuesta en línea. El ratón encima pausa el temporizador. Los urgentes no se cierran solos y van delante.
// Varios avisos de la misma app se apilan (se ve el último con «+N»); clic en «+N» despliega el grupo.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "modules/notifications"
import "components"

// Ajustes › Notificaciones: notifyPosition ("auto" = según la barra · sup-der · sup-centro · sup-izq · inf-der ·
// inf-centro · inf-izq), notifyTimeout (segundos si la app no pide otro tiempo) y notifyMaxPopups (grupos a la vez).
PanelWindow {
    id: win
    readonly property string pos: Settings.get("notifyPosition", "auto")
    readonly property bool atTop: pos === "auto" ? Settings.get("barPos", "abajo") === "arriba" : pos.startsWith("sup")
    readonly property bool atLeft: pos !== "auto" && pos.endsWith("izq")
    readonly property bool centered: pos.endsWith("centro")
    readonly property int maxGroups: Math.max(1, Settings.get("notifyMaxPopups", 4))
    readonly property var groups: Notifs.popupGroups
    readonly property var shownGroups: groups.slice(0, maxGroups)
    readonly property int hiddenCount: groups.slice(maxGroups).reduce((a, g) => a + g.items.length, 0)
    property var expanded: ({})           // clave de app → desplegado
    function toggle(k) { const e = Object.assign({}, expanded); e[k] = !e[k]; expanded = e; }
    screen: Shell.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-notifications"
    // Necesita teclado solo cuando se escribe una respuesta
    WlrLayershell.keyboardFocus: replying ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    anchors { top: win.atTop; bottom: !win.atTop; right: !win.atLeft && !win.centered; left: win.atLeft }
    margins { top: 10; bottom: 10; right: 8; left: 8 }
    implicitWidth: 340
    // Nunca más alto que la pantalla (menos la barra): si se acumulan muchos avisos, la pila se desplaza
    readonly property real maxH: Math.max(160, (win.screen?.height ?? 900) - Settings.barEdge - 28)
    implicitHeight: Math.max(1, Math.min(column.implicitHeight, maxH))
    color: "transparent"
    visible: Notifs.popups.length > 0 && !Shell.focusMode && Shell.view !== "ajustes"
    mask: Region { item: flick }
    property bool replying: false
    onGroupsChanged: {   // olvida los grupos que ya no están
        const keys = groups.map(g => g.key), e = {};
        for (const k in expanded) if (expanded[k] && keys.includes(k)) e[k] = true;
        expanded = e;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        // abajo, el más reciente va pegado a la barra: si no cabe, se queda a la vista lo último
        function stick(): void {
            contentY = win.atTop ? Math.min(contentY, Math.max(0, contentHeight - height)) : Math.max(0, contentHeight - height);
        }
        onContentHeightChanged: if (!moving) stick()
        onHeightChanged: stick()
        ScrollHint { flick: flick; inset: 0 }

        Column {
            id: column
            width: flick.width
            spacing: 6

            Repeater {
                // abajo, el más reciente pegado a la barra; arriba, el más reciente arriba
                model: win.atTop ? win.shownGroups : win.shownGroups.slice().reverse()
                Column {
                    id: grp
                    required property var modelData
                    readonly property bool open: !!win.expanded[modelData.key] && modelData.items.length > 1
                    width: column.width
                    spacing: 6

                    // Cabecera del grupo desplegado: app · cuántos · contraer · descartar todos
                    Rectangle {
                        visible: grp.open
                        width: parent.width
                        height: 30
                        radius: Theme.r(8)
                        color: Theme.glassPopup
                        border.width: Theme.borderWidth; border.color: Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                            spacing: 6
                            Txt { Layout.fillWidth: true; text: grp.modelData.app + " · " + grp.modelData.items.length; weight: Font.DemiBold; size: 11.5 }
                            IconBtn { implicitWidth: 24; implicitHeight: 22; icon: "chevron_down"; iconSize: 11; fg: Theme.tv; tooltip: "Agrupar"; onClicked: win.toggle(grp.modelData.key) }
                            IconBtn { implicitWidth: 24; implicitHeight: 22; icon: "x"; iconSize: 11; fg: Theme.tv; tooltip: "Descartar todos"; onClicked: Notifs.dismissAll(grp.modelData.items) }
                        }
                    }

                    Repeater {
                        model: grp.open ? (win.atTop ? grp.modelData.items : grp.modelData.items.slice().reverse()) : grp.modelData.items.slice(0, 1)
                        NotifCard {
                            id: card
                            required property var modelData
                            n: modelData
                            mode: "toast"
                            width: column.width
                            stack: grp.open ? 0 : grp.modelData.items.length - 1
                            onStackToggled: win.toggle(grp.modelData.key)
                            // la pila se recrea al cambiar: solo entra animado lo recién llegado
                            readonly property bool fresh: Date.now() - (Notifs.arrived[n?.id] ?? 0) < 600
                            opacity: fresh ? 0 : 1
                            x: fresh ? (win.atLeft ? -24 : win.centered ? 0 : 24) : 0
                            Component.onCompleted: { opacity = 1; x = 0; }
                            Behavior on opacity { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
                            Behavior on x { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                            Timer {
                                running: !card.critical && !card.hovered && !win.replying && !grp.open
                                // lo que le queda desde que llegó (la pila se recrea al cambiar y no debe reiniciar la cuenta)
                                interval: Math.max(1200, (card.n.expireTimeout > 0 ? card.n.expireTimeout : Settings.get("notifyTimeout", Notifs.defaultTimeout / 1000) * 1000)
                                                         - (Date.now() - (Notifs.arrived[card.n.id] ?? Date.now())))
                                // la pila entera se va con su último aviso (los urgentes se quedan)
                                onTriggered: { for (const x of grp.modelData.items) if (!Notifs.isCritical(x)) Notifs.hidePopup(x); }
                            }
                            HoverHandler { onHoveredChanged: win.replying = hovered && (card.n?.hasInlineReply ?? false) }
                        }
                    }
                }
            }

            // «+N avisos más» → centro de notificaciones
            Rectangle {
                visible: win.hiddenCount > 0
                anchors.horizontalCenter: parent.horizontalCenter
                height: 26
                width: moreT.implicitWidth + 24
                radius: 13
                color: Theme.glassPopup
                border.width: Theme.borderWidth; border.color: Theme.border
                Txt { id: moreT; anchors.centerIn: parent; size: 11.5; weight: Font.Medium
                      text: "+" + win.hiddenCount + (win.hiddenCount === 1 ? " aviso más" : " avisos más") + " · ver todos" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("notificaciones") }
            }
        }
    }
}
