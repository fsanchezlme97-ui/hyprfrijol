// Carga diferida de un módulo (ajuste lazyModules, por defecto sí): su contenido solo existe mientras una de sus
// vistas está abierta y `grace` ms después de cerrarla (así reabrirlo enseguida no lo vuelve a crear).
//   LazyView { views: ["spotlight"]; Spotlight {} }
//   LazyView { prefix: "omarchy:"; … }             vistas que empiezan por…
//   keep: true  → no se descarga (p. ej. una grabación en curso); warm: true → una vez cargado, se queda
// Shell.preload("<vista>") lo crea en segundo plano (sin bloquear) al pasar el cursor por el botón que lo abre.
// El contenido se crea dentro de Shell.open() (antes de la señal Shell.opened) y aparece con su animación de entrada:
// Overlay/ChipPopup esperan un ciclo (ready) antes de mostrarse.
// Lo que debe funcionar con la vista cerrada (IPC, atajos globales, vigilantes) NO va dentro: va en el módulo
// siempre cargado o en services/.  Con lazyModules = false todo se crea al arrancar, como antes (para depurar).
import QtQuick
import Quickshell
import ".."

Scope {
    id: root
    property var views: []
    property string prefix: ""
    property int grace: 45000
    property bool keep: false
    property bool warm: false
    default property Component component
    readonly property bool open: views.includes(Shell.view) || (prefix !== "" && Shell.view.startsWith(prefix))
    // El contenido creado (null si no lo está). No se lee loader.item mientras carga en segundo plano: lo bloquearía.
    property var item: null
    property bool held: false
    property bool preloading: false

    // Crea el contenido ya (IPC que necesita el módulo con la vista cerrada) y lo devuelve; se descarga tras `grace`
    function load(): var {
        held = true;
        if (!open) hold.restart();
        return item;
    }
    function matches(v: string): bool { return views.includes(v) || (prefix !== "" && v.startsWith(prefix)); }

    LazyLoader {
        id: loader
        component: root.component
        active: !Shell.lazyModules || root.open || root.held || root.keep
        onActiveChanged: {
            root.item = active ? loader.item : null;
            if (active && root.preloading) { root.preloading = false; root.held = true; if (!root.open) hold.restart(); }
        }
    }
    Component.onCompleted: if (loader.active) item = loader.item
    onOpenChanged: {
        if (open) { held = true; hold.stop(); }
        else hold.restart();
    }
    Timer {
        id: hold
        interval: root.grace
        onTriggered: {
            if (root.open || root.warm || !root.held) return;
            root.held = false;
            if (!loader.active) Qt.callLater(() => gc());     // devolver ya la memoria del motor JS
        }
    }
    Connections {
        target: Shell
        function onPreloadRequested(v) {
            if (!Shell.lazyModules || !root.matches(v)) return;
            if (root.item) { if (!root.open) hold.restart(); return; }
            if (root.preloading) return;
            root.preloading = true;
            loader.activeAsync = true;
        }
    }
}
