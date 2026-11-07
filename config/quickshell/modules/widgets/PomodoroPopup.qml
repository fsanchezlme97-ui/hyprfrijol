// Ventana del pomodoro (vista "w-pomodoro", clic en el chip de la barra): anillo con el tiempo, modo
// (foco / descanso / descanso largo), rondas, iniciar · pausar · reiniciar · saltar, ±1 min (o rueda sobre el
// tiempo) y las duraciones, que se guardan en Ajustes (pomodoroFocus/Break/Long/Cycles, focusAutoBreak,
// focusSound). Teclas: Espacio iniciar/pausar · S saltar · R reiniciar · ↑/↓ ±1 min (parado).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../../bar"

ChipPopup {
    id: pop
    view: "w-pomodoro"
    panelWidth: 320
    panelHeight: card.implicitHeight
    readonly property color modeColor: Pomodoro.mode === "foco" ? Theme.p : Pomodoro.mode === "largo" ? Theme.tv : Theme.ter
    onShownChanged: if (shown) Qt.callLater(() => card.forceActiveFocus())

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Space) Pomodoro.toggle();
            else if (e.key === Qt.Key_S) Pomodoro.skip();
            else if (e.key === Qt.Key_R) Pomodoro.reset();
            else if (e.key === Qt.Key_Up && !Pomodoro.running) Pomodoro.adjust(1);
            else if (e.key === Qt.Key_Down && !Pomodoro.running) Pomodoro.adjust(-1);
            else return;
            e.accepted = true;
        }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Pomodoro"; size: 14; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: Pomodoro.today > 0 ? Pomodoro.today + (Pomodoro.today === 1 ? " foco hoy" : " focos hoy") : ""; muted: true; size: 11.5 }
                // rondas del ciclo
                Row {
                    spacing: 4
                    Repeater {
                        model: Pomodoro.cycles
                        Rectangle {
                            required property int index
                            width: 7; height: 7; radius: 3.5
                            color: index < Pomodoro.done ? Theme.p : Theme.fill2
                            border.width: index === Pomodoro.done && Pomodoro.mode === "foco" ? 1.5 : 0
                            border.color: Theme.p
                        }
                    }
                }
            }

            Segmented {
                Layout.fillWidth: true
                h: 28
                model: [{ key: "foco", label: "Foco" }, { key: "descanso", label: "Descanso" }, { key: "largo", label: "Largo" }]
                current: Pomodoro.mode
                onPicked: k => Pomodoro.setMode(k)
            }

            // anillo + tiempo
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 156; implicitHeight: 156
                ProgressRing {
                    anchors.fill: parent
                    value: Pomodoro.progress
                    color: pop.modeColor
                    lineWidth: 7
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Txt { Layout.alignment: Qt.AlignHCenter; text: Pomodoro.time; size: 32; weight: Font.Medium; tabular: true }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: Pomodoro.running ? Pomodoro.label : Pomodoro.active ? "En pausa" : Pomodoro.label; muted: true; size: 12 }
                }
                WheelHandler { onWheel: e => { if (!Pomodoro.running) Pomodoro.adjust(e.angleDelta.y > 0 ? 1 : -1); } }
                IconBtn {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: -34 }
                    visible: !Pomodoro.running
                    icon: "minus"; tooltip: "−1 min"
                    onClicked: Pomodoro.adjust(-1)
                }
                IconBtn {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: -34 }
                    visible: !Pomodoro.running
                    icon: "plus"; tooltip: "+1 min"
                    onClicked: Pomodoro.adjust(1)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                WBtn { icon: "refresh"; text: "Reiniciar"; onClicked: Pomodoro.reset() }
                WBtn {
                    primary: true
                    icon: Pomodoro.running ? "pause" : "play"
                    text: Pomodoro.running ? "Pausar" : Pomodoro.active ? "Seguir" : "Empezar"
                    onClicked: Pomodoro.toggle()
                }
                WBtn { icon: "next"; text: "Saltar"; onClicked: Pomodoro.skip() }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }

            // duraciones (se guardan en Ajustes › Enfoque)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Repeater {
                    model: [
                        { k: "pomodoroFocus", l: "Foco", v: Pomodoro.focusMin, from: 1, to: 180, u: " min" },
                        { k: "pomodoroBreak", l: "Descanso", v: Pomodoro.breakMin, from: 1, to: 60, u: " min" },
                        { k: "pomodoroLong", l: "Largo", v: Pomodoro.longMin, from: 1, to: 90, u: " min" },
                        { k: "pomodoroCycles", l: "Rondas", v: Pomodoro.cycles, from: 1, to: 12, u: "" }
                    ]
                    Rectangle {
                        id: st
                        required property var modelData
                        readonly property var d: modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 52
                        radius: Theme.r(8)
                        color: Theme.fill2
                        function step(n: int): void {
                            Settings.set(d.k, Math.max(d.from, Math.min(d.to, d.v + n)));
                        }
                        ColumnLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 4; topMargin: 6; bottomMargin: 6 }
                            spacing: 0
                            Txt { text: st.d.l; muted: true; size: 11 }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Txt { Layout.fillWidth: true; text: st.d.v + st.d.u; weight: Font.DemiBold; size: 14; tabular: true }
                                IconBtn { implicitWidth: 22; icon: "minus"; iconSize: 12; onClicked: st.step(st.d.k === "pomodoroCycles" ? -1 : st.d.v > 10 ? -5 : -1) }
                                IconBtn { implicitWidth: 22; icon: "plus"; iconSize: 12; onClicked: st.step(st.d.k === "pomodoroCycles" ? 1 : st.d.v >= 10 ? 5 : 1) }
                            }
                        }
                        WheelHandler { onWheel: e => st.step(e.angleDelta.y > 0 ? 1 : -1) }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: "Encadenar bloques sin parar"; size: 12 }
                Toggle { checked: Pomodoro.autoNext; onToggled: v => Settings.set("focusAutoBreak", v) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: "Sonido al terminar"; size: 12 }
                Toggle { checked: Settings.get("focusSound", true); onToggled: v => Settings.set("focusSound", v) }
            }
            WBtn { text: "Modo sin distracciones y bloqueos"; icon: "settings"; onClicked: Shell.open("ajustesapp", "enfoque") }
        }
    }
}
