// «Tareas»: app suelta (su propia ventana, en el menú de apps y en Spotlight) para la lista de services/Tasks.qml
// (~/.local/share/hyprfrijol/tasks.json). Antes vivía dentro de Ajustes › Productividad; Ajustes es para ajustes.
// Añadir con fecha rápida (sin fecha, hoy, mañana o un día), marcar, editar (doble clic o el lápiz), borrar y
// limpiar las hechas. Agrupadas: vencidas, hoy, mañana, más adelante, sin fecha y hechas.
// Se abre con la vista "tareas" (Spotlight, la agenda, hf-tareas, hf-tareas.desktop) o por IPC:
//   qs -p <repo>/config/quickshell ipc call tareas open | close | toggle
// Atajos: Ctrl + N nueva · Ctrl + W o Esc cerrar · Alt + 1/2/3 cambian el filtro · Ctrl + Z deshace un borrado.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    property bool open: false

    Connections {
        target: Shell
        function onOpened(v) {
            if (v !== "tareas") return;
            root.open = true;
            Shell.close();
        }
    }
    IpcHandler {
        target: "tareas"
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
        function toggle(): void { root.open = !root.open; }
        function state(): string { return root.open ? "abierta" : "cerrada"; }
    }

    LazyLoader {
        active: root.open
        FloatingWindow {
            id: win
            title: "Tareas"
            readonly property var scr: Shell.screen
            implicitWidth: Math.min(640, Math.round((scr?.width ?? 1920) * 0.6))
            implicitHeight: Math.min(760, Math.round((scr?.height ?? 1080) * 0.82))
            minimumSize: Qt.size(Math.min(420, implicitWidth), Math.min(420, implicitHeight))
            visible: true
            color: Theme.blur ? Theme.winSolid : Theme.s1
            surfaceFormat.opaque: false            // ver Firmar/Ajustes: si nace opaca no puede volverse translúcida
            onVisibleChanged: if (!visible) root.open = false

            OpenProbe { name: "tareas"; shown: true }
            Shortcut { sequence: "Ctrl+W"; onActivated: root.open = false }
            // Esc cierra la ventana solo si no se está editando una tarea (ahí cancela la edición)
            Shortcut { sequence: "Escape"; enabled: win.editing === ""; onActivated: root.open = false }
            // Filtros: Alt + 1, 2, 3 (los números solos se escriben en la caja de la tarea nueva)
            Shortcut { sequence: "Alt+1"; onActivated: win.filter = "pendientes" }
            Shortcut { sequence: "Alt+2"; onActivated: win.filter = "hechas" }
            Shortcut { sequence: "Alt+3"; onActivated: win.filter = "todas" }
            Shortcut { sequence: "Ctrl+N"; onActivated: addField.focusInput() }

            // ---------- estado ----------
            property string filter: "pendientes"   // pendientes | hechas | todas
            property string when: "sin"            // sin | hoy | manana | dia
            property string editing: ""            // id de la tarea que se está editando
            readonly property string today: Tasks.today
            readonly property string tomorrow: { Time.now; const d = new Date(); d.setDate(d.getDate() + 1); return Events.key(d); }
            readonly property int nPending: Tasks.pending.length
            readonly property int nLate: Tasks.overdue.length
            readonly property int nDone: Tasks.list.length - Tasks.pending.length

            function dueFor(): string {
                return when === "hoy" ? today : when === "manana" ? tomorrow
                     : when === "dia" ? (Tasks.parseDue(dayField.text) || "") : "";
            }
            function add(): void {
                const t = addField.text.trim();
                if (!t || (when === "dia" && !dueFor())) return;
                Tasks.add(t, dueFor());
                addField.text = "";
                if (filter === "hechas") filter = "pendientes";
            }
            // «12 nov», «hoy», «mañana», «ayer»
            function dueText(k): string {
                if (!k) return "";
                if (k === today) return "hoy";
                if (k === tomorrow) return "mañana";
                const p = k.split("-").map(Number), d = new Date(p[0], p[1] - 1, p[2]);
                const y = new Date(); y.setDate(y.getDate() - 1);
                if (k === Events.key(y)) return "ayer";
                const m = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"][d.getMonth()];
                return d.getDate() + " " + m + (d.getFullYear() !== new Date().getFullYear() ? " " + d.getFullYear() : "");
            }
            readonly property var groups: {
                const L = Tasks.list, t = today, m = tomorrow;
                const by = (a, b) => String(a.due || "9").localeCompare(String(b.due || "9")) || a.created - b.created;
                const pend = L.filter(x => !x.done);
                const g = [];
                const push = (key, label, items, tone, sorted) => { if (items.length) g.push({ key: key, label: label, items: sorted ? items : items.sort(by), tone: tone ?? "" }); };
                if (filter !== "hechas") {
                    push("late", "Vencidas", pend.filter(x => x.due && x.due < t), "danger");
                    push("today", "Hoy", pend.filter(x => x.due === t));
                    push("tomorrow", "Mañana", pend.filter(x => x.due === m));
                    push("later", "Más adelante", pend.filter(x => x.due && x.due > m));
                    push("none", "Sin fecha", pend.filter(x => !x.due));
                }
                if (filter !== "pendientes")
                    push("done", "Hechas", L.filter(x => x.done).sort((a, b) => (b.doneAt ?? 0) - (a.doneAt ?? 0)), "", true);   // las últimas hechas, arriba
                return g;
            }

            Item {
                anchors.fill: parent

                // «Deshacer» unos segundos tras borrar una tarea o las hechas (services/Tasks.qml); también Ctrl + Z
                Shortcut { sequence: "Ctrl+Z"; enabled: Tasks.removed.length > 0; onActivated: Tasks.undo() }
                Rectangle {
                    z: 10
                    visible: Tasks.removed.length > 0
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 18 }
                    implicitWidth: undoRow.implicitWidth + 24; implicitHeight: 42; radius: Theme.r(10)
                    color: Theme.s3; border.width: 1; border.color: Theme.ov
                    RowLayout {
                        id: undoRow
                        anchors.centerIn: parent
                        spacing: 12
                        Txt { text: Tasks.removedLabel }
                        Btn { text: "Deshacer"; kind: "primary"; h: 28; hint: "Ctrl Z"; onClicked: Tasks.undo() }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    anchors.topMargin: 20
                    spacing: 14

                    // ---------- cabecera ----------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 40; radius: Theme.r(10)
                            color: Theme.pc
                            Icon { anchors.centerIn: parent; name: "check"; size: 20; stroke: 2; color: Theme.pcText }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt { text: "Tareas"; size: 19; weight: Font.DemiBold }
                            Txt {
                                Layout.fillWidth: true
                                text: win.nPending === 0 ? (win.nDone ? "Todo hecho" : "Nada pendiente")
                                    : (win.nPending === 1 ? "1 pendiente" : win.nPending + " pendientes")
                                      + (win.nLate ? " · " + (win.nLate === 1 ? "1 vencida" : win.nLate + " vencidas") : "")
                                color: win.nLate ? Theme.danger : Theme.tv
                                size: 12
                            }
                        }
                        Btn {
                            visible: win.nDone > 0
                            text: "Borrar las hechas"
                            h: 28
                            onClicked: Tasks.clearDone()
                        }
                    }

                    // ---------- añadir ----------
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: addCol.implicitHeight + 20
                        radius: Theme.r(12)
                        color: Qt.alpha(Theme.t, 0.04)
                        border.width: 1
                        border.color: Theme.ov
                        ColumnLayout {
                            id: addCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Field {
                                    id: addField
                                    Layout.fillWidth: true
                                    h: 36
                                    icon: "plus"
                                    placeholder: "Nueva tarea · Intro para añadir"
                                    onAccepted: win.add()
                                    Component.onCompleted: focusInput()
                                }
                                Btn {
                                    kind: "primary"
                                    h: 36
                                    text: "Añadir"
                                    enabled: addField.text.trim() !== "" && (win.when !== "dia" || win.dueFor() !== "")
                                    onClicked: win.add()
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Txt { text: "Vence"; muted: true; size: 12 }
                                Segmented {
                                    h: 28
                                    model: [{ key: "sin", label: "Sin fecha" }, { key: "hoy", label: "Hoy" }, { key: "manana", label: "Mañana" }, { key: "dia", label: "Otro día" }]
                                    current: win.when
                                    onPicked: k => { win.when = k; if (k === "dia") dayField.focusInput(); }
                                }
                                Field {
                                    id: dayField
                                    visible: win.when === "dia"
                                    Layout.preferredWidth: 150
                                    h: 28
                                    icon: "calendar"
                                    placeholder: "vie, 12 nov, 12/11…"
                                    onAccepted: win.add()
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    // ---------- filtro ----------
                    Segmented {
                        h: 30
                        model: [{ key: "pendientes", label: "Pendientes" + (win.nPending ? " · " + win.nPending : "") },
                                { key: "hechas", label: "Hechas" + (win.nDone ? " · " + win.nDone : "") },
                                { key: "todas", label: "Todas" }]
                        current: win.filter
                        onPicked: k => win.filter = k
                    }

                    // ---------- lista ----------
                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: listCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: listCol
                            width: flick.width
                            spacing: 14
                            Repeater {
                                model: win.groups
                                ColumnLayout {
                                    id: grp
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.bottomMargin: 4
                                        spacing: 6
                                        Txt { text: grp.modelData.label; weight: Font.DemiBold; size: 12; color: grp.modelData.tone === "danger" ? Theme.danger : Theme.tv }
                                        Txt { text: String(grp.modelData.items.length); size: 11; muted: true; tabular: true }
                                    }
                                    Repeater {
                                        model: grp.modelData.items
                                        Rectangle {
                                            id: tk
                                            required property var modelData
                                            readonly property bool late: !modelData.done && !!modelData.due && modelData.due < win.today
                                            readonly property bool edit: win.editing === modelData.id
                                            Layout.fillWidth: true
                                            implicitHeight: 42
                                            radius: Theme.r(8)
                                            color: tkHov.hovered || tk.edit ? Qt.alpha(Theme.t, 0.05) : "transparent"
                                            HoverHandler { id: tkHov }
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 6
                                                spacing: 10
                                                // casilla
                                                Rectangle {
                                                    implicitWidth: 20; implicitHeight: 20; radius: Theme.r(5)
                                                    color: tk.modelData.done ? Theme.p : "transparent"
                                                    border.width: tk.modelData.done ? 0 : 1.6
                                                    border.color: tk.late ? Theme.danger : Theme.o
                                                    Behavior on color { ColorAnimation { duration: Theme.durShort } }
                                                    Icon { anchors.centerIn: parent; visible: tk.modelData.done; name: "check"; size: 13; stroke: 2.2; color: Theme.pText }
                                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Tasks.toggle(tk.modelData.id) }
                                                }
                                                // texto (o su edición)
                                                Txt {
                                                    visible: !tk.edit
                                                    Layout.fillWidth: true
                                                    text: tk.modelData.text
                                                    color: tk.modelData.done ? Theme.tv : Theme.t
                                                    font.strikeout: tk.modelData.done
                                                    elide: Text.ElideRight
                                                    MouseArea { anchors.fill: parent; onDoubleClicked: if (!tk.modelData.done) win.editing = tk.modelData.id }
                                                }
                                                Field {
                                                    id: ed
                                                    visible: tk.edit
                                                    Layout.fillWidth: true
                                                    h: 30
                                                    icon: ""
                                                    text: tk.modelData.text
                                                    onVisibleChanged: if (visible) { text = tk.modelData.text; focusInput(); input.selectAll(); }
                                                    onAccepted: { Tasks.edit(tk.modelData.id, text, edDue.text.trim()); win.editing = ""; }
                                                    onKeyPressed: e => { if (e.key === Qt.Key_Escape) { win.editing = ""; e.accepted = true; } }
                                                }
                                                Field {
                                                    id: edDue
                                                    visible: tk.edit
                                                    Layout.preferredWidth: 128
                                                    h: 30
                                                    icon: "calendar"
                                                    placeholder: "sin fecha"
                                                    text: tk.modelData.due ?? ""
                                                    onVisibleChanged: if (visible) text = tk.modelData.due ?? ""
                                                    onAccepted: { Tasks.edit(tk.modelData.id, ed.text, text.trim()); win.editing = ""; }
                                                    onKeyPressed: e => { if (e.key === Qt.Key_Escape) { win.editing = ""; e.accepted = true; } }
                                                    // fecha que no se entiende: en rojo (al guardar se quedaría la que tenía)
                                                    input.color: Tasks.parseDue(text) === null ? Theme.danger : Theme.t
                                                }
                                                Txt {
                                                    visible: !tk.edit && !!tk.modelData.due
                                                    text: (tk.late ? "vencida · " : "") + win.dueText(tk.modelData.due)
                                                    size: 11.5; tabular: true
                                                    color: tk.late ? Theme.danger : Theme.tv
                                                }
                                                IconBtn {
                                                    visible: !tk.modelData.done
                                                    opacity: tkHov.hovered || tk.edit ? 1 : 0
                                                    implicitWidth: 26; implicitHeight: 26
                                                    icon: tk.edit ? "check" : "edit"; iconSize: 12
                                                    tooltip: tk.edit ? "Guardar (Intro)" : "Editar (doble clic)"
                                                    onClicked: {
                                                        if (tk.edit) { Tasks.edit(tk.modelData.id, ed.text, edDue.text.trim()); win.editing = ""; }
                                                        else win.editing = tk.modelData.id;
                                                    }
                                                }
                                                IconBtn {
                                                    opacity: tkHov.hovered ? 1 : 0
                                                    implicitWidth: 26; implicitHeight: 26
                                                    icon: "trash"; iconSize: 12
                                                    tooltip: "Borrar"
                                                    onClicked: Tasks.remove(tk.modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // vacío
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: win.groups.length === 0
                            spacing: 6
                            Icon { Layout.alignment: Qt.AlignHCenter; name: "check"; size: 28; stroke: 1.6; color: Theme.tv }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: win.filter === "hechas" ? "Aún no has terminado ninguna" : "Nada pendiente"
                                muted: true
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                visible: win.filter !== "hechas"
                                text: "También se añaden con +texto en Spotlight o pidiéndoselas al asistente"
                                muted: true; size: 11
                            }
                        }
                    }
                }
            }
        }
    }
}
