pragma Singleton
// Compatibilidad con Omarchy · qs.Commons.Border: especificaciones de borde { color, widths, gradient }.
// En hyprfrijol los bordes son planos (sin degradados de shell.toml): cada función devuelve un borde de un color.
import QtQuick
import ".."

QtObject {
    id: root
    function _spec(color, w) { const n = Math.max(0, Number(w) || 0); return { color: color ?? "transparent", widths: { top: n, right: n, bottom: n, left: n }, gradient: null }; }
    function none() { return _spec("transparent", 0); }
    function flat(color, width) { return _spec(color, width ?? 1); }
    function value(section, key) { return ""; }
    function valueOr(section, keys) { return ""; }
    function alpha(section, key, fallback) { return fallback; }
    function cssColor(color, opacity) { const c = Qt.color(color); return Qt.rgba(c.r, c.g, c.b, opacity ?? c.a); }
    function localOrSurfaceSpec(section, token, localColor, defaultColor, fallbackWidth, alphaKey) { return _spec(localColor ?? defaultColor, fallbackWidth ?? 1); }
    function surfaceSpec(section, token, fallbackColor, fallbackWidth, alphaKey) { return _spec(fallbackColor, fallbackWidth ?? 1); }
    function hyprlandActiveSpec(fallbackColor, fallbackWidth) { return _spec(fallbackColor ?? Theme.p, fallbackWidth ?? 2); }
    function controlSpec(state, foreground, accent, urgent) {
        const fg = foreground ?? Theme.t, ac = accent ?? Theme.p;
        if (state === "focus") return _spec(Style.focusBorderFor(fg, ac), Style.focusBorderWidth);
        if (state === "hover-cursor") return _spec(Style.hoverBorderFor(fg, ac), Style.hoverBorderWidth);
        if (state === "selected") return _spec(Style.selectedBorderFor(fg, ac), Style.selectedBorderWidth);
        return _spec(Style.normalBorderFor(fg, ac), Style.normalBorderWidth);
    }
    function controlHasWidth(state) { return true; }
    function withWidth(spec, width) { return _spec(spec ? spec.color : "transparent", width); }
    function isNone(spec) { return !spec || !spec.widths || Math.max(spec.widths.top, spec.widths.right, spec.widths.bottom, spec.widths.left) <= 0; }
    function needsOverlay(spec) { return false; }
    function canUseNative(spec) { return true; }
    function top(spec) { return spec && spec.widths ? spec.widths.top : 0; }
    function right(spec) { return spec && spec.widths ? spec.widths.right : 0; }
    function bottom(spec) { return spec && spec.widths ? spec.widths.bottom : 0; }
    function left(spec) { return spec && spec.widths ? spec.widths.left : 0; }
    function uniformWidth(spec) { return top(spec); }
    function color(spec) { return spec ? spec.color : "transparent"; }
}
