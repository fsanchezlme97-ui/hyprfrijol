// Compatibilidad con Omarchy · qs.Ui.BarWidget: base de los widgets de barra. La barra de hyprfrijol
// (bar/OmarchySlot.qml) le pone bar (fachada, ver modules/omarchy/BarApi.qml), moduleName, settings y fixedEdge.
import QtQuick
import qs.Commons

Item {
    id: root
    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})
    property string fixedEdge: "center"
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

    function broadcast(method) {
        const items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root];
        for (const it of items) if (it && typeof it[method] === "function") it[method]();
    }
    function setting(name, fallback) {
        const v = settings ? settings[name] : undefined;
        return v === undefined || v === null ? fallback : v;
    }
}
