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
// Además de los vídeos, las ventanas flotantes de Document Picture-in-Picture de Chromium (Meet, Teams, Spotify
// web…) y miniventanas de apps (pip-apps.json, con la regla explicada allí). Tipos (kind): video · call
// (videollamada: cerrar sin colgar y «Volver a la llamada») · music (reproductor: pausa y siguiente por MPRIS y
// volver a la app) · doc (otra página: cerrar y volver a la pestaña). Ajustes pipCalls (call y doc) y pipPlayers.
// Esas ventanas conservan su proporción (no se fuerzan a 16:9): se pide el ancho de pipSize y el alto que toque.
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
    // Ancho para llamadas y reproductores (su alto sale de la proporción con la que nació la ventana)
    readonly property var docWidths: ({ minimo: 240, pequeno: 300, mediano: 360, grande: 440 })
    readonly property string sizeKey: Settings.get("pipSize", "minimo")
    readonly property var size: {
        if (kind === "video") return sizes[sizeKey] ?? sizes.minimo;
        const w = docWidths[sizeKey] ?? docWidths.minimo;
        const a = Math.max(0.35, Math.min(1.8, Number(info?.aspect) || 0.75));
        return [w, Math.round(w * a)];
    }
    readonly property string corner: Settings.get("pipCorner", "sup-der")

    readonly property var titleRe: /^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture|[Pp]antalla[-\s]?en[-\s]?[Pp]antalla|[Ii]mage[mn]?[-\s]?(en|em|dentro de)[-\s]?[Ii]mage[mn]?)/

    // ---- Document PiP y miniventanas (pip-apps.json)
    readonly property bool calls: Settings.get("pipCalls", true) !== false
    readonly property bool players: Settings.get("pipPlayers", true) !== false
    FileView { id: appsFile; path: Paths.root + "/config/quickshell/modules/pip/pip-apps.json"; printErrors: false }
    readonly property var rules: {
        let d = {};
        try { d = JSON.parse(appsFile.text() || "{}"); } catch (e) {}
        const re = (s, def) => { try { return new RegExp(s || def, "i"); } catch (e) { return new RegExp(def, "i"); } };
        return {
            browsers: re(d.browsers, "^(google-chrome|chromium|brave-browser|microsoft-edge)$"),
            suffix: re(d.suffix, "\\s-\\s(Google Chrome|Chromium|Brave|Microsoft\u200b?\\s?Edge)\\b"),
            exclude: re(d.exclude, "^DevTools\\b"),
            apps: (d.apps ?? []).map(a => ({ name: String(a.name ?? ""), kind: String(a.kind ?? "doc"), secondary: a.secondary === true,
                                             title: a.title ? re(a.title, "$^") : null, cls: a["class"] ? re(a["class"], "$^") : null }))
        };
    }
    // Ventanas ya reconocidas: dirección → { kind, name, opener, aspect }. Se decide una vez, al verlas por primera
    // vez: luego la pestaña que la abrió puede cambiar de título (otra canción, otra pestaña) y la ventana sigue siendo PiP.
    property var known: ({})
    // ¿Es `o` la ventana de la pestaña que abrió una Document PiP titulada `t`? (mismo título, con o sin « - Google Chrome»)
    function isOpenerOf(o, t) {
        const ot = String(o.title ?? "");
        return ot === t || (ot.startsWith(t) && rules.suffix.test(ot.slice(t.length)) && !rules.suffix.test(t));
    }
    function classify(c, list) {
        const t = String(c.title ?? ""), cls = String(c["class"] ?? "");
        if (rules.browsers.test(cls)) {
            if (!c.floating || t === "" || t !== String(c.initialTitle ?? "") || rules.suffix.test(t) || rules.exclude.test(t)) return null;
            const opener = list.find(o => o.address !== c.address && o.pid === c.pid && isOpenerOf(o, t)) ?? null;
            const app = rules.apps.find(a => a.title && a.title.test(t)) ?? null;
            if (!opener && !app) return null;
            let kind = app?.kind ?? "doc";
            if (!app && Media.players.some(p => String(p.trackTitle ?? "").length > 2 && t.includes(p.trackTitle))) kind = "music";
            return { kind: kind, name: app?.name ?? "", opener: opener?.address ?? "" };
        }
        // Miniventana de una app de escritorio: otra ventana más grande de la misma app
        const area = w => (w.size?.[0] ?? 0) * (w.size?.[1] ?? 0);
        const app = rules.apps.find(a => a.cls && a.cls.test(cls)) ?? null;
        if (!app) return null;
        const main = list.find(o => o.address !== c.address && o["class"] === c["class"] && area(o) > area(c) * 1.5) ?? null;
        if (app.secondary && !main) return null;
        return { kind: app.kind, name: app.name, opener: main?.address ?? "" };
    }
    function scan() {
        const list = HyprClients.clients, k = {};
        let changed = false;
        for (const c of list) {
            if (known[c.address]) { k[c.address] = known[c.address]; continue; }
            if (titleRe.test(String(c.title))) continue;
            const r = classify(c, list);
            if (r) {
                r.aspect = c.size?.[0] > 0 ? c.size[1] / c.size[0] : 0.75;
                k[c.address] = r; changed = true;
            }
        }
        if (changed || Object.keys(k).length !== Object.keys(known).length) known = k;
    }
    function allowed(kind) { return kind === "music" ? players : kind === "video" || calls; }
    // La ventana PiP: el vídeo primero (solo hay una a la vez); después llamadas y reproductores
    readonly property var win: {
        if (!enabled) return null;
        const list = HyprClients.clients;
        return list.find(c => titleRe.test(String(c.title)))
            ?? list.find(c => known[c.address] && allowed(known[c.address].kind)) ?? null;
    }
    readonly property var info: win ? (known[win.address] ?? { kind: "video" }) : null
    readonly property string kind: info?.kind ?? "video"

    // Márgenes de la barra (como Overlay) y del panel lateral
    readonly property string barPos: Settings.barPos
    readonly property real barEdge: Shell.focusMode ? 4 : Math.max(4, Settings.barEdge)
    readonly property bool sideOpen: Shell.view === "ia" && !Shell.sidePinned     // fijado: ya va en monitor.reserved
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

    // pipScreen = "secundaria": a la pantalla que no es la principal (si hay más de una); si no, la del foco
    readonly property var pipMon: {
        const f = HyprClients.focusedMonitor;
        if (Settings.get("pipScreen", "activa") !== "secundaria") return f;
        const prim = Shell.primaryScreen?.name ?? "";
        return HyprClients.monitors.find(m => m.name !== prim && m.name !== (prim ? "" : f?.name)) ?? f;
    }
    readonly property var target: {
        const mon = pipMon;
        if (!mon) return null;
        const L = HyprClients.logical(mon);
        const w = Math.min(actual[0], L.w), h = Math.min(actual[1], L.h);
        // Zona libre: pantalla menos lo reservado (la barra u otras barras: monitor.reserved, en px lógicos)
        // y el panel lateral. La barra de hyprfrijol cuenta aunque aún no haya reservado (al arrancar).
        const r = mon.reserved ?? [0, 0, 0, 0];
        const barHere = !Shell.focusMode && Shell.barModeFor(Quickshell.screens.find(s => s.name === mon.name) ?? Shell.primaryScreen) !== "oculta";
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
    property int resizeTries: 0
    property real lastResize: 0
    property real lastMove: 0
    // Hyprland no avisa cuando una ventana solo cambia de sitio: mientras haya PiP se consulta cada poco
    Timer { running: root.win !== null; interval: 600; repeat: true; onTriggered: HyprClients.refreshGeometry() }   // por el socket, sin hyprctl

    function sel(c) { return 'window = "address:' + c.address + '"'; }
    function reconcile() {
        const c = win, t = target;
        if (!c || !t) return;
        if (String(c.workspace?.name ?? "").startsWith("special"))
            Shell.dispatch('hl.dsp.window.move({ workspace = ' + (root.pipMon?.activeWorkspace?.id ?? 1) + ', follow = false, ' + sel(c) + ' })');
        if (!c.floating) Shell.dispatch('hl.dsp.window.float({ action = "enable", ' + sel(c) + ' })');
        // Redimensionar hasta 3 veces por tamaño pedido (el navegador, recién abierta, a veces vuelve a poner el suyo);
        // si la app no baja de su mínimo, se deja (y la posición ya usa su tamaño real)
        const rk = c.address + "|" + t.w + "x" + t.h;
        if ((c.size?.[0] !== t.w || c.size?.[1] !== t.h) && (resized !== rk || (resizeTries < 3 && Date.now() - lastResize > 1200))) {
            if (resized !== rk) { resized = rk; resizeTries = 0; }
            resizeTries++;
            lastResize = Date.now();
            Shell.dispatch('hl.dsp.window.resize({ x = ' + t.w + ', y = ' + t.h + ', ' + sel(c) + ' })');
            // Hyprland (0.57) redimensiona desde el centro y la ventana se desplaza: se vuelve a colocar en la siguiente
            // pasada, sin tomarlo por un arrastre tuyo (antes eso la dejaba «libre» fuera de su esquina)
            placed = null;
            lastMove = Date.now();
            applyOpacity();
            return;
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
                const gl = root.ctlLeft ? root.gutter : 0, gr = root.ctlLeft ? 0 : root.gutter;   // + columna de botones
                root.hover = p.x >= t.x - gl && p.x < t.x + t.aw + gr && p.y >= t.y && p.y < t.y + t.ah;
                root.near = p.x >= t.x - pad && p.x < t.x + t.aw + pad && p.y >= t.y - pad && p.y < t.y + t.ah + pad;
            }
        }
    }
    onWinChanged: reconcile()
    onTargetChanged: Qt.callLater(reconcile)
    Connections { target: HyprClients; function onClientsChanged() { root.scan(); root.reconcile(); } }
    Component.onCompleted: scan()

    function close() {
        const c = win;
        if (!c) return;
        Shell.dispatch('hl.dsp.window.close({ ' + sel(c) + ' })');
    }
    // Reproductor de la miniventana de música: el que suena con el título de la ventana, si no el activo
    readonly property var player: {
        if (kind !== "music" || !win) return Media.active;
        const t = String(win.title ?? "");
        return Media.players.find(p => String(p.trackTitle ?? "").length > 2 && t.includes(p.trackTitle)) ?? Media.active;
    }
    readonly property bool playing: kind === "music" ? (player?.isPlaying ?? false) : Media.playing
    function toggle() {
        if (kind === "music") { if (player?.canTogglePlaying) player.togglePlaying(); }
        else Media.toggle();
    }
    function next() { if (player?.canGoNext) player.next(); }
    // La ventana de la que salió (la pestaña de la llamada, la del reproductor o la app): la guardada al
    // reconocerla, otra del mismo proceso con su título o, si no, la última usada de esa app
    function opener(c) {
        const list = HyprClients.clients, i = known[c.address];
        const t = String(c.title ?? "");
        const pool = list.filter(o => o.address !== c.address && !known[o.address] && (o.pid === c.pid || o["class"] === c["class"]));
        return pool.find(o => o.address === i?.opener)
            ?? pool.find(o => isOpenerOf(o, t))
            ?? pool.slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID)[0] ?? null;
    }
    function back() {
        const c = win;
        if (!c) return;
        if (kind === "video") { Shell.dispatch('hl.dsp.window.close({ ' + sel(c) + ' })'); return; }   // el navegador devuelve el vídeo a su pestaña
        // Llamada o página: se cierra el PiP (la llamada sigue en su pestaña) y se enfoca esa ventana.
        // Reproductor: se va a la app y la miniventana se queda.
        const o = opener(c);
        if (kind !== "music") Shell.dispatch('hl.dsp.window.close({ ' + sel(c) + ' })');
        if (o) HyprClients.focusWindow(o.address);
    }
    // IPC (atajos y pruebas): qs ipc call pip state|close|back|toggle|next
    IpcHandler {
        target: "pip"
        function state(): string {
            const c = root.win;
            return JSON.stringify(c ? { kind: root.kind, name: root.info?.name ?? "", title: c.title, address: c.address,
                                        at: c.at, size: c.size, pinned: c.pinned, opener: root.opener(c)?.address ?? "" } : null);
        }
        function close(): void { root.close(); }
        function back(): void { root.back(); }
        function toggle(): void { root.toggle(); }
        function next(): void { root.next(); }
    }

    // Progreso (MPRIS no avisa de la posición: se consulta cada segundo)
    property real progress: 0
    Timer {
        interval: 1000; repeat: true; running: root.win !== null
        onTriggered: {
            const p = Media.active;
            root.progress = p && p.length > 0 ? Math.min(1, p.position / p.length) : 0;
        }
    }

    // ---- controles por fuera de la ventana, en el lateral opuesto a su posición
    // (PiP a la derecha → botones a su izquierda, y al revés), en una columna arriba o abajo según la mitad
    // de la pantalla en la que esté, para no tapar el vídeo.
    readonly property string phoneSvg: '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/>'
    readonly property int gutter: 34                       // ancho de la columna de botones + separación
    readonly property bool ctlLeft: {
        const t = target;
        if (!t) return true;
        if (corner.endsWith("der")) return true;
        if (corner.endsWith("izq")) return false;
        return t.lx + t.aw / 2 > t.L.w / 2;                // centrado o libre: según qué mitad ocupe
    }
    readonly property bool ctlBottom: {
        const t = target;
        if (!t) return false;
        if (corner.startsWith("inf")) return true;
        if (corner.startsWith("sup")) return false;
        return t.ly + t.ah / 2 > t.L.h / 2;
    }

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
        // La capa cubre el PiP más la columna de botones; solo los botones reciben el ratón
        margins { left: Math.max(0, (root.target?.lx ?? 0) - (root.ctlLeft ? root.gutter : 0)); top: root.target?.ly ?? 0 }
        implicitWidth: (root.target?.aw ?? root.size[0]) + root.gutter
        implicitHeight: root.target?.ah ?? root.size[1]
        readonly property bool showCtl: !root.hoverControls || root.hover
        mask: showCtl ? btnRegion : noRegion
        Region { id: btnRegion; item: btnCol }
        Region { id: noRegion }

        component PipBtn: Rectangle {
            id: pb
            property string icon: ""
            property string svg: ""
            property bool danger: false
            signal clicked()
            width: 26; height: 26; radius: Theme.pill ? 13 : Theme.r(6)
            color: pbMouse.containsMouse ? (pb.danger ? Theme.danger : Theme.p) : "transparent"
            Icon { anchors.centerIn: parent; name: pb.icon; svg: pb.svg; size: 13; color: pbMouse.containsMouse ? (pb.danger ? Theme.bg : Theme.pText) : Theme.t }
            MouseArea { id: pbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
        }

        // Columna de botones, con el fondo del shell (como la barra y los paneles)
        Rectangle {
            id: btnCol
            readonly property int pad: 2
            width: 26 + pad * 2
            height: col.implicitHeight + pad * 2
            x: root.ctlLeft ? 0 : parent.width - width
            y: root.ctlBottom ? parent.height - height : 0
            radius: Theme.pill ? width / 2 : Theme.r(8)
            color: Theme.glassPopup
            border.width: Theme.borderWidth; border.color: Theme.border
            opacity: ctl.showCtl ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            Column {
                id: col
                anchors.centerIn: parent
                spacing: 2
                // Cerrar: en una llamada solo cierra la ventana flotante (no cuelga)
                PipBtn { icon: "x"; danger: true; onClicked: root.close() }
                PipBtn { visible: root.kind === "video" || root.kind === "music"; icon: root.playing ? "pause" : "play"; onClicked: root.toggle() }
                PipBtn { visible: root.kind === "music"; icon: "next"; onClicked: root.next() }
                // Volver: a la pestaña del vídeo, a la llamada (icono de teléfono), a la página o a la app
                PipBtn {
                    icon: root.kind === "call" ? "" : "maximize"
                    svg: root.kind === "call" ? root.phoneSvg : ""
                    onClicked: root.back()
                }
            }
        }
        // Progreso, en el borde inferior del vídeo
        Rectangle {
            visible: root.progress > 0 && root.kind === "video"
            x: (root.ctlLeft ? root.gutter : 0) + 4
            anchors { bottom: parent.bottom; bottomMargin: 4 }
            width: ((root.target?.aw ?? root.size[0]) - 8) * root.progress
            height: 2; radius: 1
            color: "#FFFFFF"; opacity: 0.85
        }
    }
}
