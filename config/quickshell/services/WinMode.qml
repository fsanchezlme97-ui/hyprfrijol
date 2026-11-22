pragma Singleton
// Modo de ventanas (ajuste "windowMode"), tres modos de primera clase:
//   "mosaico"        las ventanas se reparten la pantalla (general:layout = "layout": dwindle / master)
//   "desplazamiento" columnas en una cinta que se desplaza (diseño «scrolling» nativo de Hyprland 0.57;
//                    ancho y ajuste de columna: "scrollColumnWidth", "scrollFocusFit", "scrollOneFull")
//   "flotante"       «Clásico»: todas las ventanas flotan y las normales se abren maximizadas (se superponen;
//                    Alt + Tab trae al frente la que necesitas, Super + H minimiza), dock en todos los espacios
// El antiguo "mixto" se lee como "mosaico"; "layout" = "scrolling" (versiones anteriores) con "mosaico" se lee
// como "desplazamiento". general:layout y la regla de flotar las ponen config/apply/30-layout.py y 35-windows.py;
// aquí:
// - Cambio en vivo: al cambiar el modo pasa a flotante / mosaico / columnas las ventanas ya abiertas.
// - Excepción por espacio (ajustes rápidos › Ventanas, Super + Ctrl + Espacio, icono de la barra): setWsMode(ws, modo),
//   cycleWs(ws). Se guardan (ws-modes.json). Flotar se hace
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
    readonly property var labels: ({ mosaico: "Mosaico", desplazamiento: "Desplazamiento", flotante: "Clásico" })
    readonly property var hints: ({ mosaico: "Las ventanas se reparten la pantalla",
                                    desplazamiento: "Columnas en una cinta que se desplaza",
                                    flotante: "Ventanas maximizadas que se superponen; Alt + Tab trae la que necesitas" })
    readonly property var icons: ({ mosaico: "tiles", desplazamiento: "columns", flotante: "float" })
    // Diseño del mosaico (dwindle / master); el antiguo "scrolling" es ahora el modo «Desplazamiento»
    readonly property string tiledLayout: { const l = Settings.get("layout", "dwindle"); return l === "master" ? "master" : "dwindle"; }
    function norm(wm, lay): string {
        return wm === "flotante" ? "flotante" : wm === "desplazamiento" ? "desplazamiento"
             : lay === "scrolling" ? "desplazamiento" : "mosaico";
    }
    readonly property string mode: norm(Settings.get("windowMode", "mosaico"), Settings.get("layout", "dwindle"))
    // Espacios con excepción: { "3": "flotante" } (otro modo que el general solo en ese espacio). Se guardan en
    // ~/.local/state/hyprfrijol/ws-modes.json y vuelven al reiniciar el shell; cambiar el modo general las borra.
    property var overrides: ({})
    property bool overridesLoaded: false
    onOverridesChanged: if (overridesLoaded) wsModesFile.setText(JSON.stringify(overrides))
    FileView {
        id: wsModesFile
        path: Paths.state + "/ws-modes.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let o = {};
            try { o = JSON.parse(text()) ?? {}; } catch (e) {}
            for (const k in o) if (!root.modes.includes(o[k]) || !(parseInt(k) > 0)) delete o[k];
            root.overrides = o;
            root.overridesLoaded = true;
            root.reapplyRules();
        }
        onLoadFailed: root.overridesLoaded = true
    }
    readonly property bool dry: Quickshell.env("HF_TRY") === "1"

    // ---------- prioridad de las flotantes (floatOrder) ----------
    // "encima" (por defecto): las flotantes van sobre el mosaico, como siempre.
    // "ocultas": no se ven mientras una ventana del mosaico tiene el foco: se esconden (se minimizan, como con
    //            Super + H) y vuelven al enfocar una flotante (Alt + Tab, la vista general) o al quedarse el
    //            escritorio a la vista.
    // "espacio": se van al espacio oculto (Super + S) y se ven allí, encima del mosaico: el mosaico queda limpio.
    // «Detrás» no es posible: Hyprland dibuja las flotantes por encima de las del mosaico (solo una ventana
    // maximizada las tapa); la única forma de que el mosaico mande es esconderlas.
    readonly property string floatOrder: {
        const v = String(Settings.get("floatOrder", "encima") ?? "encima");
        return ["encima", "ocultas", "espacio"].includes(v) ? v : "encima";
    }
    property string _floatOrderKey: ""
    property var _hidden: []           // «dirección|espacio» de las que escondió «ocultas» (no las minimizadas a mano)
    property bool _hiding: false
    property string _hideKey: ""
    // Esconder espera un poco: una ventana flotante que acaba de abrirse (el chat de RustDesk, una calculadora…)
    // puede estar cogiendo el foco; si ya lo tiene, no se esconde
    Timer { id: hideTimer; interval: 260; onTriggered: { root._hiding = true; root.applyFloatOrder(); root._hiding = false; } }
    // Se llama con cada cambio de ventanas. La clave evita repetir los cambios en cada refresco.
    function applyFloatOrder(): void {
        const act = HyprClients.client(HyprClients.activeAddress);
        const focused = !!act && !isMin(act);
        if (floatOrder === "ocultas") {
            const activeWs = HyprClients.monitors.map(m => m.activeWorkspace?.id ?? 0).filter(i => i > 0);
            const fl = HyprClients.clients.filter(c => c.floating && !keep(c) && !isDialog(c)
                && activeWs.includes(c.workspace?.id ?? 0));
            const tiled = HyprClients.clients.filter(c => !c.floating && !keep(c) && activeWs.includes(c.workspace?.id ?? 0));
            // Con el escritorio a la vista (sin foco y sin mosaico) vuelven todas; si no, se esconden las flotantes
            // que no tengan el foco (si la que lo tiene es del mosaico, todas)
            const desktop = !focused && tiled.length === 0;
            const hide = desktop ? [] : focused && !act.floating ? fl : fl.filter(c => c.address !== act?.address);
            const key = "ocultas|" + hide.map(c => c.address).join(",") + "|" + (desktop ? "" : root._hidden.join(","));
            // Nada que cambiar: se anula un esconder pendiente (si no, su clave vieja impedía volver a lanzarlo)
            if (key === root._floatOrderKey) { hideTimer.stop(); root._hideKey = ""; return; }
            // Esperar solo cuando cambia lo que hay que esconder: así un refresco detrás de otro no aplaza el esconder
            if (hide.length && !root._hiding) {
                if (root._hideKey !== key) { root._hideKey = key; hideTimer.restart(); }
                return;
            }
            root._hideKey = "";
            root._floatOrderKey = key;
            if (desktop) {
                const hs = root._hidden;
                root._hidden = [];
                for (const h of hs) { const [a, ws] = h.split("|"); root.unhide(a, parseInt(ws)); }
                return;
            }
            for (const c of hide) {
                // Si está a la vista no está escondida, aunque su entrada siga (volvió sin pasar por restore)
                root._hidden = root._hidden.filter(h => h.split("|")[0] !== c.address)
                    .concat([c.address + "|" + (c.workspace?.id ?? 0)]);
                root.minimize(c.address);
            }
            return;
        }
        const fl = HyprClients.clients.filter(c => c.floating && !keep(c) && (c.workspace?.id ?? 0) > 0);
        if (floatOrder === "encima") {
            // Al volver a «encima», las flotantes recuperan su opacidad (por si venían de «atenuadas»)
            if (root._floatOrderKey === "encima") return;
            root._floatOrderKey = "encima";
            for (const c of fl)
                Shell.dispatch('hl.dsp.window.set_prop({ prop = "opacity_inactive_override", value = "unset", window = "address:' + c.address + '" })');
            return;
        }
        const key = "espacio|" + fl.map(c => c.address + "@" + (c.workspace?.id ?? 0)).join(",");
        if (key === root._floatOrderKey) return;
        root._floatOrderKey = key;
        for (const c of fl)
            Shell.dispatch('hl.dsp.window.move({ workspace = "special:special", follow = false, window = "address:' + c.address + '" })');
    }
    // Al cambiar el ajuste se rehace entero (y vuelven las que se escondieron)
    onFloatOrderChanged: {
        root._floatOrderKey = "";
        const hs = root._hidden;
        root._hidden = [];
        for (const h of hs) { const [a, ws] = h.split("|"); root.unhide(a, parseInt(ws)); }
        HyprClients.refresh();
    }

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
    // Lado del dock en cada pantalla (ajuste "dockPos"): "izquierda" · "abajo" · "auto" (por defecto: a la izquierda,
    // salvo que ese borde toque otra pantalla —el cursor se pasaría a ella en vez de tocar el borde—; entonces abajo)
    readonly property string dockPos: { const p = Settings.get("dockPos", "auto"); return ["izquierda", "abajo"].includes(p) ? p : "auto"; }
    function dockSide(monName: string): string {
        if (dockPos !== "auto") return dockPos;
        const ms = HyprClients.monitors, m = ms.find(x => x.name === monName);
        if (!m) return "izquierda";
        const L = HyprClients.logical(m);
        const touches = fn => ms.some(o => o.name !== monName && fn(HyprClients.logical(o)));
        if (!touches(o => Math.abs(o.x + o.w - L.x) < 2 && o.y < L.y + L.h && o.y + o.h > L.y)) return "izquierda";
        return touches(o => Math.abs(o.y - (L.y + L.h)) < 2 && o.x < L.x + L.w && o.x + o.w > L.x) ? "izquierda" : "abajo";
    }

    // Cambia el modo general. Al volver a «Mosaico» con el antiguo layout = "scrolling", el mosaico pasa a dwindle.
    function setMode(m: string): void {
        if (!modes.includes(m) || m === mode) return;
        const o = { windowMode: m };
        if (Settings.get("layout", "dwindle") === "scrolling") o.layout = "dwindle";
        Settings.setMany(o);
    }
    signal announced(string m)          // el OSD lo enseña (modules/osd)
    signal minimizing(var c)            // justo antes de minimizar: el dock hace volar la ventana hasta su icono
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
    // Siguiente modo solo para el espacio activo (hf:modoespacio, Super + Ctrl + Espacio; clic en el icono de la barra)
    function cycleWs(ws: int): void {
        if (ws <= 0) return;
        const next = modes[(modes.indexOf(modeOf(ws)) + 1) % modes.length];
        setWsMode(ws, next);
        announced(next);
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
        minimizing(c);
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
        root._hidden = root._hidden.filter(h => h.split("|")[0] !== a);   // ya no la esconde «ocultas»
        HyprClients.focusWindow(a);
        HyprClients.refresh();
    }
    // Devuelve una ventana escondida a su espacio, sin darle el foco (prioridad «Ocultas»)
    function unhide(address, ws): void {
        const a = HyprClients.norm(address);
        const dest = ws > 0 ? ws : (Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1);
        Shell.dispatch('hl.dsp.window.move({ workspace = ' + dest + ', follow = false, ' + win(a) + ' })');
        minOrder = minOrder.filter(x => x !== a);
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
    function isMax(c): bool { return (c?.fullscreen ?? 0) === 1 || !!held[c?.address ?? ""]; }   // o maximizada debajo
    function hyprMax(c): bool { return (c?.fullscreen ?? 0) === 1; }
    function toggleMaximize(address): void {
        const c = HyprClients.client(address);
        if (!c) return;
        if (isMin(c)) restore(c.address);
        // maximizada debajo (la mantiene grande stackStep): restaurar es volver a su tamaño, sin pasar por Hyprland
        if (held[c.address]) {
            const r = held[c.address], h = Object.assign({}, held); delete h[c.address]; held = h;
            setRect(c.address, r);
            HyprClients.focusWindow(c.address);
            return;
        }
        HyprClients.focusWindow(c.address);
        maxLater.lua = 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", ' + win(c.address) + ' })';
        maxLater.restart();
    }
    Timer { id: maxLater; property string lua: ""; interval: 130; onTriggered: { Shell.dispatch(lua); HyprClients.refresh(); } }
    // ---------- ventana activa por pantalla (dimInactive, inactiveOpacity) ----------
    // decoration:dim_inactive e inactive_opacity son globales: con dos pantallas también atenuaban (y volvían translúcida)
    // la ventana con la que trabajas en la otra. Cada pantalla deja como activa su última ventana enfocada: no_dim y
    // opacidad inactiva 1 por ventana (la enfocada ya no se atenúa). Sin atenuar ni transparencia no cambian nada.
    readonly property var undimmed: {
        if (HyprClients.monitors.length < 2) return [];
        // La pantalla con el foco, por la ventana activa: monitors[].focused solo se pone al día con la lista completa
        const am = HyprClients.client(HyprClients.activeAddress)?.monitor ?? HyprClients.focusedMonitor?.id;
        const out = [];
        for (const m of HyprClients.monitors) {
            if (m.id === am) continue;
            const c = HyprClients.byRecent.find(c => c.workspace?.id === m.activeWorkspace?.id && !isMin(c));
            if (c) out.push(c.address);
        }
        return out;
    }
    property var noDim: []
    property bool dimSwept: false
    onUndimmedChanged: {
        const prop = (a, k, v) => Shell.dispatch('hl.dsp.window.set_prop({ prop = "' + k + '", value = "' + v + '", ' + win(a) + ' })');
        const set = (a, v) => { prop(a, "no_dim", v); prop(a, "opacity_inactive_override", v); };
        // Al arrancar el shell no sabe a cuáles se las puso antes: se quitan de todas las demás una vez
        if (!dimSwept && HyprClients.clients.length) { dimSwept = true; noDim = HyprClients.clients.map(c => c.address); }
        for (const a of noDim) if (!undimmed.includes(a) && HyprClients.client(a)) set(a, "unset");
        for (const a of undimmed) if (!noDim.includes(a)) set(a, "1");
        noDim = undimmed;
    }

    // ---------- modo clásico: cada ventana sigue maximizada o no como la dejaste ----------
    // Hyprland deja una sola ventana maximizada por espacio: al enfocar otra (Alt + Tab, clic, una nueva) le quita el
    // maximizado a la anterior. Aquí la anterior se queda debajo a tamaño completo, a mano ("held"), y al volver a
    // enfocarla se maximiza de verdad; si luego la sacas de maximizar, vuelve al tamaño que tenía antes.
    property var held: ({})              // dirección → {x, y, w, h}: maximizada que quedó debajo (su tamaño normal)
    property var restoreTo: ({})         // dirección → {x, y, w, h}: al sacarla de maximizar, a este tamaño
    property string lastAct: ""
    property var maxRects: ({})          // dirección → {x, y, w, h}: las que Hyprland tenía maximizadas en la última vuelta
    function rectOf(c): var { return { x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1] }; }
    function setRect(a: string, r): void {
        const t = win(a);
        Shell.dispatch('hl.dsp.window.resize({ x = ' + r.w + ', y = ' + r.h + ', exact = true, ' + t + ' })');
        Shell.dispatch('hl.dsp.window.move({ x = ' + r.x + ', y = ' + r.y + ', exact = true, ' + t + ' })');
    }
    function stackStep(): void {
        const act = HyprClients.client(HyprClients.activeAddress)?.address ?? "";
        const now = {}, h = {};
        let changed = false;
        for (const c of HyprClients.clients) {
            const a = c.address;
            const here = c.floating && !isMin(c) && isFloat(c.workspace?.id ?? 0);
            if (hyprMax(c)) { now[a] = rectOf(c); if (held[a]) changed = true; continue; }
            if (here && held[a]) h[a] = held[a];
            const was = maxRects[a];
            if (!was || !here || (c.fullscreen ?? 0) !== 0) continue;
            if (a === act) {
                // la sacaste de maximizar (botón, doble clic o la propia app): a su tamaño de antes
                if (restoreTo[a]) setRect(a, restoreTo[a]);
            } else {
                // Hyprland se la quitó al maximizar o enfocar otra: se queda debajo, grande
                h[a] = restoreTo[a] ?? rectOf(c);
                setRect(a, was);
            }
            delete restoreTo[a];
        }
        maxRects = now;
        // la que enfocas estaba debajo maximizada: otra vez de verdad
        if (h[act]) { restoreTo[act] = h[act]; delete h[act]; maximize(HyprClients.client(act)); }
        // Hyprland deja encima de una maximizada las flotantes que enfocaste (y al volver a ella, ni bring_to_top ni
        // maximizarla otra vez lo quitan): se mandan al fondo, de la más reciente a la más antigua para no
        // desordenarlas entre sí
        else if (act !== lastAct && now[act]) {
            const ws = HyprClients.client(act)?.workspace?.id;
            for (const o of HyprClients.byRecent)
                if (o.address !== act && o.workspace?.id === ws && o.floating && !o.pinned)
                    Shell.dispatch('hl.dsp.window.alter_zorder({ mode = "bottom", ' + win(o.address) + ' })');
        }
        lastAct = act;
        if (changed || JSON.stringify(h) !== JSON.stringify(held)) held = h;
    }
    Connections { target: HyprClients; function onRefreshesChanged() { root.stackStep(); root.syncFrames(); root.applyFloatOrder(); } }

    // ---------- barra de título del modo clásico (ajuste "titleBars") ----------
    // Las islas de modules/desktop/TitleBar.qml (título, asa y botones dentro de la ventana activa) no salen en las
    // apps que ya dibujan su barra: las GTK, Chromium / Electron y Firefox (por las bibliotecas que tiene cargadas el
    // proceso, frameProbe) y las clases de "barsOwnFrame".
    readonly property bool titleBars: Settings.get("titleBars", true) !== false
    onTitleBarsChanged: HyprClients.refresh()
    readonly property var ownFrameList: (Settings.get("barsOwnFrame", []) ?? []).map(c => String(c).toLowerCase())
    property var frames: ({})            // clase en minúsculas → true (dibuja su barra) / false
    property var ungrouped: ({})         // dirección → ya se le quitó el grupo de antes (una vez)
    function hasOwnFrame(c): bool { const k = String(c.class ?? "").toLowerCase(); return ownFrameList.includes(k) || frames[k] === true; }
    function syncFrames(): void {
        const unknown = {}, ug = Object.assign({}, ungrouped);
        for (const c of HyprClients.clients) {
            const ws = c.workspace?.id ?? 0, k = String(c.class ?? "").toLowerCase(), g = c.grouped ?? [];
            // Hasta 0.10.24 la barra era la de un grupo de una sola ventana: se deshace (una vez por ventana)
            if (g.length === 1 && HyprClients.norm(g[0]) === HyprClients.norm(c.address) && !ug[c.address]) {
                ug[c.address] = true;
                Shell.dispatch('hl.dsp.group.toggle({ ' + win(c.address) + ' })');
            }
            if (titleBars && ws > 0 && c.floating && isFloat(ws) && k && frames[k] === undefined && !ownFrameList.includes(k) && !keepClass(c))
                unknown[k] = c.pid;
        }
        ungrouped = ug;
        if (Object.keys(unknown).length && !frameProbe.running) {
            frameProbe.args = Object.keys(unknown).map(k => unknown[k] + "\t" + k);
            frameProbe.running = true;
        }
    }
    Process {
        id: frameProbe
        property var args: []
        command: ["sh", "-c", 'for a; do p=${a%%\t*}; if grep -qE "libgtk-[34]\\.so|libxul\\.so|v8_context_snapshot|chrome_100_percent\\.pak" "/proc/$p/maps" 2>/dev/null; '
                  + 'then echo "${a#*\t}\t1"; else echo "${a#*\t}\t0"; fi; done', "sh"].concat(args)
        stdout: StdioCollector {
            onStreamFinished: {
                const f = Object.assign({}, root.frames);
                for (const l of text.split("\n")) { const i = l.lastIndexOf("\t"); if (i > 0) f[l.slice(0, i)] = l.slice(i + 1) === "1"; }
                root.frames = f;
                HyprClients.refresh();
            }
        }
    }

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
    Timer { interval: 600; repeat: true; running: root.smartOn && root.floatingVisible; onTriggered: HyprClients.refreshGeometry() }

    // ---------- conversión y colocación ----------
    // Ventanas que no se tocan: las del shell, juegos y apps de Wine / Proton (rules.lua: wine-float), PiP, fijadas,
    // a pantalla completa
    function keep(c): bool {
        return !c || c.pinned || (c.fullscreen ?? 0) > 0 || (c.workspace?.id ?? 0) <= 0 || keepClass(c);
    }
    function keepClass(c): bool {
        return /^(org\.quickshell|steam_app_.*|steam_proton|.*\.exe|gamescope)$/i.test(c.class ?? "")
            || /^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture|[Pp]antalla[-\s]?en[-\s]?[Pp]antalla)/.test(c.title ?? "");
    }
    // Apps que flotan siempre al centro (floatApps, reglas hf-float-apps de config/apply/35-windows.py): al salir
    // del modo flotante (o en un espacio en mosaico) no se vuelven a meter en el mosaico
    readonly property var floatApps: (Settings.get("floatApps", []) ?? []).map(c => String(c).toLowerCase())
    function isFloatApp(cls): bool { return floatApps.includes(String(cls ?? "").toLowerCase()); }
    // Diálogo (modal: etiqueta hf-dialog de config/apply/35-windows.py) o utilidad pequeña: flota y conserva su tamaño
    function isDialog(c): bool { return (c.tags ?? []).some(t => String(t).startsWith("hf-dialog")); }
    function small(c): bool { return isDialog(c) || (c.size?.[0] ?? 0) < 560 && (c.size?.[1] ?? 0) < 420; }
    // Modo clásico: las ventanas normales se abren maximizadas; los diálogos (small), el selector de archivos (portal),
    // los de rules.lua y las apps de floatApps flotan con su tamaño.
    // shortcut: un diálogo grande de una app GTK 3 (no se declara modal) también se maximiza. Si molesta, mirar el
    // padre (xdg_toplevel parent) cuando hyprctl lo exponga.
    function opensMax(c): bool {
        return !small(c) && !isFloatApp(c.class)
            && !/^(xdg-desktop-portal-.*|org\.pulseaudio\.pavucontrol|pavucontrol|nm-connection-editor|blueman-manager|polkit.*)$/i.test(c.class ?? "");
    }
    function maximize(c): void { Shell.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "set", ' + win(c.address) + ' })'); }
    // Quitarle el flotado a una ventana: si está en el espacio oculto (Super + S) vuelve antes al espacio actual
    // (en un espacio especial solo caben ventanas flotantes).
    function unfloat(c): void {
        const w = 'window = "address:' + c.address + '"';
        if ((c.workspace?.id ?? 0) <= 0) {
            const ws = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
            Shell.dispatch('hl.dsp.window.move({ workspace = ' + ws + ', follow = false, ' + w + ' })');
        }
        Shell.dispatch('hl.dsp.window.float({ action = "disable", ' + w + ' })');
    }

    function convert(list, on: bool): void {
        const placed = [];
        for (const c of list) {
            // Las maximizadas del modo clásico vuelven a su tamaño para entrar en el mosaico
            const unmax = !on && c.floating && isMax(c) && !c.pinned && (c.workspace?.id ?? 0) > 0;
            if (unmax) Shell.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", ' + win(c.address) + ' })');
            if (keep(c) && !unmax) continue;
            const w = 'window = "address:' + c.address + '"';
            if (on && !c.floating) {
                Shell.dispatch('hl.dsp.window.float({ action = "enable", ' + w + ' })');
                place(c, true, placed);
                if (opensMax(c)) maximize(c);
            } else if (!on && c.floating && !small(c) && !isFloatApp(c.class)) {
                unfloat(c);
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
    // Ventana principal de una que se abre: otra de la misma app (mismo proceso y clase) ya abierta en ese espacio, la
    // usada más recientemente. Así se reconocen los diálogos que no se declaran modales (GTK 3) y las ventanas nuevas
    // de una app ya abierta.
    function mainOf(c): var {
        return HyprClients.byRecent.find(o => o.address !== c.address && o.pid === c.pid && o.class === c.class
            && o.workspace?.id === c.workspace?.id && !isMin(o)) ?? null;
    }
    // Centrada sobre la ventana principal, con su propio tamaño (dentro del área útil)
    function centerOn(c, main): void {
        const mon = HyprClients.monitorById(c.monitor) ?? HyprClients.focusedMonitor;
        if (!mon) return;
        const U = HyprClients.usableRect(mon);
        const w = Math.min(c.size?.[0] ?? 0, U.w), h = Math.min(c.size?.[1] ?? 0, U.h);
        const mx = main.at[0] + main.size[0] / 2, my = main.at[1] + main.size[1] / 2;
        let x = Math.round(Math.max(U.x, Math.min(mx - w / 2, U.x + U.w - w)));
        let y = Math.round(Math.max(U.y, Math.min(my - h / 2, U.y + U.h - h)));
        // Del mismo tamaño que la principal (otra ventana de la app): un paso en diagonal para que se vea que son dos
        if (Math.abs(x - main.at[0]) < 24 && Math.abs(y - main.at[1]) < 24) {
            x = Math.min(x + 32, U.x + U.w - w); y = Math.min(y + 32, U.y + U.h - h);
        }
        const t = win(c.address);
        if (w !== c.size?.[0] || h !== c.size?.[1]) Shell.dispatch('hl.dsp.window.resize({ x = ' + w + ', y = ' + h + ', exact = true, ' + t + ' })');
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
    // Por clase de app, la última geometría que tuvo flotando (sin contar diálogos pequeños ni ventanas secundarias) y si
    // estaba maximizada ("max"); al abrirla de nuevo en un espacio flotante vuelve ahí (dentro del área útil; en cascada
    // si ya hay otra igual en ese sitio) y, en el modo clásico, maximizada o no como la dejaste.
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
                if (!c.floating || !c.class || !c.mapped || c.pinned || (c.workspace?.id ?? 0) <= 0 || root.keepClass(c) || root.small(c)) continue;
                if (root.pending.some(p => p.a === c.address) || root.mainOf(c) || root.held[c.address]) continue;   // aún colocándose · secundaria · maximizada debajo
                const o = g[c.class];
                // maximizada: solo se apunta eso (el tamaño guardado es al que vuelve)
                if (root.isMax(c)) { if (o?.max !== true) { g[c.class] = Object.assign({}, o ?? {}, { max: true }); changed = true; } continue; }
                if ((c.fullscreen ?? 0) > 0) continue;
                const n = { x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], mon: c.monitor, max: false };
                if (!o || o.x !== n.x || o.y !== n.y || o.w !== n.w || o.h !== n.h || o.max !== false) { g[c.class] = n; changed = true; }
            }
            if (changed) { root.geom = g; geomSave.restart(); }
        }
    }
    // Coloca la ventana donde estaba su app la última vez; false si no hay nada guardado
    function restoreGeom(c): bool {
        const r = remember ? geom[c.class] : null;
        if (!r || r.w === undefined) return false;
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
            // Juegos y apps de Windows: ajustes de su prefijo de Wine para Hyprland (scripts/hf-wine, una vez por prefijo)
            if (Settings.get("wineTweaks", true) !== false && /^(steam_proton|steam_app_\d+|.*\.exe)$/i.test(cls ?? ""))
                Quickshell.execDetached([Paths.script("hf-wine"), "fix", "0x" + addr]);
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
                if (!c) { if (now - p.t < 3000) left.push(p); continue; }   // aún no sale en hyprctl: se reintenta
                if (c.floating && !root.keep(c)) {
                    // Ventana secundaria (Preferencias, otra ventana de la misma app): centrada sobre la suya, sin maximizar
                    const main = root.mainOf(c);
                    if (main) root.centerOn(c, main);
                    // Primero su sitio de siempre: es el tamaño al que vuelve si la sacas de maximizar
                    else if (root.small(c) || !root.restoreGeom(c)) root.place(c, false, []);
                    // Como la cerraste: maximizada salvo que la última vez la dejaras en ventana (floatRemember)
                    if (!main && root.opensMax(c) && !(root.remember && root.geom[c.class]?.max === false)) root.maximize(c);
                }
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
    GlobalShortcut { appid: "hf"; name: "modoespacio"; description: "HyprFrijol: modo de ventanas solo de este espacio"; onPressed: root.cycleWs(Hyprland.focusedMonitor?.activeWorkspace?.id ?? 0) }
    GlobalShortcut { appid: "hf"; name: "minimizar"; description: "HyprFrijol: minimizar la ventana activa"; onPressed: if (HyprClients.activeAddress) root.minimize(HyprClients.activeAddress) }
    GlobalShortcut { appid: "hf"; name: "restaurar"; description: "HyprFrijol: restaurar la última ventana minimizada"; onPressed: root.restoreLast() }
}
