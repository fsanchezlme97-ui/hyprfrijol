// Botón de Aplicaciones (abre el Spotlight en «Todas las apps»): logo de la distribución en monocromo
// (blanco en temas oscuros, negro en claros; services/OsLogo). Sin logo: la pastilla del acento con ⌘.
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    property real side: 24
    readonly property bool logo: OsLogo.available
    implicitWidth: side; implicitHeight: side; radius: Theme.r(7)
    color: logo ? (ma.containsMouse || Shell.view === "spotlight" ? Theme.fill2 : "transparent") : Theme.p
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    Image {
        anchors.centerIn: parent
        visible: root.logo
        width: Math.round(root.side * 0.72); height: width
        sourceSize: Qt.size(width * 2, height * 2)
        smooth: true
        fillMode: Image.PreserveAspectFit
        source: root.logo ? OsLogo.source(Theme.light ? "#000000" : "#FFFFFF") : ""
    }
    Icon { anchors.centerIn: parent; visible: !root.logo; name: "command"; size: 15; color: Theme.pText }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: Shell.preload("spotlight"); onPressed: Shell.toggle("spotlight", "mode:apps") }
    BarTip { target: ma; text: "Aplicaciones" }
}
