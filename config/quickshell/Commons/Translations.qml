// Compatibilidad con Omarchy · Commons.Translations: catálogos JSON del plugin en su carpeta i18n/.
//   Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }   strings.t("clave") · strings.tn("clave", n)
// hyprfrijol pide es.json y, si falta una cadena, en.json (como Omarchy: idioma → idioma base → inglés → clave).
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var directory: ""
    readonly property string language: "es"
    readonly property string baseLanguage: "es"
    readonly property string directoryPath: decodeURIComponent(String(directory).replace(/^file:\/\//, "")).replace(/\/+$/, "")
    readonly property var englishStrings: parse(englishFile.loaded ? englishFile.text() : "")
    readonly property var languageStrings: parse(languageFile.loaded ? languageFile.text() : "")
    readonly property var strings: Object.assign({}, englishStrings, languageStrings)

    function parse(raw) { try { const o = JSON.parse(raw || "{}"); return o && typeof o === "object" ? o : ({}); } catch (e) { return ({}); } }
    function t(key, fallback) { const v = strings[key]; return typeof v === "string" ? v : (fallback ?? key); }
    function tn(key, count, fallback) {
        const v = strings[key];
        if (v && typeof v === "object") { const c = Number(count) === 1 ? "one" : "other"; return String(v[c] ?? v.other ?? v.one ?? fallback ?? key); }
        return typeof v === "string" ? v : (fallback ?? key);
    }
    property FileView englishFile: FileView { path: root.directoryPath ? root.directoryPath + "/en.json" : ""; printErrors: false; blockLoading: true }
    property FileView languageFile: FileView { path: root.directoryPath ? root.directoryPath + "/es.json" : ""; printErrors: false; blockLoading: true }
}
