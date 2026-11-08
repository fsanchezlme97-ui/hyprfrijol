// Sistema en la barra (Ajustes › Barra › Widgets en la barra: «recursos»).
// Qué medidas enseña (barStatsShow, lista): "cpu" · "ram" · "gpu" · "disco" · "red" · "temp"
//   (por defecto cpu, ram, gpu y temp; la GPU se oculta sola si no hay datos).
// Estilo (barStatsStyle):
//   barras   barritas de cada medida + el % de la primera (por defecto)
//   grafica  gráfica del último minuto de la primera medida + su valor
//   texto    icono de cada medida + su %: «[cpu] 12 %  [ram] 40 % …»
// La temperatura y la red (↓ bajada ↑ subida) se añaden como texto en los tres estilos.
// Clic: ventana «Sistema» (núcleos, cada GPU, procesos, discos y red). En la barra vertical, barritas y % apilados.
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

BarChip {
    id: chip
    popup: "w-sistema"
    readonly property string style: Settings.get("barStatsStyle", "barras")
    readonly property var show: { const v = Settings.get("barStatsShow", null); return Array.isArray(v) ? v : ["cpu", "ram", "gpu", "temp"]; }
    readonly property real ram: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
    readonly property real disk: SysStats.diskTotal > 0 ? SysStats.diskUsed / SysStats.diskTotal : 0
    readonly property bool hot: SysStats.cpuTemp >= 85
    readonly property bool gpuOk: SysStats.gpu >= 0
    // medidas con barra (0–1), en el orden de la lista
    readonly property var meters: {
        const all = {
            cpu: { k: "cpu", l: "CPU", i: "cpu", v: SysStats.cpu / 100, c: Theme.p, h: SysStats.cpuHist },
            ram: { k: "ram", l: "RAM", i: "ram", v: ram, c: Theme.ter, h: SysStats.memHist },
            gpu: { k: "gpu", l: "GPU", i: "gpu", v: Math.max(0, SysStats.gpu) / 100, c: Theme.tv, h: SysStats.gpuHist },
            disco: { k: "disco", l: "Disco", i: "disk", v: disk, c: Theme.o, h: SysStats.diskHist }
        };
        return show.filter(k => all[k] && (k !== "gpu" || gpuOk)).map(k => all[k]);
    }
    readonly property bool showTemp: show.includes("temp") && SysStats.cpuTemp > 0
    readonly property bool showNet: show.includes("red")
    readonly property bool empty: meters.length === 0 && !showTemp && !showNet
    function pct(v: real): string { return Math.round(100 * v) + " %"; }
    // 1,2M · 340k · 0k  (bytes/s, para que quepa en la barra)
    function short(b: real): string {
        if (b >= 1e6) return (b / 1e6).toFixed(b >= 1e7 ? 0 : 1).replace(".", ",") + "M";
        return Math.round(b / 1e3) + "k";
    }
    implicitHeight: vertical ? vcol.implicitHeight + 10 : 22
    implicitWidth: vertical ? 26 : r.implicitWidth + 14
    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--
    RowLayout {
        id: r
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 5
        Icon { visible: chip.style !== "texto" || chip.empty; name: "cpu"; color: chip.hot ? Theme.danger : Theme.t }
        // barras
        Row {
            visible: chip.style === "barras" && chip.meters.length > 0
            spacing: 2
            Layout.alignment: Qt.AlignVCenter
            Repeater { model: chip.style === "barras" ? chip.meters : []; MiniBar { required property var modelData; value: modelData.v; barColor: modelData.c } }
        }
        // gráfica de la primera medida
        MiniSpark {
            visible: chip.style === "grafica" && chip.meters.length > 0
            Layout.preferredWidth: 38; Layout.preferredHeight: 14
            values: chip.meters[0]?.h ?? []
            color: chip.meters[0]?.c ?? Theme.p
        }
        Txt { visible: chip.style !== "texto" && chip.meters.length > 0; text: chip.meters.length ? chip.pct(chip.meters[0].v) : ""; tabular: true }
        // texto: «CPU 12 %  RAM 40 %»
        Repeater {
            model: chip.style === "texto" ? chip.meters : []
            Row {
                required property var modelData
                required property int index
                spacing: 4
                Layout.leftMargin: index > 0 ? 3 : 0
                Icon { name: parent.modelData.i; size: 13; color: Theme.tv; anchors.verticalCenter: v.verticalCenter }
                Txt { id: v; text: chip.pct(parent.modelData.v); tabular: true; color: parent.modelData.v > 0.9 ? Theme.danger : Theme.t }
            }
        }
        Txt { visible: chip.showTemp; text: Math.round(SysStats.cpuTemp) + "°"; muted: !chip.hot; color: chip.hot ? Theme.danger : Theme.tv; tabular: true }
        // red
        Row {
            visible: chip.showNet
            spacing: 2
            Layout.leftMargin: 2
            Icon { name: "download"; size: 11; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: chip.short(SysStats.netRx); tabular: true; size: 11.5; anchors.verticalCenter: parent.verticalCenter; width: Math.max(implicitWidth, 30) }
            Icon { name: "upload"; size: 11; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: chip.short(SysStats.netTx); tabular: true; size: 11.5; anchors.verticalCenter: parent.verticalCenter; width: Math.max(implicitWidth, 30) }
        }
    }
    ColumnLayout {
        id: vcol
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 3
        Icon { visible: chip.meters.length === 0; Layout.alignment: Qt.AlignHCenter; name: "cpu"; color: chip.hot ? Theme.danger : Theme.t }
        Row {
            visible: chip.meters.length > 0
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Repeater { model: chip.vertical ? chip.meters.slice(0, 4) : []; MiniBar { required property var modelData; value: modelData.v; barColor: modelData.c } }
        }
        Txt { visible: chip.meters.length > 0; Layout.alignment: Qt.AlignHCenter; text: chip.meters.length ? Math.round(100 * chip.meters[0].v) + "%" : ""; size: 10.5; tabular: true }
        Txt { visible: chip.showTemp; Layout.alignment: Qt.AlignHCenter; text: Math.round(SysStats.cpuTemp) + "°"; size: 10.5; color: chip.hot ? Theme.danger : Theme.tv; tabular: true }
    }
}
