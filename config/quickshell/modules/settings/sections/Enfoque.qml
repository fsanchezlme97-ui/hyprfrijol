// Ajustes › Enfoque y pomodoro — duraciones (Pomodoro), modo sin distracciones y bloqueos durante el foco.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    ProdTabs { current: "enfoque" }   // Enfoque | Portapapeles | Agenda | Tareas (una sola entrada en la lista)
    readonly property int fMin: Settings.get("pomodoroFocus", 25)
    readonly property int brk: Settings.get("pomodoroBreak", 5)
    readonly property int lng: Settings.get("pomodoroLong", 15)
    readonly property int cycles: Settings.get("pomodoroCycles", 4)
    readonly property int total: cycles * fMin + (cycles - 1) * brk + lng
    function hm(m) { const h = Math.floor(m / 60), r = m % 60; return h ? h + " h" + (r ? " " + r + " min" : "") : r + " min"; }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Pomodoro"
            Stepper { label: "Foco"; value: root.fMin; from: 5; to: 120; step: 5; onStepped: v => Settings.set("pomodoroFocus", v) }
            Stepper { label: "Descanso corto"; value: root.brk; from: 1; to: 30; onStepped: v => Settings.set("pomodoroBreak", v) }
            Stepper { label: "Descanso largo"; value: root.lng; from: 5; to: 60; step: 5; onStepped: v => Settings.set("pomodoroLong", v) }
            Stepper { label: "Ciclos"; value: root.cycles; from: 1; to: 8; unit: ""; onStepped: v => Settings.set("pomodoroCycles", v) }
            // barra de ciclos
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3
                Repeater {
                    model: root.cycles * 2
                    Rectangle {
                        required property int index
                        readonly property bool isFocus: index % 2 === 0
                        readonly property bool last: index === root.cycles * 2 - 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: isFocus ? root.fMin : (last ? root.lng : root.brk)
                        implicitHeight: 12
                        radius: Theme.r(3)
                        color: isFocus ? Theme.p : last ? Theme.ter : Theme.s4
                    }
                }
            }
            Txt { muted: true; size: 11.5; text: root.cycles + " × " + root.fMin + " min de foco · total " + root.hm(root.total) }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Modo sin distracciones"
            headerRight: Kbd { text: "Super + Ctrl + Z" }
            SwRow { label: "Ocultar la barra"; sub: "vuelve al pasar el cursor por el borde"; key: "focusHideBar"; def: true }
            SwRow { label: "Sin gaps ni bordes"; sub: "gaps_in = 0 · border_size = 0"; mono: true; key: "focusNoGaps"; def: true }
            SwRow { label: "Silenciar notificaciones"; sub: "no molestar mientras dure el foco"; key: "focusMuteNotifs"; def: true }
            SwRow { label: "Iniciar descansos automáticamente"; sub: "y el siguiente bloque de foco"; key: "focusAutoBreak" }
            SwRow { label: "Sonido al terminar cada bloque"; sub: "canberra-gtk-play · complete"; key: "focusSound"; def: true }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Bloquear durante el foco"
        Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Las web apps y ventanas de estas categorías se cierran o no se abren mientras corre un bloque de foco." }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["youtube", "YouTube"], ["pinterest", "Pinterest"], ["whatsapp", "WhatsApp"], ["juegos", "Juegos"], ["redes", "Redes sociales"], ["correo", "Correo"]]
                Chip {
                    required property var modelData
                    readonly property var list: Settings.get("focusBlock", ["youtube", "juegos", "redes"])
                    text: modelData[1]
                    on: list.includes(modelData[0])
                    onClicked: Settings.set("focusBlock", on ? list.filter(x => x !== modelData[0]) : list.concat([modelData[0]]))
                }
            }
        }
    }
}
