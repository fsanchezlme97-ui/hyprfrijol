// Pomodoro en la barra: anillo con el progreso del bloque (color del modo) + tiempo restante.
//   clic: ventana del pomodoro (vista "w-pomodoro": iniciar, pausar, saltar, duraciones)
//   pasar el cursor: el anillo se vuelve ▶/❚❚ (clic ahí: iniciar/pausar) · clic central: iniciar/pausar
//   clic derecho: reiniciar · rueda (parado): ±1 min al bloque actual
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-pomodoro"
    readonly property color modeColor: Pomodoro.mode === "foco" ? Theme.p : Pomodoro.mode === "largo" ? Theme.tv : Theme.ter
    implicitHeight: vertical ? vcol.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    onRightClicked: Pomodoro.reset()

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => { if (!Pomodoro.running) Pomodoro.adjust(e.angleDelta.y > 0 || e.angleDelta.x > 0 ? 1 : -1); }
    }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: Pomodoro.toggle() }

    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 6
        Item {
            implicitWidth: 13; implicitHeight: 13
            ProgressRing {
                anchors.fill: parent
                visible: !chip.hovered
                value: Pomodoro.progress
                color: chip.modeColor
                lineWidth: 2.2
                // parado y sin empezar: un punto lleno, como en el diseño
                Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: Pomodoro.running ? chip.modeColor : Theme.o; visible: !Pomodoro.running || Pomodoro.progress === 0 }
            }
            Icon { anchors.centerIn: parent; visible: chip.hovered; name: Pomodoro.running ? "pause" : "play"; size: 12; color: chip.modeColor }
            MouseArea { anchors { fill: parent; margins: -4 } cursorShape: Qt.PointingHandCursor; onClicked: Pomodoro.toggle() }
        }
        Txt { text: Pomodoro.time; weight: Font.DemiBold; tabular: true; opacity: Pomodoro.running || !Pomodoro.active ? 1 : 0.7 }
    }
    ColumnLayout {
        id: vcol
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 2
        ProgressRing { Layout.alignment: Qt.AlignHCenter; implicitWidth: 12; implicitHeight: 12; value: Pomodoro.progress; color: chip.modeColor; lineWidth: 2 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: Math.ceil(Pomodoro.left / 60) + "m"; size: 10.5; weight: Font.DemiBold; tabular: true }
    }
}
