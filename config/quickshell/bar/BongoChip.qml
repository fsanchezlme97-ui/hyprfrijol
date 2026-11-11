// Gato bongo en la barra (módulo «bongo» de barModules, Ajustes › Barra): un gatito sobre la mesa que golpea con
// la pata izquierda o derecha cada vez que pulsas una tecla (services/Bongo.qml · scripts/hf-bongo, que solo dice
// la mano, nunca la tecla). Dibujo calcado del Bongo Cat de VS Code (kitgore/BongoCat, MIT) en bongo.js.
//   clic: dormirlo / despertarlo (deja de escuchar el teclado) · la ayuda dice el ritmo (teclas por minuto)
import QtQuick
import ".."
import "../components"
import "../services"
import "bongo.js" as BongoDraw

Rectangle {
    id: chip
    property bool vertical: false
    implicitWidth: vertical ? 26 : cat.width + 6
    implicitHeight: vertical ? 24 : 22
    radius: Theme.r(7)
    color: ma.containsMouse ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    // el lector del teclado solo corre mientras el gato se ve
    property bool counted: false
    function count(on: bool): void { if (on !== counted) { counted = on; Bongo.users += on ? 1 : -1; } }
    Component.onCompleted: count(visible)
    Component.onDestruction: count(false)
    onVisibleChanged: count(visible)

    // Trazos lisos calcados de los dibujos del Bongo Cat de VS Code (bongo.js; kitgore/BongoCat, MIT). La fuente
    // original se veía ondulada a este tamaño. ~13 px de alto (las chispas bajan un poco más), como la bandeja.
    Canvas {
        id: cat
        readonly property real s: chip.vertical ? 0.0125 : 0.0158
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        width: Math.ceil(1880 * s + 3); height: Math.ceil(1010 * s + 3)
        antialiasing: true
        opacity: Bongo.asleep ? 0.45 : 0.95
        readonly property color ink: Theme.t
        readonly property bool l: Bongo.left
        readonly property bool r: Bongo.right
        readonly property bool zz: Bongo.asleep
        onLChanged: requestPaint()
        onRChanged: requestPaint()
        onZzChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            BongoDraw.draw(c, s, 1.5, 1.5, l, r, zz, ink, chip.vertical ? 1.15 : 1.4);
        }
    }
    // dormido: «z»
    Txt {
        visible: Bongo.asleep
        anchors { right: parent.right; top: parent.top; rightMargin: 2 }
        text: "z"; size: 9; weight: Font.DemiBold; muted: true
    }
    // aviso: sin permiso para leer el teclado
    Rectangle {
        visible: Bongo.problem === "noperm" && !Bongo.asleep
        anchors { right: parent.right; top: parent.top; margins: 1 }
        width: 5; height: 5; radius: 2.5; color: Theme.danger
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Bongo.toggleSleep()
    }
    BarTip {
        target: ma
        text: Bongo.asleep ? "Gato bongo dormido · clic para despertarlo"
            : Bongo.problem === "noperm" ? "El gato no oye el teclado: añade tu usuario al grupo «input» (sudo usermod -aG input $USER) y vuelve a entrar"
            : Bongo.problem === "nokbd" ? "Gato bongo: no hay ningún teclado conectado"
            : "Gato bongo · " + Bongo.kpm + " teclas por minuto · " + Bongo.count + " en esta sesión · clic para dormirlo"
    }
}
