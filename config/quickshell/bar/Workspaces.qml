// Espacios (20×20, radio 6, 11.5 px seminegrita). Activo: fondo p; con ventanas: texto normal, vacío: atenuado. Clic → ir; rueda → siguiente/anterior.
// Ajustes (Escritorio y gestos › Espacios de trabajo):
//   "wsShowAll"  true (por defecto) → siempre del 1 al 9 (y cualquier otro ocupado); false → solo los
//                ocupados y el activo
//   "wsNumerals" numeración: japonesa (一 二 三, por defecto) · arábiga · romana · puntos (services/WsLabel.qml)
//   "wsPerMonitor" true (por defecto) → cada pantalla muestra solo sus espacios (WsLabel.base / local)
// Nombres e iconos ("wsNames", "wsIcons") ganan al número: en horizontal se ven «icono nombre» si
// "wsBarNames" (si no, el icono o el número); en vertical, el icono o el número.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"

Grid {
    id: root
    required property var screen
    property bool vertical: false
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    // Espacios por pantalla (WsLabel.perMonitor): solo los de esta pantalla, numerados del 1 al 10
    readonly property int base: WsLabel.base(monitor?.name)
    readonly property var occupied: Hyprland.workspaces.values.filter(w => w.id > 0 && w.toplevels.values.length > 0
        && (!WsLabel.perMonitor || w.monitor === monitor)).map(w => w.id)
    readonly property bool showAll: Settings.get("wsShowAll", true) !== false
    readonly property var ids: {
        const s = new Set(occupied);
        if (activeId > 0) s.add(activeId);
        if (showAll) for (let i = 1; i <= 9; i++) s.add(base + i);
        return [...s].sort((a, b) => a - b);
    }
    readonly property var names: Settings.get("wsNames", ({})) ?? ({})
    readonly property var icons: Settings.get("wsIcons", ({})) ?? ({})
    readonly property bool showNames: Settings.get("wsBarNames", true) !== false
    // Chroma: siempre puntos (como los Glyph de los Nothing Phone): el activo, una píldora roja
    readonly property bool dots: WsLabel.style === "puntos" || Theme.chroma
    // "" = sin nombre ni icono propio (se usa la numeración)
    function custom(n: int): string {
        const nm = String(names[String(n)] ?? ""), ic = String(icons[String(n)] ?? "");
        if (vertical) return ic;
        if (showNames && nm) return ic ? ic + " " + nm : nm;
        return ic;
    }
    columns: vertical ? 1 : ids.length + 1
    spacing: vertical ? 4 : 1

    Repeater {
        model: root.ids
        Rectangle {
            id: cell
            required property int modelData
            readonly property int n: modelData
            readonly property bool active: n === root.activeId
            readonly property bool used: root.occupied.includes(n)
            readonly property string own: root.custom(WsLabel.local(n))
            readonly property bool dot: root.dots && own === ""
            readonly property string text: own || WsLabel.numeral(WsLabel.local(n))
            readonly property bool wide: own !== "" || text.length > 1
            width: root.vertical ? 24 : dot ? 14 : wide ? Math.max(20, lbl.implicitWidth + 12) : 20
            height: root.vertical ? (dot ? 14 : 22) : 20
            radius: Theme.r(6)
            color: active && !dot ? Theme.p : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            Txt {
                id: lbl
                visible: !cell.dot
                anchors.centerIn: parent
                anchors.verticalCenterOffset: WsLabel.style === "japonesa" && cell.own === "" ? -0.5 : 0
                text: cell.text
                font.family: cell.own === "" ? WsLabel.font : Theme.font
                size: root.vertical && cell.text.length > 2 ? 9 : root.vertical && cell.text.length > 1 && cell.own === "" ? 10 : 11.5
                weight: Font.DemiBold
                tabular: true
                color: cell.active ? Theme.pText : cell.used ? Theme.t : Theme.o
            }
            // Numeración «puntos»: punto por espacio, el activo se alarga
            Rectangle {
                visible: cell.dot
                anchors.centerIn: parent
                width: root.vertical ? (cell.used || cell.active ? 6 : 5) : cell.active ? 12 : cell.used ? 6 : 5
                height: root.vertical ? (cell.active ? 12 : cell.used ? 6 : 5) : (cell.active || cell.used ? 6 : 5)
                radius: Math.min(width, height) / 2
                color: cell.active ? Theme.p : cell.used ? Theme.t : Theme.o
                Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${cell.n} })`)
                onWheel: w => Hyprland.dispatch(`hl.dsp.focus({ workspace = "${WsLabel.perMonitor ? "m" : "e"}${w.angleDelta.y > 0 ? "-1" : "+1"}" })`)
            }
        }
    }

    // Modo de ventanas del espacio activo (WinMode): atenuado si es el general, de color si este espacio tiene el
    // suyo. Clic: el siguiente modo solo para este espacio (como Super + Ctrl + Espacio).
    Item {
        id: modeCell
        readonly property string m: { WinMode.overrides; WinMode.mode; return WinMode.modeOf(root.activeId); }
        readonly property bool own: m !== WinMode.mode
        width: root.vertical ? 24 : 20; height: 20
        Icon { anchors.centerIn: parent; name: WinMode.icons[modeCell.m] ?? "tiles"; size: 12; color: modeCell.own ? Theme.p : Theme.o }
        MouseArea {
            id: modeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: WinMode.cycleWs(root.activeId)
        }
        BarTip { target: modeMa; text: (WinMode.labels[modeCell.m] ?? "") + (modeCell.own ? " · solo este espacio" : "") + " · clic: cambiar" }
    }
}
