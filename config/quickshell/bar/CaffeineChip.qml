// Indicador de cafeína en la barra (módulo «cafeina» de barModules): taza, resaltada mientras la pantalla no se
// puede apagar por inactividad. Clic: activar/desactivar · clic derecho: 1 hora · la ayuda dice cuánto queda.
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: chip
    property bool vertical: false
    implicitWidth: 26
    implicitHeight: vertical ? 26 : 22
    radius: Theme.r(7)
    color: Caffeine.on ? Theme.p : ma.containsMouse ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    Icon { anchors.centerIn: parent; name: "coffee"; size: 15; color: Caffeine.on ? Theme.pText : Theme.t; opacity: Caffeine.on ? 1 : 0.75 }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? Caffeine.set(true, 60) : Caffeine.toggle()
    }
    BarTip {
        target: ma
        text: Caffeine.on ? "Cafeína activa" + (Caffeine.left ? " · quedan " + Caffeine.left : "") + " · clic para apagar"
                          : "Cafeína: no apagar la pantalla · clic derecho: 1 hora"
    }
}
