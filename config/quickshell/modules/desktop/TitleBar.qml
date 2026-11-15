// Barra de título de la ventana activa en los espacios flotantes, dibujada por el shell (sin plugins de Hyprland). Una
// por pantalla (la crea Desktop.qml). Dos formas:
//   - Barra completa: si la ventana lleva la barra de grupo que le pone WinMode (syncBars, apps sin barra propia), se
//     pinta encima de esa franja: icono de la app, título y minimizar / maximizar / cerrar. Toda ella mueve la ventana.
//     Las demás ventanas enseñan la barra de Hyprland (su título, más apagada); un clic en ella la trae al frente.
//   - Pastilla: si aún no la lleva, una pastilla pequeña dentro de la ventana, arriba a la derecha, con un asa para
//     moverla y los tres botones.
//   - Asa (o la barra entera): arrastrar mueve la ventana (sin la animación de movimiento mientras dura, para que siga al cursor);
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
import Quickshell.Widgets
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: root
    required property int wsId                      // espacio activo de esta pantalla

    readonly property bool enabledHere: { WinMode.mode; WinMode.overrides; return Settings.get("titleBars", true) !== false && WinMode.isFloat(wsId); }

    // La ventana a la que pertenecen los botones: la activa, si flota en esta pantalla y no trae barra propia
    readonly property var target: {
        HyprClients.refreshes;
        if (!enabledHere) return null;
        const c = HyprClients.client(HyprClients.activeAddress);
        if (!c || !c.floating || c.workspace?.id !== wsId || (c.fullscreen ?? 0) === 2) return null;
        if (HyprClients.monitorById(c.monitor)?.name !== screen?.name) return null;
        if (WinMode.hasOwnFrame(c) || /^org\.quickshell/i.test(c.class ?? "")) return null;
        return c;
    }
    readonly property string addr: target?.address ?? ""
    readonly property bool full: !!target && WinMode.hasBar(target)        // barra completa (encima de la de Hyprland)

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
    mask: Region { item: drag.active ? whole : pill }

    Item { id: whole; anchors.fill: parent }

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
        // barra completa: la franja de encima de la ventana · pastilla: su esquina de arriba a la derecha
        // (durante el arrastre, donde la lleva el cursor)
        readonly property real gx: drag.active ? root.dragPos.x : (root.geo?.x ?? 0)
        readonly property real gy: drag.active ? root.dragPos.y : (root.geo?.y ?? 0)
        x: root.full ? gx - root.sx : gx - root.sx + (root.geo?.w ?? 0) - width - 6
        y: root.full ? gy - root.sy - WinMode.titleH : gy - root.sy + 6
        width: root.full ? (root.geo?.w ?? 0) : row.implicitWidth + 6
        height: root.full ? WinMode.titleH : 26
        radius: root.full ? 10 : Theme.ctl(26)
        bottomLeftRadius: root.full ? 0 : radius
        bottomRightRadius: root.full ? 0 : radius
        color: root.full ? Theme.s3 : Qt.alpha(Theme.s1, hover.hovered || drag.active ? 0.96 : 0.78)
        border.width: root.full ? 0 : 1
        border.color: Qt.alpha(Theme.ov, 0.6)

        // Barra completa: icono y título a la izquierda
        RowLayout {
            visible: root.full
            anchors { left: parent.left; right: row.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
            spacing: 8
            IconImage {
                implicitSize: 16
                source: root.target ? HyprClients.iconFor(root.target.class) : ""
                asynchronous: true
            }
            Txt {
                Layout.fillWidth: true
                text: (root.target?.title ?? "").replace(/\s+/g, " ").trim()
                size: 11.5; weight: Font.Medium
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

        HoverHandler { id: hover }
        // clic derecho en cualquier parte de la pastilla: menú de ventana
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: Shell.open("ventana") }

        // Barra completa: toda la franja es el asa (debajo de los botones)
        MouseArea {
            visible: root.full
            anchors.fill: parent
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
            onPressed: m => drag.press(mapToItem(whole, m.x, m.y))
            onPositionChanged: m => { if (pressed) drag.moveTo(mapToItem(whole, m.x, m.y)); }
            onReleased: drag.release()
            onDoubleClicked: WinMode.toggleMaximize(root.addr)
        }

        RowLayout {
            id: row
            anchors { verticalCenter: parent.verticalCenter; right: root.full ? parent.right : undefined; left: root.full ? undefined : parent.left
                      leftMargin: 4; rightMargin: 4 }
            spacing: 0

            // Asa para mover (seis puntos; con barra completa, la franja entera)
            Item {
                visible: !root.full
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
                    function press(p): void {
                        start = p;
                        startAt = Qt.point(root.geo?.x ?? 0, root.geo?.y ?? 0);
                        root.dragPos = startAt;
                    }
                    function moveTo(p): void {
                        if (!root.geo || root.geo.max) return;
                        if (!active) {
                            if (Math.abs(p.x - start.x) + Math.abs(p.y - start.y) < 4) return;
                            active = true;
                            root.noAnim(true);
                        }
                        // sin meter la ventana (ni su barra de título) bajo la barra del shell
                        root.dragPos = Qt.point(startAt.x + p.x - start.x, Math.max(root.sy + root.topLimit + (root.full ? WinMode.titleH : 0), startAt.y + p.y - start.y));
                        mover.dirty = true;
                        if (!mover.running) mover.start();
                    }
                    onPressed: m => press(mapToItem(whole, m.x, m.y))
                    onPositionChanged: m => { if (pressed) moveTo(mapToItem(whole, m.x, m.y)); }
                    onReleased: release()
                    function release(): void {
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
