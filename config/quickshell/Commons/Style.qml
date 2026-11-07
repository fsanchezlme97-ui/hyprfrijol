pragma Singleton
// Compatibilidad con Omarchy · qs.Commons.Style → medidas y movimiento de hyprfrijol.
// Cubre lo que usan los plugins publicados (leídos el 2026-11-07 en plugins.omarchy.org, ver dev/DESARROLLO.md):
// Style.space(px) / spaceReal(px), Style.font.* (caption…displayLarge, family), Style.spacing.*, Style.cornerRadius,
// Style.gapsOut, Style.bar.* (sizeHorizontal, iconSlot, iconFont…), los estados de los controles
// (hoverFillFor, selectedFillFor, normalBorderWidth…), Style.duration(ms) y Style.easeOut.
// Omarchy los lee de shell.toml; aquí salen de Theme (escala del texto, «reducir movimiento», redondeo) y Settings.
import QtQuick
import ".."

QtObject {
    id: root

    readonly property int cornerRadius: Theme.ctlRadius
    readonly property int gapsOut: Math.max(4, Number(Settings.get("gapsOut", 4)) || 4)
    readonly property var styleOverrides: ({})

    // ---------- estados de los controles (tabla [controls] de Omarchy, con sus valores por defecto)
    readonly property string normalColorToken: "foreground"
    readonly property string hoverColorToken: "foreground"
    readonly property string selectedColorToken: "foreground"
    readonly property string pressedColorToken: "foreground"
    readonly property string focusColorToken: "accent"
    readonly property string selectionColorToken: "foreground"
    readonly property int normalBorderWidth: Theme.borderWidth > 0 ? 1 : 0
    readonly property int hoverBorderWidth: normalBorderWidth
    readonly property int selectedBorderWidth: 0
    readonly property int focusBorderWidth: 1
    readonly property real normalFillAlpha: 0.04
    readonly property real hoverFillAlpha: 0.08
    readonly property real selectedFillAlpha: 0.18
    readonly property real pressedFillAlpha: 0.22
    readonly property real focusFillAlpha: hoverFillAlpha
    readonly property real selectionFillAlpha: 0.35
    readonly property real normalBorderAlpha: 0.4
    readonly property real hoverBorderAlpha: 0.25
    readonly property real selectedBorderAlpha: 1.0
    readonly property real focusBorderAlpha: 0.6

    function _a(c, a) { if (!c) return Qt.rgba(0, 0, 0, a); const q = typeof c === "string" ? Qt.color(c) : c; return Qt.rgba(q.r, q.g, q.b, a); }
    function colorFromHex(value, fallback) { const s = String(value ?? ""); return /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(s) ? s : fallback; }
    function resolveStateColor(token, foreground, accent, urgent, fallback) {
        if (token === "accent") return accent ?? Theme.p;
        if (token === "urgent") return urgent ?? Theme.danger;
        if (token === "background") return Theme.s1;
        if (token === "foreground") return foreground ?? Theme.t;
        return colorFromHex(token, fallback ?? foreground ?? Theme.t);
    }
    function normalStateColor(f, a, u) { return resolveStateColor(normalColorToken, f, a, u); }
    function hoverStateColor(f, a, u) { return resolveStateColor(hoverColorToken, f, a, u); }
    function selectedStateColor(f, a, u) { return resolveStateColor(selectedColorToken, f, a, u); }
    function pressedStateColor(f, a, u) { return resolveStateColor(pressedColorToken, f, a, u); }
    function focusStateColor(f, a, u) { return resolveStateColor(focusColorToken, f, a, u); }
    function selectionStateColor(f, a, u) { return resolveStateColor(selectionColorToken, f, a, u); }
    function mutedColorFor(f) { return _a(f ?? Theme.t, 0.6); }
    function normalFillFor(f, a, u) { return _a(normalStateColor(f, a, u), normalFillAlpha); }
    function hoverFillFor(f, a, u) { return _a(hoverStateColor(f, a, u), hoverFillAlpha); }
    function selectedFillFor(f, a, u) { return _a(selectedStateColor(f, a, u), selectedFillAlpha); }
    function pressedFillFor(f, a, u) { return _a(pressedStateColor(f, a, u), pressedFillAlpha); }
    function focusFillFor(f, a, u) { return _a(focusStateColor(f, a, u), focusFillAlpha); }
    function selectionFillFor(f, a, u) { return _a(selectionStateColor(f, a, u), selectionFillAlpha); }
    function normalBorderFor(f, a, u) { return _a(normalStateColor(f, a, u), normalBorderAlpha); }
    function hoverBorderFor(f, a, u) { return _a(hoverStateColor(f, a, u), hoverBorderAlpha); }
    function selectedBorderFor(f, a, u) { return _a(selectedStateColor(f, a, u), selectedBorderAlpha); }
    function focusBorderFor(f, a, u) { return _a(focusStateColor(f, a, u), focusBorderAlpha); }
    function controlFill(focused, hot, f, a) { return focused ? focusFillFor(f, a) : hot ? hoverFillFor(f, a) : "transparent"; }
    function controlBorder(focused, hot, f, a) { return focused ? focusBorderFor(f, a) : hot ? hoverBorderFor(f, a) : normalBorderFor(f, a); }
    function controlBorderWidth(focused, hot) { return focused ? focusBorderWidth : hot ? hoverBorderWidth : normalBorderWidth; }
    function withAlpha(c, a) { return _a(c, a); }

    readonly property color normalFill: normalFillFor(Theme.t, Theme.p)
    readonly property color hoverFill: hoverFillFor(Theme.t, Theme.p)
    readonly property color selectedFill: selectedFillFor(Theme.t, Theme.p)
    readonly property color pressedFill: pressedFillFor(Theme.t, Theme.p)
    readonly property color focusFillColor: focusFillFor(Theme.t, Theme.p)
    readonly property color normalBorderColor: normalBorderFor(Theme.t, Theme.p)
    readonly property color hoverBorderColor: hoverBorderFor(Theme.t, Theme.p)
    readonly property color selectedBorderColor: selectedBorderFor(Theme.t, Theme.p)
    readonly property color focusBorderColor: focusBorderFor(Theme.t, Theme.p)
    readonly property color selectedAccentFill: _a(Theme.p, selectedFillAlpha)
    readonly property color selectionFill: selectionFillFor(Theme.t, Theme.p)

    // ---------- espaciado: Omarchy escala con [spacing] scale × tamaño del texto; aquí con la escala del texto
    readonly property real fontScale: Theme.scale
    readonly property real spacingScale: 1.0
    readonly property bool spacingScaleWithFont: true
    readonly property real effectiveSpacingScale: spacingScale * fontScale
    function spaceReal(px) { return Number(px) * effectiveSpacingScale; }
    function space(px) { return Math.round(Number(px) * effectiveSpacingScale); }
    readonly property QtObject spacing: QtObject {
        readonly property real scale: root.effectiveSpacingScale
        readonly property int hairline: Math.max(1, root.space(1))
        readonly property int xxs: root.space(2)
        readonly property int xs: root.space(3)
        readonly property int sm: root.space(4)
        readonly property int md: root.space(6)
        readonly property int lg: root.space(8)
        readonly property int xl: root.space(10)
        readonly property int xxl: root.space(12)
        readonly property int xxxl: root.space(14)
        readonly property int huge: root.space(18)
        readonly property int small: sm
        readonly property int medium: md
        readonly property int large: lg
        readonly property int controlGap: root.space(8)
        readonly property int controlPaddingX: root.space(10)
        readonly property int controlPaddingY: root.space(6)
        readonly property int inputPaddingY: root.space(7)
        readonly property int controlHeight: root.space(28)
        readonly property int popupRowHeight: root.space(28)
        readonly property int dropdownWidth: root.space(240)
        readonly property int searchableDropdownWidth: root.space(260)
        readonly property int numberFieldWidth: root.space(120)
        readonly property int searchablePopupMinHeight: root.space(220)
        readonly property int rowGap: root.space(8)
        readonly property int rowPaddingX: root.space(12)
        readonly property int labelGap: root.space(4)
        readonly property int panelGap: root.space(14)
        readonly property int panelPadding: root.space(18)
        readonly property int popupPadding: root.space(14)
    }

    // ---------- tipografía (escala rem de Omarchy sobre 12 px × escala del texto de hyprfrijol)
    readonly property string fontFamily: Theme.font
    readonly property string resolvedFontFamily: Theme.font
    readonly property string menuFontFamily: Theme.font
    readonly property int fontBaseSize: Math.round(12 * Theme.scale)
    readonly property var fontOverrides: ({})
    function fontPx(mult) { return Math.max(1, Math.round(fontBaseSize * Number(mult))); }
    readonly property QtObject font: QtObject {
        readonly property string family: root.fontFamily
        readonly property string resolvedFamily: root.resolvedFontFamily
        readonly property string menuFamily: root.menuFontFamily
        readonly property string mono: Theme.mono
        readonly property int baseSize: root.fontBaseSize
        readonly property int caption: root.fontPx(0.833)
        readonly property int bodySmall: root.fontPx(0.917)
        readonly property int body: root.fontPx(1.0)
        readonly property int subtitle: root.fontPx(1.083)
        readonly property int title: root.fontPx(1.167)
        readonly property int heading: root.fontPx(1.333)
        readonly property int display: root.fontPx(2.0)
        readonly property int displayLarge: root.fontPx(2.333)
        readonly property int iconSmall: bodySmall
        readonly property int icon: title
        readonly property int iconLarge: root.fontPx(1.5)
    }

    // ---------- barra: el contenido de la barra de hyprfrijol se dibuja a 32 px y se escala (Settings.barScale)
    readonly property bool barScaleWithFont: false
    readonly property var barOverrides: ({})
    readonly property QtObject bar: QtObject {
        readonly property int sizeHorizontal: 32
        readonly property int sizeVertical: 36
        readonly property int notchHeight: 0
        readonly property int iconSlot: 27
        readonly property int iconCanvas: 16
        readonly property int iconFont: 14
        readonly property int iconSize: 13
        readonly property int statusSlot: 21
    }

    // Colores de estado que piden algunos plugins (no están en Omarchy: alias inofensivos)
    readonly property QtObject status: QtObject {
        readonly property color success: Theme.light ? "#2E7D32" : "#A6E3A1"
        readonly property color warning: Theme.light ? "#B26A00" : "#F9E2AF"
        readonly property color critical: Theme.danger
    }
    readonly property QtObject surface: QtObject {
        readonly property color fg: Theme.t
        readonly property color bg: Theme.s1
    }
    readonly property int tooltipDelay: 500

    // ---------- movimiento: 0 con «Reducir movimiento» o el preset «ninguno»
    readonly property bool reduceMotion: Theme.still
    function duration(ms) { return Theme.still ? 0 : Number(ms); }
    readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

    // Omarchy los usa para releer shell.toml; aquí no hacen nada
    function refresh() {}
    function scheduleRefresh() {}
    function applyShellValues(values) {}
    function applyShellTheme() {}
}
