pragma Singleton
// Numeración de los espacios (Ajustes › Escritorio y gestos › Espacios de trabajo, ajuste "wsNumerals"):
//   "japonesa" (por defecto: 一 二 三 …) · "arabiga" (1 2 3) · "romana" (I II III) · "puntos" (•)
// Los nombres e iconos propios ("wsNames", "wsIcons") ganan siempre al número.
//   WsLabel.numeral(3) → "三"   ·   WsLabel.font → familia con glifos CJK para la japonesa
// Espacios por pantalla ("wsPerMonitor", por defecto sí): la pantalla k usa del k·10+1 al k·10+10, como
// HF.wsBase en binds.lua (la principal primero, luego las de Ajustes por nombre, luego las demás por id).
//   WsLabel.base("VGA-1") → 10   ·   WsLabel.local(13) → 3 (el número que se ve)   ·   WsLabel.owns("VGA-1", 13)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

Singleton {
    id: root
    readonly property string style: {
        const v = Settings.get("wsNumerals", "japonesa");
        return ["japonesa", "arabiga", "romana", "puntos"].includes(v) ? v : "japonesa";
    }
    readonly property var styles: [["japonesa", "Japonesa"], ["arabiga", "Arábiga"], ["romana", "Romana"], ["puntos", "Puntos"]]
    // Noto Sans CJK JP si está instalada (si no, Qt busca otra con esos glifos)
    readonly property string font: style === "japonesa" ? "Noto Sans CJK JP" : Theme.font
    readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    function japanese(n: int): string {
        if (n <= 10) return kanji[n] ?? String(n);
        if (n < 100) {
            const t = Math.floor(n / 10), u = n % 10;
            return (t > 1 ? kanji[t] : "") + "十" + (u ? kanji[u] : "");
        }
        return String(n);
    }
    function roman(n: int): string {
        if (n <= 0 || n >= 4000) return String(n);
        const v = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [k, l] of v) while (n >= k) { s += l; n -= k; }
        return s;
    }
    function numeral(n: int, st): string {
        const s = st ?? style;
        return s === "japonesa" ? japanese(n) : s === "romana" ? roman(n) : s === "puntos" ? "•" : String(n);
    }
    readonly property bool perMonitor: Settings.get("wsPerMonitor", true) !== false
    // Mismo orden que HF.wsOrder (config/hypr/frijol/workspaces.lua): la principal (la guardada si está conectada; si
    // no, la más grande conectada), las demás de Ajustes por nombre (no la principal guardada) y las nuevas por id
    readonly property var groups: {
        const mons = Hyprland.monitors.values;
        const saved = String(Settings.get("primaryMonitor", "") ?? "");
        let prim = saved;
        if (!mons.some(m => m.name === prim))
            prim = mons.reduce((a, m) => !a || m.width * m.height > a.width * a.height ? m : a, null)?.name ?? prim;
        // (la principal guardada no ocupa sitio si no está conectada)
        const known = Object.keys(Settings.get("monitors", ({})) ?? ({})).filter(n => n !== prim && n !== saved).sort();
        const g = (prim ? [prim] : []).concat(known);
        return g.concat(mons.filter(m => !g.includes(m.name)).sort((a, b) => a.id - b.id).map(m => m.name));
    }
    function base(monitorName): int {
        if (!perMonitor) return 0;
        const i = groups.indexOf(String(monitorName ?? ""));
        return i < 0 ? 0 : i * 10;
    }
    function local(id: int): int { return perMonitor && id > 10 ? (id - 1) % 10 + 1 : id; }
    function owns(monitorName, id: int): bool { const b = base(monitorName); return !perMonitor || (id > b && id <= b + 10); }
    function fontFor(st): string { return (st ?? style) === "japonesa" ? "Noto Sans CJK JP" : Theme.font; }
}
