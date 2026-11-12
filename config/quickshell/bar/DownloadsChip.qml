// Descargas en la barra: solo se ve mientras hay descargas en cola o en curso (o alguna falló), con su número y
// un anillo de progreso (Ajustes › Almacenamiento › Descargas › «Indicador en la barra», downloadsBarIcon).
// Clic: lista con pausar / cancelar / reintentar / abrir carpeta — vista "w-descargas" (modules/downloads).
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-descargas"
    want: Settings.get("downloadsBarIcon", true) !== false && (Downloads.active.length > 0 || Downloads.errors > 0 || chip.open)
    readonly property real prog: Downloads.progress
    readonly property bool failed: Downloads.active.length === 0 && Downloads.errors > 0
    implicitHeight: vertical ? vcol.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    Behavior on implicitWidth { enabled: !Theme.reduceMotion && !chip.vertical; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

    component Ring: Item {
        implicitWidth: 17; implicitHeight: 17
        Canvas {
            id: cv
            anchors.fill: parent
            // la cola se lee cada 1,5 s: el anillo avanza en ese rato en vez de saltar
            property real p: Math.max(0, chip.prog)
            Behavior on p { enabled: !Theme.still && chip.prog >= 0; NumberAnimation { duration: 1500; easing.type: Easing.Linear } }
            readonly property color base: Qt.alpha(Theme.t, 0.18)
            readonly property color fg: chip.failed ? Theme.danger : Theme.p
            onPChanged: requestPaint()
            onFgChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.lineWidth = 2;
                c.strokeStyle = base;
                c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 1.5, 0, Math.PI * 2); c.stroke();
                if (p > 0) {
                    c.strokeStyle = fg;
                    c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 1.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, p)); c.stroke();
                }
            }
            RotationAnimation on rotation { running: chip.prog < 0 && !Theme.reduceMotion; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
        }
        Icon { anchors.centerIn: parent; name: chip.failed ? "alert" : "download"; size: 9; stroke: 2.2; color: chip.failed ? Theme.danger : Theme.t }
    }

    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 5
        Ring {}
        Txt {
            visible: Downloads.active.length > 0
            text: Downloads.active.length > 1 || chip.prog < 0 ? String(Downloads.active.length) : Math.round(chip.prog * 100) + " %"
            tabular: true
        }
        Txt {
            visible: chip.hovered && Downloads.active.length > 1 && chip.prog >= 0
            text: "· " + Math.round(chip.prog * 100) + " %"
            muted: true; tabular: true
        }
    }
    ColumnLayout {
        id: vcol
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 2
        Ring { Layout.alignment: Qt.AlignHCenter }
        Txt { visible: Downloads.active.length > 0; Layout.alignment: Qt.AlignHCenter; text: String(Downloads.active.length); size: 10.5; tabular: true }
    }
}
