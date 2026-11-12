// Spotlight (vista "spotlight") — design/capturas/Lanzador.png
// Búsqueda difusa de apps (DesktopEntries), web apps, acciones del shell, ventanas, archivos,
// calculadora (qalc), portapapeles, IA y web.
// Prefijos: > comandos · = calcular · ? IA · @ ventanas · / archivos · : portapapeles · ; emojis · ! web
//   · + nueva tarea (services/Tasks.qml; «+texto mañana» o «+texto 2026-12-01» le pone fecha)
// Teclado: ↑↓ elegir · ↵ abrir · Tab siguiente grupo · Ctrl K más acciones · Esc cerrar
//   en «:»  ↵ copia (y pega si clipboardAutoPaste) · Mayús ↵ lo contrario · Supr borra · Ctrl K fijar…
// «Todas las apps» (botón de la cabecera, la fila del mismo nombre o el ⌘ de la barra): cuadrícula alfabética
//   con categorías · ←↑↓→ elegir · ↵ abrir · Tab/Mayús Tab categoría · Alt + letra salta · Ctrl K o clic derecho
//   menú (dock, .desktop, desinstalar) · Esc vuelve
// Shell.open("spotlight", "texto") abre con una búsqueda ya escrita (p. ej. "=" o "@");
//   "mode:apps" abre «Todas las apps», "mode:clip" el portapapeles (Super + V) y "mode:emoji" los emojis (Super + .).
//   Shell.open("portapapeles" | "emojis") también llega aquí (Shell.redirects).
// En «:» y «;» Esc borra la búsqueda y, si ya no queda nada, cierra si se abrió en ese modo (y si no, vuelve).
// Datos del portapapeles: services/Clip.qml · emojis: EmojiGrid.qml (config/emoji/emojis.json).
// IPC (pruebas): qs ipc call spotlight state
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"
import Quickshell.Widgets
import "catalog.js" as Cat
import "../../components/catppuccin.js" as Ctp

