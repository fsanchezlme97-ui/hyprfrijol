// Columna de widgets (vista «widgets», Super + G): clima, impresora, sistema, agenda, pomodoro, notas,
// reproductor, red. Ajuste "widgets" = cuáles y en qué orden («Editar widgets»).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

ColumnLayout {
    id: col
    property bool editing: false
    property bool showButtons: true
    signal closeRequested()
    spacing: 10

    readonly property var all: [
        { k: "clima", n: "Clima" }, { k: "impresora", n: "Impresora 3D" }, { k: "sistema", n: "Sistema" },
        { k: "agenda", n: "Agenda" }, { k: "pomodoro", n: "Pomodoro" }, { k: "notas", n: "Notas" },
        { k: "reproductor", n: "Reproductor" }, { k: "red", n: "Red" }
    ]
    readonly property var keys: (Settings.get("widgets", ["clima", "impresora", "sistema"]) ?? []).filter(k => all.some(a => a.k === k))
    function setKeys(l): void { Settings.set("widgets", l); }
    function move(k: string, d: int): void {
        const l = keys.slice(), i = l.indexOf(k), j = i + d;
        if (j < 0 || j >= l.length) return;
        l.splice(i, 1); l.splice(j, 0, k); setKeys(l);
    }

    // Usuarios de los servicios (solo miden mientras la columna existe)
    Component.onCompleted: { SysStats.users++; Weather.users++; Printer.users++; }
    Component.onDestruction: { SysStats.users--; Weather.users--; Printer.users--; }

    Repeater {
        model: col.keys
        delegate: Item {
            id: slot
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: ld.item ? ld.item.implicitHeight : 0
            Loader {
                id: ld
                anchors.left: parent.left
                anchors.right: parent.right
                sourceComponent: ({ clima: weatherC, impresora: printerC, sistema: systemC, agenda: agendaC,
                                    pomodoro: pomoC, notas: notesC, reproductor: mediaC, red: netC })[slot.modelData] ?? null
            }
            // Más detalles (la ventana del chip de la barra)
            Rectangle {
                readonly property string detail: ({ sistema: "w-sistema", impresora: "w-impresora" })[slot.modelData] ?? ""   // (el clima: clic en la tarjeta)
                visible: !col.editing && detail !== "" && col.showButtons
                anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
                width: 22; height: 22; radius: Theme.ctl(22)
                color: dm.containsMouse ? Qt.alpha(Theme.t, 0.14) : "transparent"
                z: 5
                Icon { anchors.centerIn: parent; name: "maximize"; size: 12; color: Theme.tv }
                MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shell.open(parent.detail) }
            }
            // Controles de edición
            Row {
                visible: col.editing
                anchors { top: parent.top; right: parent.right; topMargin: -8; rightMargin: -6 }
                spacing: 4
                z: 5
                Repeater {
                    model: [{ i: "chevron_up", d: -1 }, { i: "chevron_down", d: 1 }, { i: "x", d: 0 }]
                    delegate: Rectangle {
                        required property var modelData
                        width: 20; height: 20; radius: 10
                        color: modelData.d === 0 ? (em.containsMouse ? Theme.danger : Theme.p) : (em.containsMouse ? Theme.s4 : Theme.s3)
                        border.width: 1; border.color: Theme.border
                        Icon { anchors.centerIn: parent; name: parent.modelData.i; size: 12; stroke: 2.2; color: parent.modelData.d === 0 ? Theme.pText : Theme.t }
                        MouseArea {
                            id: em
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: parent.modelData.d === 0 ? col.setKeys(col.keys.filter(k => k !== slot.modelData)) : col.move(slot.modelData, parent.modelData.d)
                        }
                    }
                }
            }
        }
    }

    // Vacío
    WCard {
        visible: col.keys.length === 0
        editing: col.editing
        Txt { text: "Sin widgets"; weight: Font.DemiBold }
        Txt { text: "Pulsa «Editar widgets» para añadir clima, sistema, impresora…"; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone; Layout.fillWidth: true }
    }

    // Botones inferiores
    RowLayout {
        visible: col.showButtons
        Layout.fillWidth: true
        spacing: 6
        Glass {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: Theme.panelRadius
            color: editMa.containsMouse ? Qt.alpha(Theme.glassPopup, 1) : Theme.glassPanel
            Txt { anchors.centerIn: parent; text: col.editing ? "Listo" : "Editar widgets"; weight: col.editing ? Font.DemiBold : Font.Normal }
            MouseArea { id: editMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: col.editing = !col.editing }
        }
        Glass {
            Layout.preferredWidth: showTxt.implicitWidth + 24
            Layout.preferredHeight: 30
            radius: Theme.panelRadius
            color: showMa.containsMouse ? Qt.alpha(Theme.glassPopup, 1) : Theme.glassPanel
            Txt { id: showTxt; anchors.centerIn: parent; text: "Cerrar" }
            MouseArea { id: showMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: col.closeRequested() }
        }
    }

    // Añadir widget
    WCard {
        visible: col.editing
        pad: 10
        Txt { text: col.all.length === col.keys.length ? "Ya están todos los widgets" : "Añadir widget · ↑ ↓ para mover · ✕ para quitar"; muted: true; size: 11.5 }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: col.all.filter(a => !col.keys.includes(a.k))
                delegate: Rectangle {
                    required property var modelData
                    width: addTxt.implicitWidth + 20; height: 26; radius: Theme.r(6)
                    color: am.containsMouse ? Qt.alpha(Theme.t, 0.14) : Theme.fill2
                    Txt { id: addTxt; anchors.centerIn: parent; text: "+ " + parent.modelData.n; size: 12 }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: col.setKeys(col.keys.concat([parent.modelData.k])) }
                }
            }
        }
    }

    // ================= Widgets =================
    Component {
        id: weatherC
        WCard {
            editing: col.editing
            clickable: !col.editing && col.showButtons
            onClicked: Shell.open("w-clima")
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Icon { name: Weather.icon; size: 34; stroke: 1.5; color: Theme.t; Layout.alignment: Qt.AlignVCenter }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"; size: 28; weight: Font.Medium; tabular: true }
                    Txt {
                        Layout.fillWidth: true
                        text: Weather.ready ? [Weather.city, Weather.desc].filter(s => s).join(" · ") : (Weather.err || "Buscando el tiempo…")
                        muted: true
                        size: Weather.ready ? 12.5 : 11.5
                        wrapMode: Weather.ready ? Text.NoWrap : Text.WordWrap
                        elide: Weather.ready ? Text.ElideRight : Text.ElideNone
                    }
                }
                Row {
                    spacing: 10
                    visible: Weather.days.length > 0
                    Repeater {
                        model: Weather.days
                        delegate: Column {
                            required property var modelData
                            spacing: 2
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.d; size: 11; muted: true }
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.max + "°"; size: 11; tabular: true }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: printerC
        WCard {
            editing: col.editing
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Impresora 3D"; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt { text: Printer.online ? Printer.brand : Printer.configured ? "sin conexión" : ""; size: 11; muted: true }
            }
            // Sin configurar
            ColumnLayout {
                visible: !Printer.configured
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Configura tu impresora en Ajustes"; muted: true; size: 12 }
                WBtn { text: "Abrir Ajustes"; icon: "settings"; onClicked: Shell.open("ajustesapp", "escritorio#Impresora 3D") }
            }
            // Sin conexión
            Txt {
                visible: Printer.configured && !Printer.online
                Layout.fillWidth: true
                text: Printer.err || "Conectando con " + Printer.url + "…"
                muted: true; size: 12
            }
            RowLayout {
                visible: Printer.online
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 96; Layout.preferredHeight: 72
                    radius: Theme.r(6)
                    color: "#20242B"
                    clip: true
                    // Dibujo de la pieza si no hay cámara
                    Rectangle { visible: cam.status !== Image.Ready; x: 14; width: parent.width - 28; y: parent.height - 14; height: 4; color: "#565D69" }
                    Rectangle {
                        visible: cam.status !== Image.Ready
                        x: 34; width: 28; y: parent.height - 14 - height
                        height: Math.max(2, 44 * Printer.progress)
                        color: Theme.p; opacity: 0.85
                    }
                    Image {
                        id: cam
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: Printer.camUrl
                        cache: false
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Txt { x: 4; y: 3; text: "● cámara"; size: 9; color: "#FFFFFF"; opacity: 0.8 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Txt { Layout.fillWidth: true; text: Printer.file || Printer.stateText; weight: Font.Medium }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 2
                        text: Printer.busy
                            ? [Math.round(Printer.progress * 100) + " %", Printer.layers ? "capa " + Printer.layer + "/" + Printer.layers : "",
                               Printer.left >= 0 ? "quedan " + Printer.dur(Printer.left) : "", Printer.state === "paused" ? "en pausa" : ""].filter(s => s).join(" · ")
                            : Printer.stateText
                        size: 11.5; muted: true; tabular: true
                    }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 2
                        visible: !isNaN(Printer.nozzle)
                        text: "Boquilla " + Math.round(Printer.nozzle) + "°/" + Math.round(Printer.nozzleTarget)
                            + (isNaN(Printer.bed) ? "" : " · Cama " + Math.round(Printer.bed) + "°/" + Math.round(Printer.bedTarget))
                        size: 11.5; muted: true; tabular: true
                    }
                }
            }
            Rectangle {
                visible: Printer.online
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: Theme.r(3)
                color: Theme.fill2
                Progress { anchors.fill: parent; value: Printer.progress; period: 5000; busy: Printer.state === "printing"; track: "transparent" }
            }
            RowLayout {
                visible: Printer.online
                Layout.fillWidth: true
                spacing: 6
                WBtn {
                    enabled: Printer.busy
                    opacity: enabled ? 1 : 0.5
                    text: Printer.state === "paused" ? "Reanudar" : "Pausar"
                    onClicked: Printer.state === "paused" ? Printer.resume() : Printer.pause()
                }
                WBtn {
                    readonly property var slicer: DesktopEntries.heuristicLookup("OrcaSlicer") ?? DesktopEntries.heuristicLookup("orca-slicer")
                                                ?? DesktopEntries.heuristicLookup("PrusaSlicer") ?? DesktopEntries.heuristicLookup("Cura")
                    text: slicer ? "Abrir " + slicer.name : "Abrir panel web"
                    onClicked: { if (slicer) slicer.execute(); else Printer.openWeb(); col.closeRequested(); }
                }
            }
        }
    }

    Component {
        id: systemC
        WCard {
            editing: col.editing
            spacing: 8
            Txt { text: "Sistema"; weight: Font.DemiBold }
            WMeter {
                label: "CPU"; value: SysStats.cpu / 100
                text: Math.round(SysStats.cpu) + " %" + (SysStats.cpuTemp > 0 ? " · " + Math.round(SysStats.cpuTemp) + " °C" : "")
            }
            WMeter {
                visible: SysStats.gpu >= 0
                label: "GPU"; value: SysStats.gpu / 100
                text: Math.round(SysStats.gpu) + " %" + (SysStats.gpuTemp > 0 ? " · " + Math.round(SysStats.gpuTemp) + " °C" : "")
            }
            WMeter {
                label: "RAM"; value: SysStats.memTotal ? SysStats.memUsed / SysStats.memTotal : 0
                barColor: Theme.ter
                text: SysStats.gb(SysStats.memUsed) + " / " + Math.round(SysStats.memTotal / 1073741824) + " GB"
            }
            WMeter {
                label: "Disco"; value: SysStats.diskTotal ? SysStats.diskUsed / SysStats.diskTotal : 0
                barColor: Theme.tv
                text: Math.round(SysStats.diskUsed / 1e9) + " / " + Math.round(SysStats.diskTotal / 1e9) + " GB"
            }
        }
    }

    Component {
        id: agendaC
        WCard {
            editing: col.editing
            spacing: 4
            Txt { text: Time.hhmm; size: 28; weight: Font.Medium; tabular: true }
            Txt { text: Time.longDate.charAt(0).toUpperCase() + Time.longDate.slice(1); muted: true }
            WBtn { Layout.topMargin: 6; text: "Abrir agenda"; icon: "calendar"; onClicked: { col.closeRequested(); Shell.open("agenda"); } }
        }
    }

    Component {
        id: pomoC
        WCard {
            editing: col.editing
            RowLayout {
                Layout.fillWidth: true
                Txt { text: "Pomodoro"; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt { text: Pomodoro.label + (Pomodoro.done ? " · ronda " + (Pomodoro.done + 1) : ""); muted: true; size: 11 }
            }
            Txt { text: Pomodoro.time; size: 28; weight: Font.Medium; tabular: true }
            Progress {
                Layout.fillWidth: true; Layout.preferredHeight: 6
                value: Pomodoro.progress
                period: 1000            // avanza segundo a segundo, sin saltos
                busy: false
                track: Theme.fill2
                color: Pomodoro.mode === "foco" ? Theme.p : Theme.ter
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                WBtn { text: Pomodoro.running ? "Pausar" : "Empezar"; icon: Pomodoro.running ? "pause" : "play"; onClicked: Pomodoro.toggle() }
                WBtn { text: "Reiniciar"; icon: "restart"; onClicked: Pomodoro.reset() }
            }
        }
    }

    Component {
        id: notesC
        WCard {
            editing: col.editing
            Txt { text: "Notas"; weight: Font.DemiBold }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(70, Math.min(180, notes.contentHeight + 16))
                radius: Theme.r(6)
                color: Theme.fill2
                TextEdit {
                    id: notes
                    anchors.fill: parent
                    anchors.margins: 8
                    wrapMode: TextEdit.Wrap
                    color: Theme.t
                    selectionColor: Theme.pc
                    selectedTextColor: Theme.pcText
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                    onTextChanged: if (activeFocus) saveTimer.restart()
                    Txt { visible: notes.text === ""; text: "Escribe algo…"; muted: true }
                }
                FileView {
                    id: notesFile
                    path: Paths.state + "/notas.txt"
                    printErrors: false
                    onLoaded: if (!notes.activeFocus) notes.text = text()
                }
                Timer { id: saveTimer; interval: 600; onTriggered: notesFile.setText(notes.text) }
            }
        }
    }

    Component {
        id: mediaC
        WCard {
            editing: col.editing
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: Theme.r(6); color: Theme.s3; clip: true
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; asynchronous: true }
                    Icon { anchors.centerIn: parent; visible: !Media.art; name: "play"; size: 18; color: Theme.tv }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt { Layout.fillWidth: true; text: Media.title || "Nada sonando"; weight: Font.Medium }
                    Txt { Layout.fillWidth: true; text: Media.artist || (Media.active ? "" : "Abre música o un vídeo"); muted: true; size: 11.5 }
                }
            }
            RowLayout {
                visible: !!Media.active
                Layout.fillWidth: true
                spacing: 6
                WBtn { icon: "chevron_left"; onClicked: Media.previous() }
                WBtn { icon: Media.playing ? "pause" : "play"; primary: true; onClicked: Media.toggle() }
                WBtn { icon: "chevron_right"; onClicked: Media.next() }
            }
        }
    }

    Component {
        id: netC
        WCard {
            editing: col.editing
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: Theme.r(9)
                    color: Net.connected ? Theme.p : Theme.s4
                    Icon { anchors.centerIn: parent; name: Net.type === "ethernet" ? "globe" : "wifi"; size: 16; color: Net.connected ? Theme.pText : Theme.t }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { text: Net.connected ? (Net.type === "ethernet" ? "Cable" : Net.ssid || "Wi-Fi") : "Sin conexión"; weight: Font.DemiBold }
                    Txt { text: Net.connected ? (Net.type === "wifi" ? "Señal " + Net.signal + " %" : "Conectado") : (Net.wifiEnabled ? "Wi-Fi activado" : "Wi-Fi desactivado"); muted: true; size: 11.5 }
                }
                WBtn { Layout.fillWidth: false; text: "Redes"; onClicked: { col.closeRequested(); Shell.open("ajustes", "wifi"); } }
            }
        }
    }
}
