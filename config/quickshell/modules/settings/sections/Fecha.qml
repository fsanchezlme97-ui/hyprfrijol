// Ajustes › Fecha, hora e idioma — timedatectl (hora automática NTP, zona horaria, hora manual, reloj del
// equipo en hora local), formato de 24 h (clock24 → services/Time.qml) y primer día de la semana (weekStart →
// calendario de la agenda), relojes del mundo (worldClocks), idioma del sistema (localectl set-locale), idioma
// y formatos de tu sesión (~/.config/locale.conf: LANG y LC_TIME/NUMERIC/MONETARY/MEASUREMENT/PAPER) y añadir
// idiomas (descomenta /etc/locale.gen y ejecuta locale-gen con pkexec) y calendarios .ics de la agenda
// (calendarIcs: [{ url, name, color }] → services/Events.qml; ui/IcsCalendars.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var td: ({})               // salida de timedatectl show
    property var zones: []
    property var locales: []            // generados (localectl list-locales)
    property var available: []          // en /etc/locale.gen (UTF-8)
    property string sysLang: ""
    property var user: ({})             // ~/.config/locale.conf
    property var preview: ({})          // { date, num, money }
    readonly property bool ntp: td.NTP === "yes"

    function refresh() { tdProc.running = false; tdProc.running = true; }
    Timer { id: later; interval: 1200; onTriggered: root.refresh() }
    Process {
        id: tdProc
        running: true
        command: ["sh", "-c", "timedatectl show 2>/dev/null; echo \"SYS=$(localectl status 2>/dev/null | sed -n 's/.*System Locale: LANG=//p')\"; "
            + "[ -f \"$HOME/.config/locale.conf\" ] && sed -n 's/^\\([A-Z_]*\\)=\"\\{0,1\\}\\([^\"]*\\)\"\\{0,1\\}$/U_\\1=\\2/p' \"$HOME/.config/locale.conf\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}, u = {};
                text.split("\n").forEach(l => { const i = l.indexOf("="); if (i < 0) return; const k = l.slice(0, i), v = l.slice(i + 1); if (k.startsWith("U_")) u[k.slice(2)] = v; else o[k] = v; });
                root.td = o; root.sysLang = o.SYS ?? ""; root.user = u;
                if (!dateField.input.activeFocus) dateField.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd");
                if (!timeField.input.activeFocus) timeField.text = Qt.formatDateTime(new Date(), "HH:mm");
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null | sed 's/^/z:/'; localectl list-locales 2>/dev/null | sed 's/^/l:/'; "
            + "sed -n 's/^#\\{0,1\\} *\\([A-Za-z_@.0-9-]*\\.UTF-8\\) UTF-8.*/a:\\1/p' /etc/locale.gen 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.zones = l.filter(x => x.startsWith("z:")).map(x => x.slice(2));
                root.locales = l.filter(x => x.startsWith("l:")).map(x => x.slice(2)).filter(x => x !== "C.UTF-8");
                root.available = l.filter(x => x.startsWith("a:")).map(x => x.slice(2));
            }
        }
    }

    // nombre legible: «español (Perú)» con los nombres nativos de Qt
    function langName(code) {
        if (!code) return "";
        const base = code.replace(/\..*$/, "").replace(/@.*$/, "");
        const lc = Qt.locale(base);
        if (lc.name === "C" || !lc.nativeLanguageName) return code;
        const n = lc.nativeLanguageName + (base.includes("_") && lc.nativeTerritoryName ? " (" + lc.nativeTerritoryName + ")" : "");
        return n.charAt(0).toUpperCase() + n.slice(1);
    }
    function zoneName(z) { return z.replace(/_/g, " ").replace(/\//g, " / "); }
    readonly property string userLang: user.LANG ?? ""
    readonly property string userFormats: user.LC_TIME ?? ""

    // escribe ~/.config/locale.conf (se aplica al volver a iniciar sesión)
    function writeUserLocale(lang, fmt) {
        const lines = [];
        if (lang) lines.push("LANG=" + lang);
        if (fmt) ["LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_MEASUREMENT", "LC_PAPER"].forEach(k => lines.push(k + "=" + fmt));
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config\"; if [ -n \"$1\" ]; then printf '%s\\n' \"$1\" > \"$HOME/.config/locale.conf\"; else rm -f \"$HOME/.config/locale.conf\"; fi", "sh", lines.join("\n")]);
        later.restart();
    }
    function addLocale(code) {
        Quickshell.execDetached(["pkexec", "sh", "-c", "c=$(printf '%s' \"$1\" | sed 's/[.]/[.]/g'); sed -i \"s/^# *\\($c UTF-8\\)/\\1/\" /etc/locale.gen && locale-gen", "sh", code]);
        localesLater.restart();
    }
    Timer { id: localesLater; interval: 9000; onTriggered: { root.refreshLocales(); } }
    function refreshLocales() { locProc.running = false; locProc.running = true; }
    Process {
        id: locProc
        command: ["localectl", "list-locales"]
        stdout: StdioCollector { onStreamFinished: root.locales = text.split("\n").filter(x => x && x !== "C.UTF-8") }
    }

    // vista previa de formatos
    readonly property string fmtLocale: userFormats || userLang || sysLang
    onFmtLocaleChanged: if (fmtLocale) { prevProc.running = false; prevProc.running = true; }
    Process {
        id: prevProc
        command: ["sh", "-c", "export LC_ALL=\"$1\"; date '+%x'; date '+%A %e de %B'; printf \"%'.2f\\n\" 1234567.89; locale currency_symbol 2>/dev/null; locale -k LC_PAPER 2>/dev/null | sed -n 's/height=//p'", "sh", root.fmtLocale]
        stdout: StdioCollector {
            onStreamFinished: { const l = text.split("\n"); root.preview = { date: l[0], long: l[1], num: l[2], cur: l[3], paper: l[4] === "279" ? "Carta" : l[4] === "297" ? "A4" : l[4] }; }
        }
    }

    // ---------- fecha y hora ----------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Fecha y hora"
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Txt { text: Time.hhmm; size: 34; weight: Font.Medium; tabular: true }
                Txt { visible: Time.ampm !== ""; text: Time.ampm; size: 14; muted: true; Layout.alignment: Qt.AlignBaseline }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: Time.longDate.charAt(0).toUpperCase() + Time.longDate.slice(1) + " de " + Time.now.getFullYear(); weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; muted: true; size: 11.5; text: root.zoneName(root.td.Timezone ?? "") + (root.ntp ? (root.td.NTPSynchronized === "yes" ? " · sincronizada" : " · sincronizando…") : " · manual") }
                }
            }
            SwRow {
                label: "Fecha y hora automáticas"
                sub: root.td.CanNTP === "no" ? "no hay servicio NTP (systemd-timesyncd)" : "por Internet (NTP)"
                enabled: root.td.CanNTP !== "no"
                checked: root.ntp
                onToggled: v => { Quickshell.execDetached(["timedatectl", "set-ntp", v ? "true" : "false"]); later.restart(); }
            }
            RowLayout {
                visible: !root.ntp
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Ajustar a mano"; muted: true; Layout.preferredWidth: 110 }
                Field { id: dateField; Layout.fillWidth: true; icon: "calendar"; placeholder: "AAAA-MM-DD" }
                Field { id: timeField; Layout.preferredWidth: 96; icon: "clock"; placeholder: "HH:MM" }
                Button {
                    kind: "primary"; text: "Aplicar"
                    enabled: /^\d{4}-\d{2}-\d{2}$/.test(dateField.text.trim()) && /^\d{1,2}:\d{2}(:\d{2})?$/.test(timeField.text.trim())
                    onClicked: { Quickshell.execDetached(["timedatectl", "set-time", dateField.text.trim() + " " + timeField.text.trim() + (timeField.text.trim().length <= 5 ? ":00" : "")]); later.restart(); }
                }
            }
            LabeledRow {
                label: "Zona horaria"; labelWidth: 110
                Dropdown {
                    model: root.zones.map(z => [z, root.zoneName(z)])
                    current: root.td.Timezone ?? ""
                    popupWidth: 320
                    searchable: true
                    onPicked: k => { Quickshell.execDetached(["timedatectl", "set-timezone", k]); later.restart(); }
                }
            }
            Button {
                kind: "link"; text: "Detectar zona por mi ubicación (IP)"
                onClicked: Quickshell.execDetached(["sh", "-c", "z=$(curl -fsS --max-time 6 https://ipapi.co/timezone || curl -fsS --max-time 6 https://ipinfo.io/timezone) && [ -n \"$z\" ] && timedatectl set-timezone \"$z\" && notify-send -a Ajustes 'Zona horaria' \"$z\""])
            }
            SwRow {
                label: "Reloj del equipo en hora local"
                sub: "actívalo solo si arrancas también Windows y la hora sale mal"
                checked: root.td.LocalRTC === "yes"
                onToggled: v => { Quickshell.execDetached(["timedatectl", "set-local-rtc", v ? "1" : "0"]); later.restart(); }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Formato"
            SwRow { separator: false; label: "Formato de 24 horas"; sub: Time.h24 ? "14:30" : "2:30 p. m."; key: "clock24"; def: true }
            LabeledRow {
                label: "La semana empieza el"; labelWidth: 150
                Seg {
                    model: [[1, "Lunes"], [0, "Domingo"], [6, "Sábado"]]
                    current: Number(Settings.get("weekStart", 1))
                    onPicked: k => Settings.set("weekStart", k)
                }
            }
        }
        // Relojes del mundo (services/WorldClock.qml: worldClocks [[nombre, zona], …]); se ven en la agenda y
        // al pasar el cursor por la hora de la barra. Búsqueda por ciudad, país (en español) o zona, sin tildes.
        Section {
            Layout.fillWidth: true
            title: "Relojes del mundo"
            headerRight: Mono { text: "agenda · hora de la barra" }
            Repeater {
                model: WorldClock.clocks
                RowLayout {
                    id: wc
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 12
                    Txt { Layout.preferredWidth: 80; text: wc.modelData.time; tabular: true; weight: Font.DemiBold; size: 14 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: wc.modelData.name; weight: Font.Medium }
                        Txt {
                            Layout.fillWidth: true; muted: true; size: 11
                            readonly property var zone: WorldClock.zones.find(x => x.tz === wc.modelData.tz)
                            text: (zone ? zone.country : root.zoneName(wc.modelData.tz)) + " · " + wc.modelData.diff + (wc.modelData.day ? " · " + wc.modelData.day : "")
                        }
                    }
                    IconBtn { icon: "chevron_up"; visible: wc.index > 0; onClicked: WorldClock.move(wc.index, -1) }
                    IconBtn { icon: "x"; onClicked: WorldClock.remove(wc.index) }
                }
            }
            Txt { visible: WorldClock.clocks.length === 0; muted: true; text: "Sin relojes. Añade una ciudad." }
            Field {
                id: wcSearch
                Layout.fillWidth: true
                placeholder: "Añadir ciudad o país… (p. ej. Tokio, Perú, Berlín)"
                onAccepted: if (wcResults.count > 0) { WorldClock.add(wcResults.model[0].tz); text = ""; }
                onKeyPressed: e => { if (e.key === Qt.Key_Escape && text !== "") { text = ""; e.accepted = true; } }
            }
            ListView {
                id: wcResults
                visible: wcSearch.text.trim() !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(6, count) * 34
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: visible ? WorldClock.search(wcSearch.text).filter(z => !WorldClock.list.some(c => c[1] === z.tz)).slice(0, 40) : []
                delegate: Rectangle {
                    id: zr
                    required property var modelData
                    width: ListView.view.width
                    height: 34
                    radius: Theme.r(6)
                    color: zma.containsMouse ? Theme.fill2 : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Txt { text: zr.modelData.city; weight: Font.Medium }
                        Txt { Layout.fillWidth: true; text: zr.modelData.country; muted: true }
                        Txt { text: zr.modelData.tz; muted: true; size: 11; font.family: "monospace" }
                        Icon { name: "plus"; size: 13; color: Theme.tv }
                    }
                    MouseArea { id: zma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { WorldClock.add(zr.modelData.tz); wcSearch.text = ""; } }
                }
            }
            Txt { visible: wcSearch.text.trim() !== "" && wcResults.count === 0; muted: true; size: 11.5; text: "No hay ninguna zona con «" + wcSearch.text.trim() + "»." }
        }
    }

    // ---------- idioma y región ----------
    ColumnLayout {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Idioma y región"
            LabeledRow {
                label: "Idioma de tu sesión"; labelWidth: 140
                hint: "~/.config/locale.conf"
                Dropdown {
                    model: [["", "Igual que el sistema"]].concat(root.locales.map(l => [l, root.langName(l)]))
                    current: root.userLang
                    popupWidth: 300
                    onPicked: k => root.writeUserLocale(k, root.userFormats)
                }
            }
            LabeledRow {
                label: "Formatos"; labelWidth: 140
                hint: "fecha, números…"
                Dropdown {
                    model: [["", "Según el idioma"]].concat(root.locales.map(l => [l, root.langName(l)]))
                    current: root.userFormats
                    popupWidth: 300
                    onPicked: k => root.writeUserLocale(root.userLang, k)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: pv.implicitHeight + 20
                radius: Theme.r(6)
                color: Theme.glassy ? Qt.alpha(Theme.t, 0.04) : Theme.s4
                GridLayout {
                    id: pv
                    x: 12; y: 10
                    width: parent.width - 24
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4
                    Txt { text: "Fecha"; muted: true; size: 11.5 }
                    Txt { Layout.fillWidth: true; text: (root.preview.date ?? "…") + " · " + (root.preview.long ?? "").trim(); size: 12 }
                    Txt { text: "Números"; muted: true; size: 11.5 }
                    Txt { Layout.fillWidth: true; text: root.preview.num ?? "…"; tabular: true; size: 12 }
                    Txt { text: "Moneda y papel"; muted: true; size: 11.5 }
                    Txt { Layout.fillWidth: true; text: (root.preview.cur ?? "") + " · " + (root.preview.paper ?? ""); size: 12 }
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "Los cambios de idioma y formatos se aplican al volver a iniciar sesión. La interfaz de HyprFrijol está siempre en español."
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
            LabeledRow {
                label: "Idioma del sistema"; labelWidth: 140
                hint: "localectl · login"
                Dropdown {
                    model: root.locales.map(l => [l, root.langName(l)])
                    current: root.sysLang
                    popupWidth: 300
                    onPicked: k => { Quickshell.execDetached(["localectl", "set-locale", "LANG=" + k]); later.restart(); }
                }
            }
            LabeledRow {
                label: "Añadir idioma"; labelWidth: 140
                hint: "locale-gen"
                Dropdown {
                    model: root.available.filter(a => !root.locales.includes(a)).map(a => [a, root.langName(a) + " · " + a])
                    placeholder: "Elegir para instalar…"
                    searchable: true
                    popupWidth: 320
                    onPicked: k => root.addLocale(k)
                }
            }
        }
        // Calendarios .ics de la agenda (calendarIcs → services/Events.qml) · ui/IcsCalendars.qml
        IcsCalendars { Layout.fillWidth: true }
        Section {
            Layout.fillWidth: true
            title: "Teclado y métodos de entrada"
            Txt {
                Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap
                text: "La distribución del teclado y el cambio entre idiomas al escribir están en Teclado y atajos."
            }
            Button { kind: "link"; text: "Abrir Teclado y atajos"; onClicked: Shell.open("ajustesapp", "teclado") }
        }
    }
}
