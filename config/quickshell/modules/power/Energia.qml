// Menú de energía (vista "energia", Super + Esc): Bloquear · Suspender · [Hibernar] · Cerrar sesión · Reiniciar · Apagar
// Teclas: L/S/H/E/R/P directas · ←/→ (o Tab) para moverse · Intro para elegir · Esc para cancelar.
// En pruebas (HF_TRY=1, dev/try.sh) no ejecuta nada: imprime el comando.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"

Overlay {
    id: win
    view: "energia"
    place: "center"
    dim: true
    panelWidth: card.implicitWidth
    panelHeight: card.implicitHeight

    readonly property bool dry: Quickshell.env("HF_TRY") === "1"
    property bool canHibernate: false
    property int sel: -1

    readonly property var actions: {
        const a = [
            { key: "l", label: "Bloquear", hint: "Super L", icon: "lock", run: () => win.lock() },
            { key: "s", label: "Suspender", hint: "S", icon: "moon", run: () => win.sh("systemctl suspend") }
        ];
        if (canHibernate) a.push({ key: "h", label: "Hibernar", hint: "H", icon: "sleep", run: () => win.sh("systemctl hibernate") });
        a.push({ key: "e", label: "Cerrar sesión", hint: "E", icon: "logout", run: () => win.logout() },
               { key: "r", label: "Reiniciar", hint: "R", icon: "restart", run: () => win.sh("systemctl reboot") },
               { key: "p", label: "Apagar", hint: "P", icon: "power", primary: true, run: () => win.sh("systemctl poweroff") });
        return a;
    }

    function sh(cmd: string): void {
        if (dry) { console.info("[energia] (HF_TRY) " + cmd); return; }
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    function lock(): void { sh(Paths.script("hf-lock")); }
    function logout(): void {
        if (dry) { console.info("[energia] (HF_TRY) hl.dsp.exit()"); return; }
        Shell.dispatch("hl.dsp.exit()");
    }
    function choose(i: int): void {
        const a = actions[i];
        if (!a) return;
        Shell.close();
        // Deja que el panel se cierre antes de bloquear/suspender
        runLater.action = a;
        runLater.restart();
    }
    Timer { id: runLater; property var action: null; interval: 180; onTriggered: if (action) action.run() }

    Process {
        running: true
        command: ["systemctl", "can-hibernate"]
        stdout: StdioCollector { onStreamFinished: win.canHibernate = text.trim() === "yes" }
    }
    onShownChanged: if (shown) { sel = -1; Qt.callLater(() => keys.forceActiveFocus()); }

    Glass {
        id: card
        kind: "panel"
        big: true
        anchors.fill: parent
        implicitWidth: col.implicitWidth + 52
        implicitHeight: col.implicitHeight + 44

        ColumnLayout {
            id: col
            anchors.centerIn: parent
            spacing: 16

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Repeater {
                    model: win.actions
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool hot: ma.containsMouse || win.sel === index
                        Layout.preferredWidth: 80
                        implicitHeight: tileCol.implicitHeight

                        ColumnLayout {
                            id: tileCol
                            width: parent.width
                            spacing: 0
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 60; height: 60; radius: Theme.r(8)
                                color: cell.modelData.primary ? Theme.p : Theme.fill2
                                border.width: win.sel === cell.index ? 2 : 0
                                border.color: cell.modelData.primary ? Theme.t : Theme.p
                                scale: ma.pressed ? 0.95 : cell.hot ? 1.04 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius
                                    color: cell.modelData.primary ? Theme.pText : Theme.t
                                    opacity: cell.hot ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    name: cell.modelData.icon
                                    size: 20
                                    color: cell.modelData.primary ? Theme.pText : Theme.t
                                }
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 8
                                text: cell.modelData.label
                                weight: Font.DemiBold
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 3
                                text: cell.modelData.hint
                                size: 11
                                muted: true
                            }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.choose(cell.index)
                        }
                    }
                }
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: "Antes de reiniciar por una actualización se crea un snapshot · Esc para cancelar"
                size: 11.5
                muted: true
            }
        }
    }

    // Teclado (el foco lo tiene win.panel)
    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = win.actions.length;
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { win.sel = (win.sel + 1) % n; event.accepted = true; return; }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { win.sel = win.sel <= 0 ? n - 1 : win.sel - 1; event.accepted = true; return; }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && win.sel >= 0) { win.choose(win.sel); event.accepted = true; return; }
            const t = event.text.toLowerCase();
            const i = win.actions.findIndex(a => a.key === t);
            if (i >= 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) { win.choose(i); event.accepted = true; }
        }
        Keys.onEscapePressed: Shell.close()
    }
}
