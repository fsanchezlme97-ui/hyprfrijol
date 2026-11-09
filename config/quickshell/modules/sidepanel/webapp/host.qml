// Anfitrión de las web apps integradas (WhatsApp, YouTube… del ajuste "webapps").
// QtWebEngine no puede vivir dentro de Quickshell, así que cada app es un proceso `qml6` aparte
// (lo lanza scripts/hf-webapp con --config=<JSON>: los ajustes de la app sobre los del catálogo).
//   --mode=panel    clase (app_id) "hf-webapp.qml6", título "WhatsApp (2)": el panel lateral la acopla bajo su
//                   pestaña y lee de ahí los no leídos
//   --mode=ventana  clase "hf-webwin-<clave>.qml6": ventana normal (su .desktop lleva ese StartupWMClass → icono)
// Se adapta al ancho:
//   layout "movil"       en anchos estrechos (< 720 px) pide la web para móvil (agente de usuario de Android y
//                        mobileHost, p. ej. m.youtube.com); al ensancharla vuelve a la de escritorio
//   minWidth             ancho CSS que necesita la web de escritorio: el zoom nunca deja menos (si la ventana es más
//                        estrecha se reduce) → sin barra horizontal (WhatsApp Web fija min-width: 748px por debajo)
//   zoom                 factor del usuario por web: Ctrl + / Ctrl − / Ctrl 0 en la ventana o Ajustes › Web apps; se
//                        guarda en <perfil>/zoom (lo escribe también `hf-webapp cmd <clave> zoom <f>`)
// Tema: prefers-color-scheme lo pone hf-webapp (Chromium) según el tema del escritorio; aquí se pinta el fondo con el
// color del tema (sin destello blanco) y se inyecta CSS (barras de desplazamiento finas con los colores del tema y el
// CSS propio de la app, $XDG_RUNTIME_DIR/hf-webapp/<clave>.css). Se relee el tema cada pocos segundos (theme.json).
// Enlaces: los de otros dominios se abren en el navegador predeterminado; los de inicio de sesión (Google, Apple,
// Microsoft…) en una ventanita propia para no romper el acceso.
// Nombre de la aplicación = nombre de la web app → su reproductor MPRIS se llama «YouTube» (no «Qml Runtime»).
// Órdenes: el panel escribe "<n> <orden> [arg]" en $XDG_RUNTIME_DIR/hf-webapp/<clave>.cmd
//   toggle · pause · pipon/pipoff (solo el vídeo) · back · forward · reload · home · zoom <f> · external · url <dirección>
import QtQuick
import QtQuick.Window
import QtCore
import QtWebEngine

