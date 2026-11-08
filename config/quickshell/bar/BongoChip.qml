// Gato bongo en la barra (módulo «bongo» de barModules, Ajustes › Barra): un gatito sobre la mesa que golpea con
// la pata izquierda o derecha cada vez que pulsas una tecla (services/Bongo.qml · scripts/hf-bongo, que solo dice
// la mano, nunca la tecla). Dibujo propio en Canvas con los colores del tema.
//   clic: dormirlo / despertarlo (deja de escuchar el teclado) · la ayuda dice el ritmo (teclas por minuto)
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: chip
    property bool vertical: false
    implicitWidth: vertical ? 26 : 36
    implicitHeight: vertical ? 24 : 22
    radius: Theme.r(7)
    color: ma.containsMouse ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur } }
    // el lector del teclado solo corre mientras el gato se ve
    property bool counted: false
    function count(on: bool): void { if (on !== counted) { counted = on; Bongo.users += on ? 1 : -1; } }
    Component.onCompleted: count(visible)
    Component.onDestruction: count(false)
    onVisibleChanged: count(visible)

    Canvas {
        id: cv
        anchors.centerIn: parent
        width: 34; height: 22
        scale: chip.vertical ? 0.72 : 1
        antialiasing: true
        readonly property color ink: Theme.t
        readonly property color fur: Theme.s4
        readonly property color blush: Theme.p
        readonly property bool l: Bongo.left
        readonly property bool r: Bongo.right
        readonly property bool zz: Bongo.asleep
        readonly property bool awake: Bongo.typing && !Bongo.asleep
        onLChanged: requestPaint()
        onRChanged: requestPaint()
        onZzChanged: requestPaint()
        onAwakeChanged: requestPaint()
        onInkChanged: requestPaint()
        onFurChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.lineWidth = 1.5;
            c.lineCap = "round"; c.lineJoin = "round";
            c.strokeStyle = ink;
            // cabeza y cuerpo: una gota redondeada con orejas
            c.beginPath();
            c.moveTo(8, 19);
            c.bezierCurveTo(7, 11, 10, 7, 12, 6.5);
            c.lineTo(12.5, 2.5); c.lineTo(15.5, 5.6);
            c.bezierCurveTo(16.6, 5.3, 18.4, 5.3, 19.5, 5.6);
            c.lineTo(22.5, 2.5); c.lineTo(23, 6.5);
            c.bezierCurveTo(25, 7, 28, 11, 27, 19);
            c.closePath();
            c.fillStyle = fur; c.fill(); c.stroke();
            // cara
            c.fillStyle = ink;
            if (zz || !awake) {   // ojos cerrados
                c.beginPath(); c.moveTo(12.8, 11.6); c.quadraticCurveTo(14, 12.6, 15.2, 11.6); c.stroke();
                c.beginPath(); c.moveTo(19.8, 11.6); c.quadraticCurveTo(21, 12.6, 22.2, 11.6); c.stroke();
            } else {
                c.beginPath(); c.arc(14, 11.4, 1.15, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.arc(21, 11.4, 1.15, 0, Math.PI * 2); c.fill();
            }
            // boca «w»
            c.lineWidth = 1.1;
            c.beginPath(); c.moveTo(16.2, 13.6); c.quadraticCurveTo(16.85, 14.6, 17.5, 13.7); c.quadraticCurveTo(18.15, 14.6, 18.8, 13.6); c.stroke();
            // mejillas
            c.globalAlpha = 0.45; c.fillStyle = blush;
            c.beginPath(); c.arc(11.8, 14.2, 1.1, 0, Math.PI * 2); c.fill();
            c.beginPath(); c.arc(23.2, 14.2, 1.1, 0, Math.PI * 2); c.fill();
            c.globalAlpha = 1;
            // mesa
            c.lineWidth = 1.5;
            c.beginPath(); c.moveTo(1.5, 19.5); c.lineTo(32.5, 19.5); c.stroke();
            // patas: arriba (levantada, a un lado de la cara) o abajo (golpe en la mesa)
            function paw(x, down) {
                c.fillStyle = fur;
                c.beginPath();
                if (down) {
                    c.ellipse(x - 2.6, 15.6, 5.2, 3.6);
                } else {
                    c.ellipse(x - 2.4, 9.4, 4.8, 4.2);
                }
                c.fill(); c.stroke();
                if (down) {   // chispa del golpe
                    c.beginPath(); c.moveTo(x - 4.5, 17); c.lineTo(x - 6, 15.8); c.moveTo(x + 4.5, 17); c.lineTo(x + 6, 15.8); c.stroke();
                }
            }
            c.lineWidth = 1.3;
            paw(6.5, l);
            paw(28.5, r);
            // dormido: «z»
            if (zz) {
                c.lineWidth = 1.1;
                c.beginPath(); c.moveTo(27, 2); c.lineTo(30, 2); c.lineTo(27, 5.2); c.lineTo(30, 5.2); c.stroke();
            }
        }
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
