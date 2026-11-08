// Bandeja del sistema (StatusNotifierItem: OBS, Steam, Discord, Nextcloud, Valent…). Quickshell hace de
// StatusNotifierWatcher si no hay otro, así que las apps se registran solas.
// Ajustes › Barra › Bandeja del sistema:
//   barTray        (sí)  enseñarla
//   barTrayMax     (6)   iconos a la vista; el resto, y los «pasivos» (la app pide no molestar), van al «›»
//   barTrayHidden  ([])  ids que el usuario mandó al «›» (menú de cada icono: «Ocultar de la barra»)
// Iconos y clics: TrayItem.qml · menú con el estilo del shell: TrayMenu.qml.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import ".."
import "../components"

Item {
    id: root
    required property var barWindow
    property bool vertical: false
    readonly property var hiddenIds: Settings.get("barTrayHidden", [])
    readonly property int maxShown: Math.max(0, Number(Settings.get("barTrayMax", 6)) || 0)
    readonly property var all: SystemTray.items.values
    readonly property var shownItems: {
        const v = all.filter(i => i.status !== Status.Passive && !hiddenIds.includes(i.id));
        return v.slice(0, maxShown);
    }
    readonly property var extraItems: all.filter(i => !shownItems.includes(i))
    readonly property bool any: all.length > 0
    visible: any
    implicitWidth: vertical ? 26 : grid.implicitWidth
    implicitHeight: vertical ? grid.implicitHeight : 22

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 99
        spacing: root.vertical ? 2 : 0
        Repeater {
            model: root.shownItems
            TrayItem {
                required property var modelData
                item: modelData
                onMenuRequested: from => menu.open(modelData, from)
            }
        }
        // «›»: el resto (con su número)
        Rectangle {
            id: more
            visible: root.extraItems.length > 0
            width: root.vertical ? 24 : moreRow.implicitWidth + 8
            height: 22
            radius: Theme.r(6)
            color: over.visible || moreMa.containsMouse ? Theme.fill2 : "transparent"
            Row {
                id: moreRow
                anchors.centerIn: parent
                spacing: 1
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Settings.barPos === "abajo" ? "chevron_up" : Settings.barPos === "arriba" ? "chevron_down" : Settings.barPos === "izquierda" ? "chevron_right" : "chevron_left"
                    size: 12; color: Theme.tv
                }
                Txt { visible: !root.vertical; anchors.verticalCenter: parent.verticalCenter; text: root.extraItems.length; size: 10.5; muted: true; tabular: true }
            }
            MouseArea { id: moreMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: over.shown = !over.shown }
            BarTip { target: moreMa; text: over.visible ? "" : root.extraItems.length === 1 ? "1 icono más" : root.extraItems.length + " iconos más" }
        }
    }

    TrayMenu { id: menu }

    // Desplegable con los iconos que no caben o están ocultos
    PopupWindow {
        id: over
        property bool shown: false
        readonly property string side: Settings.barPos
        visible: shown && root.extraItems.length > 0
        anchor.item: more
        anchor.edges: side === "abajo" ? Edges.Top : side === "arriba" ? Edges.Bottom : side === "izquierda" ? Edges.Right : Edges.Left
        anchor.gravity: anchor.edges
        anchor.margins.top: side === "abajo" ? -6 : 0
        anchor.margins.bottom: side === "arriba" ? -6 : 0
        anchor.margins.left: side === "derecha" ? -6 : 0
        anchor.margins.right: side === "izquierda" ? -6 : 0
        color: "transparent"
        implicitWidth: box.width
        implicitHeight: box.height
        HyprlandFocusGrab { active: over.visible; windows: [over]; onCleared: over.shown = false }
        Rectangle {
            id: box
            width: Math.max(120, og.implicitWidth + 16)
            height: og.implicitHeight + 34
            radius: Theme.r(10)
            color: Theme.glassPopup
            border.width: 1
            border.color: Theme.border
            Txt { x: 10; y: 6; text: "Bandeja"; size: 11; muted: true; weight: Font.DemiBold }
            Grid {
                id: og
                x: 8; y: 26
                columns: Math.min(6, Math.max(1, root.extraItems.length))
                spacing: 2
                Repeater {
                    model: over.visible ? root.extraItems : []
                    TrayItem {
                        required property var modelData
                        item: modelData
                        size: 18
                        // el menú se ancla al «›» (este desplegable se cierra para que no se pisen)
                        onMenuRequested: { over.shown = false; menu.open(modelData, more); }
                    }
                }
            }
        }
    }
}
