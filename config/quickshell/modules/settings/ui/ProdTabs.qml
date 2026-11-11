// Pestañas de Ajustes › Productividad: enfoque y pomodoro (sections/Enfoque.qml, la entrada de la lista), Spotlight
// (Lanzador.qml), portapapeles (Portapapeles.qml), agenda y alarmas (Agenda.qml) y tareas (Tareas.qml); cada una sigue siendo su
// propia sección por dentro (búsqueda, enlaces «ajustesapp agenda»), marcada con under: "enfoque" en SettingsApp.
//   ProdTabs { current: "enfoque" | "spotlight" | "portapapeles" | "agenda" | "tareas" }
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["enfoque", "Enfoque y pomodoro"], ["spotlight", "Spotlight"], ["portapapeles", "Portapapeles"], ["agenda", "Agenda y alarmas"], ["tareas", "Tareas"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
