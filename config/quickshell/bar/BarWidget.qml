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
    sourceComponent: wid.startsWith("sep:") ? cSep : custom ? cPropio : ({ clima: cClima, recursos: cRecursos, impresora: cImpresora, bongo: cBongo, pomodoro: cPomo,
                       cafeina: cCafe, portapapeles: cClip, atajos: cAtajos, ia: cIa, ajustes: cGear })[wid] ?? null

    Component { id: cClima; WeatherChip { vertical: root.vertical } }
    Component { id: cRecursos; StatsChip { vertical: root.vertical } }
    Component { id: cImpresora; PrinterChip { vertical: root.vertical } }
    Component { id: cBongo; BongoChip { vertical: root.vertical } }
    Component { id: cPomo; PomodoroChip { vertical: root.vertical } }
    Component { id: cCafe; CaffeineChip { vertical: root.vertical } }
    Component { id: cClip; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "clipboard"; tooltip: root.vertical ? "" : "Portapapeles"; preload: "spotlight"; onClicked: Shell.toggle("spotlight", "mode:clip") } }
    Component { id: cAtajos; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "keyboard"; tooltip: root.vertical ? "" : "Atajos de teclado"; preload: "atajos"; onClicked: Shell.toggle("atajos") } }
    Component {
        id: cIa
        Rectangle {
            id: iaBtn
            implicitWidth: 26
            implicitHeight: root.vertical ? 26 : 22
            radius: Theme.pill ? Math.min(width, height) / 2 + 2 : Theme.r(7)
            // Botón único de Emma: abre su panel (ahí están el dictado y las órdenes de voz). Mientras escucha enseña
            // el micrófono, y el clic termina de escuchar.
            readonly property bool rec: Shell.dictPhase === "rec"
            color: rec ? Theme.ter : active ? Theme.p : "transparent"
            border.width: 0
            property bool active: Shell.view === "ia" || Shell.sideShown
            function act(): void { if (rec) Shell.voiceDo(Shell.dictKind === "comando" ? "comando" : "dictado"); else Shell.toggle("ia"); }
            opacity: enabled ? 1 : Theme.stDisabled
            activeFocusOnTab: true
            Keys.onPressed: e => { if (enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { iaBtn.act(); e.accepted = true; } }
            Behavior on scale { NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
            StateLayer { radius: iaBtn.radius; hovered: ma.containsMouse; pressed: ma.pressed; focused: iaBtn.activeFocus }
            Ripple { id: rip; anchors.fill: parent; radius: iaBtn.radius; color: active ? Theme.pcText : Theme.t }
            Icon {
                anchors.centerIn: parent; size: 15; stroke: 2
                name: iaBtn.rec ? "mic" : "ai"
                color: iaBtn.rec ? Theme.bg : iaBtn.active ? Theme.pText : Theme.t
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: Shell.preload("ia")
                onPressed: rip.burst(iaBtn.width / 2, iaBtn.height / 2)
                onClicked: iaBtn.act()
            }
        }
    }
    Component { id: cGear; IconBtn { implicitHeight: root.vertical ? 26 : 22; icon: "gear"; onClicked: Shell.open("ajustesapp") } }
    // Separador puesto a mano: una raya fina con aire a los lados
    Component { id: cSep; Item { implicitWidth: root.vertical ? 26 : 9; implicitHeight: root.vertical ? 9 : 22
        Divider { anchors.centerIn: parent; vertical: !root.vertical; implicitWidth: root.vertical ? 14 : 1 } } }
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
