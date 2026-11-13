// Botones de ventana de la ventana activa en los espacios flotantes, dibujados por el shell (sin plugins de
// Hyprland): una pastilla pequeña dentro de la ventana, arriba a la derecha, con un asa para moverla, minimizar,
// maximizar / restaurar y cerrar. Una por pantalla (la crea Desktop.qml).
//   - Asa: arrastrar mueve la ventana (sin la animación de movimiento mientras dura, para que siga al cursor);
//     doble clic maximiza o restaura. Clic derecho en la pastilla: menú de ventana (WinMenu.qml).
//   - Solo en la ventana activa, que en flotante queda encima: la pastilla no tapa otras ventanas.
//   - No sale en las apps que ya dibujan su barra ("barsOwnFrame": navegadores, GNOME, VS Code…), ni en las del
//     propio shell, ni a pantalla completa. Se apaga con "titleBars" = false (Ajustes › Escritorio y gestos).
//   - La geometría se sondea cada 100 ms mientras se ve (Hyprland no avisa al mover o redimensionar una flotante),
//     por el socket de Hyprland, sin lanzar procesos.
// Capa "top" a pantalla completa y transparente: solo la pastilla recibe clics (mask); durante un arrastre, toda.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: root
    required property int wsId                      // espacio activo de esta pantalla

    readonly property bool enabledHere: { WinMode.mode; WinMode.overrides; return Settings.get("titleBars", true) !== false && WinMode.isFloat(wsId); }
    readonly property var ownFrame: (Settings.get("barsOwnFrame", []) ?? []).map(c => String(c).toLowerCase())
        .concat(["org.quickshell"])

    // La ventana a la que pertenecen los botones: la activa, si flota en esta pantalla y no trae barra propia
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
    // Por el socket de Hyprland desde Quickshell (refreshToplevels), sin lanzar un hyprctl cada 100 ms: se lee lo
    // que trajo la consulta anterior y se pide la siguiente
    property string liveKey: ""
    Timer {
        interval: 100; repeat: true
        running: root.addr !== "" && !drag.active
        onTriggered: {
            const j = HyprClients.toplevelFor(root.addr)?.lastIpcObject;
            if (j?.address && j.at && j.size) {
                const k = JSON.stringify([j.address, j.at, j.size, j.fullscreen]);
                if (k !== root.liveKey) { root.liveKey = k; root.live = j; }
            }
            Hyprland.refreshToplevels();
        }
    }

    readonly property real sx: screen?.x ?? 0
    readonly property real sy: screen?.y ?? 0
    readonly property int topLimit: { HyprClients.refreshes; return HyprClients.monitorByName(screen?.name ?? "")?.reserved?.[1] ?? 0; }

    visible: !!geo && (geo.w >= 200 && geo.h >= 120)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hf-titlebar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: drag.active ? full : pill }

    Item { id: full; anchors.fill: parent }

    // ── Arrastre: mueve la ventana (Hyprland, coordenadas globales), ~60 veces por segundo como mucho ──
    property point dragPos: Qt.point(0, 0)
    function moveLua(): string {
        return 'hl.dsp.window.move({ x = ' + Math.round(dragPos.x) + ', y = ' + Math.round(dragPos.y) + ', exact = true, ' + WinMode.win(addr) + ' })';
    }
    function noAnim(on: bool): void {
        Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "no_anim", value = "' + (on ? "1" : "unset") + '", ' + WinMode.win(addr) + ' })');
    }
    Timer {
        id: mover
        interval: 16
        property bool dirty: false
        onTriggered: if (dirty) { dirty = false; Hyprland.dispatch(root.moveLua()); }
    }

    Rectangle {
        id: pill
        // la esquina de arriba a la derecha de la ventana (durante el arrastre, donde la lleva el cursor)
        readonly property real gx: drag.active ? root.dragPos.x : (root.geo?.x ?? 0)
        readonly property real gy: drag.active ? root.dragPos.y : (root.geo?.y ?? 0)
        x: gx - root.sx + (root.geo?.w ?? 0) - width - 6
        y: gy - root.sy + 6
        width: row.implicitWidth + 6
        height: 26
        radius: Theme.ctl(26)
        color: Qt.alpha(Theme.s1, hover.hovered || drag.active ? 0.96 : 0.78)
        border.width: 1
        border.color: Qt.alpha(Theme.ov, 0.6)
        Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

        HoverHandler { id: hover }
        // clic derecho en cualquier parte de la pastilla: menú de ventana
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: Shell.open("ventana") }

        RowLayout {
            id: row
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 4 }
            spacing: 0

            // Asa para mover (seis puntos)
            Item {
                Layout.preferredWidth: 26; Layout.preferredHeight: 22
                Icon {
                    anchors.centerIn: parent
                    size: 14; stroke: 2.4
                    color: drag.active || drag.containsMouse ? Theme.t : Theme.tv
                    svg: '<path d="M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01"/>'
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point start: Qt.point(0, 0)
                    property point startAt: Qt.point(0, 0)
                    property bool active: false
                    onPressed: m => {
                        start = mapToItem(full, m.x, m.y);
                        startAt = Qt.point(root.geo?.x ?? 0, root.geo?.y ?? 0);
                        root.dragPos = startAt;
                    }
                    onPositionChanged: m => {
                        if (!pressed || !root.geo || root.geo.max) return;
                        const p = mapToItem(full, m.x, m.y);
                        if (!active) {
                            if (Math.abs(p.x - start.x) + Math.abs(p.y - start.y) < 4) return;
                            active = true;
                            root.noAnim(true);
                        }
                        // sin meter la ventana bajo la barra del shell
                        root.dragPos = Qt.point(startAt.x + p.x - start.x, Math.max(root.sy + root.topLimit, startAt.y + p.y - start.y));
                        mover.dirty = true;
                        if (!mover.running) mover.start();
                    }
                    onReleased: {
                        if (active) {
                            mover.stop(); mover.dirty = false;
                            Hyprland.dispatch(root.moveLua());
                            root.noAnim(false);
                            // hasta el siguiente sondeo, la ventana está donde se soltó (sin saltar a la posición vieja)
                            root.live = Object.assign({}, root.live ?? root.target, { address: root.addr, at: [Math.round(root.dragPos.x), Math.round(root.dragPos.y)] });
                        }
                        active = false;
                    }
                    onDoubleClicked: WinMode.toggleMaximize(root.addr)
                }
            }

            Repeater {
                model: [
                    { k: "min", icon: "minus" },
                    { k: "max", icon: root.geo?.max ? "window" : "maximize" },
                    { k: "close", icon: "x", danger: true }
                ]
                Rectangle {
                    id: btn
                    required property var modelData
                    Layout.preferredWidth: 26; Layout.preferredHeight: 22
                    radius: Theme.ctl(22)
                    color: !bma.containsMouse ? "transparent" : btn.modelData.danger ? Qt.alpha(Theme.danger, 0.24) : Theme.s3
                    Icon {
                        anchors.centerIn: parent
                        name: btn.modelData.icon; size: 13
                        color: btn.modelData.danger && bma.containsMouse ? Theme.danger : Theme.t
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const a = root.addr, k = btn.modelData.k;
                            if (k === "min") WinMode.minimize(a);
                            else if (k === "max") WinMode.toggleMaximize(a);
                            else WinMode.close(a);
                        }
                    }
                }
            }
        }
    }
}
