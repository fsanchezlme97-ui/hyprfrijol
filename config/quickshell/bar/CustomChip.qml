// Widget propio de la barra (Ajustes › Widgets de la barra › Widget propio; barCustom). Cada «interval» s corre
// «cmd» con sh y enseña lo que escribe: texto plano (la primera línea) o JSON {"text", "icon", "tooltip"}.
// Sin salida no ocupa sitio. Clic y clic derecho: sus órdenes, sin esperar. Con la pantalla bloqueada no corre.
//   conf = { id, name, cmd, interval, icon, click, rclick }
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"

Rectangle {
    id: chip
    property var conf: ({})
    property bool vertical: false
    property string text: ""
    property string iconName: conf?.icon ?? ""
    property string tip: conf?.name ?? ""
    readonly property bool want: text !== "" || (iconName !== "" && (conf?.cmd ?? "") === "")
    implicitWidth: vertical ? 26 : row.implicitWidth + 14
    implicitHeight: vertical ? col.implicitHeight + 10 : 22
    radius: Theme.r(7)
    color: ma.containsMouse && (conf?.click || conf?.rclick) ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    // La salida: JSON con text/icon/tooltip, o la primera línea tal cual (recortada a 60 caracteres)
    function parse(out: string): void {
        const s = out.trim();
        let o = null;
        if (s.startsWith("{")) try { o = JSON.parse(s); } catch (e) {}
        chip.text = String(o ? (o.text ?? "") : s.split("\n")[0]).slice(0, 60);
        chip.iconName = o?.icon ? String(o.icon) : (conf?.icon ?? "");
        chip.tip = o?.tooltip ? String(o.tooltip) : (conf?.name ?? "");
    }
    Process {
        id: proc
        command: ["sh", "-c", chip.conf?.cmd ?? ""]
        stdout: StdioCollector { onStreamFinished: chip.parse(text) }
    }
    Timer {
        interval: Math.max(2, Number(chip.conf?.interval) || 10) * 1000
        running: (chip.conf?.cmd ?? "") !== "" && !Shell.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    RowLayout {
        id: row
        visible: !chip.vertical
        anchors.centerIn: parent
        spacing: 4
        Icon { visible: chip.iconName !== ""; name: chip.iconName; size: 14; color: Theme.t }
        Txt { visible: chip.text !== ""; text: chip.text; size: 12; weight: Font.Medium }
    }
    ColumnLayout {
        id: col
        visible: chip.vertical
        anchors.centerIn: parent
        spacing: 2
        Icon { visible: chip.iconName !== ""; Layout.alignment: Qt.AlignHCenter; name: chip.iconName; size: 14; color: Theme.t }
        Txt { visible: chip.text !== ""; Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 24; text: chip.text; size: 9.5; elide: Text.ElideRight }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: chip.conf?.click || chip.conf?.rclick ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            const c = e.button === Qt.RightButton ? chip.conf?.rclick : chip.conf?.click;
            if (c) {
                Quickshell.execDetached(["sh", "-c", c]);
                refresh.restart();      // lo que cambie el clic se ve enseguida
            }
        }
    }
    Timer { id: refresh; interval: 600; onTriggered: if (!proc.running && (chip.conf?.cmd ?? "") !== "") proc.running = true }
    BarTip { target: ma; text: chip.tip }
}
