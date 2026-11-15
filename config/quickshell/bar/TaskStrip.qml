// Barra de tareas del modo clásico: en la barra horizontal, en lugar del título de la ventana activa cuando el espacio
// visible de esta pantalla está en modo Clásico (WinMode.isFloat). Un botón por ventana de ese espacio y por cada
// minimizada, en el orden en que se abrieron: icono y título (solo el icono si no caben). La de delante va marcada.
//   clic: traerla al frente · en la de delante: minimizarla · en una minimizada: restaurarla
//   clic central: cerrarla · clic derecho: menú de ventana (WinMenu.qml; antes la trae al frente)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../components"
import "../services"

RowLayout {
    id: root
    property string screenName: ""
    property real maxWidth: 300
    spacing: 2
    readonly property int wsId: { HyprClients.refreshes; return HyprClients.monitorByName(screenName)?.activeWorkspace?.id ?? 0; }
    readonly property bool classic: { WinMode.mode; WinMode.overrides; return WinMode.isFloat(wsId); }
    readonly property var wins: {
        HyprClients.refreshes;
        if (!classic) return [];
        return HyprClients.clients.filter(c => c.mapped !== false && !/^org\.quickshell/i.test(c.class ?? "")
            && (c.workspace?.id === wsId || WinMode.isMin(c)));
    }
    // la de delante: la última enfocada de las que están a la vista
    readonly property string front: wins.filter(c => !WinMode.isMin(c))
        .reduce((a, w) => !a || w.focusHistoryID < a.focusHistoryID ? w : a, null)?.address ?? ""
    readonly property real each: Math.min(170, (maxWidth - spacing * Math.max(0, wins.length - 1)) / Math.max(1, wins.length))
    readonly property bool iconsOnly: each < 76

    Repeater {
        model: root.wins
        Rectangle {
            id: btn
            required property var modelData
            readonly property bool on: modelData.address === root.front
            readonly property bool min: WinMode.isMin(modelData)
            Layout.preferredWidth: root.iconsOnly ? 28 : root.each
            Layout.preferredHeight: 24
            radius: Theme.ctl(24)
            color: on ? Theme.fill2 : ma.containsMouse ? Qt.alpha(Theme.t, 0.06) : "transparent"
            opacity: min ? 0.55 : 1
            Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

            RowLayout {
                anchors { fill: parent; leftMargin: root.iconsOnly ? 6 : 8; rightMargin: root.iconsOnly ? 6 : 8 }
                spacing: 8
                IconImage {
                    implicitSize: 16
                    source: HyprClients.iconFor(btn.modelData.class)
                    asynchronous: true
                }
                Txt {
                    visible: !root.iconsOnly
                    Layout.fillWidth: true
                    text: (btn.modelData.title || HyprClients.appName(btn.modelData.class)).replace(/\s+/g, " ").trim()
                    size: 11; muted: !btn.on
                }
            }
            // la de delante: una rayita del acento abajo
            Rectangle {
                visible: btn.on
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                width: root.iconsOnly ? 10 : 16; height: 2; radius: 1
                color: Theme.p
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: e => {
                    const a = btn.modelData.address;
                    if (e.button === Qt.MiddleButton) { WinMode.close(a); return; }
                    if (e.button === Qt.RightButton) {
                        if (btn.min) WinMode.restore(a); else HyprClients.focusWindow(a);
                        menuLater.restart();
                        return;
                    }
                    if (btn.min) WinMode.restore(a);
                    else if (btn.on) WinMode.minimize(a);
                    else HyprClients.focusWindow(a);
                }
            }
            BarTip { target: ma; text: (btn.modelData.title || HyprClients.appName(btn.modelData.class)) + (btn.min ? " · minimizada" : "") }
        }
    }
    // el menú de ventana actúa sobre la activa: se abre cuando ya lo es
    Timer { id: menuLater; interval: 180; onTriggered: Shell.open("ventana") }
}
