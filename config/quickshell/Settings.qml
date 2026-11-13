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
        _mark(obj, []);
        saveTimer.restart();
    }
    // Lo cambiado y aún sin guardar. Si otro programa (hf-apply set, el asistente) escribe el archivo en ese rato,
    // al recargarlo se vuelve a poner encima: ni se pierde lo suyo ni lo nuestro.
    property var _dirty: ({})
    property var _gone: []
    function _mark(obj, remove): void {
        const d = Object.assign({}, _dirty, obj ?? {});
        for (const k of remove ?? []) delete d[k];
        _dirty = d;
        _gone = _gone.filter(k => !(k in (obj ?? {}))).concat(remove ?? []);
    }
    // Claves que solo usa el shell: guardarlas no necesita hf-apply (tema, Hyprland, kitty…)
    readonly property var _shellOnly: ["alarms", "timerMin", "worldClocks", "dockApps", "bongoSleep", "calendarCollapsed", "spotlightOrder",
                                       "storeSources", "welcomeDone", "aiOnboarded", "aiAlwaysApprove", "voiceCommands", "voiceAliases", "remoteHosts"]
    property string _written: ""
    // Como setMany, y además borra de settings.json las claves de «remove» (vuelven a su valor por defecto).
    //   Settings.patch({ barPos: "arriba" }, ["barHeight"])
    function patch(obj, remove): void {
        const u = Object.assign({}, user, obj ?? {});
        for (const k of remove ?? []) delete u[k];
        user = u;
        _mark(obj, remove);
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
    // Widgets que se pueden mover (Ajustes › Widgets de la barra), más los propios (barCustom → «propio:<id>»).
    // barOrder = { izquierda: [ids], derecha: [ids] } guarda en qué isla va cada uno y su orden; los que no
    // aparecen (nuevos o sin tocar) van a la derecha en este orden. Encendido o apagado sigue en barModules.
    readonly property var barWidgetIds: ["clima", "recursos", "impresora", "bongo", "pomodoro", "cafeina", "portapapeles", "dictado", "ia", "ajustes"]
    readonly property var barCustomList: { const v = get("barCustom", null); return Array.isArray(v) ? v.filter(c => c && c.id) : []; }
    readonly property var barOrder: {
        const o = get("barOrder", null) || {};
        const all = barWidgetIds.concat(barCustomList.map(c => "propio:" + c.id));
        const seen = {};
        // separadores («sep:<id>»): solo existen en barOrder, siempre encendidos
        const take = l => (Array.isArray(l) ? l : []).filter(x => (all.includes(x) || /^sep:\w+$/.test(x)) && !seen[x] && (seen[x] = true));
        const izq = take(o.izquierda), der = take(o.derecha);
        return { izquierda: izq, derecha: der.concat(all.filter(x => !seen[x])) };
    }
    // Los encendidos de una isla, en su orden
    function barZone(z: string): var { return (barOrder[z] ?? []).filter(m => m.startsWith("sep:") || barHas(m)); }
    // Información (clima, sistema, impresora, propios) y utilidades: entre un grupo y otro, un separador
    // (los separadores puestos a mano quitan el automático de al lado: ver BarH/BarV)
    function barGroup(m: string): string { if (m.startsWith("sep:")) return "sep"; return ["clima", "recursos", "impresora"].includes(m) || m.startsWith("propio:") ? "info" : "util"; }

    // Si hf-apply está a medias no se corta (podía saltarse la recarga de Hyprland): se repite al acabar
    property bool _again: false
    function apply(): void { if (applier.running) _again = true; else applier.running = true; }

    FileView {
        id: userFile
        path: Paths.home + "/.config/hyprfrijol/settings.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (t === root._written && root.loaded) return;      // el eco de lo que acabamos de guardar
            try {
                const u = JSON.parse(t);
                if (saveTimer.running) { Object.assign(u, root._dirty); for (const k of root._gone) delete u[k]; }
                root.user = u;
            } catch (e) {
                // Archivo roto (una coma de más al editarlo a mano): copia aparte antes de que el próximo cambio lo pise
                if (t.trim() !== "") {
                    console.warn("[settings] settings.json no es JSON válido; copia en settings.json.roto");
                    Quickshell.execDetached(["cp", "-f", path, path + ".roto"]);
                }
            }
            root.loaded = true;
        }
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
            const keys = Object.keys(root._dirty).concat(root._gone);
            root._dirty = ({}); root._gone = [];
            root._written = JSON.stringify(root.user, null, 2) + "\n";
            userFile.setText(root._written);
            if (!keys.length || keys.some(k => !root._shellOnly.includes(k))) root.apply();
        }
    }
    Process { id: mkdir; command: ["mkdir", "-p", Paths.home + "/.config/hyprfrijol"] }
    Process { id: applier; command: [Paths.script("hf-apply")]; onExited: if (root._again) { root._again = false; running = true; } }
}
