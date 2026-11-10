// Panel lateral (vista "ia"): pestañas IA · WhatsApp · YouTube · Pinterest, a la derecha de la pantalla.
//   Shell.open("ia")            última pestaña usada
//   Shell.open("ia", "wa")      pestaña concreta: "ia" | "wa" | "yt" | "pin"
//   Shell.open("ia", {ask: "…"}) (o el texto '{"ask":"…"}' por IPC) → pregunta directamente a la IA
//   qs … ipc call shell openWith ia yt
//
// Las apps web son ventanas aparte (scripts/hf-webapp: QtWebEngine en `qml6`, QtWebEngine no puede vivir
// dentro de Quickshell) que este panel acopla debajo de sus pestañas con dispatch de Hyprland: flotante,
// fijada en todos los espacios, 400 px de ancho. Al cerrar el panel se guardan en el espacio especial
// "hfweb" (siguen vivas: WhatsApp sigue avisando). «Desacoplar» la deja como ventana normal.
// PiP de YouTube: el botón de la cabecera la pasa al módulo pip ($XDG_RUNTIME_DIR/hf-webapp/pip).
// Ajustes › Panel lateral: sidePanelApps (pestañas visibles: "ia" + claves de "webapps"), sideWidth (px; las web apps
// usan el suyo, Ajustes › Web apps › Ancho en el panel → Shell.sideW),
// sideSide ("derecha" | "izquierda").  Shell.open("ia", {ask, image}) adjunta una imagen a la pregunta.
// Modo de cada web app (Ajustes › Web apps, services/WebApps.qml modeOf): las de modo «navegador» abren o enfocan la
// web en el navegador predeterminado (`hf-webapp open <clave>`, modo app si es Chromium) y el panel se cierra; las
// demás se acoplan como arriba. Cabecera: abrir la página actual en el navegador, desacoplar, fijar, cerrar.
// Fijar (botón de la chincheta · Ajustes › Panel lateral, sidePanelPinned): el panel deja de flotar encima y pasa a
// formar parte del mosaico: una capa invisible (hf-ia-zone) reserva su franja (zona exclusiva de layer-shell, como la
// barra) y las ventanas en mosaico se recolocan a su lado. Se queda abierto en todos los espacios y al abrir otras
// vistas, no se cierra con Esc (Esc devuelve el teclado a la última ventana) y va siempre en la pantalla principal
// (Ajustes › Pantallas). Se esconde (sin dejar la franja visible) con una ventana a pantalla completa, en el modo sin
// distracciones y durante la captura de la IA. Super + A y la × lo esconden en esta sesión (Shell.sideHidden: la
// franja se libera) y Super + A lo vuelve a mostrar fijado; desfijar = la chincheta o el ajuste.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: win
    // ---- fijado (sidePanelPinned): forma parte del mosaico
    readonly property bool pinPref: Settings.get("sidePanelPinned", false) === true
    readonly property bool pinActive: pinPref && !Shell.focusMode && !Shell.sideHidden
    readonly property var pinScreen: Shell.primaryScreen
    readonly property var pinMon: HyprClients.monitorByName(pinScreen?.name ?? "")
    // Ventana a pantalla completa de verdad (fullscreen 2; la maximizada respeta la franja) en la pantalla del panel
    readonly property bool fsHere: {
        if (!pinActive) return false;
        HyprClients.refreshes;
        const id = pinMon?.activeWorkspace?.id ?? 0;
        return HyprClients.clients.some(c => c.workspace?.id === id && (c.fullscreen ?? 0) === 2);
    }
    // Al pasar una ventana a pantalla completa el panel fijado se aparta aunque se hubiera abierto con Super + A
    // (abrirlo después, ya en pantalla completa, sí lo muestra encima)
    // Si su pantalla desaparece (monitor que se apaga, salida nueva) Quickshell esconde la ventana y su `visible` deja de
    // seguir al enlace; el panel fijado no cambia de estado y no volvería: tras cada cambio de pantallas se vuelve a enlazar
    Connections { target: Quickshell; function onScreensChanged() { kickTimer.restart(); } }
    Timer {
        id: kickTimer; interval: 400
        // Se cierra y se vuelve a crear la superficie (con la pantalla nueva puede quedarse sin capa en Hyprland)
        onTriggered: { win.visible = false; zone.visible = false; rebind.restart(); }
    }
    Timer {
        id: rebind; interval: 60
        onTriggered: {
            win.visible = Qt.binding(() => win.shown || slide.running);
            zone.visible = Qt.binding(() => win.pinActive && win.zoneW > 0);
        }
    }
    onFsHereChanged: if (fsHere && Shell.view === "ia") Shell.close()
    // Captura de pantalla de la IA (AiChat.capturing): el panel fijado también se aparta
    property bool chatCapturing: false
    Connections {
        target: chatLoader.item
        ignoreUnknownSignals: true
        function onCapturingChanged() { win.chatCapturing = chatLoader.item?.capturing ?? false; }
    }
    readonly property bool pinShown: pinActive && !fsHere && !chatCapturing
    readonly property bool shown: Shell.view === "ia" || pinShown
    onPinActiveChanged: Shell.sidePinned = pinActive
    function togglePin() {
        const on = !pinPref;
        Settings.set("sidePanelPinned", on);
        if (on) { Shell.sideHidden = false; if (Shell.view !== "ia") Shell.open("ia"); }
    }
    // × o Esc: fijado se esconde (esta sesión) o solo devuelve el teclado; si no, se cierra como siempre
    function hidePanel() {
        if (pinPref) Shell.sideHidden = true;
        if (Shell.view === "ia") Shell.close();
    }
    function releaseFocus() {
        const c = HyprClients.byRecent.find(c => c.monitor === pinMon?.id) ?? HyprClients.byRecent[0];
        if (c) HyprClients.focusWindow(c.address);
        if (Shell.view === "ia") Shell.close();
    }
    property string tab: "ia"
    readonly property bool web: tab !== "ia"
    // Web apps en modo «navegador» (Ajustes › Web apps): la pestaña abre o enfoca la web en el navegador predeterminado
    function inBrowser(k) { return k !== "ia" && WebApps.modeOf(k) === "navegador"; }
    readonly property bool browserMode: inBrowser(tab)
    function openInBrowser(k) { Quickshell.execDetached([Paths.script("hf-webapp"), "open", k]); }
    // El chat (AiChat.qml) se carga la primera vez que se usa la pestaña IA (carga diferida, lazyModules) y se descarga
    // un rato después de cerrar el panel si no hay conversación ni respuesta en curso (sin aiHistory se perdería).
    property bool chatHeld: false
    // Precarga (webappPreload, por defecto sí): la primera vez que se abre el panel se arrancan en segundo plano las
    // demás web apps de sus pestañas (nacen escondidas, regla hf-webapps), así al cambiar de pestaña ya están listas
    property bool preloaded: false
    Timer {
        id: preloadT
        interval: 1500; repeat: true
        property var queue: []
        onTriggered: {
            const k = queue.shift();
            if (k && !win.webClient(k) && !win.starting[k] && !win.inBrowser(k))
                Quickshell.execDetached([Paths.script("hf-webapp"), "start", k]);
            if (!queue.length) stop();
        }
    }
    function preload(): void {
        if (preloaded || Settings.get("webappPreload", true) === false) return;
        preloaded = true;
        preloadT.queue = webKeys.filter(k => k !== tab);
        if (preloadT.queue.length) preloadT.start();
    }
    onShownChanged: {
        Shell.sideShown = shown;
        if (shown) Qt.callLater(preload);
        if (shown) touch(tab);
        if (shown && !web) chatHeld = true;
        if (!shown) autoPip(tab);
        dock.reconcile();
    }
    onWebChanged: if (shown && !web) chatHeld = true
    Timer {
        interval: 60000
        repeat: true
        running: Shell.lazyModules && win.chatHeld && (!win.shown || win.web)
        onTriggered: {
            const c = chatLoader.item;
            if (c && (c.busy || c.capturing || c.messages.length || c.pending.length || c.winInfo)) return;
            win.chatHeld = false;
            Qt.callLater(() => gc());
        }
    }
    Connections {
        target: Shell
        function onPreloadRequested(v) { if (v === "ia") win.chatHeld = true; }   // cursor sobre el botón de la IA
    }
    readonly property var chat: chatLoader.item ?? ({ ask: () => {}, attach: () => {}, focusInput: () => {}, clear: () => {}, toggleHistory: () => {}, showHistory: false, handoff: () => {}, setWindow: () => {} })

    // ---- pestañas (diseño: SIDE)
    readonly property var builtinTones: ({ wa: "pc", yt: "ter", pin: "sc" })
    readonly property var webapps: {
        const w = Settings.get("webapps", null);
        return Array.isArray(w) && w.length ? w : [{ key: "wa", name: "WhatsApp" }, { key: "yt", name: "YouTube" }, { key: "pin", name: "Pinterest" }];
    }
    readonly property var enabledApps: {
        const a = Settings.get("sidePanelApps", null);
        return Array.isArray(a) ? a : ["ia"];   // solo el asistente; las web apps se añaden en Ajustes
    }
    readonly property var tabs: {
        const tones = ["pc", "ter", "sc"];
        const out = [];
        if (enabledApps.includes("ia")) out.push({ key: "ia", glyph: "", label: String(Settings.get("aiName", "") ?? "").trim() || "IA", tone: "p" });
        // Las web apps ya no tienen pestaña aquí (0.8.8): se abren en el navegador (Ajustes › Web apps)
        return out.length ? out : [{ key: "ia", glyph: "", label: String(Settings.get("aiName", "") ?? "").trim() || "IA", tone: "p" }];
    }
    readonly property var tabKeys: tabs.map(t => t.key)
    readonly property var webKeys: tabKeys.filter(k => k !== "ia")
    // Si la pestaña activa se desactiva en Ajustes, se pasa a la primera
    onTabKeysChanged: if (!tabKeys.includes(tab)) tab = tabKeys[0]
    function toneBg(t) { return t === "p" ? Theme.p : t === "pc" ? Theme.pc : t === "ter" ? Theme.ter : Theme.sc; }
    function toneFg(t) { return t === "p" ? Theme.pText : t === "pc" ? Theme.pcText : t === "ter" ? Theme.bg : Theme.scText; }

    // ---- márgenes como Overlay (respetan la barra)
    readonly property string barPos: Settings.get("barPos", "abajo")
    // mismos huecos que las ventanas en mosaico (Settings.winGap = gaps_out): fijado, queda alineado con ellas
    readonly property real gap: Settings.winGap
    readonly property real barEdge: Shell.focusMode ? gap : Math.max(gap, Settings.barEdge)
    readonly property real mT: barPos === "arriba" ? barEdge : gap
    readonly property real mB: barPos === "abajo" ? barEdge : gap
    readonly property bool onLeft: Settings.get("sideSide", "derecha") === "izquierda"
    readonly property real mR: (onLeft ? barPos === "izquierda" : barPos === "derecha") ? barEdge : gap     // margen del lado del panel
    // Ancho (sideWidth): "cuarto" (por defecto: una columna de un mosaico de 4), "tercio" o px
    readonly property var sideWidthPref: Settings.get("sideWidth", "cuarto")
    readonly property real baseW: sideWidthPref === "tercio" ? WebApps.third(screen?.width ?? 1920)
        : Number(sideWidthPref) > 0 ? Math.max(320, Math.min(720, Number(sideWidthPref))) : WebApps.quarter(screen?.width ?? 1920)
    // Cada web app tiene su ancho (WebApps.panelWidth: por defecto un tercio de la pantalla, una columna de un mosaico
    // de 3). Fijado, el panel mide siempre ese tercio en todas las pestañas: el reparto del mosaico no salta al cambiar
    // de pestaña y las demás ventanas se reparten los otros dos tercios.
    readonly property real panelW: baseW
    onPanelWChanged: Shell.sideW = panelW
    Component.onCompleted: { Shell.sideW = panelW; Shell.sidePinned = pinActive; Shell.sideShown = shown; }
    // Franja reservada (fijado): lo que ocupa el panel desde el borde menos lo que ya reserva la barra en ese lado
    // (Hyprland suma las zonas exclusivas; las ventanas quedan a gaps_out del panel, como del borde: sin doble hueco)
    readonly property real barSideReserve: {
        if (Settings.barPos !== (onLeft ? "izquierda" : "derecha") || Shell.focusMode) return 0;
        if (Settings.get("barAllScreens", true) === false && pinScreen !== Shell.primaryScreen) return 0;
        if (Settings.barAutoHide || Shell.barHidden) return 0;
        if (Settings.barSmartHide) {
            WinMode.overrides; WinMode.mode;
            const ws = pinMon?.activeWorkspace?.id ?? -1;
            if (WinMode.isFloat(ws) || WinMode.hasFullscreen(pinScreen?.name ?? "")) return 0;
        }
        return Settings.barThickness + Settings.barOffset;
    }
    // + lo que falta para que entre el panel y la ventana vecina haya el mismo hueco que entre dos ventanas (2 × gaps_in)
    readonly property real innerFix: Math.max(0, 2 * (Number(Settings.get("gapsIn", 1)) || 0) - Settings.gapsOutPx)
    readonly property int zoneW: Math.max(0, Math.round(mR + panelW + innerFix - barSideReserve))
    readonly property real headH: 40

    screen: pinActive ? pinScreen : Shell.screen
    visible: shown || slide.running
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-ia"
    WlrLayershell.keyboardFocus: shown && !web ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; right: !onLeft; left: onLeft }
    implicitWidth: panelW + mR + 48          // margen para la sombra; el ratón lo atraviesa (mask)
    mask: Region { item: panel }

    // ======================================================================= apertura
    property var pendingArg: null
    function handleArg(a) {
        if (typeof a === "string" && a.trim().startsWith("{")) { try { a = JSON.parse(a); } catch (e) {} }
        if ((a && typeof a === "object") || (typeof a === "string" && a.startsWith("ask:"))) {
            chatHeld = true;                                                       // crea el chat ya
            // Se carga en segundo plano: hasta que exista, chat es un sustituto que no hace nada y la pregunta se perdía
            if (!chatLoader.item) { pendingArg = a; return; }
        }
        if (a && typeof a === "object" && a.window) { tab = "ia"; chat.setWindow(a.window); }   // hf-ai summon (Super+Ctrl+A)
        if (a && typeof a === "object" && a.image) { tab = "ia"; chat.attach(String(a.image)); }
        if (a && typeof a === "object" && Array.isArray(a.images)) { tab = "ia"; a.images.forEach(p => chat.attach(String(p))); }
        if (a && typeof a === "object" && a.ask !== undefined) { tab = "ia"; chat.ask(String(a.ask)); }
        else if (typeof a === "string" && tabKeys.includes(a)) tab = a;
        else if (typeof a === "string" && a.startsWith("ask:")) { tab = "ia"; chat.ask(a.slice(4)); }
        if (tab === "yt" && webPip === "yt") leavePip();
        if (tab === "ia") Qt.callLater(() => win.chat.focusInput());
        if (web && inBrowser(tab)) {
            // Con el navegador: la pestaña pedida se abre allí; si no se pidió ninguna, el panel vuelve a la IA
            if (typeof a === "string" && tabKeys.includes(a)) { openInBrowser(a); tab = tabKeys.includes("ia") ? "ia" : tab; Qt.callLater(() => Shell.close()); return; }
            tab = tabKeys.includes("ia") ? "ia" : tab;
        }
        focusWeb = web;
        dock.reconcile();
    }
    Connections {
        target: Shell
        function onOpened(v) { if (v === "ia") win.handleArg(Shell.arg); }
        function onAiAskHidden(t) { win.askHidden(t); }
    }
    // Conversación por voz: el chat trabaja con el panel cerrado (y queda en el historial como siempre)
    function askHidden(text) {
        chatHeld = true;
        if (!chatLoader.item) { pendingArg = { ask: text, hidden: true }; return; }
        chat.ask(String(text));
    }
    function select(k) {
        if (inBrowser(k)) { openInBrowser(k); Shell.close(); return; }
        if (k === tab) return;
        autoPip(tab);
        tab = k;
        if (k === "yt" && webPip === "yt") leavePip();
        focusWeb = web;
        if (k === "ia") Qt.callLater(() => win.chat.focusInput());
        dock.reconcile();
    }

    // ======================================================================= apps web
    // Sesión de prueba anidada (HF_NESTED): carpeta propia, para no ver ni tocar las web apps de la sesión real
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hf-webapp"
        + (Quickshell.env("HF_NESTED") === "1" ? "-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "prueba") : "")
    property var detached: ({})             // clave → true si el usuario la desacopló
    property bool focusWeb: false           // dar foco a la ventana web en el próximo acople
    property string webError: ""
    property var starting: ({})
    readonly property string webPip: pipFile.text().trim()
    onWebPipChanged: dock.reconcile()
    function leavePip() { Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", webPip, "pipoff"]); setWebPip(""); }
    function setWebPip(k) { Shell.exec(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/pip"', "sh", runDir, k]); }
    FileView { id: pipFile; path: win.runDir + "/pip"; watchChanges: true; printErrors: false; onFileChanged: reload() }

    // Ventanas de hf-webapp: clase "hf-webapp.qml6", título "WhatsApp (2)" / "YouTube" / "Pinterest"
    readonly property var webNames: {
        const o = { wa: "WhatsApp", yt: "YouTube", pin: "Pinterest" };
        for (const w of webapps) if (w?.key) o[w.key] = String(w.name || w.key);
        return o;
    }
    function webClient(k) {
        return HyprClients.clients.find(c => c.class === "hf-webapp.qml6" && String(c.title).startsWith(webNames[k])) ?? null;
    }
    function unread(k) {
        const c = webClient(k);
        const m = c ? String(c.title).match(/\((\d+)\)$/) : null;
        if (m) return +m[1];
        if (k === "wa") return Notifs.list.values.filter(n => /whatsapp/i.test(n.appName ?? "")).length;
        return 0;
    }
    readonly property var current: web ? webClient(tab) : null
    // El panel se queda en la cabecera cuando la ventana web ya está acoplada
    readonly property bool docked: web && current !== null && !detached[tab]

    QtObject {
        id: dock
        function sel(c) { return 'window = "address:' + c.address + '"'; }
        function d(lua) { Shell.dispatch(lua); }
        function target() {
            const m = (win.pinActive ? win.pinMon : null) ?? HyprClients.focusedMonitor;
            if (!m) return null;
            const L = HyprClients.logical(m);
            return { ws: m.activeWorkspace?.id ?? 1, x: Math.round(win.onLeft ? L.x + win.mR : L.x + L.w - win.mR - win.panelW),
                     y: Math.round(L.y + win.mT + win.headH), w: win.panelW, h: Math.round(L.h - win.mT - win.mB - win.headH) };
        }
        function hide(c) {
            if (c.pinned) d('hl.dsp.window.pin({ action = "disable", ' + sel(c) + ' })');
            if (!String(c.workspace?.name ?? "").startsWith("special:hfweb"))
                d('hl.dsp.window.move({ workspace = "special:hfweb", follow = false, ' + sel(c) + ' })');
        }
        function show(c, t) {
            if (String(c.workspace?.name ?? "").startsWith("special") || c.workspace?.id !== t.ws && !c.pinned)
                d('hl.dsp.window.move({ workspace = ' + t.ws + ', follow = false, ' + sel(c) + ' })');
            if (!c.floating) d('hl.dsp.window.float({ action = "enable", ' + sel(c) + ' })');
            if (c.size?.[0] !== t.w || c.size?.[1] !== t.h) d('hl.dsp.window.resize({ x = ' + t.w + ', y = ' + t.h + ', ' + sel(c) + ' })');
            if (c.at?.[0] !== t.x || c.at?.[1] !== t.y) d('hl.dsp.window.move({ x = ' + t.x + ', y = ' + t.y + ', ' + sel(c) + ' })');
            if (!c.pinned) d('hl.dsp.window.pin({ action = "enable", ' + sel(c) + ' })');
            if (win.focusWeb) { win.focusWeb = false; d('hl.dsp.focus({ ' + sel(c) + ' })'); }
        }
        // Lleva cada ventana web a donde toca (idempotente: solo despacha lo que difiere)
        function reconcile() {
            const t = target();
            // Las de pestañas desactivadas también se guardan (si estaban abiertas)
            const keys = Object.keys(win.webNames).filter(k => win.webKeys.includes(k) || win.webClient(k));
            for (const k of keys) {
                const c = win.webClient(k);
                const want = win.shown && win.tab === k && win.webKeys.includes(k);
                if (!c) {
                    // sin ventana (cerrada o reiniciada): la próxima vez se le vuelve a decir si se ve
                    if (visSent[k] !== undefined) { const m = Object.assign({}, visSent); delete m[k]; visSent = m; }
                    if (want && !win.starting[k] && !win.inBrowser(k)) start(k);
                    continue;
                }
                // Ya tiene ventana: si se cierra, la próxima apertura la vuelve a lanzar (sin esperar al plazo)
                if (win.starting[k]) { const s = Object.assign({}, win.starting); delete s[k]; win.starting = s; }
                if (win.detached[k] || win.webPip === k) { vis(k, "shown"); continue; }
                if (want && t) { show(c, t); vis(k, "shown"); } else { hide(c); vis(k, "hidden"); }
            }
        }
        // Le dice a la página si se ve (repinta al instante) o está guardada (así avisa de lo que llega): solo al cambiar
        property var visSent: ({})
        function vis(k, v) {
            if (visSent[k] === v) return;
            const m = Object.assign({}, visSent); m[k] = v; visSent = m;
            win.webCmd(k, v);
        }
        function start(k) {
            const s = Object.assign({}, win.starting); s[k] = true; win.starting = s;
            win.webError = "";
            starter.command = [Paths.script("hf-webapp"), "start", k];
            starter.running = true;
            startTimeout.restart();
        }
    }
    Process {
        id: starter
        stderr: StdioCollector { id: starterErr }
        onExited: code => { if (code !== 0) { win.webError = starterErr.text.trim() || "No se pudo abrir la app web"; win.starting = ({}); } }
    }
    Timer { id: startTimeout; interval: 25000; onTriggered: { if (win.web && !win.current && win.shown) win.webError = "La app web no ha abierto ventana. ¿Está instalado qt6-webengine?"; win.starting = ({}); } }
    Connections { target: HyprClients; function onClientsChanged() { dock.reconcile(); } }
    Timer { interval: 60; running: true; onTriggered: dock.reconcile() }   // al cargar: guarda las que hubiera

    function detach() {
        const c = current;
        if (!c) return;
        const dd = Object.assign({}, detached); dd[tab] = true; detached = dd;
        const s = 'window = "address:' + c.address + '"';
        Shell.dispatch('hl.dsp.window.pin({ action = "disable", ' + s + ' })');
        Shell.dispatch('hl.dsp.window.float({ action = "disable", ' + s + ' })');
        Shell.dispatch('hl.dsp.focus({ ' + s + ' })');
        Shell.close();
    }
    function attach() {
        const dd = Object.assign({}, detached); delete dd[tab]; detached = dd;
        focusWeb = true;
        dock.reconcile();
    }
    // Atrás / Adelante en la cabecera: por defecto en todas menos las de mensajería (WhatsApp, Telegram…)
    function webConf(k) { return webapps.find(w => w?.key === k) ?? null; }
    function navOn(k) {
        const w = webConf(k);
        if (!w) return false;
        return w.nav ?? (WebApps.preset(w)?.cat !== "Mensajería");
    }
    function webCmd(k, c) { Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", k, c]); }
    // Zoom de la web app activa (cabecera): el mismo que Ctrl + / Ctrl − y Ajustes › Web apps, guardado por web
    FileView {
        id: zoomFile
        path: win.web ? Paths.home + "/.local/share/hyprfrijol/webapps/" + win.tab + "/zoom" : ""
        watchChanges: true; printErrors: false
        onFileChanged: reload()
    }
    readonly property real zoomNow: {
        const z = parseFloat(zoomFile.text());
        return z > 0 ? z : Number(webConf(tab)?.zoom ?? WebApps.panelZoom);
    }
    function setZoom(z: real): void {
        z = Math.round(Math.max(0.5, Math.min(2, z)) * 10) / 10;
        Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", tab, "zoom", String(z)]);
    }

    // Cerrar las que no se usan (campo «unload» en minutos, 0 = nunca, por defecto nunca): libera memoria. Solo las del
    // panel; nunca la que está a la vista, en PiP, desacoplada o sonando (eso lo mira hf-webapp idle-stop).
    property var lastUsed: ({})
    function touch(k) { if (k && k !== "ia") { const o = Object.assign({}, lastUsed); o[k] = Date.now(); lastUsed = o; } }
    onTabChanged: if (shown) touch(tab)
    readonly property bool anyUnload: webapps.some(w => (+w?.unload || 0) > 0)
    Timer {
        interval: 60000; repeat: true; running: win.anyUnload
        onTriggered: {
            const now = Date.now(), o = Object.assign({}, win.lastUsed);
            if (win.shown && win.web) o[win.tab] = now;
            for (const w of win.webapps) {
                const k = w?.key, mins = +w?.unload || 0;
                if (!k || mins <= 0 || WebApps.modeOf(k) !== "panel" || !win.webClient(k)) { if (k) delete o[k]; continue; }
                if ((win.shown && win.tab === k) || win.webPip === k || win.detached[k]) { o[k] = now; continue; }
                if (!o[k]) { o[k] = now; continue; }           // recién vista (precargada o abierta antes): empieza a contar
                if (now - o[k] >= mins * 60000) {
                    Quickshell.execDetached([Paths.script("hf-webapp"), "idle-stop", k]);
                    delete o[k];
                }
            }
            win.lastUsed = o;
        }
    }

    // PiP automático (pipAuto): al dejar YouTube con el vídeo sonando (cerrar el panel o cambiar de pestaña)
    readonly property bool pipOn: Settings.get("pip", true) !== false
    readonly property bool pipBtn: pipOn && Settings.get("pipButton", true) !== false
    FileView { id: audibleFile; path: win.runDir + "/" + win.tab + ".audible"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    function autoPip(k) {
        if (k !== "yt" || !pipOn || Settings.get("pipAuto", false) !== true || webPip !== "") return;
        if (audibleFile.text().trim() !== "1") return;
        const c = webClient(k);
        if (!c || detached[k]) return;
        setWebPip(k);
        Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", k, "pipon"]);
    }
    function toPip() {
        if (!current) return;
        setWebPip(tab);
        Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", tab, "pipon"]);
        if (pinPref && tabKeys.includes("ia")) tab = "ia";     // fijado: el panel sigue, con la IA
        Shell.close();
    }
    // Cerrar la ventana desacoplada hace que vuelva a abrirse acoplada la próxima vez
    onCurrentChanged: if (!current && web && detached[tab]) { const dd = Object.assign({}, detached); delete dd[tab]; detached = dd; }

    // ======================================================================= dibujo
    Item {
        id: panel
        x: win.onLeft ? win.mR : parent.width - win.mR - width
        y: win.mT
        width: win.panelW
        height: win.docked ? win.headH : parent.height - win.mT - win.mB
        Behavior on height { enabled: !win.docked; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: win.pinPref ? win.releaseFocus() : Shell.close()

        opacity: win.shown ? 1 : 0
        transform: Translate { x: win.shown ? 0 : (win.onLeft ? -24 : 24); Behavior on x { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } } }
        Behavior on opacity { NumberAnimation { id: slide; duration: win.shown ? Theme.durIn : 160; easing.type: Easing.OutCubic } }

        // Fondo: con la app web acoplada solo la cabecera (esquinas de abajo rectas, la ventana sigue debajo)
        Item {
            anchors.fill: parent
            clip: win.docked
            Glass {
                width: parent.width
                height: win.docked ? win.headH + Theme.panelRadius + 2 : parent.height
                kind: "panel"
                shadow: !win.docked
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------- cabecera
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: win.headH
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 2
                    Repeater {
                        model: win.tabs
                        delegate: Rectangle {
                            id: tb
                            required property var modelData
                            readonly property bool active: win.tab === modelData.key
                            readonly property int badge: modelData.key === "ia" ? 0 : win.unread(modelData.key)
                            implicitHeight: 28
                            implicitWidth: tbRow.implicitWidth + 18
                            radius: Theme.r(6)
                            color: active ? Theme.fill2 : "transparent"
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.light ? "#000000" : "#FFFFFF"
                                opacity: tbMouse.containsMouse && !tb.active ? 0.05 : 0
                            }
                            RowLayout {
                                id: tbRow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle {
                                    implicitWidth: 16; implicitHeight: 16; radius: Theme.r(4)
                                    color: tbIcon.status === Image.Ready ? "transparent" : win.toneBg(tb.modelData.tone)
                                    // Icono de la web app (catálogo, Papirus); si no hay, la inicial
                                    Image { id: tbIcon; anchors.fill: parent; source: tb.modelData.icon ?? ""; sourceSize: Qt.size(32, 32); visible: status === Image.Ready }
                                    Icon { visible: tb.modelData.key === "ia"; anchors.centerIn: parent; name: "ai"; size: 12; stroke: 2; color: win.toneFg(tb.modelData.tone) }
                                    Text {
                                        visible: tbIcon.status !== Image.Ready && tb.modelData.key !== "ia"
                                        anchors.centerIn: parent
                                        text: tb.modelData.glyph
                                        color: win.toneFg(tb.modelData.tone)
                                        font.family: Theme.font; font.pixelSize: Theme.px(9.5); font.weight: Font.Bold
                                    }
                                }
                                Txt {
                                    visible: tb.active
                                    text: tb.modelData.label
                                    weight: Font.DemiBold
                                }
                                Rectangle {
                                    visible: tb.badge > 0
                                    implicitHeight: 15; implicitWidth: Math.max(15, bt.implicitWidth + 8); radius: Theme.r(4)
                                    color: Theme.p
                                    Txt { id: bt; anchors.centerIn: parent; text: tb.badge; size: 10; weight: Font.DemiBold; color: Theme.pText }
                                }
                            }
                            MouseArea { id: tbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.select(tb.modelData.key) }
                        }
                    }
                    IconBtn {
                        icon: "plus"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        onClicked: { win.select("ia"); chat.clear(); }
                    }
                    IconBtn {
                        visible: win.tab === "ia"
                        icon: "clock"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        active: chat.showHistory
                        tooltip: "Conversaciones anteriores"
                        onClicked: chat.toggleHistory()
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn {
                        visible: win.web && win.current !== null && win.navOn(win.tab)
                        icon: "chevron_left"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: "Atrás (Alt + ←)"
                        onClicked: win.webCmd(win.tab, "back")
                    }
                    IconBtn {
                        visible: win.web && win.current !== null && win.navOn(win.tab)
                        icon: "chevron_right"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: "Adelante (Alt + →)"
                        onClicked: win.webCmd(win.tab, "forward")
                    }
                    // Zoom: − 90 % +  (clic en el número: 100 %; rueda encima: ±10 %)
                    Rectangle {
                        visible: win.web && win.current !== null
                        implicitWidth: zRow.implicitWidth + 4; implicitHeight: 24
                        radius: Theme.ctl(24); color: Theme.fill2
                        Row {
                            id: zRow
                            anchors.centerIn: parent
                            IconBtn { icon: "minus"; iconSize: 11; implicitWidth: 22; implicitHeight: 22; tooltip: "Reducir (Ctrl −)"; onClicked: win.setZoom(win.zoomNow - 0.1) }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; horizontalAlignment: Text.AlignHCenter
                                text: Math.round(win.zoomNow * 100) + "%"; size: 10.5; tabular: true; muted: true
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.setZoom(1)
                                            onWheel: w => win.setZoom(win.zoomNow + (w.angleDelta.y > 0 ? 0.1 : -0.1)) }
                            }
                            IconBtn { icon: "plus"; iconSize: 11; implicitWidth: 22; implicitHeight: 22; tooltip: "Ampliar (Ctrl +)"; onClicked: win.setZoom(win.zoomNow + 0.1) }
                        }
                    }
                    IconBtn {
                        visible: win.tab === "yt" && win.docked && win.pipBtn
                        icon: "pip"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        onClicked: win.toPip()
                    }
                    IconBtn {
                        visible: win.web && win.current !== null
                        icon: "globe"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: "Abrir en el navegador"
                        onClicked: { Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", win.tab, "external"]); Shell.close(); }
                    }
                    IconBtn {
                        visible: win.web && win.current !== null
                        icon: win.detached[win.tab] ? "maximize" : "detach"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        onClicked: win.detached[win.tab] ? win.attach() : win.detach()
                    }
                    IconBtn {
                        visible: !win.web
                        icon: "detach"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        onClicked: chat.handoff()
                    }
                    IconBtn {
                        icon: "pin"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        active: win.pinPref
                        tooltip: win.pinPref ? "Desfijar: volver a flotar encima" : "Fijar: parte del mosaico"
                        onClicked: win.togglePin()
                    }
                    IconBtn {
                        icon: "x"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: win.pinPref ? "Esconder (sigue fijado; vuelve con Super + A)" : ""
                        onClicked: win.hidePanel()
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Theme.ov
                    opacity: win.docked ? 0 : 1
                }
            }

            // ---------------------------------------------------- contenido
            // (Loader con URL: los tipos hermanos no se resuelven cuando el módulo se carga por URL en desarrollo)
            Loader {
                id: chatLoader
                visible: !win.web
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: win.chatHeld || !Shell.lazyModules
                asynchronous: !win.shown         // precargado (cursor encima): sin bloquear; al abrir, al momento
                source: Qt.resolvedUrl("AiChat.qml")
                onLoaded: {
                    item.active = Qt.binding(() => win.shown && !win.web);
                    if (win.pendingArg !== null) { const a = win.pendingArg; win.pendingArg = null; a.hidden ? item.ask(String(a.ask)) : win.handleArg(a); }
                }
            }
            // Mientras la app web arranca (o si falla / está desacoplada)
            Item {
                visible: win.web && !win.docked
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property var info: win.tabs.find(t => t.key === win.tab) ?? win.tabs[0]
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 10
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 44; implicitHeight: 44; radius: Theme.r(10)
                        color: bigIcon.status === Image.Ready ? "transparent" : win.toneBg(parent.parent.info.tone)
                        Image { id: bigIcon; anchors.fill: parent; source: parent.parent.parent.info.icon ?? ""; sourceSize: Qt.size(88, 88); visible: status === Image.Ready }
                        Icon { visible: parent.parent.parent.info.key === "ia"; anchors.centerIn: parent; name: "ai"; size: 24; color: win.toneFg(parent.parent.parent.info.tone) }
                        Text {
                            visible: bigIcon.status !== Image.Ready && parent.parent.parent.info.key !== "ia"
                            anchors.centerIn: parent
                            text: parent.parent.parent.info.glyph
                            color: win.toneFg(parent.parent.parent.info.tone)
                            font.family: Theme.font; font.pixelSize: Theme.px(20); font.weight: Font.Bold
                        }
                    }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.browserMode ? parent.parent.info.label + " se abre en tu navegador"
                            : win.webError !== "" ? "No se pudo abrir " + parent.parent.info.label
                            : win.detached[win.tab] ? parent.parent.info.label + " está en una ventana aparte"
                            : "Abriendo " + parent.parent.info.label + "…"
                        size: 14; weight: Font.DemiBold
                    }
                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap; elide: Text.ElideNone
                        muted: true; size: 12
                        text: win.browserMode ? "Esta web app está configurada para abrirse en tu navegador (Ajustes › Web apps)."
                            : win.webError !== "" ? win.webError
                            : win.detached[win.tab] ? "Puedes volver a acoplarla al panel."
                            : "La sesión se guarda en este equipo; la primera vez tendrás que iniciarla."
                    }
                    Btn {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.browserMode || win.webError !== "" || !!win.detached[win.tab]
                        kind: "primary"; h: 28
                        text: win.browserMode ? "Abrir en el navegador" : win.webError !== "" ? "Reintentar" : "Acoplar al panel"
                        onClicked: win.browserMode ? (win.openInBrowser(win.tab), Shell.close())
                                 : win.webError !== "" ? (win.webError = "", dock.start(win.tab)) : win.attach()
                    }
                }
            }
        }
    }

    OpenProbe { name: "ia"; shown: win.shown }

    // Reserva de la franja del panel fijado: capa invisible y sin ratón, encima de la barra en el orden de Hyprland
    // (Overlay), para que la barra del mismo lado no se desplace
    PanelWindow {
        id: zone
        screen: win.pinScreen
        visible: win.pinActive && win.zoneW > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-ia-zone"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: win.onLeft; right: !win.onLeft }
        implicitWidth: 1
        exclusiveZone: win.zoneW
        mask: Region {}
    }
    // La ventana web acoplada no se puede arrastrar fuera: mover una flotante no avisa por IPC, así que se mira cada poco
    Timer {
        interval: 1500; repeat: true
        running: win.pinShown && win.docked
        onTriggered: HyprClients.refreshNow()
    }

    IpcHandler {
        target: "sidepanel"
        function ask(text: string): void { Shell.open("ia", { ask: text }); }
        // Pregunta con una imagen adjunta (Super + Mayús + A: zona de la pantalla → IA)
        function askImage(text: string, image: string): void { Shell.open("ia", { ask: text, image: image }); }
        function tab(key: string): void { Shell.open("ia", key); }
        function pipBack(): void { Shell.open("ia", "yt"); }
        function pip(): void { if (win.shown && win.tab === "yt") win.toPip(); }
    }
}
