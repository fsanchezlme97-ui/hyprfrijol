pragma Singleton
// Compatibilidad con Omarchy · qs.Commons.Util: funciones puras que usan los plugins (alpha, clamp, shellQuote,
// execArgv, execDetached, fileUrl, parseModuleJson, readingKey, editsFilter…). Mismo comportamiento que en Omarchy
// (shell/Commons/Util.qml, leído el 2026-11-07), escrito de nuevo para hyprfrijol.
import QtQuick
import Quickshell

QtObject {
    function itemContainsPoint(target, source, x, y) {
        if (!target || !target.contains(target.mapFromItem(source, x, y))) return false;
        for (let it = target; it; it = it.parent) {
            if (!it.visible || it.opacity === 0 || !it.enabled) return false;
            if (it.clip && !it.contains(it.mapFromItem(source, x, y))) return false;
        }
        return true;
    }
    function clamp(value, min, max) { const n = Number(value); return isFinite(n) ? Math.max(min, Math.min(max, n)) : min; }
    function clampAlpha(value) { return clamp(value, 0, 1); }
    function wheelSteps(acc, delta) {
        delta = Math.max(-120, Math.min(120, delta));
        if (acc * delta < 0) acc = 0;
        const total = acc + delta;
        const steps = total < 0 ? Math.ceil(total / 120) : Math.floor(total / 120);
        return { steps: steps, remainder: total - steps * 120 };
    }
    function alpha(c, opacity) {
        const a = clampAlpha(opacity);
        if (!c) return Qt.rgba(0, 0, 0, a);
        const q = typeof c === "string" ? Qt.color(c) : c;
        return Qt.rgba(q.r, q.g, q.b, a);
    }
    function fileUrl(path) { return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : ""; }
    function isVideoPath(path) { return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(String(path ?? "")); }
    function shellQuote(value) { return "'" + String(value ?? "").replace(/'/g, "'\\''") + "'"; }
    function execDetached(command) { Quickshell.execDetached(["bash", "-lc", String(command)]); }
    function execArgv(argv) { Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv)); }
    function isPlainObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
    function canonicalWidgetId(id) { return String(id ?? ""); }
    function decodeBase64(v) { try { return v ? Qt.atob(String(v)) : ""; } catch (e) { return ""; } }
    function cloneJson(v) { return JSON.parse(JSON.stringify(v === undefined ? null : v)); }
    function parseModuleJson(raw) {
        const t = String(raw ?? "").trim();
        if (!t) return ({});
        const lines = t.split("\n");
        try { return JSON.parse(lines[lines.length - 1]); } catch (e) { return { text: t }; }
    }
    function readingKey(event, vim) {
        let k = event.key;
        if (vim && (k === Qt.Key_H || event.text === "h")) k = Qt.Key_Left;
        else if (vim && (k === Qt.Key_L || event.text === "l")) k = Qt.Key_Right;
        return k;
    }
    function editsFilter(event, text) {
        if (!text) return false;
        if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return false;
        if (event.key === Qt.Key_U) return event.modifiers === Qt.ControlModifier;
        return event.key === Qt.Key_Backspace;
    }
    function editedFilter(event, text) {
        if (event.key === Qt.Key_U) return "";
        if (event.modifiers & Qt.ControlModifier) return text.replace(/\s+$/, "").replace(/\S+$/, "");
        return text.slice(0, -1);
    }
    function normalizeLayoutEntry(e) {
        if (typeof e === "string") return { id: e };
        if (isPlainObject(e) && e.id) { const c = cloneJson(e); c.id = String(c.id); return c; }
        return null;
    }
    function normalizeLayoutSection(list) { return Array.isArray(list) ? list.map(normalizeLayoutEntry).filter(e => e) : []; }
    readonly property var barSections: ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
    function normalizeLayout(layout) {
        const src = isPlainObject(layout) ? layout : {};
        const out = {};
        for (const s of barSections) out[s] = normalizeLayoutSection(src[s]);
        return out;
    }
}
