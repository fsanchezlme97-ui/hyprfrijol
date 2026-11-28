// Tarjeta de una máquina virtual: captura de su pantalla, estado y recursos, y las acciones de uso diario
// (pantalla, pausar, reiniciar, apagar); desplegada, arranque automático, disco ISO e instantáneas. kind "qemu": QEMU suelta.
// Lógica en scripts/hf-vm; la tarjeta solo pide acciones con act([...]) y la lista las ejecuta.
//   VmCard { vm: {name,uri,state,vcpus,memMB,autostart,snaps,kind,canStart}; cmd: "…/hf-vm"; busy: false; open: false; onAct: a => … }
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"

Rectangle {
    id: root
    required property var vm
    required property string cmd
    property bool busy: false
    property bool open: false
    property var snaps: []
    property var isos: []
    property string shotSrc: ""
    signal act(var args)
    signal toggled()

    readonly property bool running: vm.state === "running"
    readonly property bool paused: vm.state === "paused"
    readonly property bool raw: vm.kind === "qemu"      // QEMU suelta (sin libvirt): sin pantalla externa, ISO ni instantáneas
    readonly property bool up: running || paused
    readonly property string stateText: busy ? "…" : ({ "running": "encendida", "shut off": "apagada", "paused": "en pausa",
        "crashed": "se cerró con error", "pmsuspended": "suspendida", "in shutdown": "apagándose" })[vm.state] ?? vm.state
    readonly property string memText: vm.memMB >= 1024 ? (vm.memMB / 1024).toFixed(vm.memMB % 1024 ? 1 : 0) + " GB" : vm.memMB + " MB"
    function lines(t) { return t.split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(Boolean); }
    function args(op, extra) { return [op, vm.name, vm.uri].concat(extra ?? []); }
    function loadExtras() { snapProc.running = false; snapProc.running = true; isoProc.running = false; isoProc.running = true; }
    onOpenChanged: if (open) loadExtras()
    Component.onCompleted: if (open) loadExtras()
    readonly property int snapCount: vm.snaps
    onSnapCountChanged: if (open) loadExtras()
    onUpChanged: if (!up) shotSrc = ""

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.r(10)
    color: "transparent"
    border.width: 1
    border.color: up ? Theme.alpha(Theme.p, 0.5) : Theme.ov

    Process { id: shot; command: [root.cmd, "shot", root.vm.name, root.vm.uri]; stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) root.shotSrc = "file://" + p + "?t=" + Date.now(); } } }
    Timer { interval: 12000; running: root.up && root.visible; repeat: true; triggeredOnStart: true; onTriggered: if (!shot.running) shot.running = true }
    Process { id: snapProc; command: [root.cmd, "snaps", root.vm.name, root.vm.uri]; stdout: StdioCollector { onStreamFinished: root.snaps = root.lines(text) } }
    Process { id: isoProc; command: [root.cmd, "isos"]; stdout: StdioCollector { onStreamFinished: root.isos = text.split("\n").filter(Boolean) } }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            // Pantalla de la máquina (captura cada 12 s mientras está encendida)
            Rectangle {
                Layout.preferredWidth: 176; Layout.preferredHeight: 110
                Layout.alignment: Qt.AlignTop
                radius: Theme.r(8)
                color: Theme.s4
                Icon { anchors.centerIn: parent; visible: pic.status !== Image.Ready; name: "monitor"; size: 26; color: Theme.tv }
                Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: Theme.r(8) } }
                Item {
                    anchors.fill: parent
                    visible: pic.status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    Image {
                        id: pic
                        anchors.fill: parent
                        source: root.up ? root.shotSrc : ""
                        sourceSize.width: 352
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: root.paused ? 0.45 : 1
                    }
                }
                Txt { visible: root.paused && pic.status === Image.Ready; anchors.centerIn: parent; text: "En pausa"; weight: Font.DemiBold }
                MouseArea {
                    anchors.fill: parent; enabled: root.up && !root.raw; cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([root.cmd, "console", root.vm.name, root.vm.uri])
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 8
                RowLayout {
                    spacing: 8
                    Txt { text: root.vm.name; weight: Font.DemiBold; size: 14 }
                    Rectangle {
                        implicitWidth: st.implicitWidth + 14; implicitHeight: 18; radius: 9
                        color: root.running ? Theme.selBg : "transparent"
                        border.width: root.running ? 0 : 1; border.color: Theme.ov
                        Txt { id: st; anchors.centerIn: parent; text: root.stateText; size: 10.5; weight: Font.DemiBold; color: root.running ? Theme.selText : Theme.tv }
                    }
                }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                    text: (root.vm.vcpus > 0 ? root.vm.vcpus + " vCPU · " + root.memText + " · " : "")
                        + (root.raw ? "QEMU suelta" : root.vm.uri === "qemu:///session" ? "de tu usuario" : "del sistema")
                        + (root.vm.autostart ? " · arranca con el equipo" : "")
                        + (root.vm.snaps > 0 ? " · " + root.vm.snaps + (root.vm.snaps === 1 ? " instantánea" : " instantáneas") : "")
                }
                Txt {
                    visible: root.raw && !root.vm.canStart && !root.up; Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
                    text: "Para encenderla desde aquí, añade su comando en ~/.config/hyprfrijol/vms.json."
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Button { visible: !root.up; kind: "primary"; text: "Encender"; enabled: !root.raw || root.vm.canStart; onClicked: root.act(root.args("start")) }
                    Button { visible: root.up && !root.raw; kind: "primary"; text: "Pantalla"; onClicked: Quickshell.execDetached([root.cmd, "console", root.vm.name, root.vm.uri]) }
                    Button { visible: root.running; text: "Pausar"; onClicked: root.act(root.args("pause")) }
                    Button { visible: root.paused; text: "Reanudar"; onClicked: root.act(root.args("resume")) }
                    Button { visible: root.running; text: "Reiniciar"; onClicked: root.act(root.args("reboot")) }
                    Button { visible: root.up; text: "Apagar"; onClicked: root.act(root.args("shutdown")) }
                    HoldButton { visible: root.up; text: "Forzar apagado"; onConfirmed: root.act(root.args("destroy")) }
                    Button { visible: !root.raw; kind: "link"; text: root.open ? "Menos" : "Más"; onClicked: root.toggled() }
                }
            }
        }

        ColumnLayout {
            visible: root.open
            Layout.fillWidth: true
            spacing: 0
            SwRow {
                label: "Arrancar con el equipo"; sub: "se enciende sola al iniciar el servicio de máquinas"
                checked: root.vm.autostart
                onToggled: v => root.act(root.args("autostart", [v ? "on" : "off"]))
            }
            // Disco ISO en el lector virtual (si la máquina lo tiene)
            Item {
                Layout.fillWidth: true; implicitHeight: 54
                Rectangle { width: parent.width; height: 1; color: Theme.ov }
                RowLayout {
                    anchors.fill: parent; anchors.topMargin: 1; spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Txt { text: "Disco ISO"; weight: Font.DemiBold }
                        Txt { text: root.isos.length ? "Se pone en el lector virtual de la máquina" : "No hay .iso en Descargas ni en ~/ISOs"; muted: true; size: 11.5 }
                    }
                    Dropdown {
                        id: isoPick
                        visible: root.isos.length > 0
                        Layout.preferredWidth: 220
                        model: root.isos.map(p => [p, p.replace(/^.*\//, "")])
                        placeholder: "Elegir ISO…"
                        onPicked: k => current = k
                    }
                    Button { visible: root.isos.length > 0; text: "Insertar"; enabled: !!isoPick.current; onClicked: root.act(root.args("iso", [isoPick.current])) }
                    Button { text: "Expulsar"; onClicked: root.act(root.args("iso", ["eject"])) }
                }
            }
            // Instantáneas
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.ov }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 8; spacing: 8
                Txt { Layout.fillWidth: true; text: "Instantáneas"; weight: Font.DemiBold }
                Field { id: snapName; Layout.preferredWidth: 180; icon: ""; placeholder: "nombre (opcional)" }
                Button {
                    kind: "primary"; text: "Crear instantánea"
                    enabled: /^[A-Za-z0-9][A-Za-z0-9_.-]*$|^$/.test(snapName.text.trim())
                    onClicked: { root.act(root.args("snap", snapName.text.trim() ? [snapName.text.trim()] : [])); snapName.text = ""; }
                }
            }
            Txt { visible: root.snaps.length === 0; Layout.topMargin: 8; text: "Aún no hay instantáneas: guardan el estado de la máquina para volver a él."; muted: true; size: 11.5 }
            Repeater {
                model: root.snaps
                Item {
                    id: sr
                    required property var modelData
                    Layout.fillWidth: true; Layout.topMargin: 8
                    implicitHeight: 38
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { text: sr.modelData.name; weight: Font.Medium }
                        Txt { text: sr.modelData.time.replace(/ [+-]\d{4}$/, ""); muted: true; size: 11 }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        HoldButton { h: 26; text: "Volver a esta"; onConfirmed: root.act(root.args("revert", [sr.modelData.name])) }
                        HoldButton { h: 26; text: "Borrar"; onConfirmed: root.act(root.args("snapdel", [sr.modelData.name])) }
                    }
                }
            }
        }
    }
}
