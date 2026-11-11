// Barra de título de la ventana activa en los espacios flotantes, dibujada por el shell (sin plugins de Hyprland):
// icono y título, menú de ventana (WinMenu.qml), minimizar, maximizar / restaurar y cerrar. Arrastrarla mueve la
// ventana y el doble clic la maximiza. Una por pantalla (la crea Desktop.qml).
//   - Solo en la ventana activa: en flotante, la ventana activa queda encima, así que la barra no tapa otras.
//   - No sale en las apps que ya dibujan su barra ("barsOwnFrame": navegadores, GNOME, VS Code…), ni en las del
//     propio shell, ni a pantalla completa. Se apaga con "titleBars" = false (Ajustes › Escritorio y gestos).
//   - Va justo encima de la ventana; si no cabe (ventana maximizada o pegada arriba), dentro de la ventana y
//     escondida: aparece al llevar el cursor al borde de arriba.
//   - La geometría se sondea cada 100 ms mientras se ve (Hyprland no avisa al mover o redimensionar una flotante).
// Capa "top" a pantalla completa y transparente: solo la barra recibe clics (mask); durante un arrastre, toda.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: root
    required property int wsId                      // espacio activo de esta pantalla

    readonly property int barH: 32
    readonly property int radius: { const r = Settings.get("rounding", 8); return typeof r === "number" ? r : 8; }
    readonly property bool enabledHere: { WinMode.mode; WinMode.overrides; return Settings.get("titleBars", true) !== false && WinMode.isFloat(wsId); }
    readonly property var ownFrame: (Settings.get("barsOwnFrame", []) ?? []).map(c => String(c).toLowerCase())
        .concat(["org.quickshell", "hf-webapp.qml6"])

    // La ventana a la que pertenece la barra: la activa, si flota en esta pantalla y no trae barra propia
    readonly property var target: {
        HyprClients.refreshes;
        if (!enabledHere) return null;
        const c = HyprClients.client(HyprClients.activeAddress);
        if (!c || !c.floating || c.workspace?.id !== wsId || (c.fullscreen ?? 0) === 2) return null;
        if (HyprClients.monitorById(c.monitor)?.name !== screen?.name) return null;
        if (ownFrame.includes(String(c.class ?? "").toLowerCase())) return null;
        return c;
    }
    readonly property string addr: target?.address ?? ""

    // Geometría al día (sondeo) o, mientras se arrastra, la que pone el propio arrastre
    property var live: null
    readonly property var geo: {
        const g = live && live.address === addr ? live : target;
        return g ? { x: g.at[0], y: g.at[1], w: g.size[0], h: g.size[1], max: (g.fullscreen ?? 0) === 1 } : null;
    }
    Timer {
        interval: 100; repeat: true
        running: root.addr !== "" && !drag.active
        onTriggered: if (!poll.running) poll.running = true
    }
    Process {
        id: poll
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            property string last: ""
            onStreamFinished: {
                if (text === last) return;
                last = text;
                try { const j = JSON.parse(text); if (j?.address) root.live = j; } catch (e) {}
            }
        }
    }

    property int border: 2
    Process {
        id: borderProc
        running: true
        command: ["hyprctl", "getoption", "general:border_size", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.border = JSON.parse(text).int ?? 2; } catch (e) {} } }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "configreloaded") borderProc.running = true; }
    }

    // Colocación, en coordenadas de esta pantalla
    readonly property int topLimit: { HyprClients.refreshes; return HyprClients.monitorByName(screen?.name ?? "")?.reserved?.[1] ?? 0; }
    readonly property real sx: screen?.x ?? 0
    readonly property real sy: screen?.y ?? 0
    readonly property bool inside: !!geo && (geo.max || geo.y - sy - border - barH < topLimit)
    readonly property bool revealed: !inside || hover.hovered || drag.active || strip.hovered

    visible: !!geo
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hf-titlebar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: drag.active ? full : root.revealed ? bar : stripZone }

    Item { id: full; anchors.fill: parent }
    // Escondida dentro de la ventana: una franja de 4 px en su borde de arriba la hace aparecer
    Item {
        id: stripZone
        visible: root.inside
        x: bar.x; y: bar.y; width: bar.width; height: 4
        HoverHandler { id: strip }
    }

    // ── Arrastre: mueve la ventana (Hyprland, coordenadas globales), ~60 veces por segundo como mucho ──
    property point dragPos: Qt.point(0, 0)
    Timer {
        id: mover
        interval: 16
        property bool dirty: false
        onTriggered: if (dirty) {
            dirty = false;
            Hyprland.dispatch('hl.dsp.window.move({ x = ' + Math.round(root.dragPos.x) + ', y = ' + Math.round(root.dragPos.y)
                              + ', exact = true, ' + WinMode.win(root.addr) + ' })');
        }
    }

    Rectangle {
        id: bar
        readonly property real gx: drag.active ? root.dragPos.x : (root.geo?.x ?? 0)
        readonly property real gy: drag.active ? root.dragPos.y : (root.geo?.y ?? 0)
        x: gx - root.sx - root.border
        y: root.inside && !drag.active ? gy - root.sy : gy - root.sy - root.border - root.barH
        width: (root.geo?.w ?? 0) + 2 * root.border
        height: root.barH
        topLeftRadius: root.radius; topRightRadius: root.radius
        bottomLeftRadius: root.inside && !drag.active ? root.radius : 0
        bottomRightRadius: bottomLeftRadius
        color: Qt.alpha(Theme.s1, 0.94)
        opacity: root.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        HoverHandler { id: hover }

        MouseArea {
            id: drag
            anchors.fill: parent
            property point start: Qt.point(0, 0)
            property point startAt: Qt.point(0, 0)
            property bool active: false
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: m => {
                if (m.button === Qt.RightButton) { Shell.open("ventana"); return; }
                if (m.button === Qt.MiddleButton) { WinMode.minimize(root.addr); return; }
                if (root.geo?.max) return;                      // maximizada: no se arrastra (doble clic la restaura)
                start = mapToItem(full, m.x, m.y);
                startAt = Qt.point(root.geo.x, root.geo.y);
                root.dragPos = startAt;
            }
            onPositionChanged: m => {
                if (!(m.buttons & Qt.LeftButton) || root.geo?.max) return;
                const p = mapToItem(full, m.x, m.y);
                if (!active && Math.abs(p.x - start.x) + Math.abs(p.y - start.y) < 4) return;
                active = true;
                // la barra no se mete bajo la del shell
                const minY = root.sy + root.topLimit + root.border + root.barH;
                root.dragPos = Qt.point(startAt.x + p.x - start.x, Math.max(minY, startAt.y + p.y - start.y));
                mover.dirty = true;
                if (!mover.running) mover.start();
            }
            onReleased: {
                if (active) {
                    mover.stop(); mover.dirty = true; mover.triggered();
                    // hasta el siguiente sondeo, la ventana está donde se soltó (sin saltar a la posición vieja)
                    root.live = Object.assign({}, root.live ?? root.target, { address: root.addr, at: [Math.round(root.dragPos.x), Math.round(root.dragPos.y)] });
                }
                active = false;
            }
            onDoubleClicked: m => { if (m.button === Qt.LeftButton) WinMode.toggleMaximize(root.addr); }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 4 }
            spacing: 8
            Image {
                Layout.preferredWidth: 16; Layout.preferredHeight: 16
                source: root.target ? HyprClients.iconFor(root.target.class) : ""
                sourceSize: Qt.size(32, 32)
                visible: status === Image.Ready
            }
            Txt {
                Layout.fillWidth: true
                text: root.target?.title || (root.target ? HyprClients.appName(root.target.class) : "")
                size: 12; weight: Font.Medium
                color: Theme.t
            }
            Repeater {
                model: [
                    { k: "menu", icon: "more", tip: "Menú de ventana" },
                    { k: "min", icon: "minus", tip: "Minimizar" },
                    { k: "max", icon: root.geo?.max ? "window" : "maximize", tip: root.geo?.max ? "Restaurar" : "Maximizar" },
                    { k: "close", icon: "x", tip: "Cerrar", danger: true }
                ]
                Rectangle {
                    id: btn
                    required property var modelData
                    Layout.preferredWidth: 30; Layout.preferredHeight: 24
                    radius: Theme.ctl(24)
                    color: !bma.containsMouse ? "transparent" : btn.modelData.danger ? Qt.alpha(Theme.danger, 0.22) : Theme.s3
                    Icon {
                        anchors.centerIn: parent
                        name: btn.modelData.icon; size: 14
                        color: btn.modelData.danger && bma.containsMouse ? Theme.danger : Theme.t
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const a = root.addr, k = btn.modelData.k;
                            if (k === "menu") Shell.open("ventana");
                            else if (k === "min") WinMode.minimize(a);
                            else if (k === "max") WinMode.toggleMaximize(a);
                            else WinMode.close(a);
                        }
                    }
                }
            }
        }
    }
}
