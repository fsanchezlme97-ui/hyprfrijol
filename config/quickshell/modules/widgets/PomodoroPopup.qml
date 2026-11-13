// Ventana del pomodoro (vista "w-pomodoro", clic en el chip de la barra), en tres pestañas:
//   · Pomodoro: bloque (foco / descanso / largo) y rondas, anillo con el tiempo (±1 min o rueda, parado), en qué te
//     concentras (opcional), iniciar · pausar · reiniciar · saltar, y las duraciones y opciones (se guardan en
//     Ajustes: pomodoroFocus/Break/Long/Cycles, focusAutoBreak, focusSound).
//   · Temporizador: cuenta atrás suelta (timerMin) con alarma al acabar, minutos rápidos, qué te recuerdo
//     (opcional) y los temporizadores que haya puesto el asistente (hf-ai timers / timer cancel).
//   · Alarmas: a una hora del día, una vez o ciertos días (services/Alarms.qml).
// Teclas (pestañas Pomodoro y Temporizador): Espacio iniciar/pausar · S saltar · R reiniciar · ↑/↓ ±1 min (parado).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
import "../../bar"

ChipPopup {
    id: pop
    view: "w-pomodoro"
    panelWidth: 348
    panelHeight: card.implicitHeight
    readonly property color modeColor: Pomodoro.mode === "foco" ? Theme.p : Pomodoro.mode === "largo" ? Theme.tv : Pomodoro.isTimer ? Theme.sc : Theme.ter
    property bool alarmsTab: false
    readonly property string tab: alarmsTab ? "alarmas" : Pomodoro.isTimer ? "temporizador" : "pomodoro"
    onShownChanged: if (shown) {
        // Shell.open("w-pomodoro", "alarmas") abre esa pestaña; si no, se queda la última salvo que haya algo en marcha
        alarmsTab = Shell.arg === "alarmas" || (alarmsTab && !Pomodoro.running);
        Qt.callLater(() => card.forceActiveFocus()); pop.refreshTimers(); Alarms.check();
    }

    // ---- temporizadores del asistente ----
    property var timers: []
    property real now: Date.now()
    readonly property var liveTimers: timers.filter(t => t.end * 1000 > now)
    function refreshTimers(): void { tlist.running = false; tlist.running = true; }
    function cancelTimer(id: string): void {
        tctl.command = [Paths.script("hf-ai"), "timer", "cancel", id];
        tctl.running = true;
    }
    function left(t): string {
        const s = Math.max(0, Math.round(t.end - pop.now / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(ss).padStart(2, "0");
    }
    Process {
        id: tlist
        command: [Paths.script("hf-ai"), "timers"]
        stdout: StdioCollector { onStreamFinished: { try { pop.timers = JSON.parse(text) ?? []; } catch (e) {} } }
    }
    Process {
        id: tctl
        stdout: StdioCollector { onStreamFinished: { try { pop.timers = JSON.parse(text).timers ?? pop.timers; } catch (e) {} } }
        onExited: pop.refreshTimers()
    }
    // cuenta atrás mientras la ventana está abierta; la lista se relee de vez en cuando (el asistente también crea)
    Timer {
        interval: 1000; repeat: true; running: pop.shown
        property int n: 0
        onTriggered: { pop.now = Date.now(); if (++n % 10 === 0) pop.refreshTimers(); }
    }

    // ---- nueva alarma ----
    property int newH: 7
    property int newM: 0
    property var newDays: []
    function wrap(v: int, n: int): int { return (v % n + n) % n; }

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32
        Keys.onPressed: e => {
            if (pop.tab === "alarmas") return;
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

            // ── Pestañas ──
            Segmented {
                Layout.fillWidth: true
                h: 30
                model: [{ key: "pomodoro", label: "Pomodoro" }, { key: "temporizador", label: "Temporizador" }, { key: "alarmas", label: "Alarmas" }]
                current: pop.tab
                onPicked: k => {
                    pop.alarmsTab = k === "alarmas";
                    if (k === "temporizador" && !Pomodoro.isTimer) Pomodoro.setMode("temporizador");
                    else if (k === "pomodoro" && Pomodoro.isTimer) Pomodoro.setMode("foco");
                }
            }

            // ── Pomodoro: bloque y rondas ──
            RowLayout {
                visible: pop.tab === "pomodoro"
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [["foco", "Foco"], ["descanso", "Descanso"], ["largo", "Largo"]]
                    Rectangle {
                        id: mchip
                        required property var modelData
                        readonly property bool on: Pomodoro.mode === modelData[0]
                        implicitWidth: mt.implicitWidth + 20; implicitHeight: 24; radius: Theme.ctl(24)
                        color: on ? Qt.alpha(pop.modeColor, 0.22) : mma.containsMouse ? Qt.alpha(Theme.t, 0.08) : "transparent"
                        border.width: on ? 0 : 1; border.color: Theme.ov
                        Txt { id: mt; anchors.centerIn: parent; text: mchip.modelData[1]; size: 11.5; weight: mchip.on ? Font.DemiBold : Font.Normal; color: mchip.on ? pop.modeColor : Theme.t }
                        MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Pomodoro.setMode(mchip.modelData[0]) }
                    }
                }
                Item { Layout.fillWidth: true }
                Txt { text: Pomodoro.today > 0 ? Pomodoro.today + (Pomodoro.today === 1 ? " foco hoy" : " focos hoy") : ""; muted: true; size: 11 }
                Row {
                    spacing: 4
                    Layout.leftMargin: 4
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

            // ── Pomodoro y temporizador: anillo, actividad y controles ──
            Item {
                visible: pop.tab !== "alarmas"
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 156; implicitHeight: 156
                ProgressRing {
                    anchors.fill: parent
                    value: 1 - Pomodoro.progress          // lo que queda: se vacía, como el de la barra
                    color: pop.modeColor
                    lineWidth: 7
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Txt { Layout.alignment: Qt.AlignHCenter; text: Pomodoro.time; size: 32; weight: Font.Medium; tabular: true }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 120
                        text: Pomodoro.active && !Pomodoro.running ? "En pausa"
                            : (Pomodoro.mode === "foco" || Pomodoro.isTimer) && Pomodoro.activity ? Pomodoro.activity : Pomodoro.label
                        muted: true; size: 12; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
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
            // Actividad (opcional): en el foco, en qué estás; en el temporizador, qué te recuerdo al acabar
            Field {
                id: actField
                visible: Pomodoro.mode === "foco" && pop.tab === "pomodoro" || pop.tab === "temporizador"
                Layout.fillWidth: true
                h: 30; icon: "edit"
                placeholder: Pomodoro.isTimer ? "¿Qué te recuerdo? (opcional)" : "¿En qué te vas a concentrar? (opcional)"
                text: Pomodoro.activity
                input.maximumLength: 80
                onAccepted: { Pomodoro.activity = text.trim(); card.forceActiveFocus(); }
                input.onActiveFocusChanged: if (!input.activeFocus) Pomodoro.activity = text.trim()
                Connections { target: Pomodoro; function onActivityChanged() { if (!actField.input.activeFocus) actField.text = Pomodoro.activity; } }
            }
            RowLayout {
                visible: pop.tab !== "alarmas"
                Layout.fillWidth: true
                spacing: 8
                WBtn { icon: "refresh"; text: "Reiniciar"; onClicked: Pomodoro.reset() }
                WBtn {
                    primary: true
                    icon: Pomodoro.running ? "pause" : "play"
                    text: Pomodoro.running ? "Pausar" : Pomodoro.active ? "Seguir" : "Empezar"
                    onClicked: Pomodoro.toggle()
                }
                WBtn { visible: !Pomodoro.isTimer; icon: "next"; text: "Saltar"; onClicked: Pomodoro.skip() }
            }

            // ── Temporizador: minutos rápidos (se recuerdan; en marcha, empieza de nuevo con ellos) ──
            Sub { visible: pop.tab === "temporizador"; text: "Minutos" }
            GridLayout {
                visible: pop.tab === "temporizador"
                Layout.fillWidth: true
                columns: 4; columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: [1, 3, 5, 10, 15, 20, 30, 60]
                    WBtn {
                        required property int modelData
                        text: modelData === 60 ? "1 h" : modelData + " min"
                        primary: Math.round(Pomodoro.total / 60) === modelData
                        onClicked: Pomodoro.setTimerMin(modelData)
                    }
                }
            }

            // ── Pomodoro: duraciones (Ajustes › Enfoque) ──
            Sub { visible: pop.tab === "pomodoro"; text: "Duraciones" }
            GridLayout {
                visible: pop.tab === "pomodoro"
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8
                Repeater {
                    model: [
                        { k: "pomodoroFocus", l: "Foco", v: Pomodoro.focusMin, from: 1, to: 180, u: " min" },
                        { k: "pomodoroBreak", l: "Descanso", v: Pomodoro.breakMin, from: 1, to: 60, u: " min" },
                        { k: "pomodoroLong", l: "Descanso largo", v: Pomodoro.longMin, from: 1, to: 90, u: " min" },
                        { k: "pomodoroCycles", l: "Rondas hasta el largo", v: Pomodoro.cycles, from: 1, to: 12, u: "" }
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
                            anchors { fill: parent; leftMargin: 12; rightMargin: 4; topMargin: 8; bottomMargin: 8 }
                            spacing: 0
                            Txt { Layout.fillWidth: true; text: st.d.l; muted: true; size: 11; elide: Text.ElideRight }
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
                visible: pop.tab === "pomodoro"
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: "Encadenar bloques sin parar"; size: 12 }
                Toggle { checked: Pomodoro.autoNext; onToggled: v => Settings.set("focusAutoBreak", v) }
            }
            RowLayout {
                visible: pop.tab !== "alarmas"
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: "Sonido al terminar"; size: 12 }
                Toggle { checked: Settings.get("focusSound", true); onToggled: v => Settings.set("focusSound", v) }
            }

            // ── Temporizador: los del asistente (acción "timer" de la IA), solo si hay alguno en marcha ──
            Sub { visible: pop.tab === "temporizador" && pop.liveTimers.length > 0; text: "Del asistente" }
            Repeater {
                model: pop.tab === "temporizador" ? pop.liveTimers : []
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.sc }
                    Txt { Layout.fillWidth: true; text: parent.modelData.label || "Temporizador"; elide: Text.ElideRight; size: 12 }
                    Txt { text: pop.left(parent.modelData); weight: Font.DemiBold; tabular: true; size: 12 }
                    IconBtn { implicitWidth: 22; icon: "x"; iconSize: 11; tooltip: "Cancelar"; onClicked: pop.cancelTimer(parent.modelData.id) }
                }
            }

            // ── Alarmas ──
            Txt {
                visible: pop.tab === "alarmas"
                Layout.fillWidth: true
                text: Alarms.next ? "Próxima: " + Alarms.next.time + (Alarms.next.label ? " · " + Alarms.next.label : "") + " (" + Alarms.untilText(Alarms.next.at) + ")"
                                  : Alarms.count ? "Ninguna alarma encendida" : "Aún no tienes alarmas"
                muted: true; size: 11.5; elide: Text.ElideRight
            }
            Repeater {
                model: pop.tab === "alarmas" ? Alarms.list : []
                Rectangle {
                    id: arow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 50
                    radius: Theme.r(8)
                    color: Theme.fill2
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                        spacing: 12
                        Txt { text: Alarms.hhmm(arow.modelData); size: 22; weight: Font.Medium; tabular: true; opacity: arow.modelData.on ? 1 : 0.45 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt { Layout.fillWidth: true; text: arow.modelData.label || "Alarma"; size: 12; elide: Text.ElideRight; opacity: arow.modelData.on ? 1 : 0.6 }
                            Txt { Layout.fillWidth: true; text: Alarms.daysText(arow.modelData); muted: true; size: 11; elide: Text.ElideRight }
                        }
                        Toggle { checked: arow.modelData.on; onToggled: v => Alarms.update(arow.modelData.id, { on: v }) }
                        IconBtn { implicitWidth: 24; icon: "x"; iconSize: 11; tooltip: "Borrar"; onClicked: Alarms.remove(arow.modelData.id) }
                    }
                }
            }
            Sub { visible: pop.tab === "alarmas"; text: "Nueva alarma" }
            RowLayout {
                visible: pop.tab === "alarmas"
                Layout.fillWidth: true
                spacing: 8
                // HH : MM con rueda o ±
                Repeater {
                    model: [{ k: "h", n: 24, step: 1 }, { k: "m", n: 60, step: 5 }]
                    Rectangle {
                        id: tbox
                        required property var modelData
                        required property int index
                        readonly property int v: modelData.k === "h" ? pop.newH : pop.newM
                        function bump(d: int): void {
                            if (modelData.k === "h") pop.newH = pop.wrap(pop.newH + d, 24);
                            else pop.newM = pop.wrap(Math.round((pop.newM + d * modelData.step) / modelData.step) * modelData.step, 60);
                        }
                        implicitWidth: 64; implicitHeight: 58; radius: Theme.r(8)
                        color: Theme.fill2
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -4
                            IconBtn { Layout.alignment: Qt.AlignHCenter; implicitWidth: 22; implicitHeight: 16; icon: "chevron_up"; iconSize: 11; onClicked: tbox.bump(1) }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: String(tbox.v).padStart(2, "0"); size: 20; weight: Font.Medium; tabular: true }
                            IconBtn { Layout.alignment: Qt.AlignHCenter; implicitWidth: 22; implicitHeight: 16; icon: "chevron_down"; iconSize: 11; onClicked: tbox.bump(-1) }
                        }
                        WheelHandler { onWheel: e => tbox.bump(e.angleDelta.y > 0 ? 1 : -1) }
                    }
                }
                Field {
                    id: alLabel
                    Layout.fillWidth: true
                    h: 30; icon: "edit"
                    placeholder: "Etiqueta (opcional)"
                    input.maximumLength: 60
                    onAccepted: addBtn.clicked()
                }
            }
            // Días: ninguno marcado = una sola vez
            RowLayout {
                visible: pop.tab === "alarmas"
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: 7
                    Rectangle {
                        id: dchip
                        required property int index
                        readonly property bool on: pop.newDays.includes(index + 1)
                        Layout.fillWidth: true
                        implicitHeight: 26; radius: Theme.ctl(26)
                        color: on ? Theme.p : dma.containsMouse ? Qt.alpha(Theme.t, 0.08) : "transparent"
                        border.width: on ? 0 : 1; border.color: Theme.ov
                        Txt { anchors.centerIn: parent; text: Alarms.dayNames[dchip.index]; size: 11.5; weight: Font.DemiBold; color: dchip.on ? Theme.pText : Theme.t }
                        MouseArea {
                            id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pop.newDays = dchip.on ? pop.newDays.filter(d => d !== dchip.index + 1) : pop.newDays.concat([dchip.index + 1])
                        }
                    }
                }
            }
            RowLayout {
                visible: pop.tab === "alarmas"
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: pop.newDays.length ? Alarms.daysText({ days: pop.newDays.slice().sort() }) : "Sin días marcados: suena una sola vez"; muted: true; size: 11; elide: Text.ElideRight }
                WBtn {
                    id: addBtn
                    primary: true; icon: "plus"; text: "Añadir"
                    onClicked: { Alarms.add(pop.newH, pop.newM, alLabel.text, pop.newDays); alLabel.text = ""; pop.newDays = []; card.forceActiveFocus(); }
                }
            }

            WBtn { visible: pop.tab === "pomodoro"; text: "Modo sin distracciones y bloqueos"; icon: "settings"; onClicked: Shell.open("ajustesapp", "enfoque") }
        }
    }

    // Subtítulo de sección dentro de la ventana
    component Sub: RowLayout {
        property alias text: subT.text
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8
        Txt { id: subT; muted: true; size: 11; weight: Font.DemiBold }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
    }
}
