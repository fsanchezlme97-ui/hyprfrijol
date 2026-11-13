// Pestañas de Ajustes › Barra: la barra en sí (sections/Barra.qml, la entrada de la lista) y sus widgets
// (BarWidgets.qml, under: "barra" en SettingsApp); cada una sigue siendo su propia sección (búsqueda, enlaces).
//   BarTabs { current: "barra" | "barwidgets" }
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["barra", "Barra"], ["barwidgets", "Widgets"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
