// Superposición de Helpert sobre la pantalla (scripts/hf-screen, Computer Use): no recibe clics ni teclado.
//   · cursor fantasma (Ghost Cursor): una flecha que viaja desde tu cursor hasta donde va a actuar, con un bocadillo
//     que dice qué hará («Clic: Guardar») y un resaltado del elemento (Visual Overlay / Highlighting)
//   · marcas (Set-of-Mark): los elementos que analizó, con su número, para ver lo mismo que ve el asistente
// IPC (coordenadas globales de Hyprland, en píxeles lógicos):
//   qs … ipc call puntero point '{"x":…,"y":…,"box":[x,y,w,h],"label":"Clic: Guardar","ms":8000,"from":[x,y]}'
//        (box y from opcionales: sin resaltado / sale desde un poco abajo a la izquierda)
//   qs … ipc call puntero marks '[{"n":1,"x":…,"y":…,"w":…,"h":…}]' MS
//   qs … ipc call puntero hide
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"

Scope {
    id: root
    property string mode: ""            // "" | "point" | "marks"
    property real px: 0
    property real py: 0
    property real fx: 0
    property real fy: 0
    property var box: [0, 0, 0, 0]
    property string label: ""
    property var marks: []
    property int seq: 0                 // cambia en cada «show»: la flecha vuelve a salir desde tu cursor

    Timer { id: hider; onTriggered: root.mode = "" }
    function arm(ms: int): void { hider.interval = Math.max(800, Math.min(60000, ms)); hider.restart(); }

    IpcHandler {
        target: "puntero"
        function point(json: string): void {
            let a;
            try { a = JSON.parse(json); } catch (e) { return; }
            const x = Number(a.x), y = Number(a.y);
            if (!isFinite(x) || !isFinite(y)) return;
            const from = Array.isArray(a.from) ? a.from : [x - 160, y + 120];
            const b = Array.isArray(a.box) && a.box.length === 4 ? a.box.map(Number) : [0, 0, 0, 0];
            root.px = x; root.py = y; root.fx = Number(from[0]) || 0; root.fy = Number(from[1]) || 0;
            root.box = b; root.label = String(a.label ?? "").slice(0, 80);
            root.seq++;
            root.mode = "point";
            root.arm(Number(a.ms) || 8000);
        }
        function marks(json: string, ms: int): void {
            try { root.marks = JSON.parse(json); } catch (e) { root.marks = []; return; }
            root.mode = "marks";
            root.arm(ms);
        }
        function hide(): void { root.mode = ""; hider.stop(); }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property real sx: modelData.x
            readonly property real sy: modelData.y
            readonly property bool here: root.mode === "marks" ? true
                : root.mode === "point" && root.px >= sx && root.px < sx + modelData.width && root.py >= sy && root.py < sy + modelData.height
            visible: here || fade.opacity > 0.01
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hf-puntero"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            Item {
                id: fade
                anchors.fill: parent
                opacity: win.here ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durShort } }

                // ── Marcas numeradas (lo que ve el asistente)
                Repeater {
                    model: root.mode === "marks" ? root.marks : []
                    Item {
                        required property var modelData
                        x: modelData.x - win.sx - 2; y: modelData.y - win.sy - 2
                        width: modelData.w + 4; height: modelData.h + 4
                        Rectangle { anchors.fill: parent; radius: 3; color: Qt.alpha(Theme.aiThink, 0.10); border.width: 1.5; border.color: Theme.aiThink }
                        Rectangle {
                            x: -1; y: -height + 1
                            width: num.implicitWidth + 8; height: num.implicitHeight + 2; radius: 3
                            color: Theme.aiThink
                            Txt { id: num; anchors.centerIn: parent; text: String(parent.parent.modelData.n); size: 10.5; weight: Font.Bold; color: "white"; tabular: true }
                        }
                    }
                }

                // ── Resaltado del elemento
                Rectangle {
                    visible: root.mode === "point" && root.box[2] > 0
                    x: root.box[0] - win.sx - 4; y: root.box[1] - win.sy - 4
                    width: root.box[2] + 8; height: root.box[3] + 8
                    radius: Theme.r(6)
                    color: Qt.alpha(Theme.aiSpeak, 0.14)
                    border.width: 2; border.color: Theme.aiSpeak
                    SequentialAnimation on opacity {
                        running: root.mode === "point" && !Theme.still; loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 650; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                    }
                }

                // ── Cursor fantasma: sale de tu cursor y llega al punto
                Item {
                    id: ghost
                    visible: root.mode === "point"
                    width: 1; height: 1
                    Behavior on x { enabled: ghost.moving; NumberAnimation { duration: Theme.still ? 0 : 480; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: ghost.moving; NumberAnimation { duration: Theme.still ? 0 : 480; easing.type: Easing.OutCubic } }
                    property bool moving: false
                    Connections {
                        target: root
                        function onSeqChanged() {
                            ghost.moving = false;
                            ghost.x = root.fx - win.sx; ghost.y = root.fy - win.sy;
                            ghost.moving = true;
                            ghost.x = root.px - win.sx; ghost.y = root.py - win.sy;
                            ring.restart();
                        }
                    }
                    // onda al llegar
                    Rectangle {
                        id: halo
                        anchors.centerIn: parent
                        width: 10; height: 10; radius: width / 2
                        color: "transparent"; border.width: 2; border.color: Theme.aiSpeak
                        opacity: 0
                    }
                    SequentialAnimation {
                        id: ring
                        PauseAnimation { duration: Theme.still ? 0 : 420 }
                        ParallelAnimation {
                            NumberAnimation { target: halo; property: "width"; from: 10; to: 46; duration: 520; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "height"; from: 10; to: 46; duration: 520; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "opacity"; from: 0.9; to: 0; duration: 520 }
                        }
                    }
                    // la flecha (punta en el punto exacto)
                    Canvas {
                        id: arrow
                        x: -1; y: -1
                        width: 22; height: 28
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.beginPath();
                            c.moveTo(2, 2); c.lineTo(2, 22); c.lineTo(7.5, 17); c.lineTo(11.5, 25.5); c.lineTo(15, 24);
                            c.lineTo(11, 15.5); c.lineTo(18.5, 15.5); c.closePath();
                            c.fillStyle = Theme.aiSpeak; c.fill();
                            c.lineWidth = 1.6; c.strokeStyle = "white"; c.stroke();
                        }
                        Connections { target: Theme; function onAiSpeakChanged() { arrow.requestPaint(); } }
                    }
                    // bocadillo: qué va a hacer
                    Rectangle {
                        x: 22; y: 20
                        visible: root.label !== ""
                        width: tip.implicitWidth + 16; height: tip.implicitHeight + 8
                        radius: height / 2
                        color: Theme.aiSpeak
                        Txt { id: tip; anchors.centerIn: parent; text: root.label; color: "white"; size: 12; weight: Font.DemiBold }
                    }
                }
            }
        }
    }
}
