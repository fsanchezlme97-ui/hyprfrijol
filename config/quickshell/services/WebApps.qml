pragma Singleton
// Web apps (ajuste "webapps"): lista del usuario + catálogo de populares (services/webapps-catalog.json, el mismo
// que lee scripts/hf-webapp). Lo usan Ajustes › Web apps, Ajustes › Panel lateral, el panel lateral y la música.
//   list                    [{ key, name, url, icon?, mode?, layout?, zoom?, tema?, css?, keybind, notify }]
//   preset(a)               entrada del catálogo que corresponde (por clave o por dominio), o {}
//   modeOf(a | clave)       "panel" (pestaña del panel lateral) | "ventana" (ventana propia integrada) | "navegador"
//                           (modo app del navegador). Sin «mode» guardado: como antes (webappEngine + sidePanelApps)
//   iconOf(a | clave)       ruta del icono del tema (Papirus) o "" → se dibuja la inicial
//   byName(nombre)          web app cuyo nombre coincide (el reproductor MPRIS de una web app integrada se llama así)
//   panelWidth(a, base, monW)  ancho de su pestaña en el panel lateral: «panelWidth» de la web app ("auto" = un tercio
//                           de la pantalla, como una columna de un mosaico de 3 | "panel" | px); nunca más de la mitad
//   third(monW)             ese tercio (también el ancho del panel fijado, en todas sus pestañas)
//   panelZoom               zoom de partida de las web apps del panel (90 %: caben más cosas en la columna)
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    readonly property var defaults: [
        { key: "wa", name: "WhatsApp", url: "https://web.whatsapp.com", keybind: "", notify: true },
        { key: "yt", name: "YouTube", url: "https://www.youtube.com", keybind: "", notify: false },
        { key: "pin", name: "Pinterest", url: "https://www.pinterest.com", keybind: "", notify: false },
        { key: "gmail", name: "Gmail", url: "https://mail.google.com", keybind: "", notify: true },
        { key: "calendario", name: "Calendario", url: "https://calendar.google.com", keybind: "", notify: true },
        { key: "notion", name: "Notion", url: "https://www.notion.so", keybind: "", notify: false }
    ]
    readonly property var list: {
        const w = Settings.get("webapps", null);
        return (Array.isArray(w) ? w : defaults).filter(a => a && a.key);
    }
    readonly property var catalog: {
        try { return JSON.parse(catFile.text()).apps ?? []; } catch (e) { return []; }
    }
    FileView { id: catFile; path: Paths.root + "/config/quickshell/services/webapps-catalog.json"; blockLoading: true; printErrors: false }

    function hostOf(u): string { return String(u ?? "").replace(/^[a-z]+:\/\//i, "").replace(/[\/?#].*$/, "").replace(/^www\./, "").toLowerCase(); }
    function find(a) { return typeof a === "string" ? (list.find(x => x.key === a) ?? catalog.find(x => x.key === a) ?? null) : a; }
    function preset(a) {
        a = find(a);
        if (!a) return {};
        const h = hostOf(a.url);
        return catalog.find(c => h && hostOf(c.url) === h) ?? (h ? null : catalog.find(c => c.key === a.key)) ?? {};
    }
    readonly property var panelApps: {
        const a = Settings.get("sidePanelApps", null);
        return Array.isArray(a) ? a : ["ia"];   // solo el asistente; las web apps se añaden en Ajustes
    }
    function modeOf(a): string {
        a = find(a);
        if (!a) return "navegador";
        // El panel lateral ya no aloja web apps (0.8.8): las que estaban en él se abren en el navegador
        return a.mode === "ventana" ? "ventana" : "navegador";
    }
    function iconName(a): string {
        a = find(a);
        if (!a) return "";
        return String(a.icon ?? preset(a).icon ?? "");
    }
    function iconOf(a): string {
        const n = iconName(a);
        return n ? Quickshell.iconPath(n, true) : "";
    }
    function byName(n) {
        const s = String(n ?? "").trim().toLowerCase();
        return s ? (list.find(a => String(a.name).toLowerCase() === s) ?? null) : null;
    }
    readonly property real panelZoom: 0.9
    // Una columna de un mosaico de 4 (ancho por defecto del panel lateral)
    function quarter(monW): real { return Math.round(Math.max(320, ((Number(monW) || 1920) - 16) / 4)); }
    function third(monW): real { return Math.round(Math.max(320, ((Number(monW) || 1920) - 16) / 3)); }
    function panelWidth(a, base, monW): real {
        a = find(a);
        if (!a) return base;
        const v = a.panelWidth ?? "auto";
        // "auto"/"tercio": un tercio de la pantalla; "panel": el ancho del asistente (Ajustes › Panel lateral › Ancho)
        const w = v === "panel" ? base : Number(v) > 0 ? Number(v) : third(monW);
        const max = Math.max(base, Math.floor((Number(monW) || 1920) * 0.5));
        return Math.round(Math.max(320, Math.min(w, max)));
    }
    readonly property var widths: [["auto", "Un tercio"], ["panel", "Como el panel"], [600, "600 px"], [800, "800 px"]]
    // Pestaña del panel lateral activada/desactivada (Ajustes › Panel lateral): «panel» al activarla; al quitarla, el
    // modo de antes (sin «mode» → navegador, como siempre)
    function setPanelMode(k, on): void {
        const l = list.map(a => {
            if (a.key !== k) return a;
            const b = Object.assign({}, a);
            if (on) b.mode = "panel"; else if (b.mode === "panel") delete b.mode;
            return b;
        });
        Settings.set("webapps", l);
    }
    // Lanzar con el modo elegido (hf-webapp open decide: panel lateral, ventana propia o navegador)
    function open(k): void { Quickshell.execDetached([Paths.script("hf-webapp"), "open", k]); }
    readonly property var modes: [["navegador", "Navegador"], ["ventana", "Ventana propia"]]
}