Overlay {
    id: spot
    view: "spotlight"
    // Centrado en la pantalla (sea cual sea la barra), algo por encima del centro como en macOS. Se centra con la
    // altura de «Todas las apps» para que el campo de búsqueda no salte al cambiar de modo.
    place: "screen"
    panelWidth: 860
    panelHeight: mode === "apps" ? 600 : 494
    centerHeight: 600
    lift: 36

    // ---------- estado ----------
    property string query: ""
    property int sel: 0
    property bool moreMode: false
    property int moreSel: 0
    property var usage: ({ counts: {}, pinned: [] })
    property var calc: ({ expr: "", result: "", ok: false, busy: false })
    property var files: []
    property var recipes: []            // recetas del asistente (hf-ai recipes; se recargan al abrir)
    property var aiImages: []           // «?»: imágenes pegadas con Ctrl+V (van al panel de la IA con la pregunta)
    property bool filesBusy: false
    property string mode: "search"      // "search" | "apps" (Todas las apps)
    property bool appsDirect: false     // se abrió directamente en «Todas las apps» (Esc cierra)
    property string appCat: ""          // categoría de «Todas las apps» ("" = todas)
    property int gsel: 0                // elegida en la cuadrícula

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var windows: Hyprland.toplevels.values
    readonly property var items: mode === "apps" || emojiMode ? [] : build(query, apps, usage, calc, files, windows, Pomodoro.running, Clip.history, Clip.pins, recipes)
    readonly property var rows: rowsOf(items)
    readonly property var cur: mode === "apps" ? (gridApps[gsel] ? appItem(gridApps[gsel]) : null)
                                               : items[Math.max(0, Math.min(sel, items.length - 1))] ?? null
    // Solo se calculan con el menú abierto (buscar la app en el catálogo de la tienda cuesta)
    readonly property var moreActions: moreMode && cur ? actionsOf(cur) : []
    readonly property bool clipMode: mode === "search" && query.trim().startsWith(":")
    readonly property bool emojiMode: mode === "search" && query.startsWith(";")
    property string direct: ""          // "" | ":" | ";" — se abrió directamente en ese modo (Esc cierra)

    function reset() {
        const a = typeof Shell.arg === "string" ? Shell.arg : "";
        appsDirect = a === "mode:apps";
        mode = appsDirect ? "apps" : "search";
        appCat = ""; gsel = 0;
        input.text = a === "mode:clip" ? ":" : a === "mode:emoji" ? ";" : a.startsWith("mode:") ? "" : a;
        direct = a === "mode:clip" ? ":" : a === "mode:emoji" ? ";" : "";
        sel = 0; moreMode = false; moreSel = 0;
        list.positionViewAtBeginning();
        grid.positionViewAtBeginning();
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
        Clip.refresh();
        recipeProc.running = false;
        recipeProc.running = Settings.get("aiProvider", "claude-code") !== "off";
    }
    Process {
        id: recipeProc
        command: [Paths.script("hf-ai"), "recipes"]
        stdout: StdioCollector { onStreamFinished: { try { spot.recipes = JSON.parse(text); } catch (e) { spot.recipes = []; } } }
    }
    function setMode(m) {
        mode = m; appsDirect = false; moreMode = false;
        appCat = ""; gsel = 0;
        input.text = "";
        input.forceActiveFocus();
        if (m === "apps") Qt.callLater(() => grid.positionViewAtBeginning());
    }
    // IPC "spotlight" (en modules/Modules.qml, siempre cargado): state
    function ipcState(): string {
        return JSON.stringify({ mode: spot.mode, query: spot.query, sel: spot.sel, gsel: spot.gsel, cat: spot.appCat,
                                cur: spot.cur?.name ?? "", kind: spot.cur?.kind ?? "", more: spot.moreMode ? spot.moreActions.map(a => a.label) : [],
                                moreSel: spot.moreSel, items: spot.mode === "apps" ? spot.gridApps.length : spot.items.length,
                                cats: spot.appCats.map(c => c.label + ":" + c.n) });
    }

    // ---------- Todas las apps ----------
    // Categoría principal (freedesktop) → grupo en español; la primera que encaje gana
    readonly property var catMap: [["Game", "Juegos"], ["Development", "Desarrollo"], ["Graphics", "Gráficos"], ["AudioVideo", "Multimedia"],
        ["Audio", "Multimedia"], ["Video", "Multimedia"], ["Office", "Oficina"], ["Network", "Internet"], ["Education", "Educación"],
        ["Science", "Educación"], ["Settings", "Ajustes"], ["System", "Sistema"], ["Utility", "Utilidades"]]
    readonly property var catOrder: ["Internet", "Oficina", "Multimedia", "Gráficos", "Desarrollo", "Juegos", "Educación", "Utilidades", "Sistema", "Ajustes", "Otras"]
    function catOf(e) {
        const c = e.categories ?? [];
        for (const m of catMap) if (c.includes(m[0])) return m[1];
        return "Otras";
    }
    function letterOf(name) {
        const c = String(name ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").charAt(0).toUpperCase();
        return /[A-Z]/.test(c) ? c : "#";
    }
    // Solo en «Todas las apps» (crear el Spotlight al abrirlo no paga la ordenación); orden por una clave sin tildes ni
    // mayúsculas calculada una vez por app
    function sortKey(s) { return String(s ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase(); }
    readonly property var allApps: mode !== "apps" ? []
        : apps.map(e => [sortKey(e.name), e]).sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0).map(x => x[1])
    readonly property var appCats: {
        if (mode !== "apps") return [];
        const n = {};
        for (const e of allApps) { const c = catOf(e); n[c] = (n[c] ?? 0) + 1; }
        return [{ key: "", label: "Todas", n: allApps.length }].concat(catOrder.filter(c => n[c]).map(c => ({ key: c, label: c, n: n[c] })));
    }
    readonly property var gridApps: {
        if (mode !== "apps") return [];
        const q = query.trim();
        const inCat = allApps.filter(e => !appCat || catOf(e) === appCat);
        if (!q) return inCat;
        return inCat.map(e => ({ e: e, sc: Cat.multiScore([e.name, e.genericName, (e.keywords ?? []).join(" "), e.comment, e.execString], q) }))
                    .filter(x => x.sc > 0).sort((a, b) => b.sc - a.sc).map(x => x.e);
    }
    readonly property var letters: { const s = {}; for (const e of gridApps) s[letterOf(e.name)] = true; return s; }
    readonly property int gcols: Math.max(1, Math.floor(grid.width / 104))
    function gmove(d) {
        if (moreMode) { moreSel = Math.max(0, Math.min(moreActions.length - 1, moreSel + (d > 0 ? 1 : -1))); return; }
        if (!gridApps.length) return;
        gsel = Math.max(0, Math.min(gridApps.length - 1, gsel + d));
        grid.positionViewAtIndex(gsel, GridView.Contain);
    }
    function jumpLetter(l) {
        const i = gridApps.findIndex(e => letterOf(e.name) === l);
        if (i < 0) return;
        moreMode = false; gsel = i;
        grid.positionViewAtIndex(i, GridView.Beginning);
    }
    function cycleCat(d) {
        const i = appCats.findIndex(c => c.key === appCat);
        appCat = appCats[(i + d + appCats.length) % appCats.length].key;
    }
    onAppCatChanged: { gsel = 0; moreMode = false; grid.positionViewAtBeginning(); }
    function appsKey(e) {
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier;
        const k = e.key;
        e.accepted = true;
        if (k === Qt.Key_Right) gmove(1);
        else if (k === Qt.Key_Left) gmove(-1);
        else if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_J || k === Qt.Key_N))) gmove(moreMode ? 1 : gcols);
        else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_P)) gmove(moreMode ? -1 : -gcols);
        else if (k === Qt.Key_PageDown) gmove(gcols * 3);
        else if (k === Qt.Key_PageUp) gmove(-gcols * 3);
        else if (ctrl && k === Qt.Key_Home) gmove(-gridApps.length);
        else if (ctrl && k === Qt.Key_End) gmove(gridApps.length);
        else if (k === Qt.Key_Tab) cycleCat(1);
        else if (k === Qt.Key_Backtab) cycleCat(-1);
        else if ((ctrl && k === Qt.Key_K) || k === Qt.Key_Menu) { if (moreMode) moreMode = false; else if (gridApps.length) openMenuAt(gsel); }
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (moreMode) moreActions[moreSel]?.run();
            else launchApp(gridApps[gsel]);
        }
        else if (k === Qt.Key_Escape) {
            if (moreMode) moreMode = false;
            else if (input.text !== "") input.text = "";
            else if (appCat !== "") appCat = "";
            else if (appsDirect) Shell.close();
            else setMode("search");
        }
        else if (alt && /^[a-z]$/i.test(e.text || String.fromCharCode(k))) jumpLetter((e.text || String.fromCharCode(k)).toUpperCase());
        else e.accepted = false;
    }
    function launchApp(e) { if (!e) return; bump(appItem(e).key); e.execute(); Shell.close(); }
    function openMenuAt(i) { gsel = i; moreSel = 0; moreMode = true; }
    Connections {
        target: Shell
        function onOpened(v) { if (v === "spotlight") Qt.callLater(spot.reset); }
    }

    // ---------- datos ----------
    function addrOf(t) { const a = String(t.address ?? ""); return a.startsWith("0x") ? a : "0x" + a; }
    function classOf(t) { return t.lastIpcObject?.class || t.wayland?.appId || ""; }
    function windowsOfApp(e) {
        const ids = [e.startupClass, e.id, String(e.id ?? "").replace(/\.desktop$/, ""), e.name]
            .filter(Boolean).map(s => String(s).toLowerCase());
        return windows.filter(t => {
            const c = classOf(t).toLowerCase();
            return c !== "" && ids.some(i => i === c || i.endsWith("." + c) || c.endsWith("." + i));
        });
    }
    function uses(key) { return usage.counts?.[key] ?? 0; }
    function isPinned(key) { return (usage.pinned ?? []).includes(key); }
    readonly property var appHints: ({ kitty: "Super ↵", foot: "Super ↵", alacritty: "Super ↵", "org.wezfurlong.wezterm": "Super ↵",
        "org.kde.dolphin": "Super E", "org.gnome.Nautilus": "Super E", thunar: "Super E",
        "google-chrome": "Super W", firefox: "Super W", "org.kde.kate": "Super X", "org.kde.plasma-systemmonitor": "Ctrl ⇧ Esc" })

    function appItem(e) {
        const id = String(e.id ?? "").replace(/\.desktop$/, "");
        return { key: "app:" + id, cat: "Apps", kind: "app", entry: e, appIcon: e.icon, g: (e.name ?? "?").charAt(0).toUpperCase(),
                 name: e.name, sub: e.genericName || e.comment || "", hint: appHints[id] ?? "" };
    }
    function windowItem(t) {
        const c = classOf(t);
        return { key: "win:" + addrOf(t), cat: "Ventanas", kind: "window", win: t, g: (c || t.title || "?").charAt(0).toUpperCase(),
                 appIcon: c ? c.toLowerCase() : "", name: t.title || c, sub: c, hint: t.workspace ? "Espacio " + t.workspace.id : "" };
    }
    function staticItems() {
        return Cat.ACTIONS.map(it => Object.assign({ kind: "static" }, it));
    }

    // Ajustes › Productividad › Spotlight: grupos que salen sin prefijo (spotlightGroups), su orden
    // (spotlightOrder: [] = por relevancia) y el buscador de «!» y de la fila «Buscar en la web» (webSearch)
    readonly property var groupKeys: ({ Apps: "apps", Acciones: "acciones", Ventanas: "ventanas", Calculadora: "calculadora", Recetas: "recetas", IA: "ia", Web: "web" })
    function groupOn(cat) { const g = Settings.get("spotlightGroups", null); return !Array.isArray(g) || g.includes(groupKeys[cat] ?? cat); }
    readonly property var engines: ({ duckduckgo: ["DuckDuckGo", "https://duckduckgo.com/?q=%s"], google: ["Google", "https://www.google.com/search?q=%s"],
                                      brave: ["Brave Search", "https://search.brave.com/search?q=%s"], kagi: ["Kagi", "https://kagi.com/search?q=%s"],
                                      startpage: ["Startpage", "https://www.startpage.com/do/search?q=%s"] })
    readonly property var engine: {
        const w = String(Settings.get("webSearch", "duckduckgo"));
        if (engines[w]) return { name: engines[w][0], url: engines[w][1] };
        const m = /^https?:\/\/([^\/]+)\S*%s/.exec(w);
        return m ? { name: m[1].replace(/^www\./, ""), url: w } : { name: engines.duckduckgo[0], url: engines.duckduckgo[1] };
    }
    function webUrl(s) { return engine.url.replace("%s", encodeURIComponent(s)); }

    function clipItem(r, cat) {
        return { key: "clip:" + (r.pinned ? "p" + r.pinIndex : r.id), cat: cat, kind: "clip", clip: r, img: r.img ?? "",
                 g: Clip.glyphs[r.kind] ?? "¶", name: r.text.replace(/\s*\n\s*/g, " ⏎ ").slice(0, 200), sub: r.meta + (r.pinned ? " · fijado" : "") };
    }
    function build(qRaw, appList, use, calcState, fileList, wins, pomoRunning, clipHist, clipPins, recipeList) {
        const q = qRaw.trim();
        const out = [];
        // : portapapeles (fijados + recientes de cliphist)
        if (q.startsWith(":")) {
            const r = Clip.rows(q.slice(1));
            const cl = r.pinned.map(x => clipItem(x, "Fijados")).concat(r.recent.slice(0, 150).map(x => clipItem(x, "Recientes")));
            return cl.length ? cl : [{ key: "noclip", cat: "Portapapeles", kind: "none", g: "⎘", name: q.slice(1).trim() ? "Nada coincide" : "El historial está vacío",
                                       sub: q.slice(1).trim() ? "" : "copia algo y aparecerá aquí" }];
        }
        // ? IA
        if (q.startsWith("?") && Settings.get("aiSpotlight", true) !== false) {
            const ask = q.slice(1).trim();
            const ni = spot.aiImages.length;
            return [{ key: "ask", cat: "IA", kind: "ask", icon: "ai", g: "", name: ask ? "Preguntar: " + ask : ni ? "Pregunta sobre la imagen…" : "Pregunta lo que quieras…",
                      sub: ni ? (ni === 1 ? "con 1 imagen adjunta" : "con " + ni + " imágenes adjuntas") + " · responde en el panel lateral"
                              : "responde en el panel lateral · Ctrl V adjunta una imagen copiada", ask: ask, hint: "↵",
                      det: [["Modelo", "El de Ajustes › IA"], ["Contexto", "Ventana activa + portapapeles"], ["Puede", "Consultar y manejar el escritorio (con Deshacer)"]] }];
        }
        // + nueva tarea: «mañana» o una fecha AAAA-MM-DD al final le ponen fecha
        if (q.startsWith("+")) {
            const m = /^(.*?)\s+(hoy|mañana|\d{4}-\d{2}-\d{2})$/i.exec(q.slice(1).trim());
            let text = q.slice(1).trim(), due = "";
            if (m) {
                text = m[1];
                due = Tasks.parseDue(m[2]) || "";
            }
            return [{ key: "task", cat: "Tareas", kind: "task", icon: "check", g: "+", name: text ? "Nueva tarea: " + text : "Escribe la tarea…",
                      sub: (due ? "vence el " + due : "sin fecha") + " · se ve en la agenda", text: text, due: due, hint: "↵",
                      det: [["Fecha", "Añade «mañana» o AAAA-MM-DD al final"], ["Dónde", "Agenda (Super + C)"]] }];
        }
        // descargar <dirección…> (o pegar una dirección sola): a la cola de descargas (scripts/hf-download)
        const dlm = /^(descargar|bajar)(\s+|$)(.*)$/i.exec(q);
        const bareUrl = /^https?:\/\/\S+$/.test(q);
        if (dlm || bareUrl) {
            const urls = (dlm ? dlm[3] : q).split(/\s+/).filter(x => /^https?:\/\//.test(x));
            const host = urls.length ? urls[0].replace(/^https?:\/\/(www\.)?/, "").slice(0, 48) : "";
            const many = urls.length > 1 ? urls.length + " enlaces" : host;
            const det = [["Destino", "Vídeos, Música, Imágenes o Descargas según el tipo"], ["Cola", "Indicador de la barra"]];
            if (!urls.length) return [{ key: "dl-none", cat: "Descargas", kind: "none", g: "↓", icon: "download", name: "Escribe o pega una dirección…",
                                        sub: "vídeo, música, galerías de imágenes o archivos; varias separadas por espacios" },
                                      { key: "dl-queue", cat: "Descargas", kind: "dlqueue", g: "↓", icon: "download", name: "Ver la cola de descargas",
                                        sub: Downloads.active.length ? Downloads.active.length + (Downloads.active.length === 1 ? " activa" : " activas") : "" }];
            const out2 = [
                { key: "dl-auto", cat: "Descargas", kind: "download", g: "↓", icon: "download", name: "Descargar " + many, sub: "elige la herramienta sola (yt-dlp, gallery-dl o aria2c)",
                  urls: urls, dlType: "auto", hint: "↵", det: det },
                { key: "dl-audio", cat: "Descargas", kind: "download", g: "♪", icon: "music", name: "Solo el audio (" + Settings.get("downloadsAudioFormat", "mp3") + ")", sub: many,
                  urls: urls, dlType: "audio", det: det },
                { key: "dl-video", cat: "Descargas", kind: "download", g: "▶", icon: "camera", name: "Vídeo (" + ({ best: "la mejor calidad" }[Settings.get("downloadsVideoFormat", "best")] ?? Settings.get("downloadsVideoFormat", "best") + "p") + ")", sub: many,
                  urls: urls, dlType: "video", det: det },
                { key: "dl-image", cat: "Descargas", kind: "download", g: "▦", icon: "image", name: "Imágenes de la galería", sub: many, urls: urls, dlType: "image", det: det }
            ];
            // Dirección sola: abrirla primero y descargarla (las opciones de formato, con «descargar <dirección>»)
            if (bareUrl && !dlm) return [{ key: "web-open", cat: "Web", kind: "web", g: "!", icon: "globe", name: "Abrir " + host, sub: "en el navegador", url: q, hint: "↵",
                                           det: [["Abre en", "Tu navegador"]] },
                                         Object.assign({}, out2[0], { hint: "", sub: "«descargar …» para elegir audio, vídeo o imágenes" })];
            return out2;
        }
        // ! web
        if (q.startsWith("!")) {
            const s = q.slice(1).trim();
            return [
                { key: "web", cat: "Web", kind: "web", g: "!", icon: "globe", name: s ? "Buscar en la web: " + s : "Escribe qué buscar…", sub: spot.engine.name,
                  url: spot.webUrl(s), hint: "↵", det: [["Motor", spot.engine.name], ["Abre en", "Tu navegador"]] },
                { key: "web-yt", cat: "Web", kind: "web", g: "Y", name: s ? "Buscar en YouTube: " + s : "Buscar en YouTube", sub: "youtube.com",
                  url: "https://www.youtube.com/results?search_query=" + encodeURIComponent(s), det: [["Abre en", "Tu navegador"]] },
                { key: "web-wiki", cat: "Web", kind: "web", g: "W", name: s ? "Wikipedia: " + s : "Buscar en Wikipedia", sub: "es.wikipedia.org",
                  url: "https://es.wikipedia.org/w/index.php?search=" + encodeURIComponent(s), det: [["Abre en", "Tu navegador"]] }
            ];
        }
        // > comandos
        if (q.startsWith(">")) {
            const c = q.slice(1).trim();
            return [
                { key: "cmd", cat: "Comandos", kind: "cmd", g: ">", icon: "terminal", name: c ? "Ejecutar en la terminal: " + c : "Escribe un comando…", sub: "", cmd: c,
                  hint: "↵", det: [["Terminal", Pkg.terminal], ["Al terminar", "La ventana se queda abierta"]] },
                { key: "cmd-bg", cat: "Comandos", kind: "cmdbg", g: "⚙", name: c ? "Ejecutar en segundo plano: " + c : "Ejecutar en segundo plano", sub: "", cmd: c,
                  det: [["Salida", "Se descarta"]] }
            ];
        }
        // @ ventanas
        if (q.startsWith("@")) {
            const s = q.slice(1).trim();
            const ws = wins.map(t => ({ t: t, sc: Cat.multiScore([t.title, classOf(t)], s) })).filter(x => x.sc > 0)
                .sort((a, b) => b.sc - a.sc).map(x => windowItem(x.t));
            return ws.length ? ws : [{ key: "nowin", cat: "Ventanas", kind: "none", g: "@", name: wins.length ? "Ninguna ventana coincide" : "No hay ventanas abiertas", sub: "" }];
        }
        // / archivos
        if (q.startsWith("/")) {
            const s = q.slice(1).trim();
            if (!s) return [{ key: "nofile", cat: "Archivos", kind: "none", g: "/", icon: "folder", name: "Escribe parte del nombre…", sub: "busca en tu carpeta personal" }];
            const fl = fileList.map(p => {
                const name = p.replace(/\/$/, "").split("/").pop();
                const dir = p.endsWith("/");
                return { key: "file:" + p, cat: "Archivos", kind: "file", path: p.replace(/\/$/, ""), icon: dir ? "folder" : "file", g: "/", catIcon: Qt.resolvedUrl("../../assets/catppuccin/" + Ctp.rel(Ctp.forPath(p, dir), Theme.light)),
                         name: name, sub: p.replace(Paths.home, "~").replace(/\/[^\/]*\/?$/, ""), isDir: dir };
            });
            if (fl.length) return fl;
            return [{ key: "nofile", cat: "Archivos", kind: "none", g: "/", icon: "folder", name: filesBusy ? "Buscando…" : "Sin resultados", sub: "" }];
        }
        // = calculadora (o aritmética directa)
        const isCalc = q.startsWith("=") || Cat.isArithmetic(q);
        if (isCalc && (q.startsWith("=") || groupOn("Calculadora"))) {
            const expr = q.replace(/^=/, "").trim();
            const res = calcState.expr === expr ? calcState.result : "";
            out.push({ key: "calc", cat: "Calculadora", kind: "calc", g: "=", name: !expr ? "Escribe una operación…" : res || "…",
                       sub: expr, hint: calcState.ok ? "↵ copia" : "", result: calcState.ok ? res : "",
                       det: [["Expresión", expr || "—"], ["Resultado", calcState.ok ? res : "—"], ["También", "Unidades, monedas, husos"]] });
            if (q.startsWith("=")) return out;
        }
        // Búsqueda vacía: fijados + recientes + lo destacado del diseño
        const stat = staticItems();
        if (!q) {
            const all = appList.map(appItem).concat(stat);
            const pinned = (use.pinned ?? []).map(k => all.find(i => i.key === k)).filter(Boolean)
                .map(i => Object.assign({}, i, { cat: "Fijados" }));
            out.push(...pinned);
            let top = appList.map(appItem).filter(i => !isPinned(i.key) && uses(i.key) > 0).sort((a, b) => uses(b.key) - uses(a.key)).slice(0, 3);
            if (!top.length) top = appList.map(appItem).filter(i => /^(kitty|foot|alacritty|org\.kde\.dolphin|org\.gnome\.Nautilus|thunar)$/.test(i.key.slice(4))).slice(0, 2);
            out.push(...top);
            if (!isPinned("act:allapps")) out.push(...stat.filter(i => i.key === "act:allapps"));
            // Lo último copiado (Ajustes: spotlightClipRecent)
            if (Settings.get("spotlightClipRecent", true) !== false)
                out.push(...Clip.rows("").recent.slice(0, 3).map(x => clipItem(x, "Portapapeles")));
            out.push(...stat.filter(i => i.top && !isPinned(i.key)).map(i => i.act === "pomo" && pomoRunning
                ? Object.assign({}, i, { name: "Pomodoro en marcha", sub: Pomodoro.time + " · " + Pomodoro.label.toLowerCase() }) : i));
            return out;
        }
        // Búsqueda normal: puntuar y agrupar
        const scored = [];
        for (const e of appList) {
            const sc = Cat.multiScore([e.name, e.genericName, (e.keywords ?? []).join(" "), e.comment, e.execString, (e.categories ?? []).join(" ")], q);
            if (sc > 0) scored.push({ it: appItem(e), sc: sc + Math.min(25, Math.log(1 + uses("app:" + String(e.id).replace(/\.desktop$/, ""))) * 8) });
        }
        for (const s of stat) {
            const sc = Cat.multiScore([s.name, s.sub, s.kw, s.cat], q);
            if (sc > 0) scored.push({ it: s, sc: sc + Math.min(25, Math.log(1 + uses(s.key)) * 8) });
        }
        for (const r of recipeList) {
            const sc = Cat.multiScore([r.name, r.prompt, "receta"], q);
            if (sc > 0) scored.push({ it: { key: "recipe:" + r.id, cat: "Recetas", kind: "recipe", icon: "ai", name: r.name, rid: r.id,
                                            sub: { seleccion: "con la selección", portapapeles: "con lo copiado", pantalla: "con la pantalla", imagen: "con la imagen copiada", nada: "" }[r.input] ?? "",
                                            det: [["Instrucción", r.prompt], ["Resultado", { panel: "En el panel lateral", copiar: "Se copia", reemplazar: "Reemplaza la selección" }[r.output] ?? r.output]] },
                                      sc: sc + Math.min(25, Math.log(1 + uses("recipe:" + r.id)) * 8) });
        }
        if (q.length >= 2) for (const t of wins) {
            const sc = Cat.multiScore([t.title, classOf(t)], q);
            if (sc >= 50) scored.push({ it: windowItem(t), sc: sc - 10 });
        }
        const groups = {};
        for (const x of scored.sort((a, b) => b.sc - a.sc)) {
            if (!groupOn(x.it.cat)) continue;
            const g = groups[x.it.cat] ?? (groups[x.it.cat] = { best: x.sc, items: [] });
            if (g.items.length < (x.it.cat === "Apps" ? 6 : x.it.cat === "Ventanas" ? 3 : 5)) g.items.push(x.it);
        }
        const order = Settings.get("spotlightOrder", []);
        const pos = k => { const i = Array.isArray(order) ? order.indexOf(groupKeys[k] ?? k) : -1; return i < 0 ? 99 : i; };
        Object.keys(groups).sort((a, b) => (order?.length ? pos(a) - pos(b) : 0) || groups[b].best - groups[a].best).forEach(k => out.push(...groups[k].items));
        // Siempre al final: IA y web
        if (groupOn("IA") && Settings.get("aiSpotlight", true) !== false) out.push({ key: "ask", cat: "IA", kind: "ask", icon: "ai", g: "", name: "Preguntar a la IA: «" + q + "»", sub: "", ask: q, det: [["Modelo", "El de Ajustes › IA"]] });
        if (groupOn("Web")) out.push({ key: "web", cat: "Web", kind: "web", g: "!", icon: "globe", name: "Buscar en la web: " + q, sub: spot.engine.name,
                   url: spot.webUrl(q), det: [["Motor", spot.engine.name]] });
        return out;
    }

    function rowsOf(list) {
        const r = []; let last = null;
        list.forEach((it, i) => {
            if (it.cat !== last) { r.push({ header: true, label: it.cat }); last = it.cat; }
            r.push({ header: false, item: it, idx: i });
        });
        return r;
    }
    function rowIndexOf(idx) { return rows.findIndex(r => !r.header && r.idx === idx); }

    // Detalle (filas clave/valor) del elemento elegido
    function detOf(it) {
        if (!it) return [];
        if (it.det) return it.det;
        if (it.kind === "app") {
            const w = windowsOfApp(it.entry);
            const d = [];
            if (it.hint) d.push(["Atajo", it.hint.split(" ").map(k => k === "↵" ? "Enter" : k).join(" + ")]);
            d.push(["Ventanas abiertas", String(w.length)]);
            if (w.length && w[0].workspace) d.push(["Espacio", String(w[0].workspace.id)]);
            if (uses(it.key)) d.push(["Abierta", uses(it.key) + (uses(it.key) === 1 ? " vez" : " veces") + " desde aquí"]);
            if (d.length < 4) d.push(["Comando", String(it.entry.execString ?? "").replace(/ %[a-zA-Z]/g, "")]);
            return d;
        }
        if (it.kind === "window") {
            const t = it.win;
            return [["Clase", classOf(t) || "—"], ["Espacio", t.workspace ? String(t.workspace.id) : "—"], ["Monitor", t.monitor?.name ?? "—"]];
        }
        if (it.kind === "file") return [["Ruta", it.path.replace(Paths.home, "~")], ["Tipo", it.isDir ? "Carpeta" : "Archivo"]];
        if (it.kind === "clip") return [["Tipo", it.clip.meta], ["Estado", it.clip.pinned ? "Fijado" : "En el historial"],
                                        ["Intro", Clip.autoPaste ? "Copia y pega · Mayús ↵ solo copia" : "Copia · Mayús ↵ también pega"]];
        return [["Tipo", it.cat]];
    }
    function catLine(it) {
        if (!it) return "";
        if (it.kind === "clip") return "Portapapeles · " + it.clip.meta;
        const sub = it.kind === "app" ? (it.entry.genericName || catOf(it.entry).toLowerCase()) : it.sub;
        return it.cat + (sub ? " · " + sub : "");
    }

    // Más acciones (Ctrl K)
    function actionsOf(it) {
        const a = [];
        if (it.kind === "app") {
            const w = windowsOfApp(it.entry);
            if (mode === "apps") a.push({ label: w.length ? "Abrir otra ventana" : "Abrir", run: () => runItem(it) });
            if (w.length) a.push({ label: "Ir a la ventana abierta", run: () => focusWindow(w[0]) });
            for (const da of (it.entry.actions ?? [])) a.push({ label: da.name, run: () => { da.execute(); Shell.close(); } });
            const id = String(it.entry.id ?? "");
            a.push({ label: DockPins.isPinned(id) ? "Quitar del dock" : "Fijar en el dock", run: () => { DockPins.toggle(id); moreMode = false; } });
            a.push({ label: "Mostrar el archivo .desktop", run: () => { Shell.exec([Paths.script("hf-appfile"), "show", id]); Shell.close(); } });
            const tool = storeToolOf(it.entry);
            if (tool) a.push({ label: "Ver en el Centro de aplicaciones", run: () => Shell.open("herramientas", "app:" + tool.id) });
            a.push({ label: "Desinstalar…", run: () => uninstallApp(it.entry, tool) });
            a.push({ label: "Copiar comando", run: () => copy(String(it.entry.execString ?? "")) });
        } else if (it.kind === "window") {
            const ad = addrOf(it.win);
            a.push({ label: "Ir a la ventana", run: () => focusWindow(it.win) });
            a.push({ label: "Traer a este espacio", run: () => { Shell.dispatch(`hl.dsp.window.move({ workspace = ${Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1}, window = "address:${ad}" })`); Shell.close(); } });
            a.push({ label: "Cerrar ventana", run: () => { Shell.dispatch(`hl.dsp.window.close({ window = "address:${ad}" })`); } });
        } else if (it.kind === "file") {
            a.push({ label: "Abrir", run: () => runItem(it) });
            a.push({ label: "Abrir la carpeta que lo contiene", run: () => { Shell.exec(["xdg-open", it.path.replace(/\/[^\/]*$/, "") || "/"]); Shell.close(); } });
            a.push({ label: "Copiar ruta", run: () => copy(it.path) });
        } else if (it.kind === "clip") {
            a.push({ label: "Copiar y pegar en la ventana anterior", run: () => Clip.copy(it.clip, true) });
            a.push({ label: "Solo copiar", run: () => Clip.copy(it.clip, false) });
            a.push({ label: it.clip.pinned ? "Soltar (quitar de fijados)" : "Fijar", run: () => { Clip.togglePin(it.clip); moreMode = false; } });
            if (!it.clip.pinned) a.push({ label: "Borrar del historial  Supr", run: () => { Clip.remove(it.clip); moreMode = false; } });
        } else if (it.kind === "calc" && it.result) {
            a.push({ label: "Copiar resultado", run: () => copy(it.result) });
        } else if (it.kind !== "none") {
            a.push({ label: "Abrir", run: () => runItem(it) });
        }
        if (canPin(it) && it.kind !== "clip")
            a.push({ label: isPinned(it.key) ? "Quitar de fijados de Spotlight" : mode === "apps" ? "Fijar en Spotlight" : "Fijar arriba", run: () => { togglePin(it); moreMode = false; } });
        return a;
    }
    function canPin(it) { return it && (it.kind === "app" || it.kind === "static" || it.kind === "clip"); }
    function pinnedNow(it) { return it ? (it.kind === "clip" ? it.clip.pinned : isPinned(it.key)) : false; }
    // App del catálogo de la tienda que corresponde a una entrada .desktop (o null)
    function storeToolOf(e) { return Pkg.tools.find(t => Pkg.entryOf(t)?.id === e.id) ?? null; }
    function uninstallApp(e, tool) {
        Shell.close();
        if (tool && Pkg.uninstallCmd(tool) !== "") { Pkg.uninstall(tool); return; }
        Pkg.runInTerminal(Paths.script("hf-appfile") + " uninstall '" + String(e.id).replace(/'/g, "'\\''") + "'", "Desinstalar " + (e.name ?? ""));
    }

    // ---------- ejecutar ----------
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]); Shell.close(); }
    function focusWindow(t) { Shell.close(); HyprClients.focusWindow(addrOf(t)); }
    function bump(key) {
        if (!key) return;
        const c = Object.assign({}, usage.counts ?? {}); c[key] = (c[key] ?? 0) + 1;
        usage = { counts: c, pinned: usage.pinned ?? [] };
        saveTimer.restart();
    }
    function togglePin(it) {
        if (it.kind === "clip") { Clip.togglePin(it.clip); return; }
        const p = (usage.pinned ?? []).slice();
        const i = p.indexOf(it.key);
        if (i >= 0) p.splice(i, 1); else p.unshift(it.key);
        usage = { counts: usage.counts ?? {}, pinned: p };
        saveTimer.restart();
    }
    function openApp(url) {
        Quickshell.execDetached(["sh", "-c", 'for b in google-chrome-stable chromium brave vivaldi microsoft-edge-stable; do command -v "$b" >/dev/null && exec "$b" --app="$1"; done; exec xdg-open "$1"', "sh", url]);
    }
    function runAct(act) {
        if (act.startsWith("view:")) { Shell.open(act.slice(5)); return; }
        if (act.startsWith("app:")) { openApp(act.slice(4)); Shell.close(); return; }
        if (act === "allapps") { setMode("apps"); return; }
        if (act.startsWith("prefix:")) { input.text = act.slice(7); input.forceActiveFocus(); return; }
        Shell.close();
        switch (act) {
        case "pomo": Pomodoro.start(0); break;
        case "focus": Shell.setFocusMode(true); break;
        case "lock": Quickshell.execDetached(["loginctl", "lock-session"]); break;
        case "game":
            Quickshell.execDetached(["sh", "-c", "if command -v gamescope >/dev/null; then exec gamescope -e -f -- steam -gamepadui; else exec steam -gamepadui; fi"]);
            break;
        case "snapshot":
            Quickshell.execDetached(["sh", "-c",
                'd="HyprFrijol · manual"; ' +
                'if n=$(snapper -c root create -p -d "$d" 2>&1) || n=$(pkexec snapper -c root create -p -d "$d" 2>&1); then ' +
                '  notify-send -a "Restauración" -i drive-harddisk "Punto de restauración creado" "Snapshot #$n · snapper"; ' +
                'else notify-send -u critical -a "Restauración" "No se pudo crear el punto de restauración" "$n"; fi']);
            break;
        }
    }
    function runItem(it, alt) {
        if (!it || it.kind === "none") return;
        if (it.kind === "clip") { Clip.copy(it.clip, alt ? !Clip.autoPaste : Clip.autoPaste); return; }
        bump(it.key);
        switch (it.kind) {
        case "app": it.entry.execute(); Shell.close(); break;
        case "window": focusWindow(it.win); break;
        case "static": runAct(it.act); break;
        case "calc": if (it.result) copy(it.result); break;
        case "ask": {
            const im = aiImages;
            aiImages = [];
            Shell.open("ia", it.ask ? (im.length ? { ask: it.ask, images: im } : { ask: it.ask }) : im.length ? { images: im } : null);
            break;
        }
        case "web": if (query.replace(/^!/, "").trim()) { Shell.exec(["xdg-open", it.url]); Shell.close(); } break;
        case "cmd": if (it.cmd) { Pkg.runInTerminal(it.cmd, "Comando"); Shell.close(); } break;   // en la terminal de Ajustes › Predeterminadas
        case "cmdbg": if (it.cmd) { Shell.exec(["sh", "-c", it.cmd]); Shell.close(); } break;
        case "file": Shell.exec(["xdg-open", it.path]); Shell.close(); break;
        case "download": Downloads.add(it.urls, it.dlType, it.dlType === "audio" ? Settings.get("downloadsAudioFormat", "mp3") : ""); Shell.open("w-descargas"); break;
        case "dlqueue": Shell.open("w-descargas"); break;
        case "task": if (it.text) { Tasks.add(it.text, it.due); Shell.close(); } break;
        case "recipe": Shell.close(); Quickshell.execDetached([Paths.script("hf-ai"), "recipe", it.rid]); break;
        }
    }
    function runIndex(i) { sel = i; runItem(items[i]); }
    function move(d) {
        if (moreMode) { moreSel = Math.max(0, Math.min(moreActions.length - 1, moreSel + d)); return; }
        sel = Math.max(0, Math.min(items.length - 1, sel + d));
        list.positionViewAtIndex(Math.max(0, rowIndexOf(sel) - (items[sel - 1]?.cat !== items[sel]?.cat ? 1 : 0)), ListView.Contain);
    }
    function jumpGroup(d) {
        if (!items.length) return;
        const c = items[sel]?.cat;
        let i = sel;
        if (d > 0) { while (i < items.length && items[i].cat === c) i++; if (i >= items.length) i = 0; }
        else { while (i > 0 && items[i - 1].cat === c) i--; i--; if (i < 0) i = items.length - 1; const c2 = items[i].cat; while (i > 0 && items[i - 1].cat === c2) i--; }
        sel = i; move(0);
    }

    // ---------- procesos ----------
    onQueryChanged: {
        sel = 0; moreMode = false; gsel = 0;
        if (!query.startsWith("?") && aiImages.length) aiImages = [];
        if (mode === "apps") grid.positionViewAtBeginning();
        const q = query.trim();
        if (q.startsWith("=") || Cat.isArithmetic(q)) calcTimer.restart();
        if (q.startsWith("/") && q.slice(1).trim()) { filesBusy = true; fileTimer.restart(); } else files = [];
    }
    // «?» + Ctrl V: si el portapapeles tiene una imagen se adjunta (hf-ai attach clipboard); si no, se pega el texto
    Process {
        id: aiPaste
        command: [Paths.script("hf-ai"), "attach", "clipboard"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) {}
                if (r.images?.length) spot.aiImages = spot.aiImages.concat(r.images.filter(p => !spot.aiImages.includes(p))).slice(0, 6);
                else input.paste();
            }
        }
    }
    Timer {
        id: calcTimer; interval: 120
        onTriggered: {
            const expr = spot.query.trim().replace(/^=/, "").trim();
            if (!expr) return;
            if (/[+\-*\/^(,.]$/.test(expr)) { spot.calc = { expr: expr, result: "Expresión incompleta", ok: false }; return; }
            calcProc.expr = expr;
            calcProc.command = ["sh", "-c", 'LC_ALL=C timeout 3 qalc -t -- "$1" 2>/dev/null | head -1', "sh", expr];
            calcProc.running = true;
        }
    }
    Process {
        id: calcProc
        property string expr: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                const bad = !r || /^error|warning|^\?/i.test(r);
                spot.calc = { expr: calcProc.expr, result: bad ? "No se puede calcular" : r, ok: !bad };
            }
        }
    }
    Timer {
        id: fileTimer; interval: 220
        onTriggered: {
            fileProc.running = false;
            fileProc.command = ["sh", "-c",
                'q="$1"; cd "$HOME" || exit; ' +
                'if command -v fd >/dev/null; then fd -i --max-results 40 --max-depth 6 --type f --type d -- "$q" "$HOME" 2>/dev/null | ' +
                '  awk -v q="$(printf %s "$q" | tr A-Z a-z)" "{ n=tolower(\\$0); sub(/\\/$/, \\"\\", n); sub(/.*\\//, \\"\\", n); print (index(n,q)?0:1) \\"\\t\\" \\$0 }" | sort -s -k1,1 | cut -f2-; ' +
                'else find "$HOME" -maxdepth 5 -not -path "*/.*" -iname "*$q*" 2>/dev/null | head -40; fi',
                "sh", spot.query.trim().slice(1).trim()];
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: { spot.files = text.split("\n").filter(Boolean).slice(0, 40); spot.filesBusy = false; }
        }
    }

    // Uso y fijados
    FileView {
        id: usageFile
        path: Paths.state + "/spotlight-usage.json"
        printErrors: false
        watchChanges: true                  // Ajustes › Privacidad puede borrar el uso
        onFileChanged: reload()
        onLoaded: { try { const u = JSON.parse(text()); spot.usage = { counts: u.counts ?? {}, pinned: u.pinned ?? [] }; } catch (e) {} }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: usageFile.setText(JSON.stringify(spot.usage)) }

    // ---------- interfaz ----------
    Glass {
        anchors.fill: parent
        kind: "panel"
        big: true
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Búsqueda (52 px)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon {
                        name: spot.mode === "apps" ? "chevron_left" : spot.emojiMode ? "smile" : spot.clipMode ? "clipboard" : "search"; size: 19; color: backMa.containsMouse ? Theme.t : Theme.tv
                        MouseArea {
                            id: backMa; anchors.fill: parent; anchors.margins: -6; enabled: spot.mode === "apps"
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spot.setMode("search")
                        }
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.t
                        selectionColor: Theme.pc
                        selectedTextColor: Theme.pcText
                        font.family: Theme.font
                        font.pixelSize: Theme.px(17)
                        clip: true
                        focus: true
                        onTextChanged: spot.query = text
                        // Tras el prefijo de un modo: qué se busca
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            x: input.contentWidth + 4
                            visible: (input.text === ";" || input.text === ":") && !input.preeditText
                            text: input.text === ";" ? "Busca un emoji… (corazón, risa, ok, cohete)" : "Busca en el portapapeles…"
                            size: 17
                            muted: true
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === "" && !input.preeditText
                            text: spot.mode === "apps" ? "Filtra las " + spot.allApps.length + " apps instaladas…" : "Busca apps, archivos, ajustes… o escribe ? para la IA"
                            size: 17
                            color: Theme.t
                            opacity: 0.88
                        }
                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            if (spot.mode === "apps") { spot.appsKey(e); return; }
                            if (spot.emojiMode && emojis.key(e)) { e.accepted = true; return; }
                            if (e.matches(StandardKey.Paste) && spot.query.startsWith("?") && Settings.get("aiContextCapture", true) !== false && !aiPaste.running) {
                                aiPaste.running = true; e.accepted = true; return;
                            }
                            if (spot.clipMode && e.key === Qt.Key_Delete && input.cursorPosition === input.text.length && spot.cur?.kind === "clip") {
                                Clip.remove(spot.cur.clip); e.accepted = true;
                            }
                            else if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_J || e.key === Qt.Key_N))) { spot.move(1); e.accepted = true; }
                            else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_P))) { spot.move(-1); e.accepted = true; }
                            else if (e.key === Qt.Key_PageDown) { spot.move(6); e.accepted = true; }
                            else if (e.key === Qt.Key_PageUp) { spot.move(-6); e.accepted = true; }
                            else if (e.key === Qt.Key_Tab) { spot.jumpGroup(1); e.accepted = true; }
                            else if (e.key === Qt.Key_Backtab) { spot.jumpGroup(-1); e.accepted = true; }
                            else if (ctrl && e.key === Qt.Key_K) { spot.moreMode = !spot.moreMode; spot.moreSel = 0; e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (spot.moreMode) spot.moreActions[spot.moreSel]?.run();
                                else spot.runItem(spot.cur, e.modifiers & Qt.ShiftModifier);
                                e.accepted = true;
                            }
                            else if (e.key === Qt.Key_Escape) {
                                const pre = spot.emojiMode ? ";" : spot.clipMode ? ":" : "";
                                if (spot.moreMode) spot.moreMode = false;
                                else if (pre && input.text.trim() !== pre) input.text = pre;
                                else if (pre && spot.direct === pre) Shell.close();
                                else if (input.text !== "") input.text = "";
                                else Shell.close();
                                e.accepted = true;
                            }
                        }
                    }
                    // «Todas las apps» (en esa vista: volver a la búsqueda)
                    Rectangle {
                        implicitWidth: allRow.implicitWidth + 18
                        implicitHeight: 26
                        radius: Theme.ctl(26)
                        color: spot.mode === "apps" ? Theme.fillOn : allMa.containsMouse ? Theme.fill2 : "transparent"
                        border.width: spot.mode === "apps" ? 0 : 1
                        border.color: Theme.ov
                        RowLayout {
                            id: allRow
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: "grid"; size: 13; color: spot.mode === "apps" ? Theme.fillOnText : Theme.t }
                            Txt { text: "Todas las apps"; size: 11.5; weight: Font.Medium; color: spot.mode === "apps" ? Theme.fillOnText : Theme.t }
                        }
                        MouseArea {
                            id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: spot.setMode(spot.mode === "apps" ? "search" : "apps")
                        }
                    }
                    Rectangle {
                        implicitWidth: escT.implicitWidth + 12
                        implicitHeight: escT.implicitHeight + 4
                        radius: Theme.r(5)
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.ov
                        Txt { id: escT; anchors.centerIn: parent; text: "Esc"; size: 11; muted: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Shell.close() }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.ov }

            // Emojis («;»)
            EmojiGrid {
                id: emojis
                visible: spot.emojiMode
                active: spot.emojiMode && spot.shown
                query: spot.emojiMode ? spot.query.slice(1) : ""
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Resultados + detalle (410 px)
            RowLayout {
                visible: spot.mode === "search" && !spot.emojiMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ListView {
                    id: list
                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    Layout.margins: 8
                    clip: true
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds
                    model: spot.rows
                    delegate: SpotRow {
                        required property var modelData
                        row: modelData
                        selected: !modelData.header && modelData.idx === spot.sel
                        onRowHovered: if (!modelData.header) { spot.sel = modelData.idx; spot.moreMode = false; }
                        onActivated: spot.runIndex(modelData.idx)
                    }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.ov }

                // Detalle
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 20
                    spacing: 14

                    RowLayout {
                        spacing: 14
                        visible: spot.cur !== null
                        SpotTile { item: spot.cur ?? ({}); size: 48 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Txt { Layout.fillWidth: true; text: spot.cur?.name ?? ""; size: 16; weight: Font.DemiBold }
                            Txt { Layout.fillWidth: true; text: spot.catLine(spot.cur); muted: true }
                        }
                    }

                    // Vista previa del portapapeles (texto completo o la imagen)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 128
                        visible: spot.cur?.kind === "clip" && !spot.moreMode
                        radius: Theme.r(6)
                        color: spot.cur?.clip?.kind === "color" ? spot.cur.clip.text.trim() : Theme.fill2
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 6
                            visible: status === Image.Ready
                            source: spot.cur?.kind === "clip" ? Clip.imgUrl(spot.cur.img) : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(720, 360)
                            asynchronous: true
                            cache: false
                        }
                        Text {
                            anchors.fill: parent; anchors.margins: 10
                            visible: spot.cur?.kind === "clip" && !spot.cur.img && spot.cur.clip.kind !== "color"
                            text: spot.cur?.kind === "clip" ? spot.cur.clip.text.slice(0, 1500) : ""
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            maximumLineCount: 6
                            font.family: spot.cur?.kind === "clip" && Clip.isMono(spot.cur.clip.kind) ? Theme.mono : Theme.font
                            font.pixelSize: Theme.px(12)
                            color: Theme.t
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                        }
                    }

                    // Filas clave/valor o "Más acciones"
                    Rectangle {
                        Layout.fillWidth: true
                        visible: spot.cur !== null && spot.cur.kind !== "none"
                        implicitHeight: detCol.implicitHeight + 4
                        radius: Theme.r(6)
                        color: Theme.fill2
                        Column {
                            id: detCol
                            x: 14; y: 2
                            width: parent.width - 28
                            Repeater {
                                model: spot.moreMode ? spot.moreActions : spot.detOf(spot.cur)
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: detCol.width
                                    height: 34
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.ov }
                                    // modo detalle
                                    Txt { id: keyT; visible: !spot.moreMode; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: spot.moreMode ? "" : parent.modelData[0]; muted: true }
                                    Txt {
                                        visible: !spot.moreMode
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, parent.width - keyT.implicitWidth - 16)
                                        horizontalAlignment: Text.AlignRight
                                        text: spot.moreMode ? "" : parent.modelData[1]; weight: Font.Medium
                                    }
                                    // modo "más"
                                    Rectangle {
                                        visible: spot.moreMode
                                        anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 3
                                        anchors.leftMargin: -8; anchors.rightMargin: -8
                                        radius: Theme.r(5)
                                        color: spot.moreMode && spot.moreSel === parent.index ? Theme.pc : "transparent"
                                        Txt {
                                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                            text: spot.moreMode ? parent.parent.modelData.label : ""
                                            color: spot.moreSel === parent.parent.index ? Theme.pcText : Theme.t
                                            weight: Font.Medium
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: spot.moreSel = parent.parent.index
                                            onClicked: parent.parent.modelData.run()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        visible: spot.cur !== null && spot.cur.kind !== "none"
                        Btn {
                            kind: "primary"; h: 32; padX: 16
                            text: spot.cur?.kind === "clip" ? (Clip.autoPaste ? "Pegar  ↵" : "Copiar  ↵")
                                  : spot.cur?.kind === "calc" ? "Copiar  ↵" : spot.cur?.kind === "recipe" ? "Aplicar  ↵" : spot.cur?.kind === "window" ? "Ir  ↵" : spot.cur?.kind === "download" ? "Descargar  ↵" : "Abrir  ↵"
                            onClicked: spot.runItem(spot.cur)
                        }
                        Btn {
                            kind: "outline"; h: 32; padX: 14
                            visible: spot.canPin(spot.cur)
                            text: spot.pinnedNow(spot.cur) ? "Quitar" : "Fijar"
                            onClicked: spot.togglePin(spot.cur)
                        }
                        Btn {
                            kind: "outline"; h: 32; padX: 14
                            active: spot.moreMode
                            text: "Más  Ctrl K"
                            onClicked: { spot.moreMode = !spot.moreMode; spot.moreSel = 0; input.forceActiveFocus(); }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    // Sugerencias (clic = se escriben en la búsqueda)
                    Flow {
                        Layout.fillWidth: true
                        visible: !spot.clipMode
                        spacing: 0
                        Txt { text: "Prueba: "; size: 11.5; muted: true }
                        Repeater {
                            model: ["whats", "12*8+4", "?resume el informe", "restaurar", "snap"]
                            Txt {
                                required property string modelData
                                required property int index
                                text: "«" + modelData + "»" + (index < 4 ? " · " : "")
                                size: 11.5
                                color: tipM.containsMouse ? Theme.t : Theme.tv
                                elide: Text.ElideNone
                                MouseArea {
                                    id: tipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { input.text = parent.modelData; input.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                }
            }

            // Todas las apps: categorías + cuadrícula
            ColumnLayout {
                visible: spot.mode === "apps"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    contentWidth: catRow.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    RowLayout {
                        id: catRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: spot.appCats
                            Rectangle {
                                required property var modelData
                                readonly property bool on: spot.appCat === modelData.key
                                implicitWidth: chipRow.implicitWidth + 20
                                implicitHeight: 26
                                radius: Theme.ctl(26)
                                color: on ? Theme.fillOn : chipMa.containsMouse ? Theme.fill2 : "transparent"
                                border.width: on ? 0 : 1
                                border.color: Theme.ov
                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Txt { text: parent.parent.modelData.label; size: 11.5; weight: Font.Medium; color: parent.parent.on ? Theme.fillOnText : Theme.t; elide: Text.ElideNone }
                                    Txt { text: String(parent.parent.modelData.n); size: 10.5; color: parent.parent.on ? Theme.fillOnText : Theme.tv; opacity: 0.8; elide: Text.ElideNone }
                                }
                                MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { spot.appCat = parent.modelData.key; input.forceActiveFocus(); } }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 6
                        clip: true
                        cellWidth: Math.floor(width / spot.gcols)
                        cellHeight: 102
                        boundsBehavior: Flickable.StopAtBounds
                        model: spot.gridApps
                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property bool on: spot.gsel === index
                            width: grid.cellWidth
                            height: grid.cellHeight
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 3
                                radius: Theme.r(10)
                                color: cell.on ? Theme.selBg : cellMa.containsMouse ? Theme.fill2 : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                SpotTile {
                                    id: cellTile
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10
                                    size: 48
                                    item: ({ appIcon: cell.modelData.icon, g: spot.letterOf(cell.modelData.name), cat: "Apps" })
                                }
                                Text {
                                    anchors { top: cellTile.bottom; topMargin: 7; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
                                    horizontalAlignment: Text.AlignHCenter
                                    text: cell.modelData.name ?? ""
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 0.95
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(11.5)
                                    font.weight: cell.on ? Font.DemiBold : Font.Normal
                                    color: cell.on ? Theme.selText : Theme.t
                                    renderType: Text.NativeRendering
                                }
                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: m => {
                                        input.forceActiveFocus();
                                        if (m.button === Qt.RightButton) spot.openMenuAt(cell.index);
                                        else { spot.gsel = cell.index; spot.launchApp(cell.modelData); }
                                    }
                                }
                            }
                        }
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: spot.gridApps.length === 0
                        text: spot.query.trim() ? "Ninguna app coincide con «" + spot.query.trim() + "»" : "No hay apps en esta categoría"
                        muted: true
                    }
                    // Fondo que cierra el menú al hacer clic fuera
                    MouseArea { anchors.fill: parent; visible: spot.moreMode; onClicked: { spot.moreMode = false; input.forceActiveFocus(); } }
                    // Menú de la app (clic derecho / Ctrl K)
                    Glass {
                        id: appMenu
                        kind: "popup"
                        visible: spot.moreMode && spot.mode === "apps"
                        width: 250
                        height: menuCol.implicitHeight + 12
                        readonly property int col: spot.gsel % spot.gcols
                        readonly property int rowN: Math.floor(spot.gsel / spot.gcols)
                        readonly property real cellX: grid.x + col * grid.cellWidth
                        readonly property real cellY: grid.y + rowN * grid.cellHeight - grid.contentY
                        x: Math.max(6, Math.min(parent.width - width - 6, cellX + grid.cellWidth / 2 - 20))
                        y: cellY + grid.cellHeight - 8 + height > parent.height ? Math.max(4, cellY - height + 8) : cellY + grid.cellHeight - 8
                        z: 5
                        Column {
                            id: menuCol
                            x: 6; y: 6
                            width: parent.width - 12
                            Repeater {
                                model: spot.mode === "apps" ? spot.moreActions : []
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: menuCol.width
                                    height: 30
                                    radius: Theme.r(6)
                                    color: spot.moreSel === index ? Theme.selBg : "transparent"
                                    Txt {
                                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                        text: parent.modelData.label
                                        color: parent.modelData.label.startsWith("Desinstalar") ? Theme.danger : spot.moreSel === parent.index ? Theme.selText : Theme.t
                                        weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: spot.moreSel = parent.index
                                        onClicked: { input.forceActiveFocus(); parent.modelData.run(); }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.ov }

            // Pie (32 px): prefijos
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14
                    Repeater {
                        model: spot.mode === "apps" ? [] : [[">", "comandos"], ["=", "calcular"], ["?", "IA"], ["@", "ventanas"], ["/", "archivos"], [":", "portapapeles"], [";", "emojis"], ["!", "web"], ["+", "tarea"]].filter(h => h[0] !== "?" || Settings.get("aiSpotlight", true) !== false)
                        Text {
                            required property var modelData
                            textFormat: Text.StyledText
                            font.family: Theme.font
                            font.pixelSize: Theme.px(11.5)
                            color: pm.containsMouse ? Theme.t : Theme.tv
                            renderType: Text.NativeRendering
                            text: "<b><font color='" + Theme.t + "'>" + modelData[0].replace(">", "&gt;") + "</font></b> " + modelData[1]
                            MouseArea {
                                id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { input.text = parent.modelData[0]; input.forceActiveFocus(); }
                            }
                        }
                    }
                    // «Todas las apps»: salto por letra
                    RowLayout {
                      visible: spot.mode === "apps"
                      spacing: 1
                      Repeater {
                        model: spot.mode === "apps" ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("") : []
                        Rectangle {
                            required property string modelData
                            readonly property bool has: !!spot.letters[modelData]
                            readonly property bool here: spot.letterOf(spot.gridApps[spot.gsel]?.name) === modelData
                            Layout.preferredWidth: 17; Layout.preferredHeight: 20
                            radius: Theme.r(5)
                            color: here ? Theme.selBg : lm.containsMouse && has ? Theme.fill2 : "transparent"
                            Txt {
                                anchors.centerIn: parent; text: parent.modelData; size: 11; elide: Text.ElideNone
                                weight: parent.here ? Font.DemiBold : Font.Normal
                                color: parent.here ? Theme.selText : Theme.t; opacity: parent.has ? 1 : 0.3
                            }
                            MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; enabled: parent.has; cursorShape: Qt.PointingHandCursor
                                        onClicked: { spot.jumpLetter(parent.modelData); input.forceActiveFocus(); } }
                        }
                      }
                    }
                    Item { Layout.fillWidth: true }
                    Txt {
                        text: spot.moreMode ? "Más acciones · ↑↓ · ↵ · Esc vuelve"
                              : spot.mode === "apps" ? "←↑↓→ · ↵ · Tab categoría · Ctrl K"
                              : spot.clipMode ? "↵ " + (Clip.autoPaste ? "pega" : "copia") + " · Supr borra · Ctrl K fijar"
                              : spot.emojiMode ? "←↑↓→ · ↵ " + (emojis.autoPaste ? "escribe" : "copia") + " · Tab grupo"
                              : "Búsqueda difusa · ↑↓ · ↵"
                        size: 11.5; muted: true
                    }
                }
            }
        }
    }

    // ---------- componentes internos ----------
    // Fila de resultado (38 px, radio 8) o cabecera de categoría
    component SpotRow: Item {
        id: root
        property var row: ({})
        property bool selected: false
        signal rowHovered()
        signal activated()
        readonly property bool header: row.header === true
        width: ListView.view ? ListView.view.width : 400
        height: header ? 24 : 38

        Txt {
            visible: root.header
            anchors { left: parent.left; leftMargin: 10; bottom: parent.bottom; bottomMargin: 3 }
            text: root.row.label ?? ""
            size: 11
            weight: Font.DemiBold
            muted: true
        }

        Rectangle {
            visible: !root.header
            anchors.fill: parent
            radius: Theme.r(8)
            color: root.selected ? Theme.pc : mouse.containsMouse ? Theme.fill2 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            readonly property color fg: root.selected ? Theme.pcText : Theme.t
            readonly property color subFg: root.selected ? Theme.pcText : Theme.tv

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10
                SpotTile { item: root.row.item ?? ({}); size: 24; selected: root.selected }
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                    color: parent.parent.fg
                    renderType: Text.NativeRendering
                    function esc(s) { return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
                    text: "<b>" + esc(root.row.item?.name) + "</b>"
                          + ((root.row.item?.sub ?? "") !== "" ? "&nbsp;&nbsp;<font color='" + parent.parent.subFg + "'>" + esc(root.row.item.sub) + "</font>" : "")
                }
                Txt {
                    visible: text !== ""
                    text: root.row.item?.hint ?? ""
                    size: 11
                    color: parent.parent.subFg
                    elide: Text.ElideNone
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property point last: Qt.point(-1, -1)
                onPositionChanged: m => {
                    if (last.x >= 0 && (Math.abs(m.x - last.x) > 1 || Math.abs(m.y - last.y) > 1)) root.rowHovered();
                    last = Qt.point(m.x, m.y);
                }
                onClicked: root.activated()
            }
        }
    }

    // Baldosa: icono real de la app si lo hay; si no, letra/glifo sobre el color de su categoría
    component SpotTile: Rectangle {
        id: root
        property var item: ({})
        property real size: 24
        property bool selected: false
        readonly property string tone: Cat.CAT_TILE[item.cat] ?? "s4"
        readonly property string iconSrc: item.appIcon ? Quickshell.iconPath(item.appIcon, true) : ""
        readonly property bool hasImage: (iconSrc !== "" && img.status !== Image.Error) || thumb.status === Image.Ready || catImg.status === Image.Ready
        readonly property bool isColor: item.kind === "clip" && item.clip?.kind === "color"
        implicitWidth: size
        implicitHeight: size
        radius: size >= 40 ? 13 : 7
        color: isColor ? item.clip.text.trim() : hasImage ? "transparent" : tone === "p" ? Theme.p : tone === "pc" ? Theme.pc : Theme.s4
        readonly property color fg: tone === "p" ? Theme.pText : tone === "pc" ? Theme.pcText : Theme.t

        clip: thumb.visible
        // Miniatura de una imagen del portapapeles
        Image {
            id: thumb
            anchors.fill: parent
            visible: status === Image.Ready
            source: Clip.imgUrl(root.item.img)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            asynchronous: true
            cache: false
        }
        // Icono Catppuccin de un archivo o carpeta
        Image {
            id: catImg
            anchors.centerIn: parent
            visible: status === Image.Ready && !thumb.visible
            width: root.size >= 40 ? 34 : 18; height: width
            source: root.item.catIcon ?? ""
            sourceSize: Qt.size(width * 2, height * 2)
            smooth: true; mipmap: true
        }
        IconImage {
            id: img
            anchors.centerIn: parent
            visible: root.hasImage && !thumb.visible
            implicitSize: root.size >= 40 ? 44 : 22
            source: root.iconSrc
            asynchronous: true
        }
        Icon {
            anchors.centerIn: parent
            visible: !root.hasImage && (root.item.icon ?? "") !== "" && !root.isColor
            name: root.item.icon ?? ""
            size: root.size >= 40 ? 22 : 13
            color: root.fg
        }
        Txt {
            anchors.centerIn: parent
            visible: !root.hasImage && !(root.item.icon ?? "") && !root.isColor
            text: root.item.g ?? ""
            size: root.size >= 40 ? 19 : 11
            weight: Font.DemiBold
            color: root.fg
            elide: Text.ElideNone
        }
    }
}
