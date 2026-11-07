// Anfitrión de los plugins de Omarchy (capa de compatibilidad; ver services/OmarchyPlugins.qml y scripts/hf-plugin).
//   service                → se carga al arrancar (una vez) y vive mientras esté activado
//   panel · overlay · menu → vistas de hyprfrijol: Shell.open("omarchy:<id>", payload) / Shell.close()
//   bar-widget             → bar/OmarchySlot.qml (hueco de la barra, Ajustes › Plugins de Omarchy)
//   bar (barra completa)   → no soportado
// IPC (= `omarchy-shell shell summon|hide|toggle <id> [payload]` de Omarchy):
//   qs -p <repo>/config/quickshell ipc call omarchy summon <id> '<payload>'   (o hf-plugin summon <id>)
//   qs -p <repo>/config/quickshell ipc call shell open omarchy:<id>           (lo mismo, sin payload)
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../services"

Scope {
    Item { id: pluginHolder }
    Instantiator {
        model: OmarchyPlugins.serviceEntries
        delegate: PluginInstance { required property var modelData; entry: ({ id: modelData.id, kind: "service", url: modelData.url, keepLoaded: true }); holder: pluginHolder }
    }
    Instantiator {
        model: OmarchyPlugins.viewEntries
        delegate: PluginInstance { required property var modelData; entry: modelData; holder: pluginHolder }
    }

    IpcHandler {
        target: "omarchy"
        function summon(id: string, payload: string): string { return OmarchyPlugins.summon(id, payload) ? "ok" : "unknown"; }
        function hide(id: string): string { return OmarchyPlugins.hide(id) ? "ok" : "unknown"; }
        function toggle(id: string, payload: string): string { return OmarchyPlugins.toggle(id, payload) ? "ok" : "unknown"; }
        function isOpen(id: string): bool { return OmarchyPlugins.isOpen(id); }
        function rescan(): string { OmarchyPlugins.refresh(); return "ok"; }
        function rescanPlugins(): string { OmarchyPlugins.refresh(); return "ok"; }
        function listPlugins(): string { return JSON.stringify(OmarchyPlugins.plugins.map(p => ({ id: p.id, enabled: p.enabled, kinds: p.kinds, inBar: p.inBar, tested: p.tested }))); }
        function errors(): string { return JSON.stringify(OmarchyPlugins.errors); }
        function widgets(): string { return JSON.stringify(OmarchyPlugins.widgetInfo()); }
        function call(id: string, method: string, arg: string): string {
            const o = OmarchyPlugins.services[id];
            if (!o || typeof o[method] !== "function") return "unknown";
            const r = o[method](arg);
            return r === undefined ? "ok" : String(r);
        }
    }
}
