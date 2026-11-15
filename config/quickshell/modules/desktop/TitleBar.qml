// Barra de título de la ventana activa en los espacios flotantes (modo Clásico), dibujada por el shell (sin plugins
// de Hyprland). Una por pantalla (la crea Desktop.qml). Tres islas dentro de la ventana, arriba, como el archipiélago
// de la barra: a la izquierda icono y título · en el centro el asa para moverla · a la derecha minimizar, maximizar y
// cerrar. Solo salen al acercar el puntero al borde de arriba de la ventana activa (una franja fina que cruza ese
// borde) y se van al rato de alejarse; mientras no se ven no tapan nada ni roban clics a la app.
//   - Asa: arrastrar mueve la ventana (sin la animación de movimiento mientras dura, para que siga al cursor);
//     doble clic maximiza o restaura. Clic derecho en cualquier isla: menú de ventana (WinMenu.qml).
//   - No sale en las apps que ya dibujan su barra ("barsOwnFrame" y las GTK, Chromium / Electron y Firefox, que
//     WinMode reconoce solas), ni en las del propio shell, ni a pantalla completa. Se apaga con "titleBars" = false.
//   - La geometría se sondea cada 100 ms mientras hay ventana (Hyprland no avisa al mover o redimensionar una
//     flotante), por el socket de Hyprland, sin lanzar procesos.
// Capa "top" a pantalla completa y transparente: solo reciben clics la franja del borde y, cuando se ven, las islas
// (mask); durante un arrastre, toda.
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

    // Geometría al día (sondeo) o, mientras se arrastra, la que pone el propio arrastre
    property var live: null
    readonly property var geo: {
        const g = live && live.address === addr ? live : target;
        return g ? { x: g.at[0], y: g.at[1], w: g.size[0], h: g.size[1], max: (g.fullscreen ?? 0) === 1 } : null;
    }
    // Por el socket de Hyprland desde Quickshell (refreshToplevels), sin lanzar un hyprctl cada 100 ms: se lee lo
    // que trajo la consulta anterior y se pide la siguiente
    property string liveKey: ""
    function poll(): void {
        const j = HyprClients.toplevelFor(root.addr)?.lastIpcObject;
        if (j?.address && j.at && j.size) {
            const k = JSON.stringify([j.address, j.at, j.size, j.fullscreen]);
            if (k !== root.liveKey) { root.liveKey = k; root.live = j; }
        }
    }
    Timer {
        interval: 100; repeat: true
        running: root.addr !== "" && !drag.active
        onTriggered: { root.poll(); Hyprland.refreshToplevels(); }
    }
    // Maximizar, flotar o encajar: se pregunta ya (no al siguiente sondeo), para que las islas sigan a la ventana
    // mientras se anima y no ~200 ms después
    Timer { id: pollSoon; interval: 30; onTriggered: root.poll() }
    // Solo se anima tras esos eventos (Hyprland anima la ventana): moverla con Super + arrastrar o redimensionarla va
    // al instante, y unas islas animadas se quedarían detrás dando tirones con cada sondeo
    property bool animating: false
    Timer { id: animEnd; interval: Theme.durWin + 300; onTriggered: root.animating = false }
    Connections {
        target: Hyprland
        enabled: root.addr !== "" && !drag.active
        function onRawEvent(ev) {
            if (["fullscreen", "changefloatingmode", "movewindowv2"].includes(ev.name)) {
                Hyprland.refreshToplevels(); pollSoon.restart();
                root.animating = true; animEnd.restart();
            }
        }
    }
    // Seguir a la ventana con animación solo cuando sigue siendo la misma; al pasar a otra, directa y escondida
    property bool glide: false
    onAddrChanged: { glide = false; glideOn.restart(); near = false; }
    Timer { id: glideOn; interval: 60; onTriggered: root.glide = true }

    // ── Cuándo se ven: puntero en la franja del borde o en una isla; se van 700 ms después de salir ──
    readonly property bool hovering: hotHover.hovered || leftHover.hovered || midHover.hovered || rightHover.hovered
    property bool near: false
    onHoveringChanged: { if (hovering) { near = true; hideLater.stop(); } else hideLater.restart(); }
    Timer { id: hideLater; interval: 700; onTriggered: root.near = root.hovering }
    readonly property bool shown: !!geo && (near || drag.active)

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
    // escondidas, solo la franja; a la vista, también las tres islas (no el hueco entre ellas: es de la app)
    // (en coordenadas de la capa: una Region con item no sigue al padre cuando este se mueve, y frame se mueve)
    mask: Region {
        item: drag.active ? whole : null
        Region { x: frame.x; y: frame.y + hot.y; width: frame.width; height: hot.height }
        Region { x: frame.x + islandL.x; y: frame.y + islandL.y; width: root.shown ? islandL.width : 0; height: islandL.height }
        Region { x: frame.x + islandC.x; y: frame.y + islandC.y; width: root.shown ? islandC.width : 0; height: islandC.height }
        Region { x: frame.x + islandR.x; y: frame.y + islandR.y; width: root.shown ? islandR.width : 0; height: islandR.height }
    }

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

    component Island: Rectangle {
        implicitHeight: 30
        radius: Theme.ctl(30)
        color: Qt.alpha(Theme.s1, 0.94)
        border.width: 1
        border.color: Qt.alpha(Theme.ov, 0.7)
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: Shell.open("ventana") }
    }

    // La parte de arriba de la ventana (durante el arrastre, donde la lleva el cursor)
    Item {
        id: frame
        x: (drag.active ? root.dragPos.x : (root.geo?.x ?? 0)) - root.sx
        y: (drag.active ? root.dragPos.y : (root.geo?.y ?? 0)) - root.sy
        width: root.geo?.w ?? 0
        height: 44
        Behavior on x { enabled: root.glide && root.animating && !drag.active; NumberAnimation { duration: Theme.durWin; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeWin } }
        Behavior on y { enabled: root.glide && root.animating && !drag.active; NumberAnimation { duration: Theme.durWin; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeWin } }
        Behavior on width { enabled: root.glide && root.animating && !drag.active; NumberAnimation { duration: Theme.durWin; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeWin } }

        // Franja que cruza el borde de arriba: 8 px por fuera y 6 por dentro de la ventana
        Item {
            id: hot
            y: -8; width: parent.width; height: 14
            HoverHandler { id: hotHover }
        }

        // Las tres islas: bajan un poco y aparecen al acercarse
        Item {
            id: islands
            anchors.fill: parent
            opacity: root.shown ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.shown ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } } }
            Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.durMedium : Theme.durShort } }

            // Izquierda: icono y título (sin sitio, solo el icono)
            Island {
                id: islandL
                x: 6; y: 6
                width: Math.min(titleRow.implicitWidth + 24, Math.max(42, islandC.x - 12 - x))
                HoverHandler { id: leftHover }
                RowLayout {
                    id: titleRow
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8
                    IconImage {
                        implicitSize: 16
                        source: root.target ? HyprClients.iconFor(root.target.class) : ""
                        asynchronous: true
                    }
                    Txt {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 320
                        text: (root.target?.title || HyprClients.appName(root.target?.class ?? "")).replace(/\s+/g, " ").trim()
                        size: 11.5; weight: Font.Medium
                    }
                }
            }

            // Centro: el asa para mover (doble clic maximiza o restaura)
            Island {
                id: islandC
                x: (parent.width - width) / 2; y: 6
                width: 64
                color: drag.active || drag.containsMouse ? Qt.alpha(Theme.s3, 0.97) : Qt.alpha(Theme.s1, 0.94)
                HoverHandler { id: midHover }
                Icon {
                    anchors.centerIn: parent
                    size: 16; stroke: 2.4
                    color: drag.active || drag.containsMouse ? Theme.t : Theme.tv
                    svg: '<path d="M6 9h.01M12 9h.01M18 9h.01M6 15h.01M12 15h.01M18 15h.01"/>'
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
                        // sin meter la ventana bajo la barra del shell
                        root.dragPos = Qt.point(startAt.x + p.x - start.x, Math.max(root.sy + root.topLimit, startAt.y + p.y - start.y));
                        mover.dirty = true;
                        if (!mover.running) mover.start();
                    }
                    onPressed: m => press(mapToItem(whole, m.x, m.y))
                    onPositionChanged: m => { if (pressed) moveTo(mapToItem(whole, m.x, m.y)); }
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

            // Derecha: minimizar, maximizar / restaurar y cerrar
            Island {
                id: islandR
                x: parent.width - width - 6; y: 6
                width: buttons.implicitWidth + 8
                HoverHandler { id: rightHover }
                RowLayout {
                    id: buttons
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [
                            { k: "min", icon: "minus", tip: "Minimizar" },
                            { k: "max", icon: root.geo?.max ? "window" : "maximize", tip: root.geo?.max ? "Restaurar" : "Maximizar" },
                            { k: "close", icon: "x", danger: true, tip: "Cerrar" }
                        ]
                        Rectangle {
                            id: btn
                            required property var modelData
                            Layout.preferredWidth: 28; Layout.preferredHeight: 24
                            radius: Theme.ctl(24)
                            color: !bma.containsMouse ? "transparent" : btn.modelData.danger ? Qt.alpha(Theme.danger, 0.24) : Theme.s3
                            Behavior on color { ColorAnimation { duration: Theme.durShort } }
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
    }
}
