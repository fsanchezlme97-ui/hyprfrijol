pragma Singleton
// Plugins de Omarchy en hyprfrijol: estado que enseña la shell. El trabajo lo hace scripts/hf-plugin (añadir,
// validar, activar, «probado / no probado», ajustes por widget); aquí solo se lee `hf-plugin list --json` y se
// vuelve a leer cuando cambia ~/.config/hyprfrijol/omarchy-plugins.json (lo reescribe hf-plugin en cada cambio).
//
// Lo usan: modules/omarchy/OmarchyHost.qml (servicios y vistas: panel / overlay / menu), bar/OmarchySlot.qml
// (widgets de barra) y Ajustes › Plugins de Omarchy. Abrir un plugin = Shell.open("omarchy:<id>", payload),
// así `qs ipc call shell open omarchy:<id>` hace lo mismo que `omarchy-shell shell summon <id>`.
// Ajustes: omarchyPlugins (interruptor general), omarchyBarSlot ("derecha" · "izquierda").
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    readonly property bool on: Settings.get("omarchyPlugins", true)
    readonly property string pluginsDir: dir
    property string dir: Paths.home + "/.local/share/hyprfrijol/plugins"
    property var plugins: []
    property bool listed: false
    property string listError: ""
    // id → texto del error de QML al cargarlo (lo ve Ajustes)
    property var errors: ({})
    // Instancias vivas: servicios (id → objeto) y widgets de barra (id → [items], uno por barra)
    property var services: ({})
    property var widgets: ({})

    readonly property var byId: { const o = {}; for (const p of plugins) o[p.id] = p; return o; }
    // Listas estables (solo cambian si cambia su contenido: así no se reinician los plugins al releer)
    property string _svcKey: "[]"
    property string _viewKey: "[]"
    property string _barKey: "[]"
    readonly property var serviceEntries: JSON.parse(_svcKey)
    readonly property var viewEntries: JSON.parse(_viewKey)
    readonly property var barEntries: JSON.parse(_barKey)

    // Vista abierta: Shell.view = "omarchy:<id>", Shell.arg = payload (JSON en texto)
    readonly property string openId: Shell.view.startsWith("omarchy:") ? Shell.view.slice(8) : ""
    readonly property string payload: openId !== "" && Shell.arg !== null && Shell.arg !== undefined ? String(Shell.arg) : ""

    function hasKind(p, k) { return !!p && (p.supportedKinds ?? []).includes(k); }
    function isView(p) { return hasKind(p, "panel") || hasKind(p, "overlay") || hasKind(p, "menu"); }
    function viewKind(p) { return hasKind(p, "panel") ? "panel" : hasKind(p, "overlay") ? "overlay" : "menu"; }

    function rebuild() {
        const act = on ? plugins.filter(p => p.enabled && p.supported) : [];
        const svc = act.filter(p => hasKind(p, "service") && p.entryUrls.service).map(p => ({ id: p.id, url: p.entryUrls.service }));
        const views = act.filter(p => isView(p)).map(p => { const k = viewKind(p); return { id: p.id, kind: k, url: p.entryUrls[k] ?? "", keepLoaded: p.keepLoaded }; }).filter(e => e.url);
        const bar = act.filter(p => p.inBar && p.entryUrls.barWidget).sort((a, b) => a.barIndex - b.barIndex)
            .map(p => ({ id: p.id, url: p.entryUrls.barWidget, settings: p.settings ?? {} }));
        const s = JSON.stringify(svc), v = JSON.stringify(views), b = JSON.stringify(bar);
        if (s !== _svcKey) _svcKey = s;
        if (v !== _viewKey) _viewKey = v;
        if (b !== _barKey) _barKey = b;
    }
    onOnChanged: rebuild()

    function refresh() { lister.running = false; lister.running = true; }
    function setError(id, msg) {
        const e = Object.assign({}, errors);
        if (msg) e[id] = msg; else delete e[id];
        errors = e;
        if (msg) console.warn("Plugin de Omarchy «" + id + "»: " + msg);
    }

    // ---------- abrir / cerrar (lo que en Omarchy es shell.summon / hide / toggle)
    function summon(id, payloadJson) {
        const p = byId[id];
        if (!p || !p.enabled) { console.warn("omarchy: «" + id + "» no está instalado o no está activado"); return false; }
        if (isView(p)) { Shell.open("omarchy:" + id, payloadJson ?? ""); return true; }
        // Solo widget de barra: abre su panel (el de la pantalla con el foco, o el primero)
        const w = widgetOnFocusedScreen(id);
        if (w && typeof w.open === "function") { w.open(); return true; }
        return false;
    }
    function hide(id) {
        if (openId === id) { Shell.close(); return true; }
        for (const w of widgets[id] ?? []) if (w && typeof w.close === "function") w.close();
        return true;
    }
    function isOpen(id) {
        if (openId === id) return true;
        return (widgets[id] ?? []).some(w => w && w.opened === true);
    }
    function toggle(id, payloadJson) { return isOpen(id) ? hide(id) : summon(id, payloadJson); }

    function registerWidget(id, item) { const w = Object.assign({}, widgets); w[id] = (w[id] ?? []).filter(x => x !== item).concat([item]); widgets = w; }
    function unregisterWidget(id, item) { const w = Object.assign({}, widgets); w[id] = (w[id] ?? []).filter(x => x !== item); widgets = w; }
    function widgetOnFocusedScreen(id) {
        const list = (widgets[id] ?? []).filter(x => x);
        return list.find(x => x.QsWindow?.window?.screen === Shell.screen) ?? list[0] ?? null;
    }
    function registerService(id, obj) { const s = Object.assign({}, services); if (obj) s[id] = obj; else delete s[id]; services = s; }

    // Manifiesto que ve el plugin (como publicPluginManifest de Omarchy: sin rutas internas)
    function publicManifest(id) {
        const p = byId[id];
        if (!p) return ({ id: id });
        return { schemaVersion: 1, id: p.id, name: p.name, version: p.version, author: p.author, description: p.description,
                 kinds: p.kinds, keepLoaded: p.keepLoaded, barWidget: p.barWidget, license: p.license };
    }

    // Fachada «shell» de cada plugin (PluginShellApi de Omarchy): solo puede abrir/cerrar plugins y ver su propio servicio
    readonly property var _apis: ({})        // se rellena sin avisar (no es estado que se vea): sin bucles de enlace
    function shellApiFor(id) {
        if (!_apis[id]) _apis[id] = apiComp.createObject(root, { pluginId: id });
        return _apis[id];
    }
    // Diagnóstico (IPC omarchy widgets): tamaño y visibilidad de cada widget de barra vivo
    function widgetInfo() {
        const o = {};
        for (const id in widgets) o[id] = (widgets[id] ?? []).filter(w => w).map(w => ({ w: w.width, h: w.height, iw: w.implicitWidth, visible: w.visible, opened: w.opened ?? null }));
        return o;
    }
    Component {
        id: apiComp
        QtObject {
            required property string pluginId
            property var appLibrary: null
            readonly property var bar: barInfo
            readonly property var barConfig: ({ id: "hyprfrijol.bar", position: barInfo.position, layout: {} })
            readonly property var idleConfig: ({})
            function serviceFor(id) { return String(id) === pluginId ? (root.services[pluginId] ?? null) : null; }
            function firstPartyServiceFor(id) { return null; }
            function pluginShellForBarEntry(ownerId, moduleName) { return null; }
            function summon(id, payloadJson) { return root.summon(String(id), payloadJson ?? ""); }
            function hide(id) { return root.hide(String(id)); }
            function toggle(id, payloadJson) { return root.toggle(String(id), payloadJson ?? ""); }
            function isPluginOpen(id) { return root.isOpen(String(id)); }
            function updateEntryInline(id, settings) {
                if (String(id) !== pluginId) return false;
                Quickshell.execDetached([Paths.script("hf-plugin"), "set", pluginId, JSON.stringify(settings ?? {})]);
                return true;
            }
            function mutateShellConfig(mutator) { return false; }
        }
    }
    readonly property QtObject barInfo: QtObject {
        readonly property string position: ({ abajo: "bottom", arriba: "top", izquierda: "left", derecha: "right" })[Settings.barPos] ?? "bottom"
        readonly property bool vertical: Settings.barVertical
        readonly property int barSize: Settings.barThickness
        readonly property var barSizes: ({})
        function barSizeFor(screenName) { return Settings.barThickness; }
    }

    Process {
        id: lister
        running: true
        command: [Paths.script("hf-plugin"), "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.dir = j.dir ?? root.dir;
                    root.plugins = j.plugins ?? [];
                    root.listError = "";
                } catch (e) {
                    root.listError = "hf-plugin list no respondió JSON";
                }
                root.listed = true;
                root.rebuild();
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.listError = text.trim() }
    }
    FileView {
        path: Paths.home + "/.config/hyprfrijol/omarchy-plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }
}
