// Pestañas de Ajustes › Productividad: enfoque y pomodoro (sections/Enfoque.qml, la entrada de la lista), Spotlight
// (Lanzador.qml), portapapeles (Portapapeles.qml) y agenda (Agenda.qml); cada una sigue siendo su
// propia sección por dentro (búsqueda, enlaces «ajustesapp agenda»), marcada con under: "enfoque" en SettingsApp.
//   ProdTabs { current: "enfoque" | "spotlight" | "portapapeles" | "agenda" }
// Las tareas y las alarmas son apps (su ventana): aquí solo se ajustan; Enfoque tiene los botones para abrirlas.
import QtQuick
import QtQuick.Layouts
import "../../.."

Seg {
    Layout.alignment: Qt.AlignLeft
    fill: false
    pill: true
    model: [["enfoque", "Enfoque y pomodoro"], ["spotlight", "Spotlight"], ["portapapeles", "Portapapeles"], ["agenda", "Agenda"]]
    onPicked: k => { if (k !== current) Shell.open("ajustesapp", k); }
}
