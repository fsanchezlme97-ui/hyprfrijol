pragma Singleton
// Ajustes del usuario: ~/.config/hyprfrijol/settings.json (una sola fuente de verdad).
// Los valores por defecto están en config/defaults/settings.json.
//   Settings.get("estilo")            → valor (o el de por defecto)
//   Settings.set("estilo", "flat")    → guarda y aplica (hf-apply: tema, Hyprland, hyprlock, kitty…)
//   Settings.setMany({ a: 1, b: 2 })
//   Settings.patch({ a: 1 }, ["b"])   (las claves de la lista se borran → valor por defecto) · Settings.reset(["a", "b"])
// Cualquier módulo puede usar claves nuevas sin tocar este archivo; pon su valor por defecto en
// config/defaults/settings.json o pásalo a get(clave, defecto).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var user: ({})
    property var defaults: ({})
    readonly property var data: Object.assign({}, defaults, user)
    property bool loaded: false

    function get(key: string, def): var {
        const v = data[key];
        return v === undefined ? def : v;
    }
    function set(key: string, value): void { const o = {}; o[key] = value; setMany(o); }
    function setMany(obj): void {
        user = Object.assign({}, user, obj);
        saveTimer.restart();
    }
    // Como setMany, y además borra de settings.json las claves de «remove» (vuelven a su valor por defecto).
    //   Settings.patch({ barPos: "arriba" }, ["barHeight"])
    function patch(obj, remove): void {
        const u = Object.assign({}, user, obj ?? {});
        for (const k of remove ?? []) delete u[k];
        user = u;
        saveTimer.restart();
    }
    // Quita claves de settings.json («Restaurar valores por defecto» de una sección)
    function reset(keys): void { patch({}, keys); }
    // ---------- Barra: medidas compartidas (Bar, Overlay, OSD) ----------
    // barHeight (Ajustes › Barra › Tamaño): grosor en px, de 24 a 56 (34 = «Normal», las medidas del diseño:
    // fija 32 px, flotante/isla/archipiélago 30 px + margen, lateral 36 px de ancho). El contenido se escala en
    // proporción (barScale), así iconos y textos crecen con la barra.
    // barMode: "fija" · "flotante" · "isla" (isla central) · "archipielago" (cada grupo en su propia píldora)
    readonly property int barSize: Math.max(24, Math.min(56, Math.round(Number(get("barHeight", 34)) || 34)))
    readonly property string barPos: get("barPos", "abajo")
    readonly property string barMode: get("barMode", "fija")
    readonly property bool barFloating: barMode === "flotante" || barMode === "isla" || barMode === "archipielago"
    readonly property bool barIsland: barMode === "isla"
    readonly property bool barArchipelago: barMode === "archipielago"
    readonly property bool barVertical: barPos === "izquierda" || barPos === "derecha"
    // Margen con el borde si flota: el mismo hueco que las ventanas (gapsOut), entre 2 y 4 px, igual en los 4 lados
    // (config/apply/52-pip.py lo calcula igual)
    // Margen de la barra flotante con el borde: el mismo hueco que las ventanas (gaps_out), así barra, ventanas y
    // paneles quedan a la misma distancia del borde y entre sí (antes se forzaba a 2–4 px y no casaba)
    readonly property int barOffset: barFloating ? Math.max(0, Math.min(24, Math.round(Number(get("gapsOut", 1)) || 0))) : 0
    readonly property int barThickness: barVertical ? barSize + 2 : barSize - 2 - (barFloating ? 2 : 0)
    readonly property real barScale: barThickness / (barVertical ? 36 : barFloating ? 30 : 32)
    // Comportamiento (Ajustes › Barra): "siempre" · "auto" (se esconde y vuelve con el cursor en el borde) ·
    // "inteligente" (se aparta cuando una ventana la tapa o hay una maximizada). Migra el antiguo barAutoHide.
    readonly property string barBehavior: {
        const v = user.barBehavior ?? (user.barAutoHide === true ? "auto" : get("barBehavior", "siempre"));
        return ["siempre", "auto", "inteligente"].includes(v) ? v : "siempre";
    }
    // Se oculta sola: el ajuste, o el modo sin distracciones con «Ocultar la barra»
    readonly property bool barAutoHide: barBehavior === "auto" || (Shell.focusMode && get("focusHideBar", true))
    readonly property bool barSmartHide: barBehavior === "inteligente" && !barAutoHide
    // ¿La barra ocupa sitio ahora? (si no, los paneles llegan al borde)
    readonly property bool barReserves: !barAutoHide && !Shell.barHidden
    // Hueco de los paneles con el borde de la pantalla y con la barra: el mismo que el de las ventanas en mosaico
    // (gapsOut = gaps_out de Hyprland) más el filo de las ventanas (border_size: 1, 2 con alto contraste): las ventanas
    // dejan ver gaps_out de fondo y luego su filo claro, así que el borde visible del panel cae donde empieza su contenido
    readonly property int gapsOutPx: Math.max(0, Math.min(24, Math.round(Number(get("gapsOut", 1)) || 0)))
    readonly property int winBorder: get("highContrast", false) ? 2 : 1
    readonly property int winGap: gapsOutPx + winBorder
    // Distancia del borde de la pantalla a la que se abren los paneles en el lado de la barra (margen + barra + hueco)
    readonly property real barEdge: barReserves ? barOffset + barThickness + winGap : winGap
    // Módulos visibles de la barra (Ajustes › Barra › Módulos visibles). Es un conjunto: el orden lo fija la barra
    // (BarH/BarV: espacios y título · onda · información · utilidades · bandeja · estado y hora)
    readonly property var barModuleList: {
        const v = get("barModules", null);
        return Array.isArray(v) ? v : ["espacios", "titulo", "musica", "clima", "recursos", "pomodoro", "cafeina", "dictado", "ia", "red", "bateria", "notificaciones", "reloj"];
    }
    function barHas(m: string): bool { return barModuleList.includes(m); }

    function apply(): void { applier.running = false; applier.running = true; }

    FileView {
        id: userFile
        path: Paths.home + "/.config/hyprfrijol/settings.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: { try { root.user = JSON.parse(text()); } catch (e) {} root.loaded = true; }
        onLoadFailed: root.loaded = true
    }
    FileView {
        path: Paths.root + "/config/defaults/settings.json"
        printErrors: false
        onLoaded: { try { root.defaults = JSON.parse(text()); } catch (e) {} }
    }
    Timer {
        id: saveTimer
        interval: 250
        onTriggered: {
            mkdir.running = true;
            userFile.setText(JSON.stringify(root.user, null, 2) + "\n");
            root.apply();
        }
    }
    Process { id: mkdir; command: ["mkdir", "-p", Paths.home + "/.config/hyprfrijol"] }
    Process { id: applier; command: [Paths.script("hf-apply")] }
}
