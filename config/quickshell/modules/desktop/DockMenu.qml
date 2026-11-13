// Menú del dock (clic derecho en una app): Maximizar / Restaurar, Minimizar / Mostrar, Nueva ventana,
// Fijar / Quitar del dock y Cerrar. Lo crea Dock.qml; «item» es el elemento del dock (Desktop.qml › dockItems).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

Glass {
    id: menu
    property var item: null
    property var desk: null
    signal done()
    kind: "popup"
    radius: Theme.r(10)
    width: 210
    height: col.implicitHeight + 12

    readonly property var wins: item?.wins ?? []
    readonly property var live: wins.filter(w => !WinMode.isMin(w))
    // Ventana sobre la que actúan Maximizar / Minimizar: la activa de la app, la más reciente o una minimizada
    readonly property var target: live.find(w => w.address === HyprClients.activeAddress) ?? live[0] ?? wins[0] ?? null
    readonly property bool targetMin: WinMode.isMin(target)
    readonly property var actions: {
        const a = [];
        if (target) {
            a.push({ k: "max", icon: "maximize", l: WinMode.isMax(target) && !targetMin ? "Restaurar tamaño" : "Maximizar" });
            a.push(targetMin ? { k: "show", icon: "window", l: "Mostrar" } : { k: "min", icon: "minus", l: "Minimizar" });
        }
        a.push({ k: "new", icon: "plus", l: "Nueva ventana" });
        if (item?.entry) a.push({ k: "pin", icon: "pin", l: item.pinned ? "Quitar del dock" : "Fijar en el dock", sep: true });
        if (wins.length) a.push({ k: "close", icon: "x", l: wins.length > 1 ? "Cerrar " + wins.length + " ventanas" : "Cerrar", sep: !item?.entry, danger: true });
        return a;
    }
    function run(k: string): void {
        const d = item, t = target;
        menu.done();
        if (!d) return;
        if (k === "max" && t) WinMode.toggleMaximize(t.address);
        else if (k === "min" && t) WinMode.minimize(t.address);
        else if (k === "show" && t) WinMode.restore(t.address);
        else if (k === "new") desk.launch(d);
        else if (k === "pin") desk.togglePin(d);
        else if (k === "close") for (const w of d.wins) WinMode.close(w.address);
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        spacing: 1
        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.preferredHeight: 24
            text: menu.item ? (menu.item.entry?.name ?? HyprClients.appName(menu.item.cls)) : ""
            weight: Font.DemiBold; size: 11.5; muted: true
        }
        Repeater {
            model: menu.actions
            ColumnLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                spacing: 1
                Rectangle { visible: !!row.modelData.sep; Layout.fillWidth: true; Layout.margins: 4; implicitHeight: 1; color: Theme.ov }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Theme.ctl(30)
                    color: rma.containsMouse ? (row.modelData.danger ? Qt.alpha(Theme.danger, 0.16) : Theme.selBg) : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        Icon { name: row.modelData.icon; size: 14; color: row.modelData.danger ? Theme.danger : rma.containsMouse ? Theme.selText : Theme.t }
                        Txt { Layout.fillWidth: true; text: row.modelData.l; color: row.modelData.danger ? Theme.danger : rma.containsMouse ? Theme.selText : Theme.t }
                    }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.run(row.modelData.k) }
                }
            }
        }
    }
}
