// Menú de ventana (vista "ventana"), como el de GNOME u Openbox: Minimizar, Maximizar / Restaurar, Fijar en
// todos los espacios, Organizar (snap layouts), Mover a otro espacio y Cerrar, para la ventana activa.
// Se abre con el botón ⋮ de la barra de título (Hyprbars, config/apply/70-plugins.py: pulsar la barra enfoca antes
// la ventana) o con Alt + Espacio (hf:ventana). Sale junto al cursor si está sobre la ventana; si no, en su esquina.
// Esc o un clic fuera lo cierran (Overlay).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: root
    view: "ventana"
    place: "fill"

    property var target: null                  // cliente de Hyprland sobre el que actúa (la ventana activa al abrir)
    property point at: Qt.point(0, 0)          // esquina del menú, en coordenadas de la pantalla
    onShownChanged: if (shown) {
        target = HyprClients.client(HyprClients.activeAddress);
        if (!target) { Shell.close(); return; }
        cursorProc.running = true;
    }
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = root.target, sx = root.screen?.x ?? 0, sy = root.screen?.y ?? 0;
                let p = null;
                try { p = JSON.parse(text); } catch (e) {}
                const tx = t.at?.[0] ?? 0, ty = t.at?.[1] ?? 0, tw = t.size?.[0] ?? 0, th = t.size?.[1] ?? 0;
                const inside = p && p.x >= tx && p.x < tx + tw && p.y >= ty - 40 && p.y < ty + th;
                const gx = inside ? p.x : tx + 8, gy = inside ? p.y : ty + 8;
                // dentro del panel (Overlay deja márgenes por la barra) y sin salirse por la derecha ni por abajo
                root.at = Qt.point(Math.max(0, Math.min(root.panel.width - menu.width, gx - sx - root.mL)),
                                   Math.max(0, Math.min(root.panel.height - menu.height, gy - sy - root.mT)));
            }
        }
    }

    readonly property string addr: target?.address ?? ""
    readonly property bool pinned: !!target?.pinned
    readonly property int wsNow: target?.workspace?.id ?? 0
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id).sort((a, b) => a - b)
    readonly property var actions: [
        { k: "min", icon: "minus", l: "Minimizar" },
        { k: "max", icon: "maximize", l: WinMode.isMax(target) ? "Restaurar tamaño" : "Maximizar" },
        { k: "pin", icon: "pin", l: pinned ? "Quitar de todos los espacios" : "Mostrar en todos los espacios" },
        { k: "snap", icon: "grid", l: "Organizar…" },
        { k: "close", icon: "x", l: "Cerrar", sep: true, danger: true }
    ]
    function run(k: string): void {
        const a = addr, pin = pinned;
        Shell.close();
        if (!a) return;
        if (k === "min") WinMode.minimize(a);
        else if (k === "max") WinMode.toggleMaximize(a);
        else if (k === "pin") Shell.dispatch('hl.dsp.window.pin({ action = "' + (pin ? "disable" : "enable") + '", ' + WinMode.win(a) + ' })');
        else if (k === "snap") Shell.open("snap");
        else if (k === "close") WinMode.close(a);
        HyprClients.refresh();
    }
    function moveTo(ws): void {
        const a = addr;
        Shell.close();
        if (a) Shell.dispatch('hl.dsp.window.move({ workspace = ' + (ws === "nuevo" ? '"emptynm"' : ws) + ', follow = false, ' + WinMode.win(a) + ' })');
        HyprClients.refresh();
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Shell.close() }   // fuera del menú: cierra

    Glass {
        id: menu
        kind: "popup"
        radius: Theme.r(10)
        x: root.at.x; y: root.at.y
        width: 264
        height: col.implicitHeight + 12
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }       // los clics dentro no cierran

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 1
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.preferredHeight: 24
                text: root.target ? HyprClients.appName(root.target.class) : ""
                weight: Font.DemiBold; size: 11.5; muted: true
            }
            Repeater {
                model: root.actions
                ColumnLayout {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 1
                    // Mover a otro espacio: justo antes de Cerrar, una fila de números (+ uno nuevo vacío)
                    ColumnLayout {
                        visible: row.modelData.k === "close"
                        Layout.fillWidth: true
                        spacing: 2
                        Rectangle { Layout.fillWidth: true; Layout.margins: 4; implicitHeight: 1; color: Theme.ov }
                        Txt { Layout.leftMargin: 8; text: "Mover al espacio"; size: 11; muted: true }
                        Flow {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.bottomMargin: 2
                            spacing: 4
                            Repeater {
                                model: root.workspaces.concat(["nuevo"])
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property bool here: chip.modelData === root.wsNow
                                    width: chip.modelData === "nuevo" ? 30 : 28; height: 26
                                    radius: Theme.ctl(26)
                                    color: here ? Theme.selBg : cma.containsMouse ? Theme.s3 : Theme.s1
                                    Txt { anchors.centerIn: parent; text: chip.modelData === "nuevo" ? "+" : String(chip.modelData); size: 11.5; color: chip.here ? Theme.selText : Theme.t }
                                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; enabled: !chip.here; cursorShape: Qt.PointingHandCursor; onClicked: root.moveTo(chip.modelData) }
                                }
                            }
                        }
                    }
                    Rectangle { visible: !!row.modelData.sep; Layout.fillWidth: true; Layout.margins: 4; implicitHeight: 1; color: Theme.ov }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Theme.ctl(30)
                        color: rma.containsMouse ? (row.modelData.danger ? Qt.alpha(Theme.danger, 0.16) : Theme.selBg) : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                            spacing: 9
                            Icon { name: row.modelData.icon; size: 14; color: row.modelData.danger ? Theme.danger : rma.containsMouse ? Theme.selText : Theme.t }
                            Txt { Layout.fillWidth: true; text: row.modelData.l; color: row.modelData.danger ? Theme.danger : rma.containsMouse ? Theme.selText : Theme.t }
                        }
                        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.run(row.modelData.k) }
                    }
                }
            }
        }
    }
}
