// Ajustes › Productividad › Agenda › Calendarios: suscripciones .ics de la agenda ("calendarIcs" =
// [{ url, name, color }]). Añadir (URL https/webcal o archivo local), quitar, cambiar nombre y color,
// «Actualizar ahora» y estado de la última sincronización (services/Events.qml: status, lastSync).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"

Section {
    id: root
    title: "Calendarios (.ics)"
    // Colores: tokens del tema y algunos tonos fijos (como los de Google Calendar)
    readonly property var swatches: ["p", "ter", "tv", "danger", "#4F8EF7", "#3FB27F", "#F2A33A", "#B07CE8"]
    readonly property var cals: Events.calendars
    property string newColor: ""
    function save(list) { Settings.set("calendarIcs", list.map(c => ({ url: c.url, name: c.name, color: c.color }))); }
    function patch(i, p) { const l = cals.slice(); l[i] = Object.assign({}, l[i], p); save(l); }
    function remove(i) { const l = cals.slice(); l.splice(i, 1); save(l); }
    function add() {
        const u = urlField.text.trim();
        if (!u || cals.some(c => c.url === u)) return;
        save(cals.concat([{ url: u, name: nameField.text.trim() || Events.calName(u), color: newColor || swatches[cals.length % swatches.length] }]));
        urlField.text = ""; nameField.text = ""; newColor = "";
    }
    readonly property bool validUrl: /^(https?|webcal):\/\/\S+$/i.test(urlField.text.trim()) || /^(~|\/|file:\/\/)\S/.test(urlField.text.trim())

    headerRight: Button {
        kind: "link"
        text: Events.loading ? "Actualizando…" : "Actualizar ahora"
        enabled: root.cals.length > 0 && !Events.loading
        onClicked: Events.refresh()
    }

    Txt {
        visible: root.cals.length === 0
        Layout.fillWidth: true; muted: true; wrapMode: Text.WordWrap
        text: "Sin calendarios. Pega la dirección .ics privada de Google Calendar, Outlook, iCloud o Nextcloud, o elige un archivo .ics."
    }
    Repeater {
        model: root.cals
        ColumnLayout {
            id: cal
            required property var modelData
            required property int index
            readonly property var st: Events.status[index] ?? null
            property bool picking: false
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                // color: toca para elegir
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 9
                    color: Events.tint(cal.modelData.color)
                    border.width: cal.picking ? 2 : 0; border.color: Theme.t
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.picking = !cal.picking }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    TextInput {
                        id: nm
                        Layout.fillWidth: true
                        text: cal.modelData.name
                        color: Theme.t
                        font.family: Theme.font; font.pixelSize: Theme.px(12.5); font.weight: Font.DemiBold
                        selectByMouse: true
                        clip: true
                        onEditingFinished: if (text.trim() && text.trim() !== cal.modelData.name) root.patch(cal.index, { name: text.trim() })
                    }
                    Mono { Layout.fillWidth: true; text: cal.modelData.url; elide: Text.ElideMiddle }
                }
                Txt {
                    Layout.maximumWidth: 200
                    horizontalAlignment: Text.AlignRight
                    size: 11.5
                    color: !cal.st ? Theme.tv : cal.st.ok ? Theme.tv : Theme.danger
                    text: !cal.st ? (Events.loading ? "Descargando…" : "Sin sincronizar")
                        : cal.st.ok ? (cal.st.count === 1 ? "1 evento" : cal.st.count + " eventos")
                        : "Error"
                }
                IconBtn { icon: "x"; tooltip: "Quitar calendario"; onClicked: root.remove(cal.index) }
            }
            Txt {
                visible: !!cal.st && !cal.st.ok
                Layout.fillWidth: true; Layout.leftMargin: 28
                size: 11.5; color: Theme.danger; wrapMode: Text.WordWrap
                text: cal.st?.error ?? ""
            }
            ColorSwatches {
                visible: cal.picking
                Layout.leftMargin: 28
                colors: root.swatches
                current: cal.modelData.color
                onPicked: c => { root.patch(cal.index, { color: c }); cal.picking = false; }
            }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 1; color: Theme.ov; opacity: 0.6 }
        }
    }

    // Añadir
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field { id: urlField; Layout.fillWidth: true; icon: "calendar"; placeholder: "https://…/basic.ics, webcal://… o ~/archivo.ics"; onAccepted: if (root.validUrl) root.add() }
        Button {
            text: "Archivo…"
            onClicked: { picker.running = false; picker.running = true; }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field { id: nameField; Layout.fillWidth: true; icon: "edit"; placeholder: "Nombre (opcional)"; onAccepted: if (root.validUrl) root.add() }
        ColorSwatches {
            colors: root.swatches
            current: root.newColor || root.swatches[root.cals.length % root.swatches.length]
            onPicked: c => root.newColor = c
        }
        Button { kind: "primary"; text: "Añadir"; enabled: root.validUrl; onClicked: root.add() }
    }
    Txt {
        Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
        text: (Events.lastSync ? "Última sincronización: " + Time.fmt(Events.lastSync) : root.cals.length ? "Aún sin sincronizar" : "")
              + (root.cals.length ? " · se actualizan cada 15 min · " : "")
              + "los eventos salen en la agenda con su color"
    }
    Process {
        id: picker
        command: ["sh", "-c", "zenity --file-selection --title='Elegir calendario .ics' --file-filter='Calendarios (*.ics) | *.ics *.ICS' 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f) urlField.text = f; } }
    }
}
