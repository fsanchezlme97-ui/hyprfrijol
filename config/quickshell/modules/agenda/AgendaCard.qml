// Agenda del centro de control (QuickSettings.qml; reloj de la barra = Shell.open("agenda") / Super + C):
// calendario del mes (es_ES, lunes primero) · eventos del día elegido con «Unirse» · relojes del mundo (WorldClock).
// Eventos: services/Events.qml (locales + .ics del ajuste calendarIcs). «+» añade un evento local o una tarea.
// Tareas: services/Tasks.qml, bajo los eventos (hoy: las vencidas arriba, en rojo, y las sin fecha; otro día: las
// que vencen ese día). Una tarea creada hoy queda sin fecha; en otro día, vence ese día.
// Teclas (cuando tiene el foco): ← → ↑ ↓ días · RePág/AvPág mes · Inicio = hoy · N nuevo evento · Esc cerrar.
// Contraído (botón ⌃ de la cabecera, ajuste calendarCollapsed): solo la semana del día elegido (con los días de los meses
// vecinos), para que eventos y relojes quepan sin desplazar; ‹ › pasan de semana. La rejilla se pliega deslizándose
// hasta esa fila (altura y desplazamiento animados con Theme.dur).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

Glass {
    id: win
    kind: "panel"
    implicitHeight: body.implicitHeight + 26

    property date month: new Date()      // día 1 del mes visible
    property date day: new Date()        // día elegido
    property bool adding: false
    property string addKind: "evento"    // el «+»: evento o tarea
    readonly property var es: Qt.locale("es_ES")
    readonly property date today: Time.now
    readonly property bool collapsed: Settings.get("calendarCollapsed", false) === true

    function sameDay(a, b): bool { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function cap(s: string): string { return s.charAt(0).toUpperCase() + s.slice(1); }
    function goMonth(d: int): void { const m = new Date(month); m.setMonth(m.getMonth() + d, 1); month = m; }
    function pick(d): void { day = d; if (d.getMonth() !== month.getMonth() || d.getFullYear() !== month.getFullYear()) month = new Date(d.getFullYear(), d.getMonth(), 1); }
    function moveDays(n: int): void { const d = new Date(day); d.setDate(d.getDate() + n); pick(d); }
    // Al abrir el centro: vuelve a hoy; focusKeys = dar el teclado al calendario (teclas del calendario)
    function reset(focusKeys: bool): void {
        const now = new Date();
        month = new Date(now.getFullYear(), now.getMonth(), 1); day = now; adding = false;
        if (focusKeys) Qt.callLater(() => keys.forceActiveFocus());
    }

    // 6×7 celdas (weekStart: 1 = lunes primero, 0 = domingo, 6 = sábado); los días de los meses vecinos solo se ven
    // contraído (out: fuera del mes)
    readonly property int weekStart: Number(Settings.get("weekStart", 1)) || 0
    readonly property var dayLetters: { const d = ["D", "L", "M", "X", "J", "V", "S"]; return d.slice(weekStart).concat(d.slice(0, weekStart)); }
    readonly property var cells: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const lead = (first.getDay() + 7 - weekStart) % 7;
        const n = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = lead; i > 0; i--) out.push(new Date(month.getFullYear(), month.getMonth(), 1 - i));
        for (let i = 1; i <= n; i++) out.push(new Date(month.getFullYear(), month.getMonth(), i));
        for (let i = 1; out.length % 7; i++) out.push(new Date(month.getFullYear(), month.getMonth() + 1, i));
        return out;
    }
    readonly property int rows: cells.length / 7
    // Fila que queda a la vista contraído: la del día elegido (o la de hoy, o la primera)
    readonly property int weekRow: {
        let i = cells.findIndex(d => sameDay(d, day));
        if (i < 0) i = cells.findIndex(d => sameDay(d, today));
        return Math.max(0, Math.floor(i / 7));
    }
    readonly property real cellH: 29
    onCollapsedChanged: foldAnim.restart()
    Timer { id: foldAnim; interval: Theme.dur + 60 }
    readonly property string dayTitle: {
        if (sameDay(day, today)) return "Hoy";
        const t = new Date(today); t.setDate(t.getDate() + 1);
        if (sameDay(day, t)) return "Mañana";
        const y = new Date(today); y.setDate(y.getDate() - 1);
        if (sameDay(day, y)) return "Ayer";
        return cap(es.toString(day, "dddd d 'de' MMMM"));
    }
    readonly property var dayEvents: { Events.all; return Events.forDay(day); }
    readonly property var dayTasks: { Tasks.list; return Tasks.forDay(day); }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 13 }
        spacing: 4

        // Cabecera: fecha de hoy grande (clic = volver a hoy) · mes · ‹ ›
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            spacing: 2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1
                Txt { text: win.cap(win.es.toString(win.today, "dddd")); size: 11.5; weight: Font.DemiBold; color: Theme.p }
                Txt {
                    Layout.fillWidth: true
                    text: win.cap(win.es.toString(win.month, "MMMM yyyy"))
                    size: 15; weight: Font.DemiBold
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.pick(new Date()) }
                }
            }
            IconBtn { implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6); icon: "chevron_left"; iconSize: 13; fg: Theme.tv; tooltip: win.collapsed ? "Semana anterior" : "Mes anterior"; onClicked: win.collapsed ? win.moveDays(-7) : win.goMonth(-1) }
            IconBtn { implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6); icon: "chevron_right"; iconSize: 13; fg: Theme.tv; tooltip: win.collapsed ? "Semana siguiente" : "Mes siguiente"; onClicked: win.collapsed ? win.moveDays(7) : win.goMonth(1) }
            IconBtn {
                implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6)
                icon: win.collapsed ? "chevron_down" : "chevron_up"; iconSize: 13; fg: Theme.tv
                tooltip: win.collapsed ? "Mostrar el mes" : "Contraer: solo esta semana"
                onClicked: {
                    // Al contraer, la semana que queda es la del día elegido: si el mes visible es otro, vuelve a él
                    if (!win.collapsed && (win.day.getMonth() !== win.month.getMonth() || win.day.getFullYear() !== win.month.getFullYear())) win.pick(win.day);
                    Settings.set("calendarCollapsed", !win.collapsed);
                }
            }
        }

        // Letras de los días (siempre a la vista)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 0
            Repeater {
                model: win.dayLetters
                Txt { required property string modelData; text: modelData; size: 10.5; muted: true; weight: Font.DemiBold; Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 20; horizontalAlignment: Text.AlignHCenter }
            }
        }
        // Días: contraído, la ventana se encoge a una fila y la rejilla sube hasta la semana elegida
        Item {
            id: daysClip
            Layout.fillWidth: true
            Layout.preferredHeight: (win.collapsed ? 1 : win.rows) * win.cellH
            Behavior on Layout.preferredHeight { enabled: !Theme.still; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            clip: true
            GridLayout {
                width: parent.width
                y: win.collapsed ? -win.weekRow * win.cellH : 0
                // solo al plegar o desplegar (al pasar de semana o de mes la fila cambia sin deslizarse)
                Behavior on y { enabled: !Theme.still && foldAnim.running; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
                columns: 7
                rowSpacing: 0
                columnSpacing: 0
                Repeater {
                    model: win.cells
                    delegate: Item {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: win.cellH
                        readonly property bool out: modelData.getMonth() !== win.month.getMonth()
                        // Fuera del mes: hueco con el mes entero; contraído, día atenuado de la semana
                        readonly property bool live: !out || win.collapsed
                        readonly property bool isToday: win.sameDay(modelData, win.today)
                        readonly property bool isSel: win.sameDay(modelData, win.day)
                        readonly property bool busy: { Events.all; return Events.hasDay(modelData); }
                        opacity: !live ? 0 : out ? 0.55 : 1
                        Behavior on opacity { enabled: !Theme.still; NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 27; height: 27; radius: 13.5
                            color: parent.isToday ? Theme.p : dayMa.containsMouse ? Theme.fill2 : "transparent"
                            border.width: parent.isSel && !parent.isToday ? 1.5 : 0
                            border.color: Theme.p
                            Txt {
                                anchors.centerIn: parent
                                text: parent.parent.modelData.getDate()
                                color: parent.parent.isToday ? Theme.pText : Theme.t
                                weight: parent.parent.isToday ? Font.Bold : Font.Normal
                                size: 12
                                tabular: true
                            }
                        }
                        // punto: hay eventos ese día
                        Rectangle {
                            visible: parent.busy
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                            width: 4; height: 4; radius: 2
                            color: parent.isToday ? Theme.pText : Theme.p
                            z: 1
                        }
                        MouseArea { id: dayMa; anchors.fill: parent; enabled: parent.live; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.pick(parent.modelData); keys.forceActiveFocus(); } }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 2; implicitHeight: 1; color: Theme.ov; opacity: 0.6 }

        // ── Eventos del día elegido ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            spacing: 4
            Txt {
                Layout.fillWidth: true
                readonly property int nt: win.dayTasks.filter(x => !x.done).length
                text: win.dayTitle + (win.dayEvents.length ? " · " + win.dayEvents.length + (win.dayEvents.length === 1 ? " evento" : " eventos") : "")
                      + (nt ? " · " + nt + (nt === 1 ? " tarea" : " tareas") : "")
                weight: Font.DemiBold
            }
            IconBtn {
                implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6)
                icon: win.adding ? "x" : "plus"; iconSize: 13
                tooltip: win.adding ? "Cancelar" : "Nuevo evento o tarea (N)"
                onClicked: { win.adding = !win.adding; if (win.adding) Qt.callLater(() => fTitle.focusInput()); else keys.forceActiveFocus(); }
            }
        }

        // Nuevo evento
        ColumnLayout {
            visible: win.adding
            Layout.fillWidth: true
            spacing: 6
            Segmented {
                h: 28
                model: [{ key: "evento", label: "Evento" }, { key: "tarea", label: "Tarea" }]
                current: win.addKind
                onPicked: k => { win.addKind = k; fTitle.focusInput(); }
            }
            Field { id: fTitle; Layout.fillWidth: true; h: 30; icon: win.addKind === "tarea" ? "check" : "calendar"
                    placeholder: win.addKind === "tarea" ? "Qué hay que hacer" : "Título del evento"; onAccepted: addBtn.clicked()
                    onKeyPressed: e => { if (e.key === Qt.Key_Escape) { win.adding = false; keys.forceActiveFocus(); e.accepted = true; } } }
            RowLayout {
                visible: win.addKind === "evento"
                Layout.fillWidth: true
                spacing: 6
                Field { id: fFrom; Layout.preferredWidth: 78; h: 30; icon: "clock"; placeholder: "10:00"; onAccepted: addBtn.clicked() }
                Txt { text: "–"; muted: true }
                Field { id: fTo; Layout.preferredWidth: 62; h: 30; icon: ""; placeholder: "11:00"; onAccepted: addBtn.clicked() }
                Field { id: fWhere; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Lugar o enlace"; onAccepted: addBtn.clicked() }
            }
            RowLayout {
                Layout.fillWidth: true
                Txt { Layout.fillWidth: true; text: win.addKind === "tarea" ? (win.sameDay(win.day, win.today) ? "Sin fecha" : "Vence " + win.dayTitle.toLowerCase()) : "Sin hora = todo el día"; size: 11; muted: true }
                Btn {
                    id: addBtn
                    kind: "primary"; h: 26; text: "Guardar"
                    enabled: fTitle.text.trim() !== ""
                    onClicked: {
                        if (!enabled) return;
                        if (win.addKind === "tarea") {
                            Tasks.add(fTitle.text, win.sameDay(win.day, win.today) ? "" : Events.key(win.day));
                            fTitle.text = "";
                            win.adding = false;
                            keys.forceActiveFocus();
                            return;
                        }
                        const t = s => { const m = s.trim().match(/^(\d{1,2})(?:[:.h](\d{2}))?$/); return m ? [+m[1], +(m[2] || 0)] : null; };
                        const a = t(fFrom.text), b = t(fTo.text);
                        const s = new Date(win.day), e = new Date(win.day);
                        if (a) { s.setHours(a[0], a[1], 0, 0); if (b) e.setHours(b[0], b[1], 0, 0); else e.setTime(s.getTime() + 3600000); }
                        else { s.setHours(0, 0, 0, 0); e.setTime(s.getTime() + 86400000); }
                        const w = fWhere.text.trim();
                        Events.add({ title: fTitle.text.trim(), start: s, end: e, allDay: !a, where: w, link: Events.linkIn(w) || (/^https?:\/\//.test(w) ? w : "") });
                        fTitle.text = fFrom.text = fTo.text = fWhere.text = "";
                        win.adding = false;
                        keys.forceActiveFocus();
                    }
                }
            }
        }

        ListView {
            visible: win.dayEvents.length > 0
            Layout.fillWidth: true
            // hasta 3 eventos a la vista; el resto, desplazando
            Layout.preferredHeight: Math.min(contentHeight, 3 * 50 + 8)
            clip: true
            spacing: 5
            model: win.dayEvents
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: ev
                required property var modelData
                readonly property var e: modelData
                readonly property bool soon: !e.allDay && e.start - win.today < 60 * 60000 && e.end > win.today
                readonly property bool past: e.end < win.today
                width: ListView.view.width
                height: evCol.implicitHeight + 14
                radius: Theme.r(6)
                color: Theme.fill2
                opacity: past ? 0.6 : 1
                Rectangle {
                    x: 9; y: 7; width: 3; height: parent.height - 14; radius: 2
                    color: Events.tint(ev.e.color)
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 8; topMargin: 7; bottomMargin: 7 }
                    spacing: 8
                    ColumnLayout {
                        id: evCol
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: ev.e.title; weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: (ev.e.allDay ? "Todo el día" : Events.hhmm(ev.e.start) + " – " + Events.hhmm(ev.e.end))
                                  + (ev.e.where && ev.e.where !== ev.e.link ? " · " + ev.e.where : ev.e.link ? " · videollamada" : "")
                                  + (ev.soon ? " · " + Events.relative(ev.e.start) : "")
                            muted: true; size: 11.5; elide: Text.ElideRight
                        }
                    }
                    Btn {
                        visible: !!ev.e.link
                        kind: ev.soon ? "primary" : "tonal"; h: 24; padX: 10; text: "Unirse"
                        onClicked: { Qt.openUrlExternally(ev.e.link); Shell.close(); }
                    }
                    IconBtn {
                        visible: ev.e.source === "local" && evMa.containsMouse
                        implicitWidth: 24; implicitHeight: 24
                        icon: "trash"; iconSize: 12
                        tooltip: "Borrar evento"
                        onClicked: Events.remove(ev.e)
                    }
                }
                MouseArea { id: evMa; anchors.fill: parent; z: -1; hoverEnabled: true }
            }
        }
        // Tareas del día: casilla para marcarlas; las vencidas en rojo; papelera al pasar por encima
        Repeater {
            model: win.dayTasks
            RowLayout {
                id: tk
                required property var modelData
                readonly property bool late: !modelData.done && !!modelData.due && modelData.due < Tasks.today
                Layout.fillWidth: true
                Layout.leftMargin: 3
                spacing: 8
                Rectangle {
                    implicitWidth: 16; implicitHeight: 16; radius: Theme.r(4)
                    color: tk.modelData.done ? Theme.p : "transparent"
                    border.width: tk.modelData.done ? 0 : 1.5
                    border.color: tk.late ? Theme.danger : Theme.o
                    Icon { anchors.centerIn: parent; visible: tk.modelData.done; name: "check"; size: 11; color: Theme.pText }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Tasks.toggle(tk.modelData.id) }
                }
                Txt {
                    Layout.fillWidth: true
                    text: tk.modelData.text + (tk.late ? " · vencida" : "")
                    color: tk.late ? Theme.danger : tk.modelData.done ? Theme.tv : Theme.t
                    font.strikeout: tk.modelData.done
                    elide: Text.ElideRight
                }
                IconBtn {
                    opacity: tkHov.hovered ? 1 : 0
                    implicitWidth: 22; implicitHeight: 22
                    icon: "trash"; iconSize: 11
                    tooltip: "Borrar tarea"
                    onClicked: Tasks.remove(tk.modelData.id)
                }
                HoverHandler { id: tkHov }
            }
        }
        Txt {
            visible: Tasks.list.length > 0 && !win.adding
            Layout.leftMargin: 3
            text: "Todas las tareas" + (Tasks.pending.length ? " (" + Tasks.pending.length + ")" : "") + "  ›"
            size: 11.5
            color: allMa.containsMouse ? Theme.t : Theme.p
            MouseArea { id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("tareas") }
        }
        RowLayout {
            visible: win.dayEvents.length === 0 && win.dayTasks.length === 0 && !win.adding
            Layout.fillWidth: true
            Layout.leftMargin: 3
            spacing: 6
            Txt {
                Layout.fillWidth: true
                text: Events.loading ? "Cargando calendarios…" : "Nada en la agenda"
                muted: true; size: 11.5
            }
            Txt {
                visible: !Events.loading && Events.sources.length === 0
                text: "Añadir calendarios"; size: 11.5
                color: icsMa.containsMouse ? Theme.t : Theme.p
                MouseArea { id: icsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("ajustesapp", "agenda") }
            }
        }

        // ── Relojes del mundo: «Madrid 18:25 +6 h» (clic: Ajustes › Fecha para añadir o quitar) ──
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 4
            Repeater {
                model: WorldClock.clocks
                Rectangle {
                    id: wcl
                    required property var modelData
                    width: wclRow.implicitWidth + 16
                    height: 22
                    radius: Theme.ctl(22)
                    color: wclMa.containsMouse ? Theme.fill2 : Qt.alpha(Theme.fill2, 0.55)
                    Row {
                        id: wclRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { name: "globe"; size: 11; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: wcl.modelData.name; size: 11; muted: true }
                        Txt { text: wcl.modelData.time; size: 11; weight: Font.DemiBold; tabular: true }
                        Txt { text: wcl.modelData.day ? wcl.modelData.day : wcl.modelData.diff === "misma hora" ? "" : wcl.modelData.diff; visible: text !== ""; size: 10.5; muted: true; tabular: true }
                    }
                    MouseArea { id: wclMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("ajustesapp", "fecha") }
                }
            }
            Rectangle {
                visible: WorldClock.clocks.length === 0
                width: addRow.implicitWidth + 16; height: 22; radius: Theme.ctl(22)
                color: addMa.containsMouse ? Theme.fill2 : "transparent"
                Row { id: addRow; anchors.centerIn: parent; spacing: 5
                    Icon { name: "globe"; size: 11; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "Añadir relojes del mundo"; size: 11; muted: true } }
                MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open("ajustesapp", "fecha") }
            }
        }
    }

    Item {
        id: keys
        Keys.onPressed: e => {
            switch (e.key) {
            case Qt.Key_Left: win.moveDays(-1); break;
            case Qt.Key_Right: win.moveDays(1); break;
            case Qt.Key_Up: win.moveDays(-7); break;
            case Qt.Key_Down: win.moveDays(7); break;
            case Qt.Key_PageUp: win.goMonth(-1); break;
            case Qt.Key_PageDown: win.goMonth(1); break;
            case Qt.Key_Home: win.pick(new Date()); break;
            case Qt.Key_N: case Qt.Key_Plus: win.adding = true; Qt.callLater(() => fTitle.focusInput()); break;
            default: return;
            }
            e.accepted = true;
        }
        Keys.onEscapePressed: Shell.close()
    }
}
