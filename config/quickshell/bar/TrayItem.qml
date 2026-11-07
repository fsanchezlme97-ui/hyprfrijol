// Un icono de la bandeja (StatusNotifierItem: OBS, Steam, Discord, KDE Connect…).
//   clic: abrir (o el menú si la app solo tiene menú) · clic derecho: menú · clic central: acción secundaria
//   rueda: se la pasa a la app (volumen, etc.) · al pasar el cursor: su descripción
// El icono se busca así: tema de iconos (Papirus) por su nombre → el IconThemePath de la app (Quickshell no
// encuentra ahí los .png/.svg) → variantes del nombre sin «-tray», «-symbolic»… y el id de la app → genérico.
// Los iconos en pixmap (sin nombre) los da Quickshell tal cual.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../components"

Item {
    id: root
    required property SystemTrayItem item
    property real size: 16
    signal menuRequested(Item from)
    implicitWidth: size + 8
    implicitHeight: size + 6

    // nombre e IconThemePath de image://icon/<nombre>?path=<ruta>
    readonly property var parts: {
        const m = String(item?.icon ?? "").match(/^image:\/\/icon\/([^?]*)(?:\?path=(.*))?$/);
        return m ? { name: decodeURIComponent(m[1]), path: m[2] ? decodeURIComponent(m[2]) : "" } : null;
    }
    property string found: ""            // archivo encontrado en el IconThemePath
    readonly property string source: {
        const raw = String(item?.icon ?? "");
        const p = parts;
        if (!p) return raw;                                            // pixmap de la app (image://qspixmap/…)
        if (p.name.startsWith("/")) return "file://" + p.name;          // ruta absoluta como nombre
        if (p.name && Quickshell.hasThemeIcon(p.name)) return Quickshell.iconPath(p.name);
        if (found) return "file://" + found;
        const id = String(item?.id ?? "").toLowerCase(), title = String(item?.title ?? "").toLowerCase();
        const base = p.name.replace(/([-_](tray|panel|indicator|status|symbolic|mono|dark|light|active|passive|attention))+$/i, "");
        for (const n of [base, base.toLowerCase(), id, id.replace(/[\s_]+/g, "-"), title, title.replace(/\s+/g, "-")])
            if (n && Quickshell.hasThemeIcon(n)) return Quickshell.iconPath(n);
        return p.path ? "" : Quickshell.iconPath("application-x-executable");
    }
    Process {
        running: !!root.parts && root.parts.path !== "" && !Quickshell.hasThemeIcon(root.parts.name)
        command: ["sh", "-c", 'find -L "$1" -maxdepth 5 -type f \\( -name "$2.svg" -o -name "$2.png" -o -name "$2.xpm" \\) 2>/dev/null | sort | tail -n1', "sh",
                  root.parts?.path ?? "", root.parts?.name ?? ""]
        stdout: StdioCollector { onStreamFinished: root.found = text.trim() || "-" }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.r(6)
        color: Theme.fill2
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.found === "-" ? Quickshell.iconPath("application-x-executable") : root.source
        asynchronous: true
        mipmap: true
        opacity: root.item?.status === Status.Passive ? 0.6 : 1
    }
    // pide atención (NeedsAttention): un punto
    Rectangle {
        visible: root.item?.status === Status.NeedsAttention
        width: 6; height: 6; radius: 3
        color: Theme.danger
        anchors { right: parent.right; top: parent.top; rightMargin: 2; topMargin: 1 }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => {
            const it = root.item;
            if (e.button === Qt.MiddleButton) it.secondaryActivate();
            else if (e.button === Qt.RightButton || (it.onlyMenu && it.hasMenu)) root.menuRequested(root);
            else it.activate();
        }
        onWheel: e => { root.item.scroll(e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x, e.angleDelta.y === 0); }
    }
    BarTip {
        target: ma
        text: {
            const t = root.item?.tooltipTitle || root.item?.title || root.item?.id || "";
            const d = String(root.item?.tooltipDescription ?? "").replace(/<[^>]*>/g, "").trim();
            return d && d !== t ? t + " · " + d.split("\n")[0] : t;
        }
    }
}
