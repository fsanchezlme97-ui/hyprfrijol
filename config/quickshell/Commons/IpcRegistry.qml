pragma Singleton
// Compatibilidad con Omarchy · Commons.IpcRegistry: cada barra (una por pantalla) crea su copia de un widget, y
// con ella su IpcHandler. Solo el primero vivo de cada destino se activa (como en Omarchy), para que Quickshell
// no avise de destinos repetidos.
import QtQuick

QtObject {
    id: root
    property var handlers: []
    property int revision: 0
    function touch() { revision++; }
    function register(h) { if (handlers.indexOf(h) < 0) handlers = handlers.concat([h]); touch(); }
    function unregister(h) { handlers = handlers.filter(x => x !== h); touch(); }
    function leads(h, rev) {
        if (!h || !h.target) return false;
        for (const x of handlers) if (x && x.target === h.target) return x === h;
        return false;
    }
}