Window {
    id: win
    function arg(n) { return Qt.application.arguments.find(a => a.startsWith("--" + n + "="))?.slice(n.length + 3) ?? ""; }
    readonly property string key: arg("key") || "wa"
    readonly property string runtime: arg("runtime")
    readonly property string store: arg("store")
    readonly property string stateDir: arg("state")
    readonly property string mode: arg("mode") || "panel"
    // Compatibilidad: sin --config (versión anterior de hf-webapp) se usan --url/--name
    readonly property var cfg: {
        try { const c = JSON.parse(arg("config")); if (c && c.url) return c; } catch (e) {}
        return { url: arg("url") || "https://web.whatsapp.com/", name: arg("name") || key, layout: "escritorio", minWidth: key === "wa" ? 760 : 0 };
    }
    readonly property string appName: String(cfg.name || key)
    readonly property string homeUrl: /^[a-z]+:/i.test(cfg.url) ? cfg.url : "https://" + cfg.url

    // ---- tamaño y diseño
    width: mode === "ventana" ? 1180 : 398
    height: mode === "ventana" ? 780 : 760
    readonly property bool compact: width < 720
    readonly property string layout: String(cfg.layout || "escritorio")
    readonly property bool mobile: layout === "movil" && compact
    readonly property real minW: mobile ? 0 : Number(cfg.minWidth || 0)
    // en el panel lateral se parte del 90 % (la columna es estrecha); en ventana propia, del 100 %
    property real userZoom: Math.max(0.3, Math.min(3, Number(cfg.zoom || (mode === "panel" ? 0.9 : 1))))
    // Zoom efectivo: el del usuario, salvo que deje la página más estrecha que minWidth (px CSS = ancho / zoom)
    readonly property real effZoom: Math.max(0.25, minW > 0 ? Math.min(userZoom, width / minW) : userZoom)
    // Zoom por web guardado en el perfil (sobrevive a cerrar la app y manda sobre el de Ajustes)
    readonly property string zoomFile: store ? "file://" + store + "/zoom" : ""
    function loadZoom() {
        if (!zoomFile) return;
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            const z = parseFloat(x.responseText);
            if (z > 0) userZoom = Math.max(0.3, Math.min(3, z));
        };
        x.open("GET", zoomFile);
        x.send();
    }
    function setZoom(z) {
        userZoom = Math.round(Math.max(0.3, Math.min(3, z)) * 100) / 100;
        if (!zoomFile) return;
        const x = new XMLHttpRequest();
        x.open("PUT", zoomFile);
        x.send(String(userZoom));
    }
    readonly property string uaDesktop: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
    readonly property string uaMobile: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"

    visible: false
    // app_id de Wayland = "<dominio>.qml6" (Qt lo forma con el dominio + el ejecutable) → reglas de ventana
    Component.onCompleted: {
        Qt.application.domain = mode === "ventana" ? "hf-webwin-" + key : "hf-webapp";
        Qt.application.name = appName;          // identidad del reproductor MPRIS (Chromium la toma al arrancar)
        prof = profComp.createObject(win);     // después del nombre: Chromium arranca con el perfil
        loadTheme();
        loadZoom();
        visible = true;
        viewLoader.active = true;
    }
    // "(3) WhatsApp" → el panel enseña 3 sin leer en la pestaña
    readonly property int unread: viewLoader.item ? +((viewLoader.item.title.match(/^\((\d+)\)/) ?? [0, 0])[1]) : 0
    title: appName + (unread > 0 ? " (" + unread + ")" : "")

    // ---- tema del escritorio (theme.json de hf-apply)
    property var theme: ({ bg: "#121314", t: "#E4E6E8", o: "#8A9097", p: "#A9C1D9", light: false })
    color: theme.bg
    function loadTheme() {
        if (!stateDir) return;
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE || !x.responseText) return;
            try {
                const j = JSON.parse(x.responseText), c = j.c ?? {};
                const t = { bg: c.bg ?? theme.bg, t: c.t ?? theme.t, o: c.o ?? theme.o, p: c.p ?? theme.p, light: !!j.light };
                if (JSON.stringify(t) !== JSON.stringify(theme)) { theme = t; injectCss(); }
            } catch (e) {}
        };
        x.open("GET", "file://" + stateDir + "/theme.json");
        x.send();
    }
    property string userCss: ""
    function loadUserCss() {
        if (!runtime) return;
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) { const s = x.responseText ?? ""; if (s !== userCss) { userCss = s; injectCss(); } } };
        x.open("GET", "file://" + runtime + "/" + key + ".css");
        x.send();
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { win.loadTheme(); win.loadUserCss(); } }
    readonly property string css: "::-webkit-scrollbar{width:9px;height:9px;background:transparent}"
        + "::-webkit-scrollbar-thumb{background-color:" + theme.o + "66;border-radius:9px;border:2px solid transparent;background-clip:content-box}"
        + "::-webkit-scrollbar-thumb:hover{background-color:" + theme.o + "aa}"
        + "::-webkit-scrollbar-corner,::-webkit-scrollbar-track{background:transparent}"
        + "\n" + userCss
    function injectCss() {
        viewLoader.item?.runJavaScript("(function(c){var s=document.getElementById('hf-style');if(!s){s=document.createElement('style');s.id='hf-style';"
            + "(document.head||document.documentElement).appendChild(s);}if(s.textContent!==c)s.textContent=c;})(" + JSON.stringify(css) + ")");
    }

    // ---- enlaces: dentro de la app solo su dominio (y los que pida el catálogo); el resto, al navegador
    function baseHost(u) {
        const h = String(u).replace(/^[a-z]+:\/\//i, "").replace(/[\/?#:].*$/, "").toLowerCase();
        const p = h.split(".");
        // dominio registrable aproximado: dos últimas partes (tres en co.uk, com.br…)
        return p.length > 2 && /^(co|com|org|net|gov|edu|ac)$/.test(p[p.length - 2]) ? p.slice(-3).join(".") : p.slice(-2).join(".");
    }
    readonly property var authHosts: ["accounts.google.com", "accounts.youtube.com", "appleid.apple.com", "login.microsoftonline.com",
        "login.live.com", "www.facebook.com", "github.com", "discord.com", "auth.openai.com"]
    readonly property var allowed: [baseHost(homeUrl)].concat((cfg.allow ?? []).map(d => baseHost(d)))
    function inApp(u) {
        const s = String(u);
        if (!/^https?:/i.test(s)) return true;          // blob:, data:, about:…
        return allowed.includes(baseHost(s));
    }
    function isAuth(u) { return authHosts.includes(String(u).replace(/^[a-z]+:\/\//i, "").replace(/[\/?#:].*$/, "").toLowerCase()); }
    function external(u) { Qt.openUrlExternally(u); }

    property WebEngineProfile prof: null
    Component {
        id: profComp
        WebEngineProfile {
            storageName: "hf-" + win.key
            persistentStoragePath: win.store
            cachePath: win.store + "/cache"
            offTheRecord: false
            httpCacheType: WebEngineProfile.DiskHttpCache
            persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
            // WhatsApp Web exige un navegador «normal»; las de diseño móvil piden la web de Android cuando es estrecha
            httpUserAgent: win.mobile ? win.uaMobile : win.uaDesktop
            // Las notificaciones web salen por stderr y hf-webapp las pasa a notify-send
            onPresentNotification: n => { console.warn("HLNOTIFY\t" + n.title + "\t" + n.message.replace(/[\t\n]/g, " ")); n.show(); }
            // Descargas (WhatsApp, Drive…): a la carpeta de descargas
            onDownloadRequested: d => {
                d.downloadDirectory = String(StandardPaths.writableLocation(StandardPaths.DownloadLocation)).replace(/^file:\/\//, "");
                d.accept();
            }
            onDownloadFinished: d => console.warn("HLNOTIFY\tDescarga completada\t" + d.downloadFileName)
        }
    }

    // El agente de usuario cambia al cruzar el ancho móvil/escritorio: se recarga (cambiando de host si hace falta)
    property bool loadedOnce: false
    onMobileChanged: if (loadedOnce) uaSwitch.restart()
    Timer {
        id: uaSwitch
        interval: 700
        onTriggered: {
            const v = viewLoader.item;
            if (!v) return;
            let u = String(v.url);
            const mh = win.cfg.mobileHost, dh = win.cfg.desktopHost;
            if (mh && dh) u = win.mobile ? u.replace("//" + dh, "//" + mh) : u.replace("//" + mh, "//" + dh);
            if (u !== String(v.url)) v.url = u; else v.reload();
        }
    }

    Loader {
        id: viewLoader
        anchors.fill: parent
        active: false
        sourceComponent: WebEngineView {
            id: view
            profile: prof
            backgroundColor: win.theme.bg
            url: {
                const mh = win.cfg.mobileHost, dh = win.cfg.desktopHost;
                return win.mobile && mh && dh ? win.homeUrl.replace("//" + dh, "//" + mh) : win.homeUrl;
            }
            zoomFactor: win.effZoom
            settings.playbackRequiresUserGesture: false
            settings.fullScreenSupportEnabled: true
            settings.showScrollBars: true
            settings.focusOnNavigationEnabled: true
            onPermissionRequested: p => {
                const t = p.permissionType;
                if (t === WebEnginePermission.PermissionType.Notifications) { if (win.cfg.notify === false) p.deny(); else p.grant(); }
                else if (t === WebEnginePermission.PermissionType.ClipboardReadWrite) p.grant();
                else p.deny();
            }
            onNavigationRequested: req => {
                if (req.isMainFrame && req.navigationType === WebEngineNavigationRequest.LinkClickedNavigation
                    && !win.inApp(req.url) && !win.isAuth(req.url)) {
                    req.reject();
                    win.external(req.url);
                }
            }
            onNewWindowRequested: req => {
                // Ventanas de inicio de sesión (OAuth): dentro, en una ventanita; el resto, al navegador
                if (win.isAuth(req.requestedUrl) || req.destination === WebEngineNewWindowRequest.InNewDialog && win.inApp(req.requestedUrl)) {
                    const w = popupComp.createObject(win);
                    req.openIn(w.view);
                } else win.external(req.requestedUrl);
            }
            onFullScreenRequested: req => req.accept()
            onLoadingChanged: r => { if (r.status === WebEngineView.LoadSucceededStatus) { win.loadedOnce = true; win.injectCss(); } }
            // Sonido (vídeo reproduciéndose): hf-webapp lo deja en $XDG_RUNTIME_DIR/hf-webapp/<clave>.audible (PiP automático)
            onRecentlyAudibleChanged: console.warn("HLAUDIBLE\t" + (recentlyAudible ? 1 : 0) + "\t")
        }
    }

    // Zoom con el teclado: Ctrl + / Ctrl − / Ctrl 0
    Shortcut { sequences: [StandardKey.ZoomIn, "Ctrl+="]; onActivated: win.setZoom(win.userZoom + 0.1) }
    Shortcut { sequences: [StandardKey.ZoomOut]; onActivated: win.setZoom(win.userZoom - 0.1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: win.setZoom(1) }
    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; onActivated: viewLoader.item?.goBack() }
    Shortcut { sequences: ["Alt+Right", StandardKey.Forward]; onActivated: viewLoader.item?.goForward() }
    Shortcut { sequences: ["Ctrl+R", "F5"]; onActivated: viewLoader.item?.reload() }

    Component {
        id: popupComp
        Window {
            id: pw
            property alias view: pv
            width: 520; height: 680; visible: true
            title: win.appName + " · " + (pv.title || "Iniciar sesión")
            color: win.theme.bg
            WebEngineView {
                id: pv
                anchors.fill: parent
                profile: prof
                backgroundColor: win.theme.bg
                onWindowCloseRequested: pw.destroy()
                onNewWindowRequested: req => win.external(req.requestedUrl)
            }
            onClosing: pw.destroy()
        }
    }

    // Órdenes del panel
    property int lastSeq: -1
    function command(line) {
        const m = line.trim().match(/^(\d+)\s+(\S+)\s*(.*)$/);
        if (!m || +m[1] === lastSeq) return;
        const first = lastSeq < 0;
        lastSeq = +m[1];
        if (first) return;                      // la orden vieja de un arranque anterior no se repite
        const view = viewLoader.item;
        if (!view) return;
        const cmd = m[2], arg = m[3];
        if (cmd === "toggle") view.runJavaScript("(()=>{const v=document.querySelector('video');if(v){v.paused?v.play():v.pause();}})()");
        else if (cmd === "pause") view.runJavaScript("document.querySelectorAll('video').forEach(v=>v.pause())");
        // PiP: solo el vídeo, ocupando toda la ventana (YouTube de escritorio y móvil)
        else if (cmd === "pipon") view.runJavaScript("(()=>{const v=document.querySelector('video');if(!v)return;"
            + "v.dataset.hlStyle=v.getAttribute('style')||'';"
            + "v.setAttribute('style','position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;"
            + "z-index:2147483647!important;background:#000!important;object-fit:contain!important;left:0!important;top:0!important');"
            + "document.documentElement.style.overflow='hidden';"
            + "const st=document.createElement('style');st.id='hf-pip';st.textContent='#masthead-container,ytd-masthead,.ytp-chrome-top,"
            + ".ytp-chrome-bottom,.ytp-gradient-top,.ytp-gradient-bottom,ytm-mobile-topbar-renderer,#header-bar,ytm-pivot-bar-renderer,"
            + ".player-controls-background,.player-controls-content{display:none!important}';document.head.appendChild(st);})()");
        else if (cmd === "pipoff") view.runJavaScript("(()=>{const v=document.querySelector('video[data-hl-style]');"
            + "if(v){v.setAttribute('style',v.dataset.hlStyle);delete v.dataset.hlStyle;}document.documentElement.style.overflow='';document.getElementById('hf-pip')?.remove();})()");
        else if (cmd === "back") view.goBack();
        else if (cmd === "forward") view.goForward();
        else if (cmd === "reload") view.reload();
        else if (cmd === "home") view.url = win.homeUrl;
        else if (cmd === "zoom" && +arg > 0) win.setZoom(+arg);
        else if (cmd === "external") win.external(view.url);
        else if (cmd === "url" && arg) view.url = arg;
    }
    Timer {
        interval: 400; running: win.runtime !== ""; repeat: true
        onTriggered: {
            const x = new XMLHttpRequest();
            x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE && x.responseText) win.command(x.responseText); };
            x.open("GET", "file://" + win.runtime + "/" + win.key + ".cmd");
            x.send();
        }
    }
}
