// Alt + Tab (vista "alttab"): ventanas por uso reciente con miniaturas en vivo.
// Atajos globales propios (además de la vista "alttab", que abre el selector sin ciclar):
//   hf:altnext  → abre / siguiente      (ALT + TAB)
//   hf:altprev  → abre / anterior       (ALT + SHIFT + TAB)
//   hf:altapp   → otra ventana de la misma app (ALT + `)
// Al soltar Alt se enfoca la elegida. Mientras está abierto: Tab / ← → también ciclan, Intro elige, Esc cancela,
// Q o Supr cierra la ventana seleccionada, clic elige. Las minimizadas (WinMode) van al final, atenuadas:
// elegirlas las trae al espacio actual.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "alttab"
    place: "screen"            // centrado en la pantalla entera, sea cual sea la barra
    closeOnOutside: true
    panelWidth: card.implicitWidth
    panelHeight: card.implicitHeight

    property int sel: 0
    property string appFilter: ""        // clase (Alt + `)
    property var snapshot: []            // lista congelada al abrir (no se reordena mientras ciclas)
    property bool cycling: false         // abierto con Alt pulsado → soltar Alt elige

    readonly property var items: snapshot
    readonly property int warm: HyprClients.refreshes      // arranca el servicio al cargar el módulo
    onWarmChanged: if (shown && !snapshot.length) { build(appFilter); sel = items.length > 1 ? 1 : 0; }
    readonly property int perRow: Math.max(1, Math.min(items.length, Math.floor(((Shell.screen?.width ?? 1440) - 120) / 186)))

    function build(cls: string): void {
        let l = HyprClients.byRecent.concat(WinMode.minimized);
        if (cls) l = l.filter(c => c.class === cls);
        snapshot = l;
    }
    function begin(dir: int, cls: string): void {
        if (Shell.view !== "alttab") {
            appFilter = cls ?? "";
            build(appFilter);
            cycling = true;
            sel = items.length > 1 ? (dir > 0 ? 1 : items.length - 1) : 0;
            Shell.open("alttab", "ciclo");
        } else {
            step(dir);
        }
    }
    function step(dir: int): void {
        const n = items.length;
        if (n) sel = (sel + dir + n) % n;
    }
    function choose(i: int): void {
        const c = items[i];
        Shell.close();
        if (!c) return;
        if (WinMode.isMin(c)) WinMode.restore(c.address);
        else HyprClients.focusWindow(c.address);
    }
    function closeSelected(): void {
        const c = items[sel];
        if (!c) return;
        Shell.dispatch('hl.dsp.window.close({ window = "address:' + c.address + '" })');
        snapshot = snapshot.filter(x => x.address !== c.address);
        if (!snapshot.length) Shell.close();
        else sel = Math.min(sel, snapshot.length - 1);
    }

    onShownChanged: {
        if (shown) {
            // Abierto desde la vista "alttab" (menú, IPC…) en lugar de por los atajos
            if (Shell.arg !== "ciclo") { appFilter = ""; build(""); cycling = false; sel = items.length > 1 ? 1 : 0; }
            HyprClients.refreshNow();
            Qt.callLater(() => keys.forceActiveFocus());
        } else {
            cycling = false;
        }
    }

    GlobalShortcut { appid: "hf"; name: "altnext"; description: "HyprFrijol: Alt + Tab (siguiente)"; onPressed: win.begin(1, "") }
    GlobalShortcut { appid: "hf"; name: "altprev"; description: "HyprFrijol: Alt + Shift + Tab (anterior)"; onPressed: win.begin(-1, "") }
    GlobalShortcut {
        appid: "hf"; name: "altapp"; description: "HyprFrijol: Alt + ` (misma app)"
        onPressed: {
            const cur = HyprClients.client(HyprClients.activeAddress) ?? HyprClients.byRecent[0];
            win.begin(1, cur?.class ?? "");
        }
    }

    Glass {
        id: card
        anchors.fill: parent
        kind: "panel"
        big: true
        implicitWidth: body.implicitWidth + 28
        implicitHeight: body.implicitHeight + 28

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const shift = e.modifiers & Qt.ShiftModifier;
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Down) { win.step(1); e.accepted = true; }
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_Up) { win.step(-1); e.accepted = true; }
                else if (e.key === Qt.Key_QuoteLeft || e.key === Qt.Key_Dead_Grave) { win.step(shift ? -1 : 1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { win.choose(win.sel); e.accepted = true; }
                else if (e.key === Qt.Key_Q || e.key === Qt.Key_Delete) { win.closeSelected(); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) { Shell.close(); e.accepted = true; }
            }
            Keys.onReleased: e => {
                if (win.cycling && (e.key === Qt.Key_Alt || e.key === Qt.Key_AltGr || e.key === Qt.Key_Meta)) {
                    win.choose(win.sel);
                    e.accepted = true;
                }
            }
        }

        ColumnLayout {
            id: body
            anchors.centerIn: parent
            spacing: 10

            // Sin ventanas
            ColumnLayout {
                visible: win.items.length === 0
                Layout.preferredWidth: 360
                Layout.preferredHeight: 120
                spacing: 6
                Icon { Layout.alignment: Qt.AlignHCenter; name: "window"; size: 26; color: Theme.tv }
                Txt { Layout.alignment: Qt.AlignHCenter; text: win.appFilter ? "No hay más ventanas de esta app" : "No hay ventanas abiertas"; weight: Font.DemiBold }
                Txt { Layout.alignment: Qt.AlignHCenter; text: "Abre apps con Super + Espacio"; muted: true; size: 11.5 }
            }

            GridLayout {
                visible: win.items.length > 0
                columns: win.perRow
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: win.items
                    delegate: Rectangle {
                        id: it
                        required property var modelData
                        required property int index
                        readonly property bool on: index === win.sel
                        Layout.preferredWidth: 176
                        Layout.preferredHeight: col.implicitHeight + 12
                        radius: Theme.r(8)
                        color: on ? Theme.fill2 : ma.containsMouse ? Qt.alpha(Theme.fill2, 0.5) : "transparent"
                        border.width: on ? 2 : 0
                        border.color: Qt.alpha(Theme.p, 0.7)
                        Behavior on color { ColorAnimation { duration: Theme.ms(120); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                        ColumnLayout {
                            id: col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                            spacing: 8
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 108
                                // La captura conserva la proporción de la ventana
                                readonly property real ar: Math.max(0.3, it.modelData.size[0] / Math.max(1, it.modelData.size[1]))
                                Rectangle { anchors.fill: parent; radius: Theme.r(5); color: Theme.s3 }
                                WindowThumb {
                                    anchors.centerIn: parent
                                    opacity: WinMode.isMin(it.modelData) ? 0.45 : 1
                                    width: Math.min(parent.width, parent.height * parent.ar)
                                    height: Math.min(parent.height, parent.width / parent.ar)
                                    address: it.modelData.address
                                    cls: it.modelData.class
                                    title: it.modelData.title
                                    live: win.shown
                                    radius: Theme.r(5)
                                    showLabel: false
                                }
                                Rectangle {
                                    visible: it.modelData.workspace?.id !== (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1)
                                    anchors { top: parent.top; right: parent.right; margins: 5 }
                                    width: wsTxt.implicitWidth + 10; height: 16; radius: Theme.ctl(16)
                                    color: Qt.alpha("#000000", 0.55)
                                    Txt { id: wsTxt; anchors.centerIn: parent; text: WinMode.isMin(it.modelData) ? "Minimizada" : String(it.modelData.workspace?.id ?? ""); size: 10; color: "white"; weight: Font.DemiBold }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7
                                Rectangle {
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                    radius: Theme.r(5)
                                    color: appIcon.visible ? "transparent" : (it.index % 3 === 0 ? Theme.p : it.index % 3 === 1 ? Theme.sc : Theme.s4)
                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        sourceSize: Qt.size(36, 36)
                                        source: HyprClients.iconFor(it.modelData.class)
                                        visible: status === Image.Ready
                                        asynchronous: true
                                    }
                                    Txt {
                                        anchors.centerIn: parent
                                        visible: !appIcon.visible
                                        text: HyprClients.appName(it.modelData.class).charAt(0).toUpperCase()
                                        size: 10
                                        weight: Font.DemiBold
                                        color: it.index % 3 === 0 ? Theme.pText : it.index % 3 === 1 ? Theme.scText : Theme.t
                                    }
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: it.modelData.title || HyprClients.appName(it.modelData.class)
                                    weight: it.on ? Font.Medium : Font.Normal
                                }
                            }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: e => {
                                if (e.button === Qt.MiddleButton) { win.sel = it.index; win.closeSelected(); }
                                else win.choose(it.index);
                            }
                            onPositionChanged: if (!win.cycling) win.sel = it.index
                        }
                    }
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: Math.max(520, win.perRow * 186 - 10)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: "Alt + Tab siguiente · Alt + Shift + Tab anterior · Alt + ` otra ventana de la misma app"
                muted: true
                size: 11.5
            }
        }
    }
}
