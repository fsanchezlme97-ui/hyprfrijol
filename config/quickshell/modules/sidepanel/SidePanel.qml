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
// demás se acoplan como arriba. Cabecera: abrir la página actual en el navegador, desacoplar, cerrar.
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
    readonly property bool shown: Shell.view === "ia"
    property string tab: "ia"
    readonly property bool web: tab !== "ia"
    // Web apps en modo «navegador» (Ajustes › Web apps): la pestaña abre o enfoca la web en el navegador predeterminado
    function inBrowser(k) { return k !== "ia" && WebApps.modeOf(k) === "navegador"; }
    readonly property bool browserMode: inBrowser(tab)
    function openInBrowser(k) { Quickshell.execDetached([Paths.script("hf-webapp"), "open", k]); }
    readonly property var chat: chatLoader.item ?? ({ ask: () => {}, attach: () => {}, focusInput: () => {}, clear: () => {}, handoff: () => {}, setWindow: () => {} })

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
        if (enabledApps.includes("ia")) out.push({ key: "ia", glyph: "", label: "IA", tone: "p" });
        webapps.forEach((w, i) => {
            if (!w?.key || !enabledApps.includes(w.key)) return;
            const n = String(w.name || w.key);
            out.push({ key: w.key, glyph: n.charAt(0).toUpperCase(), label: n, tone: builtinTones[w.key] ?? tones[i % 3], icon: WebApps.iconOf(w) });
        });
        return out.length ? out : [{ key: "ia", glyph: "", label: "IA", tone: "p" }];
    }
    readonly property var tabKeys: tabs.map(t => t.key)
    readonly property var webKeys: tabKeys.filter(k => k !== "ia")
    // Si la pestaña activa se desactiva en Ajustes, se pasa a la primera
    onTabKeysChanged: if (!tabKeys.includes(tab)) tab = tabKeys[0]
    function toneBg(t) { return t === "p" ? Theme.p : t === "pc" ? Theme.pc : t === "ter" ? Theme.ter : Theme.sc; }
    function toneFg(t) { return t === "p" ? Theme.pText : t === "pc" ? Theme.pcText : t === "ter" ? Theme.bg : Theme.scText; }

    // ---- márgenes como Overlay (respetan la barra)
    readonly property string barPos: Settings.get("barPos", "abajo")
    readonly property real barEdge: Shell.focusMode ? 4 : Math.max(4, Settings.barEdge)
    readonly property real mT: barPos === "arriba" ? barEdge : 4
    readonly property real mB: barPos === "abajo" ? barEdge : 4
    readonly property bool onLeft: Settings.get("sideSide", "derecha") === "izquierda"
    readonly property real mR: (onLeft ? barPos === "izquierda" : barPos === "derecha") ? barEdge : 4     // margen del lado del panel
    readonly property real baseW: Math.max(320, Math.min(720, Number(Settings.get("sideWidth", 400)) || 400))
    // Cada web app tiene su ancho (WebApps.panelWidth): WhatsApp de escritorio no cabe en 400 px sin encogerse
    readonly property real panelW: web ? WebApps.panelWidth(tab, baseW, screen?.width ?? 1920) : baseW
    onPanelWChanged: Shell.sideW = panelW
    Component.onCompleted: Shell.sideW = panelW
    readonly property real headH: 40

    screen: Shell.screen
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
    function handleArg(a) {
        if (typeof a === "string" && a.trim().startsWith("{")) { try { a = JSON.parse(a); } catch (e) {} }
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
        function onViewChanged() { if (!win.shown) { win.autoPip(win.tab); dock.reconcile(); } }
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
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hf-webapp"
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
            const m = HyprClients.focusedMonitor;
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
                    if (want && !win.starting[k] && !win.inBrowser(k)) start(k);
                    continue;
                }
                // Ya tiene ventana: si se cierra, la próxima apertura la vuelve a lanzar (sin esperar al plazo)
                if (win.starting[k]) { const s = Object.assign({}, win.starting); delete s[k]; win.starting = s; }
                if (win.detached[k] || win.webPip === k) continue;
                if (want && t) show(c, t); else hide(c);
            }
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
        Keys.onEscapePressed: Shell.close()

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
                    Item { Layout.fillWidth: true }
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
                    IconBtn { icon: "x"; iconSize: 14; implicitWidth: 26; implicitHeight: 26; onClicked: Shell.close() }
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
                source: Qt.resolvedUrl("AiChat.qml")
                onLoaded: item.active = Qt.binding(() => win.shown && !win.web)
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
