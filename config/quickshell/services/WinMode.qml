pragma Singleton
// Modo de ventanas (ajuste "windowMode"), tres modos de primera clase:
//   "mosaico"        las ventanas se reparten la pantalla (general:layout = "layout": dwindle / master)
//   "desplazamiento" columnas en una cinta que se desplaza (diseño «scrolling» nativo de Hyprland 0.57;
//                    ancho y ajuste de columna: "scrollColumnWidth", "scrollFocusFit", "scrollOneFull")
//   "flotante"       escritorio clásico: todas las ventanas flotan, dock en todos los espacios
// El antiguo "mixto" se lee como "mosaico"; "layout" = "scrolling" (versiones anteriores) con "mosaico" se lee
// como "desplazamiento". general:layout y la regla de flotar las ponen config/apply/30-layout.py y 35-windows.py;
// aquí:
// - Cambio en vivo: al cambiar el modo pasa a flotante / mosaico / columnas las ventanas ya abiertas.
// - Excepción por espacio de la sesión (ajustes rápidos › Ventanas): setWsMode(ws, modo). Flotar se hace
//   convirtiendo las ventanas; el diseño (mosaico ↔ columnas) con una regla de espacio de Hyprland que se vuelve
//   a poner tras cada recarga de la configuración.
// - Ventanas nuevas que flotan por el modo: tamaño cómodo (62 % × 70 % del área útil si la app pide poco),
//   centradas y en cascada para no taparse justo encima. Los diálogos pequeños se dejan como vienen.
// - Minimizar: la ventana va al espacio especial «minimized» (minimize / restore / toggleMinimize; también
//   cuando la app lo pide con su botón de minimizar). Restaurar la trae al espacio actual.
// - Ocultación inteligente (dock y barra): covered(monitor, rect) dice si alguna ventana tapa esa zona.
// - IPC: qs ipc call winmode cycle · set <modo> · setWs <espacio> <modo> · get <espacio> (0 = general).
// - Atajos globales: hf:modoventanas (Super + Mayús + Espacio, mosaico → desplazamiento → flotante, con aviso
//   en el OSD) · hf:minimizar (Super + H) · hf:restaurar (Super + Mayús + H, trae la última minimizada).
//   Las teclas propias del desplazamiento (columnas) están en config/hypr/frijol/binds.lua (HF.scroll).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property var modes: ["mosaico", "desplazamiento", "flotante"]
    readonly property var labels: ({ mosaico: "Mosaico", desplazamiento: "Desplazamiento", flotante: "Flotante" })
    readonly property var hints: ({ mosaico: "Las ventanas se reparten la pantalla",
                                    desplazamiento: "Columnas en una cinta que se desplaza",
                                    flotante: "Escritorio clásico: las ventanas se mueven libremente" })
    readonly property var icons: ({ mosaico: "tiles", desplazamiento: "columns", flotante: "float" })
    // Diseño del mosaico (dwindle / master); el antiguo "scrolling" es ahora el modo «Desplazamiento»
    readonly property string tiledLayout: { const l = Settings.get("layout", "dwindle"); return l === "master" ? "master" : "dwindle"; }
    function norm(wm, lay): string {
        return wm === "flotante" ? "flotante" : wm === "desplazamiento" ? "desplazamiento"
             : lay === "scrolling" ? "desplazamiento" : "mosaico";
    }
    readonly property string mode: norm(Settings.get("windowMode", "mosaico"), Settings.get("layout", "dwindle"))
    // Espacios con excepción en esta sesión: { "3": "flotante" } (otro modo que el general solo en ese espacio)
    property var overrides: ({})
    readonly property bool dry: Quickshell.env("HF_TRY") === "1"

    // Modo de un espacio (con su excepción) · ¿flotan sus ventanas? · diseño de Hyprland de un modo
    function modeOf(ws: int): string { return overrides[String(ws)] ?? mode; }
    function baseFloat(ws: int, m: string): bool { return ws > 0 && m === "flotante"; }
    function isFloat(ws: int): bool { return ws > 0 && modeOf(ws) === "flotante"; }
    function isScroll(ws: int): bool { return ws > 0 && modeOf(ws) === "desplazamiento"; }
    function layoutFor(m: string): string { return m === "desplazamiento" ? "scrolling" : tiledLayout; }
    // Escritorio ordenado por grupos (ajuste "deskIcons" = "ordenado"; el antiguo "flotante" también)
    readonly property string deskIcons: Settings.get("deskIcons", "todos")
    function isDeskWs(ws: int): bool { return ws > 0 && (deskIcons === "ordenado" || deskIcons === "flotante"); }
    // ¿Hay dock en este espacio? Donde las ventanas flotan, o en todos con «Mostrar el dock también en mosaico»
    readonly property bool dockInTiling: Settings.get("dockInTiling", false) === true
    function dockOn(ws: int): bool { return ws > 0 && (isFloat(ws) || dockInTiling); }

    // Cambia el modo general. Al volver a «Mosaico» con el antiguo layout = "scrolling", el mosaico pasa a dwindle.
    function setMode(m: string): void {
        if (!modes.includes(m) || m === mode) return;
        const o = { windowMode: m };
        if (Settings.get("layout", "dwindle") === "scrolling") o.layout = "dwindle";
        Settings.setMany(o);
    }
    signal announced(string m)          // el OSD lo enseña (modules/osd)
    function cycle(): void {
        const next = modes[(modes.indexOf(mode) + 1) % modes.length];
        setMode(next);
        announced(next);
    }
    function toggle(): void { cycle(); }

    // Excepción para un espacio (ajustes rápidos): m = "" o el modo general la quita
    function setWsMode(ws: int, m: string): void {
        if (ws <= 0) return;
        const k = String(ws), o = Object.assign({}, overrides);
        const was = modeOf(ws);
        if (!modes.includes(m) || m === mode) delete o[k]; else o[k] = m;     // "" / "general": como todos
        overrides = o;
        const now = modeOf(ws);
        if (now === was) return;
        if (layoutFor(now) !== layoutFor(was)) wsLayout(ws, layoutFor(now));
        if ((now === "flotante") !== (was === "flotante")) convert(HyprClients.onWorkspace(ws), now === "flotante");
    }
    // Compatibilidad: flotar o no un espacio
    function setFloat(ws: int, on: bool): void { setWsMode(ws, on ? "flotante" : (mode === "flotante" ? "mosaico" : mode)); }
    // Regla de espacio de Hyprland con el diseño (las reglas se pierden al recargar: reapplyRules)
    function wsLayout(ws: int, lay: string): void {
        Shell.dispatch('function() hl.workspace_rule({ workspace = "' + ws + '", layout = "' + lay + '" }) end');
    }
    function reapplyRules(): void {
        for (const k in overrides) if (layoutFor(overrides[k]) !== layoutFor(mode)) wsLayout(parseInt(k), layoutFor(overrides[k]));
    }

    // ---------- minimizar ----------
    readonly property string minWs: "special:minimized"
    function isMin(c): bool { return (c?.workspace?.name ?? "") === minWs; }
    readonly property var minimized: { HyprClients.refreshes; return HyprClients.clients.filter(c => isMin(c)); }
    property var minOrder: []          // direcciones, la última minimizada al final
    function win(address): string { return 'window = "address:' + HyprClients.norm(address) + '"'; }
    function minimize(address): void {
        const c = HyprClients.client(address);
        if (!c || isMin(c)) return;
        if ((c.fullscreen ?? 0) === 2) Shell.dispatch('hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", ' + win(c.address) + ' })');
        Shell.dispatch('hl.dsp.window.move({ workspace = "' + minWs + '", follow = false, ' + win(c.address) + ' })');
        minOrder = minOrder.filter(a => a !== c.address).concat([c.address]);
        HyprClients.refresh();
    }
    // La trae al espacio activo del monitor con el foco y la enfoca
    function restore(address): void {
        const a = HyprClients.norm(address);
        const ws = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        Shell.dispatch('hl.dsp.window.move({ workspace = ' + ws + ', follow = false, ' + win(a) + ' })');
        minOrder = minOrder.filter(x => x !== a);
        HyprClients.focusWindow(a);
        HyprClients.refresh();
    }
    function toggleMinimize(address): void { const c = HyprClients.client(address); if (c) isMin(c) ? restore(c.address) : minimize(c.address); }
    function restoreLast(): void {
        const m = minimized;
        if (!m.length) return;
        const last = minOrder.slice().reverse().find(a => m.some(c => c.address === a)) ?? m[0].address;
        restore(last);
    }
    // Maximizar / restaurar (modo «maximized» de Hyprland: respeta la barra y el dock fijo)
    function isMax(c): bool { return (c?.fullscreen ?? 0) === 1; }
    function toggleMaximize(address): void {
        const c = HyprClients.client(address);
        if (!c) return;
        if (isMin(c)) restore(c.address);
        HyprClients.focusWindow(c.address);
        maxLater.lua = 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", ' + win(c.address) + ' })';
        maxLater.restart();
    }
    Timer { id: maxLater; property string lua: ""; interval: 130; onTriggered: { Shell.dispatch(lua); HyprClients.refresh(); } }
    function close(address): void { Shell.dispatch('hl.dsp.window.close({ ' + win(address) + ' })'); HyprClients.refresh(); }

    // ---------- ocultación inteligente (dock y barra) ----------
    // ¿Alguna ventana del espacio visible del monitor tapa r = { x, y, w, h } (coordenadas lógicas globales)?
    // En un espacio en mosaico solo cuentan las flotantes y las maximizadas / a pantalla completa (las del
    // mosaico nunca tapan algo que reserva su sitio).
    function covered(monName: string, r): bool {
        HyprClients.refreshes;
        const m = HyprClients.monitorByName(monName);
        if (!m || !r) return false;
        const ids = [m.activeWorkspace?.id ?? 0, m.specialWorkspace?.id ?? 0].filter(i => i !== 0);
        for (const c of HyprClients.clients) {
            const ws = c.workspace?.id ?? 0;
            if (!ids.includes(ws) || isMin(c)) continue;
            const fs = (c.fullscreen ?? 0) > 0;
            if (!fs && !c.floating && !isFloat(ws)) continue;
            if (fs) return true;
            const x = c.at?.[0] ?? 0, y = c.at?.[1] ?? 0, w = c.size?.[0] ?? 0, h = c.size?.[1] ?? 0;
            if (x < r.x + r.w && x + w > r.x && y < r.y + r.h && y + h > r.y) return true;
        }
        return false;
    }
    // ¿Hay una ventana maximizada / a pantalla completa en el espacio visible del monitor?
    function hasFullscreen(monName: string): bool {
        HyprClients.refreshes;
        const m = HyprClients.monitorByName(monName);
        const id = m?.activeWorkspace?.id ?? 0;
        return !!m && HyprClients.clients.some(c => c.workspace?.id === id && (c.fullscreen ?? 0) > 0);
    }
    // Arrastrar o redimensionar una ventana no avisa por IPC: mientras alguien use la ocultación inteligente
    // y haya ventanas flotantes a la vista, se mira la geometría cada poco
    readonly property bool smartOn: Settings.barSmartHide || (Settings.get("dockBehavior", "inteligente") === "inteligente"
        && (mode === "flotante" || dockInTiling || Object.values(overrides).includes("flotante")))
    readonly property bool floatingVisible: {
        HyprClients.refreshes;
        const act = HyprClients.monitors.map(m => m.activeWorkspace?.id ?? 0);
        return HyprClients.clients.some(c => c.floating && act.includes(c.workspace?.id ?? 0));
    }
    Timer { interval: 600; repeat: true; running: root.smartOn && root.floatingVisible; onTriggered: HyprClients.refreshNow() }

    // ---------- conversión y colocación ----------
    // Ventanas que no se tocan: las del shell, web apps, PiP, fijadas, a pantalla completa
    function keep(c): bool {
        return !c || c.pinned || (c.fullscreen ?? 0) > 0 || (c.workspace?.id ?? 0) <= 0
            || /^(org\.quickshell|steam_app_.*|gamescope)$/.test(c.class ?? "")
            || /^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture|[Pp]antalla[-\s]?en[-\s]?[Pp]antalla)/.test(c.title ?? "");
    }
    // Apps que flotan siempre al centro (floatApps, reglas hf-float-apps de config/apply/35-windows.py): al salir
    // del modo flotante (o en un espacio en mosaico) no se vuelven a meter en el mosaico
    readonly property var floatApps: (Settings.get("floatApps", []) ?? []).map(c => String(c).toLowerCase())
    function isFloatApp(cls): bool { return floatApps.includes(String(cls ?? "").toLowerCase()); }
    // Diálogo o utilidad pequeña: flota y conserva su tamaño
    function small(c): bool { return (c.size?.[0] ?? 0) < 560 && (c.size?.[1] ?? 0) < 420; }

    function convert(list, on: bool): void {
        const placed = [];
        for (const c of list) {
            if (keep(c)) continue;
            const w = 'window = "address:' + c.address + '"';
            if (on && !c.floating) {
                Shell.dispatch('hl.dsp.window.float({ action = "enable", ' + w + ' })');
                place(c, true, placed);
            } else if (!on && c.floating && !small(c) && !isFloatApp(c.class)) {
                Shell.dispatch('hl.dsp.window.float({ action = "disable", ' + w + ' })');
            }
        }
        HyprClients.refresh();
    }
    // Tamaño y posición de una ventana flotante: grande si es una ventana normal, centrada y en cascada.
    // placed: rectángulos ya colocados en esta tanda (para encadenar la cascada)
    function place(c, force: bool, placed): void {
        const mon = HyprClients.monitorById(c.monitor) ?? HyprClients.focusedMonitor;
        if (!mon) return;
        const U = HyprClients.usableRect(mon);
        let w = c.size?.[0] ?? 0, h = c.size?.[1] ?? 0;
        const tw = Math.round(U.w * 0.62), th = Math.round(U.h * 0.70);
        const resize = force || (!small(c) && w < tw && h < th);
        // Venía del mosaico, o Hyprland le dio casi toda el área (regla de espacio): su tamaño no sirve
        if (force || (w >= U.w * 0.9 && h >= U.h * 0.85)) { w = tw; h = th; }
        else if (resize) { w = Math.max(w, tw); h = Math.max(h, th); }
        w = Math.min(w, Math.round(U.w * 0.94)); h = Math.min(h, Math.round(U.h * 0.94));
        let x = Math.round(U.x + (U.w - w) / 2), y = Math.round(U.y + (U.h - h) / 2);
        // Cascada: si otra ventana flotante del espacio ya está ahí (±24 px), baja 32 px en diagonal
        const ws = c.workspace?.id;
        const others = HyprClients.clients.filter(o => o.address !== c.address && o.floating && o.workspace?.id === ws)
            .map(o => ({ x: o.at[0], y: o.at[1] })).concat(placed ?? []);
        for (let i = 0; i < 12 && others.some(o => Math.abs(o.x - x) < 24 && Math.abs(o.y - y) < 24); i++) {
            x += 32; y += 32;
            if (x + w > U.x + U.w || y + h > U.y + U.h) { x = U.x + 24 + 32 * i; y = U.y + 24; }
        }
        placed?.push({ x: x, y: y });
        const t = 'window = "address:' + c.address + '"';
        if (w !== c.size?.[0] || h !== c.size?.[1])
            Shell.dispatch('hl.dsp.window.resize({ x = ' + w + ', y = ' + h + ', exact = true, ' + t + ' })');
        Shell.dispatch('hl.dsp.window.move({ x = ' + x + ', y = ' + y + ', exact = true, ' + t + ' })');
    }
    // Para Snap (Super + ↓) cuando no hay geometría previa: tamaño cómodo en el centro
    function placeDefault(address: string): void {
        const c = HyprClients.client(address);
        if (c) place(c, true, []);
    }

    // ---------- cambio de modo en vivo ----------
    property string appliedMode: ""
    function sync(): void {
        if (!Settings.loaded) return;
        if (appliedMode === "") { appliedMode = mode; return; }
        if (mode === appliedMode) return;
        const om = appliedMode, old = overrides;
        appliedMode = mode;
        overrides = ({});
        // Las excepciones de diseño se van con la recarga de la configuración que trae el cambio de modo; las de
        // flotar se deshacen aquí junto con el resto (el espacio vuelve al modo general)
        // Solo los espacios cuyo modo cambia: lo que hayas hecho flotar a mano en un espacio en mosaico se queda
        const byWs = {};
        for (const c of HyprClients.clients) {
            const ws = c.workspace?.id ?? 0;
            if (ws <= 0) continue;
            const was = baseFloat(ws, old[String(ws)] ?? om), now = baseFloat(ws, mode);
            if (was === now) continue;
            (byWs[ws] = byWs[ws] ?? { on: now, list: [] }).list.push(c);
        }
        for (const k in byWs) convert(byWs[k].list, byWs[k].on);
    }
    onModeChanged: Qt.callLater(sync)
    readonly property bool ready: Settings.loaded
    onReadyChanged: { HyprClients.refreshNow(); Qt.callLater(sync); }
    Component.onCompleted: Qt.callLater(sync)

    // ---------- recordar posiciones (Ajustes › Escritorio › «Recordar dónde estaba cada app», floatRemember) ----------
    // Por clase de app, la última geometría que tuvo flotando (sin contar diálogos pequeños ni maximizadas); al abrirla
    // de nuevo en un espacio flotante vuelve ahí (dentro del área útil; en cascada si ya hay otra igual en ese sitio).
    // Se guarda en ~/.local/state/hyprfrijol/float-geometry.json.
    readonly property bool remember: Settings.get("floatRemember", true) === true
    property var geom: ({})
    FileView {
        id: geomFile
        path: Paths.state + "/float-geometry.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { root.geom = JSON.parse(text()) ?? {}; } catch (e) { root.geom = {}; } }
    }
    Timer { id: geomSave; interval: 2000; onTriggered: geomFile.setText(JSON.stringify(root.geom)) }
    Connections {
        target: HyprClients
        enabled: root.remember
        function onRefreshesChanged() {
            let changed = false;
            const g = Object.assign({}, root.geom);
            for (const c of HyprClients.clients) {
                if (!c.floating || root.keep(c) || root.small(c) || !c.class || !c.mapped) continue;
                if (root.pending.some(p => p.a === c.address)) continue;      // aún colocándose
                const o = g[c.class], n = { x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], mon: c.monitor };
                if (!o || o.x !== n.x || o.y !== n.y || o.w !== n.w || o.h !== n.h) { g[c.class] = n; changed = true; }
            }
            if (changed) { root.geom = g; geomSave.restart(); }
        }
    }
    // Coloca la ventana donde estaba su app la última vez; false si no hay nada guardado
    function restoreGeom(c): bool {
        const r = remember ? geom[c.class] : null;
        if (!r) return false;
        const mon = HyprClients.monitorById(r.mon) ?? HyprClients.monitorById(c.monitor) ?? HyprClients.focusedMonitor;
        if (!mon) return false;
        const U = HyprClients.usableRect(mon);
        const w = Math.min(r.w, U.w), h = Math.min(r.h, U.h);
        let x = Math.max(U.x, Math.min(r.x, U.x + U.w - w)), y = Math.max(U.y, Math.min(r.y, U.y + U.h - h));
        // Otra ventana de la misma app ya en ese sitio: un paso en diagonal
        for (let i = 0; i < 8 && HyprClients.clients.some(o => o.address !== c.address && o.class === c.class && o.floating
                && Math.abs(o.at[0] - x) < 24 && Math.abs(o.at[1] - y) < 24); i++) {
            x = Math.min(x + 32, U.x + U.w - w); y = Math.min(y + 32, U.y + U.h - h);
        }
        const t = 'window = "address:' + c.address + '"';
        Shell.dispatch('hl.dsp.window.resize({ x = ' + w + ', y = ' + h + ', exact = true, ' + t + ' })');
        Shell.dispatch('hl.dsp.window.move({ x = ' + x + ', y = ' + y + ', exact = true, ' + t + ' })');
        return true;
    }

    // ---------- ventanas nuevas ----------
    property var pending: []        // [{ a: dirección, t: ms }] recién abiertas que flotan por el modo
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            // Petición de minimizar (barras de tareas, foreign-toplevel): al espacio de las minimizadas. Ojo: el botón
            // de minimizar de las propias apps (Chrome, GNOME…) no llega: Hyprland 0.57 lo ignora sin avisar
            if (ev.name === "minimized") {
                const [a, on] = ev.data.split(",");
                if (on === "1") root.minimize("0x" + a);
                return;
            }
            // Recarga de la configuración (cada cambio de ajustes): vuelven las excepciones de diseño
            if (ev.name === "configreloaded") { Qt.callLater(root.reapplyRules); return; }
            if (ev.name !== "openwindow") return;
            const [addr, wsName, cls] = ev.data.split(",");
            const ws = parseInt(wsName);
            if (!(ws > 0)) return;
            const want = root.isFloat(ws), base = root.baseFloat(ws, root.mode);
            if (want !== base && (want || !root.isFloatApp(cls)))
                Shell.dispatch('hl.dsp.window.float({ action = "' + (want ? "enable" : "disable") + '", window = "address:0x' + addr + '" })');
            if (want) { root.pending = root.pending.concat([{ a: "0x" + addr, t: Date.now() }]); HyprClients.refresh(); }
        }
    }
    Connections {
        target: HyprClients
        enabled: root.pending.length > 0
        function onRefreshesChanged() {
            const now = Date.now(), left = [];
            for (const p of root.pending) {
                const c = HyprClients.client(p.a);
                if (c) { if (c.floating && !root.keep(c) && (root.small(c) || !root.restoreGeom(c))) root.place(c, false, []); }
                else if (now - p.t < 3000) left.push(p);   // aún no sale en hyprctl: se reintenta
            }
            root.pending = left;
            if (left.length) retry.restart();
        }
    }
    Timer { id: retry; interval: 250; onTriggered: HyprClients.refresh() }

    // qs ipc call winmode cycle | set <modo> | setWs <espacio> <modo|""> | get [espacio]
    IpcHandler {
        target: "winmode"
        function cycle(): void { root.cycle(); }
        function set(m: string): void { root.setMode(m); }
        function setWs(ws: int, m: string): void { root.setWsMode(ws, m); }
        function get(ws: int): string { return ws > 0 ? root.modeOf(ws) : root.mode; }
    }
    GlobalShortcut { appid: "hf"; name: "modoventanas"; description: "HyprFrijol: modo de ventanas (mosaico, desplazamiento, flotante)"; onPressed: root.cycle() }
    GlobalShortcut { appid: "hf"; name: "minimizar"; description: "HyprFrijol: minimizar la ventana activa"; onPressed: if (HyprClients.activeAddress) root.minimize(HyprClients.activeAddress) }
    GlobalShortcut { appid: "hf"; name: "restaurar"; description: "HyprFrijol: restaurar la última ventana minimizada"; onPressed: root.restoreLast() }
}
