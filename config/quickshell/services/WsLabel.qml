pragma Singleton
// Numeración de los espacios (Ajustes › Escritorio y gestos › Espacios de trabajo, ajuste "wsNumerals"):
//   "japonesa" (por defecto: 一 二 三 …) · "arabiga" (1 2 3) · "romana" (I II III) · "puntos" (•)
// Los nombres e iconos propios ("wsNames", "wsIcons") ganan siempre al número.
//   WsLabel.numeral(3) → "三"   ·   WsLabel.font → familia con glifos CJK para la japonesa
import QtQuick
import Quickshell
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
    function fontFor(st): string { return (st ?? style) === "japonesa" ? "Noto Sans CJK JP" : Theme.font; }
}
