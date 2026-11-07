// Una instancia de un plugin de Omarchy (servicio o vista). Crea el objeto del archivo QML de su entryPoint,
// le pone lo que el anfitrión de Omarchy inyecta (omarchyPath, shell, manifest, pluginRegistry,
// barWidgetRegistry y, en las vistas, service) y guarda el error de QML si no carga (Ajustes lo enseña).
//   kind "service": se carga una vez al arrancar (o al activarlo) y vive hasta que se desactiva.
//   kind "panel" / "overlay" / "menu": se carga al abrirse (Shell.view = "omarchy:<id>") y se descarga al cerrarse,
//   salvo keepLoaded; al abrir se llama a item.open(payload) y al cerrar a item.close() (como en Omarchy).
import QtQuick
import "../.."
import "../../services"

QtObject {
    id: inst
    required property var entry            // { id, kind, url, keepLoaded }
    property Item holder: null             // padre visual del objeto (fuera de cualquier ventana; sus ventanas son suyas)
    readonly property string pid: entry.id
    readonly property bool isService: entry.kind === "service"
    readonly property bool wanted: isService || OmarchyPlugins.openId === pid
    readonly property bool loadIt: isService || entry.keepLoaded || wanted
    property var item: null
    property var comp: null
    property bool _opened: false

    onLoadItChanged: loadIt ? load() : unload()
    onWantedChanged: sync()
    Component.onCompleted: if (loadIt) load()
    Component.onDestruction: unload()

    function load() {
        if (item || comp) return;
        comp = Qt.createComponent(entry.url, Component.Asynchronous);
        if (comp.status === Component.Loading) comp.statusChanged.connect(finish);
        else finish();
    }
    function finish() {
        if (!comp || comp.status === Component.Loading) return;
        if (comp.status !== Component.Ready) {
            OmarchyPlugins.setError(pid, comp.errorString().trim());
            comp = null;
            if (!isService && OmarchyPlugins.openId === pid) Shell.close();
            return;
        }
        const o = comp.createObject(holder ?? inst);
        if (!o) { OmarchyPlugins.setError(pid, "createObject devolvió null"); return; }
        OmarchyPlugins.setError(pid, "");
        if ("omarchyPath" in o) o.omarchyPath = "";
        if ("shell" in o) o.shell = OmarchyPlugins.shellApiFor(pid);
        if ("manifest" in o) o.manifest = OmarchyPlugins.publicManifest(pid);
        if ("pluginRegistry" in o) o.pluginRegistry = registryApi;
        if ("barWidgetRegistry" in o) o.barWidgetRegistry = null;
        if (!isService && "service" in o) o.service = OmarchyPlugins.services[pid] ?? null;
        item = o;
        if (isService) OmarchyPlugins.registerService(pid, o);
        sync();
    }
    function unload() {
        if (item && !isService && _opened && typeof item.close === "function") { try { item.close(); } catch (e) {} }
        _opened = false;
        if (isService) OmarchyPlugins.registerService(pid, null);
        if (item) { item.destroy(); item = null; }
        comp = null;
    }
    function sync() {
        if (!item || isService) return;
        if (wanted && !_opened) {
            _opened = true;
            if (typeof item.open === "function") { try { item.open(OmarchyPlugins.payload); } catch (e) { OmarchyPlugins.setError(pid, "open() falló: " + e); } }
            else if ("visible" in item) item.visible = true;
        } else if (!wanted && _opened) {
            _opened = false;
            if (typeof item.close === "function") { try { item.close(); } catch (e) {} }
            else if ("visible" in item) item.visible = false;
        }
    }
    // Si el plugin se cierra solo (opened → false), la vista de hyprfrijol también
    property Connections closer: Connections {
        target: inst.item && !inst.isService && inst.item.openedChanged !== undefined ? inst.item : null
        ignoreUnknownSignals: true
        function onOpenedChanged() { if (inst.item && inst.item.opened === false && inst._opened && OmarchyPlugins.openId === inst.pid) Shell.close(); }
    }
    // pluginRegistry de un plugin de terceros en Omarchy: solo lectura de sí mismo
    readonly property QtObject registryApi: QtObject {
        readonly property var manifest: OmarchyPlugins.publicManifest(inst.pid)
        readonly property var installedPlugins: { const o = {}; o[inst.pid] = OmarchyPlugins.publicManifest(inst.pid); return o; }
        function isEnabled(id) { return String(id) === inst.pid; }
        function resolveEnabledId(id) { return String(id); }
    }
}
