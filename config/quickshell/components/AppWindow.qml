// Ventana de una app suelta del shell (como Tareas o Firmar): flotante, centrada (regla «hf-shell-apps» de
// config/apply/50-rules.py, por su título), diferida (no existe hasta abrirla) y con su vista y su IPC:
//   AppWindow { view: "remoto"; title: "Conexiones remotas"; content: Component { … } }
//   Shell.open("remoto") · qs … ipc call remoto open | close | toggle | state
// Ctrl + W o Esc cierran (Esc no, mientras se escribe en un campo). El contenido va en un desplazable con el título.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root
    required property string view
    required property string title
    property string subtitle: ""
    property int prefW: 920
    property int prefH: 720
    property Component content: null
    property bool open: false

    Connections {
        target: Shell
        function onOpened(v) {
            if (v !== root.view) return;
            root.open = true;
            Shell.close();
        }
    }
    IpcHandler {
        target: root.view
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
        function toggle(): void { root.open = !root.open; }
        function state(): string { return root.open ? "abierta" : "cerrada"; }
    }

    LazyLoader {
        active: root.open
        FloatingWindow {
            id: win
            title: root.title
            readonly property var scr: Shell.screen
            implicitWidth: Math.min(root.prefW, Math.round((scr?.width ?? 1920) * 0.8))
            implicitHeight: Math.min(root.prefH, Math.round((scr?.height ?? 1080) * 0.85))
            minimumSize: Qt.size(Math.min(480, implicitWidth), Math.min(400, implicitHeight))
            visible: true
            color: Theme.blur ? Theme.winSolid : Theme.s1
            surfaceFormat.opaque: false            // ver Firmar/Ajustes: si nace opaca no puede volverse translúcida
            onVisibleChanged: if (!visible) root.open = false

            OpenProbe { name: root.view; shown: true }
            Shortcut { sequence: "Ctrl+W"; onActivated: root.open = false }
            Shortcut {
                sequence: "Escape"
                enabled: !(win.activeFocusItem && win.activeFocusItem.cursorPosition !== undefined)   // no en un campo de texto
                onActivated: root.open = false
            }

            Flickable {
                id: fl
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                topMargin: 20; bottomMargin: 22
                contentWidth: width
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: col
                    width: fl.width
                    spacing: 14
                    ColumnLayout {
                        spacing: 2
                        Txt { text: root.title; size: 20; weight: Font.DemiBold }
                        Txt { visible: root.subtitle !== ""; text: root.subtitle; muted: true; size: 12 }
                    }
                    Loader { Layout.fillWidth: true; sourceComponent: root.content }
                }
            }
        }
    }
}
