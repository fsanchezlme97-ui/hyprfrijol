pragma Singleton
// Compatibilidad con Omarchy · qs.Commons.Color → Theme de hyprfrijol.
// Los plugins de la shell de Omarchy leen la paleta así: Commons.Color.foreground / background / accent / urgent /
// muted y los papeles por superficie (Color.bar.*, popups.*, tooltip.*, notifications.*, menu.*, polkit.*, lock.*,
// imagePicker.*). Aquí todos salen del tema activo de hyprfrijol (Theme.qml), así un plugin sigue la paleta, el
// modo claro/oscuro y el acento sin saber nada de hyprfrijol.
// Referencia (leída el 2026-11-07): github.com/omacom/omarchy · shell/Commons/Color.qml y docs/omarchy-shell.md.
import QtQuick
import ".."

QtObject {
    id: root

    readonly property string home: Paths.home
    readonly property string stateHome: home + "/.local/state"
    readonly property string currentThemePath: Paths.state

    readonly property color foreground: Theme.t
    readonly property color background: Theme.s1
    readonly property color accent: Theme.p
    readonly property color urgent: Theme.danger
    readonly property color muted: Theme.o

    // Omarchy guarda aquí las claves de shell.toml del tema. hyprfrijol no tiene shell.toml: siempre vacío,
    // así pick()/pickAlpha() devuelven su valor por defecto.
    readonly property var shellValues: ({})
    readonly property var themeShellValues: ({})
    readonly property var userShellValues: ({})

    function pick(key, fallback) { const v = shellValues[key]; return (typeof v === "string" && v.length > 0) ? v : fallback; }
    function pickAlpha(key, fallback) { return fallback; }
    function flatColor(value, fallback) {
        const s = String(value ?? "").trim().split(/\s+/)[0] ?? "";
        const role = s.toLowerCase();
        if (role === "foreground" || role === "text") return root.foreground;
        if (role === "accent") return root.accent;
        if (role === "urgent") return root.urgent;
        if (role === "muted") return root.muted;
        if (role === "background") return root.background;
        if (role === "transparent") return Qt.rgba(0, 0, 0, 0);
        if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)) return s;
        const m = s.match(/^rgba?\(([0-9a-f]{6})([0-9a-f]{2})?\)$/i);     // Hyprland: rgba(rrggbbaa)
        if (m) return "#" + (m[2] ?? "ff") + m[1];
        return fallback;
    }
    function composed(colorKey, alphaKey, colorFallback, alphaFallback) {
        const c = Qt.color(flatColor(pick(colorKey, colorFallback), colorFallback));
        return Qt.rgba(c.r, c.g, c.b, alphaFallback);
    }
    // Omarchy los llama al cambiar de tema; aquí el tema lo pone hf-apply
    function loadColors(raw) {}
    function loadShell(raw) {}
    function loadUserShell(raw) {}
    function mergeShell() {}
    function parseShell(raw) { return ({}); }

    readonly property QtObject bar: QtObject {
        readonly property color background: Theme.glass
        readonly property color text: Theme.t
        readonly property color active: Theme.p
    }
    readonly property QtObject popups: QtObject {
        readonly property color background: Theme.glassPopup
        readonly property color text: Theme.t
        readonly property color border: Theme.border
    }
    readonly property QtObject tooltip: QtObject {
        readonly property color background: Theme.s3
        readonly property color text: Theme.t
        readonly property color border: Theme.ov
    }
    readonly property QtObject notifications: QtObject {
        readonly property color background: Theme.glassPopup
        readonly property color text: Theme.t
        readonly property color border: Theme.border
        readonly property color countdown: Theme.p
    }
    readonly property QtObject menu: QtObject {
        readonly property color background: Theme.glassPopup
        readonly property color text: Theme.t
        readonly property color border: Theme.border
        readonly property color scrim: Qt.alpha(Theme.bg, 0.5)
        readonly property color selectedBackground: Theme.selBg
        readonly property color selectedText: Theme.selText
        readonly property color selectedBorder: "transparent"
    }
    readonly property QtObject polkit: QtObject {
        readonly property color background: Theme.glassPopup
        readonly property color text: Theme.t
        readonly property color textError: Theme.danger
        readonly property color border: Theme.border
        readonly property color borderError: Theme.danger
        readonly property color accent: Theme.p
        readonly property color scrim: Qt.alpha(Theme.bg, 0.5)
    }
    readonly property QtObject lock: QtObject {
        readonly property color background: Qt.alpha(Theme.s1, 0.8)
        readonly property color text: Theme.t
        readonly property color placeholder: Qt.alpha(Theme.t, 0.66)
        readonly property color textError: Theme.danger
        readonly property color border: Theme.ov
        readonly property color borderActive: Theme.p
        readonly property color borderError: Theme.danger
        readonly property color selection: Qt.alpha(Theme.p, 0.45)
    }
    readonly property QtObject imagePicker: QtObject {
        readonly property color text: Theme.t
        readonly property color selectedBorder: Theme.p
        readonly property color unselectedBorder: Qt.alpha(Theme.t, 0.28)
    }
}
