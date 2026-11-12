// Ajustes › Notificaciones — «no molestar» (y su horario: notifyDndSchedule/From/To), pantalla de bloqueo (notifyLock),
// posición y duración de los avisos (notifyPosition, notifyTimeout), sonido (notifySound) y, por aplicación
// (las que han avisado alguna vez: ~/.local/state/hyprfrijol/notify-apps.json), permitir / emergentes / sonido
// (notifyApps).
// Las reglas las aplica modules/settings/NotifRules.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var seen: ({})
    property string appQuery: ""
    readonly property var rules: Settings.get("notifyApps", ({}))
    readonly property var apps: Object.keys(seen).map(k => Object.assign({ key: k }, seen[k])).sort((a, b) => (b.last || 0) - (a.last || 0))
    readonly property var times: {
        const t = [];
        for (let h = 0; h < 24; h++) for (const m of ["00", "30"]) { const s = (h < 10 ? "0" : "") + h + ":" + m; t.push([s, s]); }
        return t;
    }

    FileView {
        id: appsFile
        path: Paths.state + "/notify-apps.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.seen = JSON.parse(text()) ?? {}; } catch (e) {} }
    }

    function setRule(k: string, field: string, v: bool): void {
        const all = Object.assign({}, rules);
        const r = Object.assign({}, all[k] ?? {});
        r[field] = v;
        if (r.allow !== false) delete r.allow;
        if (r.popups !== false) delete r.popups;
        if (r.sound !== false) delete r.sound;
        if (Object.keys(r).length) all[k] = r; else delete all[k];
        Settings.set("notifyApps", all);
    }
    function forget(k: string): void {
        const s = Object.assign({}, seen); delete s[k]; seen = s;
        appsFile.setText(JSON.stringify(s, null, 1) + "\n");
        setRule(k, "allow", true);
    }
    function iconFor(a): string {
        const e = a.entry ? DesktopEntries.heuristicLookup(a.entry) : DesktopEntries.heuristicLookup(a.name || a.key);
        const n = e?.icon || (/^(file:\/\/)?\/(run|tmp)\//.test(a.icon || "") ? "" : a.icon) || "";   // temporales: ver NotifRules.tempPath
        if (!n) return "";
        if (n.startsWith("/") || n.startsWith("file:") || n.startsWith("image:")) return n.startsWith("/") ? "file://" + n : n;
        return Quickshell.iconPath(n, true) || "";
    }
    function ago(t): string {
        if (!t) return "";
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "ahora";
        if (m < 60) return "hace " + m + " min";
        const h = Math.floor(m / 60);
        if (h < 24) return "hace " + h + " h";
        const d = Math.floor(h / 24);
        return d === 1 ? "ayer" : "hace " + d + " días";
    }

    // ---------------- general ----------------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "No molestar"
            SwRow {
                separator: false
                label: "No molestar"
                sub: "los avisos van al centro sin aparecer; los urgentes sí salen"
                checked: Notifs.dnd
                onToggled: v => Notifs.setDnd(v)
            }
            SwRow { label: "Activarlo con horario"; sub: "se enciende y se apaga solo cada día"; key: "notifyDndSchedule"; def: false }
            RowLayout {
                visible: Settings.get("notifyDndSchedule", false)
                Layout.fillWidth: true
                spacing: 10
                Txt { text: "Desde"; muted: true }
                Dropdown { Layout.preferredWidth: 110; model: root.times; current: Settings.get("notifyDndFrom", "22:00"); onPicked: k => Settings.set("notifyDndFrom", k) }
                Txt { text: "hasta"; muted: true }
                Dropdown { Layout.preferredWidth: 110; model: root.times; current: Settings.get("notifyDndTo", "07:00"); onPicked: k => Settings.set("notifyDndTo", k) }
                Item { Layout.fillWidth: true }
            }
            // Días en que empieza la franja (0 = domingo)
            Flow {
                visible: Settings.get("notifyDndSchedule", false)
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [[1, "L"], [2, "M"], [3, "X"], [4, "J"], [5, "V"], [6, "S"], [0, "D"]]
                    Chip {
                        required property var modelData
                        readonly property var days: Settings.get("notifyDndDays", [0, 1, 2, 3, 4, 5, 6]) ?? []
                        h: 28; mark: false
                        text: modelData[1]
                        on: days.includes(modelData[0])
                        onClicked: Settings.set("notifyDndDays", on ? days.filter(d => d !== modelData[0]) : days.concat([modelData[0]]).sort())
                    }
                }
                Txt {
                    height: 28; verticalAlignment: Text.AlignVCenter; leftPadding: 4
                    muted: true; size: 11.5
                    text: { const d = Settings.get("notifyDndDays", [0, 1, 2, 3, 4, 5, 6]) ?? []; return d.length === 7 ? "todos los días" : d.length === 5 && !d.includes(0) && !d.includes(6) ? "entre semana" : d.length === 0 ? "ningún día" : ""; }
                }
            }
            LinkRow { label: "Silenciar en modo sin distracciones"; target: "Silenciar notificaciones"; value: Settings.get("focusMuteNotifs", true) ? "Activado" : "Desactivado"; section: "enfoque"; sectionLabel: "Enfoque y pomodoro" }
        }
        Section {
            Layout.fillWidth: true
            title: "Avisos emergentes"
            LabeledRow {
                label: "Posición"; labelWidth: 110
                Dropdown {
                    h: 32
                    model: [["auto", "Según la barra"], ["sup-der", "Arriba a la derecha"], ["sup-centro", "Arriba en el centro"], ["sup-izq", "Arriba a la izquierda"],
                            ["inf-der", "Abajo a la derecha"], ["inf-centro", "Abajo en el centro"], ["inf-izq", "Abajo a la izquierda"]]
                    current: Settings.get("notifyPosition", "auto")
                    onPicked: k => Settings.set("notifyPosition", k)
                }
            }
            LabeledRow {
                visible: Quickshell.screens.length > 1
                label: "Pantalla"; labelWidth: 110
                Dropdown {
                    h: 32
                    model: [["activa", "La que tiene el foco"], ["principal", "La principal"]].concat(Quickshell.screens.map(s => [s.name, s.name]))
                    current: Settings.get("notifyScreen", "activa")
                    onPicked: k => Settings.set("notifyScreen", k)
                }
            }
            LabeledRow {
                label: "Duración"; labelWidth: 110
                Pills {
                    model: [[3, "3 s"], [6, "6 s"], [10, "10 s"], [15, "15 s"], [30, "30 s"]]
                    current: Settings.get("notifyTimeout", 6)
                    onPicked: k => Settings.set("notifyTimeout", k)
                }
            }
            LabeledRow {
                label: "A la vez"; labelWidth: 110
                Pills {
                    model: [[2, "2"], [3, "3"], [4, "4"], [6, "6"]]
                    current: Settings.get("notifyMaxPopups", 4)
                    onPicked: k => Settings.set("notifyMaxPopups", k)
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Si una app pide otro tiempo se respeta. Con el ratón encima, el aviso no se cierra; los urgentes se quedan hasta que los cierres. Los avisos de una misma app se apilan (+N) y se despliegan con un clic; arrástralos a un lado para descartarlos."
            }
            SwRow { label: "Sonido al recibir un aviso"; sub: "canberra-gtk-play · " + Settings.get("notifySoundName", "message-new-instant"); key: "notifySound"; def: false }
            SwRow { label: "En la pantalla de bloqueo"; sub: "cuántos avisos hay, nunca su contenido"; key: "notifyLock"; def: true }
            SwRow { label: "Guardar historial"; sub: "los últimos 300 avisos, con búsqueda, en el centro de notificaciones"; key: "notifyHistory"; def: true }
            RowLayout {
                Layout.topMargin: 2
                spacing: 8
                Button {
                    text: "Enviar un aviso de prueba"
                    onClicked: Quickshell.execDetached(["notify-send", "-a", "Ajustes", "-i", "preferences-system-notifications", "Aviso de prueba", "Así se verán tus notificaciones."])
                }
                Button { text: "Abrir el centro"; onClicked: Shell.open("notificaciones") }
                Button { kind: "link"; visible: Notifs.history.length > 0; text: "Vaciar historial (" + Notifs.history.length + ")"; onClicked: Notifs.clearHistory() }
            }
        }
    }

    // ---------------- por aplicación ----------------
    ColumnLayout {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Aplicaciones"
            headerRight: Mono { text: root.apps.length ? root.apps.length + (root.apps.length === 1 ? " app" : " apps") : "" }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Las apps aparecen aquí cuando envían su primer aviso."
            }
            Field {
                visible: root.apps.length > 6
                Layout.fillWidth: true
                h: 30
                placeholder: "Buscar app…"
                onTextChanged: root.appQuery = text.trim().toLowerCase()
            }
            Repeater {
                model: root.appQuery === "" ? root.apps : root.apps.filter(a => String(a.name || a.key).toLowerCase().includes(root.appQuery))
                Item {
                    id: ap
                    required property var modelData
                    readonly property var r: root.rules[modelData.key] ?? {}
                    readonly property bool allowed: r.allow !== false
                    Layout.fillWidth: true
                    implicitHeight: col.implicitHeight + 16
                    Rectangle { width: parent.width; height: 1; color: Theme.ov }
                    ColumnLayout {
                        id: col
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                implicitWidth: 30; implicitHeight: 30; radius: Theme.r(6)
                                color: Theme.s4
                                Image {
                                    id: ic
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    sourceSize: Qt.size(44, 44)
                                    source: root.iconFor(ap.modelData)
                                    visible: status === Image.Ready
                                }
                                Txt { anchors.centerIn: parent; visible: !ic.visible; text: String(ap.modelData.name || ap.modelData.key).charAt(0).toUpperCase(); weight: Font.DemiBold }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Txt { Layout.fillWidth: true; text: ap.modelData.name || ap.modelData.key; weight: Font.DemiBold; opacity: ap.allowed ? 1 : 0.6 }
                                Txt {
                                    Layout.fillWidth: true; muted: true; size: 11.5
                                    text: ap.allowed ? root.ago(ap.modelData.last) + " · " + (ap.modelData.count || 1) + ((ap.modelData.count || 1) === 1 ? " aviso" : " avisos") : "Bloqueada: sus avisos se descartan"
                                }
                            }
                            Sw { checked: ap.allowed; onToggled: v => root.setRule(ap.modelData.key, "allow", v) }
                        }
                        RowLayout {
                            visible: ap.allowed
                            Layout.fillWidth: true
                            Layout.leftMargin: 40
                            spacing: 6
                            Chip { h: 26; text: "Emergentes"; on: ap.r.popups !== false; onClicked: root.setRule(ap.modelData.key, "popups", !on) }
                            Chip { h: 26; text: "Sonido"; on: ap.r.sound !== false; opacity: Settings.get("notifySound", false) ? 1 : 0.5; onClicked: root.setRule(ap.modelData.key, "sound", !on) }
                            Item { Layout.fillWidth: true }
                            Button { kind: "link"; text: "Historial"; onClicked: Shell.open("notificaciones", { app: String(ap.modelData.name || ap.modelData.key) }) }
                            Button { kind: "link"; text: "Olvidar"; onClicked: root.forget(ap.modelData.key) }
                        }
                    }
                }
            }
            ColumnLayout {
                visible: root.apps.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 4
                Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Aún no ha llegado ningún aviso"; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; muted: true; size: 11.5; text: "Prueba con «Enviar un aviso de prueba»." }
            }
        }
    }
}
