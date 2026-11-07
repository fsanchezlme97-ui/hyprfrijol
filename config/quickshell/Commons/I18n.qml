pragma Singleton
// Compatibilidad con Omarchy · qs.Commons.I18n. hyprfrijol está en español: language "es", formato es-ES.
// t(clave) devuelve las pocas cadenas comunes de Omarchy que usan sus componentes (common.*) o la propia clave.
import QtQuick

QtObject {
    readonly property string language: "es"
    readonly property string formatLocale: "es-ES"
    readonly property string decimal: ","
    readonly property string zeroDigit: "0"
    readonly property bool rightToLeft: false
    readonly property var strings: ({ "common.yes": "Sí", "common.no": "No", "common.cancel": "Cancelar", "common.confirm": "Confirmar",
        "common.close": "Cerrar", "common.ok": "Aceptar", "common.save": "Guardar", "common.delete": "Borrar", "common.remove": "Quitar",
        "common.loading": "Cargando…", "common.error": "Error", "common.settings": "Ajustes", "common.open": "Abrir" })
    function t(key, fallback) { const v = strings[key]; return typeof v === "string" ? v : (fallback ?? key); }
    function tn(key, count, fallback) { return t(key, fallback); }
    function formatNumber(value, decimals) {
        const n = Number(value);
        if (!isFinite(n)) return String(value);
        return Number(n.toFixed(decimals ?? 0)).toLocaleString(Qt.locale("es_ES"), "f", decimals ?? 0);
    }
}
