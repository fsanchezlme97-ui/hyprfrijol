// Todos los programas abiertos y lo que gastan, en cualquier espacio y pantalla (barra de las pantallas secundarias,
// a la derecha: con una sola pantalla no se ve; ahí ya está el chip de sistema). Una entrada por programa (por su
// clase: dos kitty abiertos por separado son dos procesos, pero un solo programa): icono, CPU (% de todo el equipo)
// y memoria, sumando cada proceso con todos sus hijos (SysStats.tree: pestañas de Chrome, apps Electron, lo que
// corre en una terminal). Orden fijo (los abiertos antes, primero); si hay más de `max`, los que más gastan y «+N».
// En rojo la CPU si pasa del 25 % y la memoria si pasa de 2 GB: dice qué ventana está frenando el equipo.
// Clic: ir a su ventana (con varias, una tras otra) · clic central: cerrarla · al pasar el cursor: nombre, ventanas
// y procesos.
import QtQuick
import ".."
import "../components"
import "../services"

Row {
    id: root
    property int max: 8
    spacing: 2
    readonly property var groups: {
        const by = {}, order = [];
        for (const c of HyprClients.clients) {
            const k = c.class ? "c" + c.class : c.address;
            if (!by[k]) { by[k] = []; order.push(k); }
            by[k].push(c);
        }
        const first = g => Math.min(...g.map(c => c.pid > 0 ? c.pid : 1e9));
        return order.map(k => by[k]).sort((a, b) => first(a) - first(b));
    }
    // Lo que gasta un programa: cada uno de sus procesos con sus hijos (sin contar dos veces uno que cuelga de otro)
    function usage(g): var {
        const pids = [...new Set(g.map(c => c.pid).filter(p => p > 0))];
        const tops = pids.filter(p => { for (let q = SysStats.procTable[p]?.ppid; q > 1; q = SysStats.procTable[q]?.ppid) if (pids.includes(q)) return false; return true; });
        return tops.reduce((a, p) => { const u = SysStats.tree(p); return { cpu: a.cpu + u.cpu, mem: a.mem + u.mem, n: a.n + u.n }; }, { cpu: 0, mem: 0, n: 0 });
    }
    // Cuánto pesa un programa para elegir cuáles caben: su parte de CPU más su parte de memoria
    function score(u): real { return u.cpu / 100 + (SysStats.memTotal > 0 ? u.mem / SysStats.memTotal : 0); }
    // Con más de `max`, el peso mínimo para salir (solo cambia qué se ve, no se rehace la lista cada 2 s)
    readonly property real cut: {
        SysStats.procTable;
        if (groups.length <= max) return -1;
        const v = groups.map(g => score(usage(g))).sort((a, b) => b - a);
        return v[max - 1];
    }
    Component.onCompleted: { SysStats.users++; SysStats.procUsers++; }
    Component.onDestruction: { SysStats.users--; SysStats.procUsers--; }

    // 840M · 1,2G
    function mem(b: real): string {
        return b >= 1073741824 ? (b / 1073741824).toFixed(1).replace(".", ",") + "G" : Math.round(b / 1048576) + "M";
    }

    Repeater {
        model: root.groups
        Rectangle {
            id: chip
            required property var modelData
            readonly property var win: modelData[0]
            readonly property var use: { SysStats.procTable; return root.usage(modelData); }
            readonly property string name: HyprClients.appName(win.class ?? "")
            visible: root.cut < 0 || root.score(use) >= root.cut
            implicitHeight: 22
            implicitWidth: row.implicitWidth + 12
            radius: Theme.r(7)
            color: ma.containsMouse ? Theme.fill2 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 5
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: HyprClients.iconFor(chip.win.class ?? "")
                    asynchronous: true
                }
                Txt {
                    visible: chip.modelData.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×" + chip.modelData.length
                    size: 10.5; muted: true
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(implicitWidth, 28)
                    horizontalAlignment: Text.AlignRight
                    tabular: true
                    text: Math.round(chip.use.cpu) + " %"
                    color: chip.use.cpu >= 25 ? Theme.danger : Theme.t
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(implicitWidth, 32)
                    horizontalAlignment: Text.AlignRight
                    tabular: true
                    text: root.mem(chip.use.mem)
                    color: chip.use.mem >= 2147483648 ? Theme.danger : Theme.tv
                }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                // clic: la siguiente ventana del programa (de una en una si hay varias) · central: cerrar la activa o la primera
                onClicked: e => {
                    const g = chip.modelData, i = g.findIndex(c => c.address === HyprClients.activeAddress);
                    if (e.button === Qt.MiddleButton) WinMode.close(g[Math.max(0, i)].address);
                    else HyprClients.focusWindow(g[(i + 1) % g.length].address);
                }
            }
            BarTip {
                target: ma
                text: chip.name + (chip.modelData.length > 1 ? " · " + chip.modelData.length + " ventanas" : "")
                      + " · " + chip.use.n + (chip.use.n === 1 ? " proceso" : " procesos") + " · clic central: cerrar"
            }
        }
    }
    Txt {
        readonly property int hidden: root.cut < 0 ? 0 : root.groups.length - root.max
        visible: hidden > 0
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 4; rightPadding: 4
        text: "+" + hidden
        size: 11; muted: true
    }
}
