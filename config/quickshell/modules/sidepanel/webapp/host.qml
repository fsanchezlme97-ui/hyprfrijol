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
//   oneColumn            (WhatsApp) en anchos estrechos, una sola columna como en el móvil: la lista de chats o el
//                        chat abierto, con «←» para volver; sin el mínimo de 748 px (no hace falta encoger el zoom).
//                        Escribe en $XDG_RUNTIME_DIR/hf-webapp/<clave>.layout si encontró la estructura (sin contenido)
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
//   shown · hidden: el panel la trae a la vista o la guarda en su espacio especial. La página no se entera sola
//   (Chromium la cree siempre visible): con «hidden» se le dice que está oculta → WhatsApp, Gmail… avisan de lo
//   que llega; con «shown» se fuerza a repintar (YouTube se quedaba en negro hasta mover el ratón encima).
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
    readonly property real minW: mobile || cfg.oneColumn === true ? 0 : Number(cfg.minWidth || 0)
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
            onLoadingChanged: r => { if (r.status === WebEngineView.LoadSucceededStatus) { win.loadedOnce = true; win.injectCss(); if (win.pageHidden) win.applyVisibility(); if (win.cfg.oneColumn === true) { oneColRetry.n = 0; oneColRetry.restart(); } } }
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

    // ---- WhatsApp a una columna (cfg.oneColumn). Sin clases fijas (WhatsApp las cambia): parte de #side (lista de chats),
    // sube hasta el elemento cuyo hermano a la derecha es la zona del chat y marca los dos paneles con data-hf-pane.
    readonly property string oneColJs: "(function(){if(window.__hfOneCol){window.__hfOneCol();return JSON.stringify(window.__hfOneColState||{})}"
        + "var st=document.createElement('style');st.id='hf-onecol';st.textContent="
        + "'html[data-hf-narrow] [data-hf-chain]{min-width:0!important}"
        + "html[data-hf-narrow] [data-hf-pane]{flex:1 1 auto!important;max-width:none!important;width:auto!important;min-width:0!important}"
        // Sin chat abierto, solo la lista; con uno abierto, la lista arriba y el chat abajo, mitad y mitad (el chat se
        // coloca encima de la mitad inferior: el contenedor común también lleva la barra de iconos de la izquierda)
        + "html[data-hf-narrow]:not([data-hf-chat]) [data-hf-pane=main]{display:none!important}"
        + "html[data-hf-narrow][data-hf-chat] [data-hf-split]{position:relative!important}"
        + "html[data-hf-narrow][data-hf-chat] [data-hf-pane=side]{height:50%!important;max-height:50%!important;align-self:flex-start!important}"
        + "html[data-hf-narrow][data-hf-chat] [data-hf-pane=main]{position:absolute!important;left:var(--hf-railw,0px)!important;right:0!important;"
        + "bottom:0!important;top:auto!important;height:50%!important;max-height:50%!important;border-top:1px solid rgba(127,127,127,.28)!important;z-index:1}"
        // Los «cajones» (perfil, nuevo chat, info del contacto…) llevan un borde de 1 px que en una columna quedaba
        // en medio como una línea vertical. Solo se quita el borde: tocar su flex encogía el chat a la mitad.
        + "html[data-hf-narrow] [data-testid^=drawer-]{border-left:0!important;border-right:0!important}"
        + "#hf-back{display:none;flex:none;width:36px;height:36px;margin:0 2px 0 -6px;border:0;border-radius:50%;background:transparent;"
        + "color:inherit;font-size:20px;line-height:36px;cursor:pointer;align-self:center}#hf-back:hover{background:rgba(127,127,127,.18)}"
        + "html[data-hf-narrow] #hf-back{display:block}';(document.head||document.documentElement).appendChild(st);"
        + "var P=null,t=0;function find(){var s=document.getElementById('side');if(!s)return null;var n=s;"
        + "while(n.parentElement&&n.parentElement!==document.body){var p=n.parentElement,r=n.getBoundingClientRect();"
        + "var m=[].slice.call(p.children).filter(function(c){return c!==n&&c.getBoundingClientRect().left>=r.right-4&&c.getBoundingClientRect().width>120})[0];"
        + "if(m){var ch=[],a=p;while(a&&a!==document.body){ch.push(a);a=a.parentElement}return{side:n,main:m,chain:ch}}n=p}return null}"
        + "function apply(){var h=document.documentElement,narrow=window.innerWidth<900;h.toggleAttribute('data-hf-narrow',narrow);"
        + "if(!P||!P.side.isConnected||!P.main.isConnected){if(P){P.side.removeAttribute('data-hf-pane');P.main.removeAttribute('data-hf-pane')}"
        + "h.removeAttribute('data-hf-narrow');P=find();h.toggleAttribute('data-hf-narrow',narrow);"
        + "if(P){P.side.setAttribute('data-hf-pane','side');P.main.setAttribute('data-hf-pane','main');P.chain.forEach(function(e){e.setAttribute('data-hf-chain','')});"
        + "P.side.parentElement.setAttribute('data-hf-split','')}}"
        + "if(P){var sp0=P.side.parentElement;sp0.style.setProperty('--hf-railw',Math.max(0,Math.round(P.side.getBoundingClientRect().left-sp0.getBoundingClientRect().left))+'px')}"
        + "var chat=!!document.getElementById('main')||!!window.__hfForceChat;h.toggleAttribute('data-hf-chat',chat);"
        + "var hd=document.querySelector('#main header');if(hd&&!document.getElementById('hf-back')){var b=document.createElement('button');b.id='hf-back';b.title='Cerrar el chat';b.textContent='\\u2715';"
        + "b.onclick=function(e){e.stopPropagation();var o={key:'Escape',code:'Escape',keyCode:27,which:27,bubbles:true};"
        + "(document.activeElement||document.body).dispatchEvent(new KeyboardEvent('keydown',o));document.body.dispatchEvent(new KeyboardEvent('keydown',o))};hd.insertBefore(b,hd.firstChild)}"
        + "var sp=P&&P.side.parentElement;window.__hfOneColState={found:!!P,narrow:narrow,chat:chat,width:window.innerWidth,"
        + "split:sp?{disp:getComputedStyle(sp).display,grid:getComputedStyle(sp).gridTemplateColumns.slice(0,60),kids:[].map.call(sp.children,function(c){var r=c.getBoundingClientRect();"
        + "return (c.id||c.getAttribute('data-testid')||c.getAttribute('data-hf-pane')||c.tagName)+':'+getComputedStyle(c).position+':'+Math.round(r.left)+'+'+Math.round(r.width)+'x'+Math.round(r.height)})}:null}}"
        + "window.__hfOneCol=apply;new MutationObserver(function(){clearTimeout(t);t=setTimeout(apply,150)}).observe(document.body,{childList:true,subtree:true});"
        + "window.addEventListener('resize',function(){clearTimeout(t);t=setTimeout(apply,150)});apply();return JSON.stringify(window.__hfOneColState)})()"
    function oneCol() {
        if (cfg.oneColumn !== true) return;
        viewLoader.item?.runJavaScript(oneColJs, r => {
            if (!runtime || !r) return;
            const x = new XMLHttpRequest();
            x.open("PUT", "file://" + runtime + "/" + key + ".layout");
            x.send(String(r));
        });
    }
    // WhatsApp monta su interfaz un rato después de cargar: se intenta varias veces hasta encontrarla
    Timer { id: oneColRetry; interval: 2500; repeat: true; property int n: 0; onTriggered: { win.oneCol(); if (++n >= 12) stop(); } }

    // ---- visible / oculta (órdenes shown / hidden del panel)
    property bool pageHidden: false
    function applyVisibility() {
        viewLoader.item?.runJavaScript("(function(h){var V=window.__hfVis;if(!V){V=window.__hfVis={h:false};"
            + "Object.defineProperty(document,'hidden',{configurable:true,get:function(){return V.h}});"
            + "Object.defineProperty(document,'visibilityState',{configurable:true,get:function(){return V.h?'hidden':'visible'}});"
            + "var hf=Document.prototype.hasFocus;document.hasFocus=function(){return !V.h&&hf.call(document)};}"
            + "if(V.h!==h){V.h=h;document.dispatchEvent(new Event('visibilitychange'));window.dispatchEvent(new Event(h?'blur':'focus'));}"
            + "})(" + (pageHidden ? "true" : "false") + ")");
    }
    // Repintado al volver a la vista: unos cuantos fotogramas pedidos a Qt y un cambio invisible en la página para
    // que Chromium componga uno nuevo (antes hacía falta mover el ratón por encima)
    Timer {
        id: repaint
        property int n: 0
        interval: 70; repeat: true
        onTriggered: {
            // Cambiar el tamaño de la vista 1 px y devolverlo obliga a Chromium a componer un cuadro nuevo (lo que
            // antes solo conseguía el ratón); entre medias, cuadros pedidos a Qt
            if (n === 0 || n === 6) viewLoader.anchors.rightMargin = 1;
            else if (n === 1 || n === 7) viewLoader.anchors.rightMargin = 0;
            win.requestUpdate();
            if (++n >= 12) { viewLoader.anchors.rightMargin = 0; stop(); }
        }
    }
    function nudge() { repaint.n = 0; repaint.restart(); }

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
        else if (cmd === "shown") { win.pageHidden = false; win.applyVisibility(); win.nudge(); Qt.callLater(win.oneCol); }
        else if (cmd === "hidden") { win.pageHidden = true; win.applyVisibility(); }
        // Diagnóstico de maquetación: qué elementos hay en un punto (px CSS). Solo estructura (etiqueta, tamaño, bordes,
        // posición), nunca texto: va a $XDG_RUNTIME_DIR/hf-webapp/<clave>.probe
        // Prueba del reparto lista/chat sin abrir un chat: «probe forcechat on|off», «probe panes» (solo rectángulos)
        else if (cmd === "probe" && /^forcechat (on|off)$/.test(arg))
            view.runJavaScript("window.__hfForceChat=" + (arg.endsWith("on") ? "true" : "false") + ";window.__hfOneCol&&window.__hfOneCol()");
        else if (cmd === "probe" && arg === "panes") {
            view.runJavaScript("JSON.stringify([].map.call(document.querySelectorAll('[data-hf-pane]'),function(e){var r=e.getBoundingClientRect();"
                + "return e.getAttribute('data-hf-pane')+' x'+Math.round(r.left)+' y'+Math.round(r.top)+' w'+Math.round(r.width)+' h'+Math.round(r.height)+' '+getComputedStyle(e).display}))", res => {
                const x = new XMLHttpRequest();
                x.open("PUT", "file://" + win.runtime + "/" + win.key + ".probe");
                x.send(String(res));
            });
        }
        else if (cmd === "probe" && arg === "lines") {
            // Barrido: elementos (y ::before/::after) que pintan una línea vertical alta — bordes laterales,
            // cajas de ≤3 px de ancho o sombras — con su posición. Sin texto.
            view.runJavaScript("(function(){var H=innerHeight*0.3,out=[];function px(v){return parseFloat(v)||0}"
                + "function d(e){return e.tagName.toLowerCase()+(e.id?'#'+e.id:'')+(e.getAttribute('data-testid')?'['+e.getAttribute('data-testid')+']':'')"
                + "+(e.getAttribute('data-hf-pane')?'{'+e.getAttribute('data-hf-pane')+'}':'')}"
                + "document.querySelectorAll('*').forEach(function(e){var r=e.getBoundingClientRect();if(r.height<H||r.width===0)return;"
                + "var c=getComputedStyle(e);if(c.visibility==='hidden'||c.display==='none')return;"
                + "var why=[];if(px(c.borderLeftWidth)>0&&c.borderLeftStyle!=='none')why.push('bl '+c.borderLeftWidth+' '+c.borderLeftColor+' @'+Math.round(r.left));"
                + "if(px(c.borderRightWidth)>0&&c.borderRightStyle!=='none')why.push('br '+c.borderRightWidth+' '+c.borderRightColor+' @'+Math.round(r.right));"
                + "if(r.width<=3)why.push('thin bg '+c.backgroundColor+' @'+Math.round(r.left));"
                + "if(c.boxShadow!=='none')why.push('shadow '+c.boxShadow.slice(0,50)+' @'+Math.round(r.left)+'-'+Math.round(r.right));"
                + "['::before','::after'].forEach(function(p){var s=getComputedStyle(e,p);if(s.content==='none'||s.display==='none')return;"
                + "if(px(s.width)<=3||px(s.borderLeftWidth)>0||px(s.borderRightWidth)>0)why.push(p+' w'+s.width+' h'+s.height+' pos '+s.position+' l'+s.left+' r'+s.right+' bg '+s.backgroundColor+' bl'+s.borderLeftWidth+' br'+s.borderRightWidth)});"
                + "if(why.length)out.push(d(e)+' x'+Math.round(r.left)+' w'+Math.round(r.width)+' h'+Math.round(r.height)+' :: '+why.join(' | '))});"
                + "return 'vw '+innerWidth+'\\n'+out.slice(0,60).join('\\n')})()", res => {
                const x = new XMLHttpRequest();
                x.open("PUT", "file://" + win.runtime + "/" + win.key + ".probe");
                x.send(String(res));
            });
        }
        else if (cmd === "probe") {
            const xy = arg.split(/\s+/).map(Number);
            view.runJavaScript("(function(x,y){return JSON.stringify(document.elementsFromPoint(x,y).slice(0,14).map(function(e){"
                + "var c=getComputedStyle(e),r=e.getBoundingClientRect();return{tag:e.tagName.toLowerCase(),id:e.id||undefined,"
                + "role:e.getAttribute('role')||undefined,testid:e.getAttribute('data-testid')||undefined,pane:e.getAttribute('data-hf-pane')||undefined,"
                + "x:Math.round(r.left),w:Math.round(r.width),h:Math.round(r.height),pos:c.position,disp:c.display,"
                + "bl:c.borderLeftWidth+' '+c.borderLeftColor,br:c.borderRightWidth+' '+c.borderRightColor,bg:c.backgroundColor,"
                + "bgi:c.backgroundImage.slice(0,60),shadow:c.boxShadow.slice(0,60),before:getComputedStyle(e,'::before').content,"
                + "after:getComputedStyle(e,'::after').content,cls:(e.className&&e.className.baseVal===undefined?String(e.className):'').slice(0,80)}}))})("
                + (xy[0] || 0) + "," + (xy[1] || 0) + ")", res => {
                const x = new XMLHttpRequest();
                x.open("PUT", "file://" + win.runtime + "/" + win.key + ".probe");
                x.send(String(res));
            });
        }
    }
    Timer {
        interval: 200; running: win.runtime !== ""; repeat: true; triggeredOnStart: true
        onTriggered: {
            const x = new XMLHttpRequest();
            x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE && x.responseText) win.command(x.responseText); };
            x.open("GET", "file://" + win.runtime + "/" + win.key + ".cmd");
            x.send();
        }
    }
}
