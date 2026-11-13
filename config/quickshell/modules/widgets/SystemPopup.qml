// Ventana «Sistema» (vista "w-sistema", clic en el chip de recursos de la barra): CPU con su gráfica y cada
// núcleo, memoria, cada GPU (uso, temperatura y VRAM), red (bajada/subida), discos (uso y lectura/escritura)
// y los procesos que más CPU usan.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../../bar"

ChipPopup {
    id: pop
    property int killPid: -1
    Timer { id: killDisarm; interval: 3000; onTriggered: pop.killPid = -1 }
    view: "w-sistema"
    panelWidth: 420
    panelHeight: card.implicitHeight

    property bool using: false
    onShownChanged: {
        if (shown && !using) { using = true; SysStats.users++; SysStats.detailUsers++; }
        else if (!shown && using) { using = false; SysStats.users--; SysStats.detailUsers--; }
    }
    function pct(v: real): string { return Math.round(v) + " %"; }
    function upFmt(s: real): string {
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        return d > 0 ? d + " d " + h + " h" : h > 0 ? h + " h " + m + " min" : m + " min";
    }

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12

            // ---- cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Sistema"; size: 14; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: SysStats.uptime > 0 ? "encendido " + pop.upFmt(SysStats.uptime) : ""; muted: true; size: 11.5 }
                Txt { visible: SysStats.load !== ""; text: "carga " + SysStats.load; muted: true; size: 11; tabular: true }
            }

            // ---- CPU
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    spacing: 0
                    Layout.preferredWidth: 92
                    SectionLabel { text: "CPU" }
                    Txt { text: pop.pct(SysStats.cpu); size: 24; weight: Font.Medium; tabular: true }
                    Txt {
                        visible: SysStats.cpuTemp > 0
                        text: Math.round(SysStats.cpuTemp) + " °C"
                        color: SysStats.cpuTemp >= 85 ? Theme.danger : Theme.tv; size: 11.5; tabular: true
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: Theme.r(8)
                    color: Theme.fill2
                    MiniSpark { anchors.fill: parent; anchors.margins: 8; values: SysStats.cpuHist; lineWidth: 1.8 }
                }
            }
            // núcleos
            Grid {
                visible: SysStats.cores.length > 0
                Layout.fillWidth: true
                readonly property int n: SysStats.cores.length
                columns: n > 16 ? Math.ceil(n / 2) : n
                columnSpacing: 4; rowSpacing: 4
                readonly property real cw: (width - (columns - 1) * columnSpacing) / Math.max(1, columns)
                Repeater {
                    model: SysStats.cores
                    MiniBar {
                        required property var modelData
                        width: parent.cw; height: 22
                        value: modelData / 100
                    }
                }
            }

            // ---- memoria y GPU
            WMeter {
                label: "RAM"; labelWidth: 44; textWidth: 112
                value: SysStats.memTotal ? SysStats.memUsed / SysStats.memTotal : 0
                barColor: Theme.ter
                text: SysStats.gb(SysStats.memUsed) + " / " + Math.round(SysStats.memTotal / 1073741824) + " GB"
            }
            WMeter {
                visible: SysStats.swapTotal > 0
                label: "Swap"; labelWidth: 44; textWidth: 112
                value: SysStats.swapTotal ? SysStats.swapUsed / SysStats.swapTotal : 0
                barColor: Theme.tv
                text: SysStats.gb(SysStats.swapUsed) + " / " + SysStats.gb(SysStats.swapTotal) + " GB"
            }
            // ---- gráficas (una o varias: AMD por sysfs, NVIDIA por nvidia-smi, Intel por su frecuencia)
            Repeater {
                model: SysStats.gpus
                ColumnLayout {
                    id: gp
                    required property var modelData
                    readonly property var g: modelData
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Txt { text: "GPU"; muted: true; size: 12; Layout.preferredWidth: 44 }
                        Txt { Layout.fillWidth: true; text: gp.g.name; size: 12; weight: Font.Medium; elide: Text.ElideRight }
                        Txt {
                            visible: gp.g.temp > 0
                            text: Math.round(gp.g.temp) + " °C"; size: 11.5; tabular: true
                            color: gp.g.temp >= 85 ? Theme.danger : Theme.tv
                        }
                    }
                    WMeter {
                        visible: gp.g.busy >= 0 || gp.g.freq >= 0
                        label: gp.g.busy >= 0 ? "uso" : "frec."; labelWidth: 44; textWidth: 112
                        value: (gp.g.busy >= 0 ? gp.g.busy : gp.g.freq) / 100
                        text: gp.g.busy >= 0 ? pop.pct(gp.g.busy) : gp.g.freqMhz + " MHz"
                    }
                    WMeter {
                        visible: gp.g.memTotal > 0
                        label: "VRAM"; labelWidth: 44; textWidth: 112
                        value: gp.g.memUsed / gp.g.memTotal
                        barColor: Theme.ter
                        text: SysStats.gb(gp.g.memUsed) + " / " + SysStats.gb(gp.g.memTotal) + " GB"
                    }
                    Txt {
                        visible: gp.g.busy < 0 && gp.g.freq < 0
                        Layout.leftMargin: 52
                        text: gp.g.vendor === "nvidia" ? "el controlador no informa del uso" : "sin datos de uso"
                        muted: true; size: 11
                    }
                }
            }

            // ---- red
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: [
                        { l: "Bajada", i: "download", v: SysStats.netRx, h: SysStats.rxHist, c: Theme.p },
                        { l: "Subida", i: "upload", v: SysStats.netTx, h: SysStats.txHist, c: Theme.ter }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 52
                        radius: Theme.r(8)
                        color: Theme.fill2
                        MiniSpark { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 } height: 20; values: parent.modelData.h; max: NaN; color: parent.modelData.c; lineWidth: 1.2 }
                        Row {
                            x: 8; y: 6
                            spacing: 4
                            Icon { name: parent.parent.modelData.i; size: 12; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: parent.parent.modelData.l; muted: true; size: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Txt { anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 4 } text: SysStats.rate(parent.modelData.v); weight: Font.DemiBold; size: 12; tabular: true }
                    }
                }
            }

            // ---- discos
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "Discos"; Layout.fillWidth: true }
                    Txt { text: "lee " + SysStats.rate(SysStats.diskRead) + "  ·  escribe " + SysStats.rate(SysStats.diskWrite); muted: true; size: 11; tabular: true }
                }
                Repeater {
                    model: SysStats.disks.length ? SysStats.disks : [{ mount: "/", used: SysStats.diskUsed, size: SysStats.diskTotal }]
                    WMeter {
                        required property var modelData
                        label: modelData.mount; labelWidth: 90; textWidth: 112
                        value: modelData.size ? modelData.used / modelData.size : 0
                        barColor: Theme.tv
                        text: Math.round(modelData.used / 1e9) + " / " + Math.round(modelData.size / 1e9) + " GB"
                    }
                }
            }

            // ---- procesos
            ColumnLayout {
                visible: SysStats.procs.length > 0
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "Procesos"; Layout.fillWidth: true }
                    SectionLabel { text: "CPU"; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                    SectionLabel { text: "RAM"; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight }
                    Item { Layout.preferredWidth: 22 }
                }
                Repeater {
                    model: SysStats.procs
                    RowLayout {
                        id: prow
                        required property var modelData
                        readonly property bool armed: pop.killPid === modelData.pid
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        HoverHandler { id: prowHover }
                        Txt { Layout.fillWidth: true; text: prow.armed ? "¿Cerrar «" + prow.modelData.name + "»? Pulsa otra vez" : prow.modelData.name; color: prow.armed ? Theme.danger : Theme.t }
                        Txt { Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight; text: prow.modelData.cpu.toFixed(1).replace(".", ",") + " %"; tabular: true }
                        Txt { Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; text: prow.modelData.mem.toFixed(1).replace(".", ",") + " %"; muted: true; tabular: true }
                        // Cerrar el proceso: dos clics (el primero lo marca 3 s). SIGTERM: el programa puede guardar antes de salir
                        IconBtn {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            opacity: prowHover.hovered || prow.armed ? 1 : 0
                            icon: "x"; iconSize: 11; fg: prow.armed ? Theme.danger : Theme.tv
                            tooltip: "Cerrar este proceso"
                            onClicked: {
                                if (!prow.armed) { pop.killPid = prow.modelData.pid; killDisarm.restart(); return; }
                                Quickshell.execDetached(["kill", "-TERM", String(prow.modelData.pid)]);
                                pop.killPid = -1;
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                WBtn {
                    readonly property var mon: DesktopEntries.heuristicLookup("btop") ?? DesktopEntries.heuristicLookup("htop")
                                             ?? DesktopEntries.heuristicLookup("gnome-system-monitor") ?? DesktopEntries.heuristicLookup("missioncenter")
                    text: mon ? "Abrir " + mon.name : "Abrir btop"
                    icon: "external"
                    onClicked: { if (mon) mon.execute(); else Quickshell.execDetached(["kitty", "-e", "btop"]); Shell.close(); }
                }
                WBtn { text: "Ajustes de la barra"; icon: "settings"; onClicked: Shell.open("ajustesapp", "barra#Sistema") }
            }
        }
    }
}
