pragma Singleton
// Estado global del shell: qué vista/panel está abierto y en qué pantalla.
// Las vistas son las mismas que en el diseño: spotlight, ajustes (rápidos), ia (panel lateral), vista,
// agenda, portapapeles, snap, energia, alttab, fondos, captura, widgets, actualizaciones,
// notificaciones… Solo hay una abierta a la vez (como en el prototipo).
//
// Desde fuera:
//   qs -p <repo>/config/quickshell ipc call shell toggle spotlight
//   Hyprland:  hl.bind("SUPER + SPACE", hl.dsp.global("hf:spotlight"))   (atajo global por vista)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // Vista abierta ("" = escritorio)
    property string view: ""
    // Parámetro opcional de la vista (p. ej. pestaña del panel lateral, texto inicial del Spotlight)
    property var arg: null
    // Modo sin distracciones (barra oculta, sin huecos)
    property bool focusMode: false
    // Ancho actual del panel lateral (lo pone el panel: cada web app tiene el suyo); 0 = aún no se sabe
    property real sideW: 0
    // Panel lateral fijado (sidePanelPinned, modules/sidepanel/SidePanel.qml): sidePinned = fijado y activo (reserva su
    // franja), sideShown = el panel se ve, sideHidden = escondido en esta sesión con Super + A o la × (sigue fijado)
    property bool sidePinned: false
    property bool sideShown: false
    property bool sideHidden: false
    // Barra escondida a mano en esta sesión (Super + J → hf:barra; IPC shell toggleBar): vuelve al llevar el cursor al borde
    property bool barHidden: false
    // Dictado (modules/dictado): fase que pinta el botón de la barra (idle | rec | trans…) y la orden de empezar/terminar
    property string dictPhase: "idle"
    signal dictToggle()
    // Pantalla donde se abren los paneles: la del monitor con foco
    readonly property var screen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    // Pantalla principal (Ajustes › Pantallas, primaryMonitor); si no hay, la primera
    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === Settings.get("primaryMonitor", "")) ?? Quickshell.screens[0]

    // Centro de control: ajustes rápidos, notificaciones y agenda viven en UN panel (vista "ajustes",
    // modules/quicksettings/QuickSettings.qml). Los nombres antiguos siguen valiendo como alias y dicen
    // qué parte se pidió (Shell.section): reloj → "agenda", campana → "notificaciones", estado → "ajustes".
    readonly property var aliases: ({ "agenda": ["ajustes", "agenda"], "notificaciones": ["ajustes", "notificaciones"], "centro": ["ajustes", "ajustes"] })
    property string section: ""

    // Portapapeles y emojis viven dentro de Spotlight (modos «:» y «;»): sus vistas antiguas (atajos hf:portapapeles
    // y hf:emojis, IPC, la IA) abren Spotlight directamente en ese modo.
    readonly property var redirects: ({ "portapapeles": ["spotlight", "mode:clip"], "emojis": ["spotlight", "mode:emoji"] })

    signal opened(string view)

    // Carga diferida (components/LazyView, ajuste lazyModules): los módulos se crean al abrir su vista y se
    // descargan poco después de cerrarla. preload(v) los va creando en segundo plano (al pasar el cursor por el
    // botón que los abre), para que la primera apertura no espere.
    readonly property bool lazyModules: Settings.get("lazyModules", true) !== false
    signal preloadRequested(string view)
    function preload(v: string): void {
        const rd = redirects[v], al = aliases[v];
        preloadRequested(rd ? rd[0] : al ? al[0] : v);
    }
    // Sonda de apertura (HF_PROBE_OPEN=1, components/OpenProbe): hora de la última petición de abrir
    property real openedAt: 0
    function stamp(): void { openedAt = Date.now(); }

    function open(v: string, a): void {
        const rd = redirects[v];
        if (rd) { v = rd[0]; a = rd[1]; }
        const al = aliases[v];
        openedAt = Date.now();
        arg = a ?? null;
        section = al ? al[1] : v === "ajustes" ? "ajustes" : "";
        view = al ? al[0] : v;
        if (view === "ia") sideHidden = false;
        opened(view);
    }
    function toggle(v: string, a): void {
        const rd = redirects[v];
        if (rd) { v = rd[0]; a = rd[1]; }
        const al = aliases[v];
        // Panel lateral fijado: el atajo lo esconde (sigue fijado, la franja se libera) y lo vuelve a mostrar
        if (v === "ia" && (a === undefined || a === null) && Settings.get("sidePanelPinned", false) === true && !focusMode) {
            if (sideShown) { sideHidden = true; if (view === "ia") close(); }
            else open(v);
            return;
        }
        if (view === (al ? al[0] : v) && (a === undefined || a === null || arg === a)) close();
        else open(v, a);
    }
    function close(): void { view = ""; arg = null; section = ""; }
    function isOpen(v: string): bool { const rd = redirects[v]; if (rd) return view === rd[0] && arg === rd[1]; const al = aliases[v]; return al ? view === al[0] && section === al[1] : view === v; }

    // Ajustes › Enfoque: focusNoGaps (sin huecos ni bordes); focusHideBar lo aplica la barra (Settings.barAutoHide)
    function setFocusMode(on: bool): void {
        focusMode = on;
        const noGaps = Settings.get("focusNoGaps", true);
        if (on && noGaps)
            Hyprland.dispatch("function() hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 0 }, decoration = { rounding = 0 } }) end");
        else if (!on)
            reloader.running = true;
        if (on) close();
    }

    // Ejecuta un comando sin esperar (atajo para todos los módulos)
    function exec(cmd): void { Quickshell.execDetached(Array.isArray(cmd) ? cmd : ["sh", "-c", cmd]); }
    // Dispatch de Hyprland en Lua (0.57+): Shell.dispatch('hl.dsp.focus({ workspace = 3 })')
    function dispatch(lua: string): void { Hyprland.dispatch(lua); }

    Process { id: reloader; command: ["hyprctl", "reload", "config-only"] }

    IpcHandler {
        target: "shell"
        function toggle(view: string): void { root.toggle(view); }
        function open(view: string): void { root.open(view); }
        function openWith(view: string, arg: string): void { root.open(view, arg); }
        function close(): void { root.close(); }
        function preload(view: string): void { root.preload(view); }      // carga diferida: crear la vista en segundo plano
        function current(): string { return root.view; }
        function focus(): void { root.setFocusMode(!root.focusMode); }
        function toggleBar(): void { root.barHidden = !root.barHidden; }
    }

    // Un atajo global por vista:  hl.dsp.global("hf:<vista>")
    Variants {
        model: ["spotlight", "ajustes", "ia", "vista", "agenda", "portapapeles", "snap", "energia", "alttab",
                "fondos", "captura", "widgets", "actualizaciones", "notificaciones",
                "ajustesapp", "bienvenida", "herramientas", "emojis", "atajos", "musica", "color"]
        GlobalShortcut {
            required property string modelData
            appid: "hf"
            name: modelData
            description: "HyprFrijol: " + modelData
            onPressed: root.toggle(modelData)
        }
    }
    GlobalShortcut {
        appid: "hf"; name: "enfoque"; description: "HyprFrijol: modo sin distracciones"
        onPressed: root.setFocusMode(!root.focusMode)
    }
    GlobalShortcut {
        appid: "hf"; name: "barra"; description: "HyprFrijol: mostrar / ocultar la barra"
        onPressed: root.barHidden = !root.barHidden
    }
    GlobalShortcut {
        appid: "hf"; name: "cerrar"; description: "HyprFrijol: cerrar panel"
        onPressed: root.close()
    }
}
