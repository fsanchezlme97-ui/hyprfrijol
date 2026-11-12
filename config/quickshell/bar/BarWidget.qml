// Un widget movible de la barra por su id (Settings.barWidgetIds o «propio:<id>»). BarH/BarV lo repiten por islas
// (Settings.barZone) con un separador entre información y utilidades. Acciones propias de clic derecho y rueda
// (barActions[id] = { rclick, up, down }): se ponen encima del widget solo si hay alguna.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"

Loader {
    id: root
    required property string wid
    property bool vertical: false
    readonly property bool shown: item ? (item.want ?? true) : false
    readonly property var acts: (Settings.get("barActions", {}) ?? {})[wid] ?? {}
    readonly property var custom: wid.startsWith("propio:") ? (Settings.barCustomList.find(c => "propio:" + c.id === wid) ?? null) : null
    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    sourceComponent: custom ? cPropio : ({ clima: cClima, recursos: cRecursos, impresora: cImpresora, bongo: cBongo, pomodoro: cPomo,
                       cafeina: cCafe, portapapeles: cClip, dictado: cDict, ia: cIa, ajustes: cGear })[wid] ?? null

    Component { id: cClima; WeatherChip { vertical: root.vertical } }
    Component { id: cRecursos; StatsChip { vertical: root.vertical } }
    Component { id: cImpresora; PrinterChip { vertical: root.vertical } }
    Component { id: cBongo; BongoChip { vertical: root.vertical } }
    Component { id: cPomo; PomodoroChip { vertical: root.vertical } }
    Component { id: cCafe; CaffeineChip { vertical: root.vertical } }
    Component { id: cClip; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "clipboard"; tooltip: root.vertical ? "" : "Portapapeles"; preload: "spotlight"; onClicked: Shell.toggle("spotlight", "mode:clip") } }
    Component { id: cDict; MicBtn { implicitHeight: root.vertical ? 26 : 22 } }
    Component { id: cIa; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "ai"; preload: "ia"; active: Shell.view === "ia" || Shell.sideShown; onClicked: Shell.toggle("ia") } }
    Component { id: cGear; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "gear"; onClicked: Shell.open("ajustesapp") } }
    Component { id: cPropio; CustomChip { vertical: root.vertical; conf: root.custom } }

    // Clic derecho y rueda propios: lo demás (clic, pasar el cursor) sigue llegando al widget
    MouseArea {
        anchors.fill: parent
        z: 1
        visible: !!(root.acts.rclick || root.acts.up || root.acts.down)
        acceptedButtons: root.acts.rclick ? Qt.RightButton : Qt.NoButton
        onClicked: Quickshell.execDetached(["sh", "-c", root.acts.rclick])
        onWheel: w => {
            const c = w.angleDelta.y > 0 ? root.acts.up : root.acts.down;
            if (c) Quickshell.execDetached(["sh", "-c", c]);
            else w.accepted = false;
        }
    }
}
