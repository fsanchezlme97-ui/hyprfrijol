// Imagen en imagen (diseño: Main.png, arriba a la derecha).
// Detecta las ventanas PiP de los navegadores ("Picture-in-Picture", "Imagen en imagen"…) y el YouTube del
// panel lateral cuando se pasa a PiP; las deja flotantes, fijadas en todos los espacios, con el tamaño y la
// esquina de Ajustes (pipSize: minimo|pequeno|mediano · pipCorner: sup-der|sup-izq|inf-der|inf-izq) y les
// pone encima los controles del diseño: cerrar (izquierda), pausa y «Volver al panel» (derecha), progreso.
// Si el panel lateral está abierto, el PiP se aparta a su izquierda.  Ajuste "pip": false lo desactiva.
// Posición (pipCorner): sup-izq · sup-centro · sup-der · inf-izq · inf-centro · inf-der · libre.
// Si lo arrastras con el ratón no se le obliga a volver: al soltarlo se imanta a la posición fija más cercana
// (a menos de 90 px) o se queda donde lo dejes («libre», pipFree = [x, y] en fracción de la pantalla).
// Ajustes › PiP: pipSize (+ grande), pipMargin (px), pipOpacity (0–1), pipAllWs (fijado en todos los espacios),
// pipHoverControls (controles solo con el cursor encima), pipFadeNear (casi transparente si el cursor se acerca).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    readonly property bool enabled: Settings.get("pip", true)
    readonly property var sizes: ({ minimo: [192, 108], pequeno: [256, 144], mediano: [320, 180], grande: [400, 225] })
    readonly property var size: sizes[Settings.get("pipSize", "minimo")] ?? sizes.minimo
    readonly property string corner: Settings.get("pipCorner", "sup-der")
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hf-webapp"
    readonly property string webPip: pipFile.text().trim()
    FileView { id: pipFile; path: root.runDir + "/pip"; watchChanges: true; printErrors: false; onFileChanged: reload() }

    readonly property var titleRe: /^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture|[Pp]antalla[-\s]?en[-\s]?[Pp]antalla|[Ii]mage[mn]?[-\s]?(en|em|dentro de)[-\s]?[Ii]mage[mn]?)/
    readonly property var webNames: {
        const o = { wa: "WhatsApp", yt: "YouTube", pin: "Pinterest" };
        for (const w of (Settings.get("webapps", []) ?? [])) if (w?.key) o[w.key] = String(w.name || w.key);
        return o;
    }
    function isWeb(c) { return root.webPip !== "" && c.class === "hf-webapp.qml6" && String(c.title).startsWith(webNames[root.webPip] ?? "-"); }
    readonly property var win: enabled ? (HyprClients.clients.find(c => titleRe.test(String(c.title)) || isWeb(c)) ?? null) : null

    // Márgenes de la barra (como Overlay) y del panel lateral
    readonly property string barPos: Settings.barPos
    readonly property real barEdge: Shell.focusMode ? 4 : Math.max(4, Settings.barEdge)
    readonly property bool sideOpen: Shell.view === "ia"
    readonly property bool sideLeft: Settings.get("sideSide", "derecha") === "izquierda"
    readonly property real sideW: Shell.sideW > 0 ? Shell.sideW : Math.max(320, Math.min(720, Number(Settings.get("sideWidth", 400)) || 400))
    readonly property real m: Math.max(0, Number(Settings.get("pipMargin", 12)) || 0)
    readonly property bool allWs: Settings.get("pipAllWs", true) !== false
    readonly property real pipOpacity: Math.max(0.2, Math.min(1, Number(Settings.get("pipOpacity", 1)) || 1))
    readonly property bool hoverControls: Settings.get("pipHoverControls", false) === true
    readonly property bool fadeNear: Settings.get("pipFadeNear", false) === true

    // Tamaño real de la ventana: algunas no bajan del pedido (tamaño mínimo del navegador, proporción del
    // vídeo con keep_aspect_ratio) y la posición se calcula con el que tiene de verdad para que no se salga
    readonly property var actual: {
        const c = win, sz = c?.size;
        if (!sz || !(sz[0] > 0) || !(sz[1] > 0)) return size;
        return [Math.max(1, sz[0]), Math.max(1, sz[1])];
    }

    readonly property var target: {
        const mon = HyprClients.focusedMonitor;
        if (!mon) return null;
        const L = HyprClients.logical(mon);
        const w = Math.min(actual[0], L.w), h = Math.min(actual[1], L.h);
        // Zona libre: pantalla menos lo reservado (la barra u otras barras: monitor.reserved, en px lógicos)
        // y el panel lateral. La barra de hyprfrijol cuenta aunque aún no haya reservado (al arrancar).
        const r = mon.reserved ?? [0, 0, 0, 0];
        const barHere = !Shell.focusMode && (Settings.get("barAllScreens", true) !== false || mon.name === (Shell.primaryScreen?.name ?? mon.name));
        const edge = side => Math.max(4, (r[side] ?? 0) > 0 ? r[side] + 4 : 0,
                                      barHere && barPos === ["izquierda", "arriba", "derecha", "abajo"][side] ? barEdge : 0);
        const aL = edge(0), aT = edge(1), aR = edge(2), aB = edge(3);
        const x0 = L.x + (sideOpen && sideLeft ? aL + sideW : aL) + m;
        const x1 = Math.max(x0, L.x + L.w - (sideOpen && !sideLeft ? aR + sideW : aR) - m - w);
        const y0 = L.y + aT + m, y1 = Math.max(y0, L.y + L.h - aB - m - h);
        let x, y;
        const f = Settings.get("pipFree", null);       // leído aquí mismo: sin estados intermedios
        if (corner === "libre" && f && f.length === 2) {
            x = L.x + Number(f[0]) * L.w; y = L.y + Number(f[1]) * L.h;
        } else {
            x = corner.endsWith("der") ? x1 : corner.endsWith("centro") ? (x0 + x1) / 2 : x0;
            y = corner.startsWith("sup") ? y0 : y1;
        }
        // Siempre dentro de la pantalla (aunque la ventana sea más grande que el hueco libre)
        x = Math.max(L.x, Math.min(L.x + L.w - w, Math.max(x0, Math.min(x1, x))));
        y = Math.max(L.y, Math.min(L.y + L.h - h, Math.max(y0, Math.min(y1, y))));
        return { x: Math.round(x), y: Math.round(y), w: size[0], h: size[1], aw: w, ah: h,
                 lx: Math.round(x - L.x), ly: Math.round(y - L.y), x0: x0, x1: x1, y0: y0, y1: y1, L: L, mon: mon.name };
    }
    // ¿Está donde toca? (con 2 px de tolerancia: con escalas fraccionarias Hyprland redondea a píxeles físicos)
    function near2(a, b) { return Math.abs(a - b) <= 2; }
    function atTarget(c, t) { return !!c?.at && near2(c.at[0], t.x) && near2(c.at[1], t.y); }
    // Las posiciones fijas, para imantar al soltar
    function presets(t) {
        const cx = (t.x0 + t.x1) / 2;
        return [["sup-izq", t.x0, t.y0], ["sup-centro", cx, t.y0], ["sup-der", t.x1, t.y0],
                ["inf-izq", t.x0, t.y1], ["inf-centro", cx, t.y1], ["inf-der", t.x1, t.y1]];
    }
    // Dónde lo pusimos la última vez (para distinguir un arrastre del usuario de un cambio nuestro)
    property var placed: null
    property string resized: ""
    property real lastMove: 0
    // Hyprland no avisa cuando una ventana solo cambia de sitio: mientras haya PiP se consulta cada poco
    Timer { running: root.win !== null; interval: 600; repeat: true; onTriggered: HyprClients.refreshNow() }

    function sel(c) { return 'window = "address:' + c.address + '"'; }
    function reconcile() {
        const c = win, t = target;
        if (!c || !t) return;
        if (String(c.workspace?.name ?? "").startsWith("special"))
            Shell.dispatch('hl.dsp.window.move({ workspace = ' + (HyprClients.focusedMonitor?.activeWorkspace?.id ?? 1) + ', follow = false, ' + sel(c) + ' })');
        if (!c.floating) Shell.dispatch('hl.dsp.window.float({ action = "enable", ' + sel(c) + ' })');
        // Redimensionar una vez por tamaño pedido: si la app no baja de su mínimo, no se insiste (y la posición
        // ya usa su tamaño real)
        const rk = c.address + "|" + t.w + "x" + t.h;
        if ((c.size?.[0] !== t.w || c.size?.[1] !== t.h) && resized !== rk) {
            resized = rk;
            Shell.dispatch('hl.dsp.window.resize({ x = ' + t.w + ', y = ' + t.h + ', ' + sel(c) + ' })');
        }
        const atT = atTarget(c, t);
        const ours = placed && placed.addr === c.address && placed.x === t.x && placed.y === t.y;
        if (atT) { placed = { addr: c.address, x: t.x, y: t.y }; adopt.stop(); }
        else if (ours) {
            // Fuera de su sitio: o aún no ha llegado (lo acabamos de mover) o lo ha arrastrado el usuario
            if (Date.now() - lastMove > 1500) adopt.watch(c.at);
        } else {
            Shell.dispatch('hl.dsp.window.move({ x = ' + t.x + ', y = ' + t.y + ', ' + sel(c) + ' })');
            placed = { addr: c.address, x: t.x, y: t.y };
            lastMove = Date.now();
        }
        if (allWs && !c.pinned) Shell.dispatch('hl.dsp.window.pin({ action = "enable", ' + sel(c) + ' })');
        else if (!allWs && c.pinned) Shell.dispatch('hl.dsp.window.pin({ action = "disable", ' + sel(c) + ' })');
        applyOpacity();
    }
    onAllWsChanged: reconcile()

    // Arrastrado por el usuario: al quedarse quieto, imantar a la posición fija más cercana o quedarse «libre»
    Timer {
        id: adopt
        interval: 700
        property var from: null
        // Espera a que la posición deje de cambiar (el usuario lo ha soltado)
        function watch(at) {
            const k = at ? at[0] + "," + at[1] : "";
            if (from !== k) { from = k; restart(); }
            else if (!running) restart();
        }
        onTriggered: {
            const c = root.win, t = root.target;
            if (!c || !t || !c.at || from !== c.at[0] + "," + c.at[1]) return;
            from = null;
            const px = c.at[0], py = c.at[1];
            let best = null, bd = 1e9;
            for (const p of root.presets(t)) {
                const d = Math.hypot(p[1] - px, p[2] - py);
                if (d < bd) { bd = d; best = p; }
            }
            root.placed = null;
            if (bd < 90) { if (best[0] !== root.corner) Settings.setMany({ pipCorner: best[0] }); }
            else Settings.setMany({ pipCorner: "libre", pipFree: [+((px - t.L.x) / t.L.w).toFixed(4), +((py - t.L.y) / t.L.h).toFixed(4)] });
            root.reconcile();
        }
    }

    // ---- opacidad (pipOpacity) y transparencia al acercar el cursor (pipFadeNear)
    property string opaKey: ""
    readonly property real wantOpacity: fadeNear && near ? Math.min(pipOpacity, 0.25) : pipOpacity
    onWantOpacityChanged: applyOpacity()
    function applyOpacity() {
        const c = win;
        if (!c) { opaKey = ""; return; }
        const k = c.address + "|" + wantOpacity;
        if (k === opaKey) return;
        opaKey = k;
        Shell.dispatch('hl.dsp.window.set_prop({ prop = "opacity", value = "' + wantOpacity.toFixed(2) + '", ' + sel(c) + ' })');
    }

    // ---- posición del cursor (solo si hace falta: controles al pasar el cursor o transparencia al acercarse)
    property bool hover: false
    property bool near: false
    Timer {
        interval: 180; repeat: true
        running: root.win !== null && root.target !== null && (root.hoverControls || root.fadeNear)
        onRunningChanged: if (!running) { root.hover = false; root.near = false; }
        onTriggered: if (!cursorProc.running) cursorProc.running = true
    }
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = null;
                try { p = JSON.parse(text); } catch (e) { return; }
                const t = root.target;
                if (!p || !t) return;
                const pad = 28;
                root.hover = p.x >= t.x && p.x < t.x + t.aw && p.y >= t.y && p.y < t.y + t.ah;
                root.near = p.x >= t.x - pad && p.x < t.x + t.aw + pad && p.y >= t.y - pad && p.y < t.y + t.ah + pad;
            }
        }
    }
    onWinChanged: reconcile()
    onTargetChanged: Qt.callLater(reconcile)
    Connections { target: HyprClients; function onClientsChanged() { root.reconcile(); } }

    function close() {
        const c = win;
        if (!c) return;
        if (isWeb(c)) {           // el YouTube del panel no se cierra: se pausa y vuelve a guardarse
            Quickshell.execDetached(["sh", "-c", '"$0" cmd "$1" pause; sleep 0.5; "$0" cmd "$1" pipoff', Paths.script("hf-webapp"), root.webPip]);
            Shell.dispatch('hl.dsp.window.pin({ action = "disable", ' + sel(c) + ' })');
            Shell.dispatch('hl.dsp.window.move({ workspace = "special:hfweb", follow = false, ' + sel(c) + ' })');
            setWebPip("");
        } else Shell.dispatch('hl.dsp.window.close({ ' + sel(c) + ' })');
    }
    function toggle() {
        if (win && isWeb(win)) Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", root.webPip, "toggle"]);
        else Media.toggle();
    }
    function back() {
        const c = win;
        if (!c) return;
        if (isWeb(c)) Shell.open("ia", root.webPip);      // el panel la saca del PiP (pipoff) y la acopla
        else Shell.dispatch('hl.dsp.window.close({ ' + sel(c) + ' })');   // el navegador devuelve el vídeo a su pestaña
    }
    function setWebPip(k) { Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/pip"', "sh", root.runDir, k]); }

    // Progreso (MPRIS no avisa de la posición: se consulta cada segundo)
    property real progress: 0
    Timer {
        interval: 1000; repeat: true; running: root.win !== null
        onTriggered: {
            const p = Media.active;
            root.progress = p && p.length > 0 ? Math.min(1, p.position / p.length) : 0;
        }
    }

    // ---- controles encima de la ventana
    PanelWindow {
        id: ctl
        readonly property bool here: root.win !== null && root.target !== null
            && !String(root.win.workspace?.name ?? "").startsWith("special") && !root.win.fullscreen
            && root.atTarget(root.win, root.target)
        screen: Shell.screen
        visible: here
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hf-pip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        margins { left: root.target?.lx ?? 0; top: root.target?.ly ?? 0 }
        implicitWidth: root.target?.aw ?? root.size[0]
        implicitHeight: root.target?.ah ?? root.size[1]
        readonly property bool showCtl: !root.hoverControls || root.hover
        mask: showCtl ? btnRegion : noRegion
        Region {
            id: btnRegion
            Region { item: closeB }
            Region { item: rightBtns }
        }
        Region { id: noRegion }

        component PipBtn: Rectangle {
            id: pb
            property string icon: ""
            property string tip: ""
            signal clicked()
            width: 22; height: 22; radius: Theme.pill ? 11 : Theme.r(5)
            color: Qt.rgba(0, 0, 0, pbMouse.containsMouse ? 0.75 : 0.55)
            Icon { anchors.centerIn: parent; name: pb.icon; size: 11; color: "#FFFFFF" }
            MouseArea { id: pbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
        }

        PipBtn {
            id: closeB; x: 6; y: 6; icon: "x"; onClicked: root.close()
            opacity: ctl.showCtl ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Row {
            id: rightBtns
            x: parent.width - width - 6; y: 6
            opacity: ctl.showCtl ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            spacing: 4
            PipBtn { icon: Media.playing ? "pause" : "play"; onClicked: root.toggle() }
            PipBtn { icon: "maximize"; onClicked: root.back() }
        }
        Rectangle {
            visible: root.progress > 0 && !root.isWeb(root.win)
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 4; bottomMargin: 3 }
            width: (parent.width - 8) * root.progress
            height: 2; radius: 1
            color: "#FFFFFF"; opacity: 0.85
        }
    }
}
