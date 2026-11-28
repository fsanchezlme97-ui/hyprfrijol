// Isla dinámica (ajuste island, apagada de fábrica): una pastilla arriba al centro con lo que está pasando. Plegada
// enseña lo más importante en una línea (reunión en menos de 10 min > Pomodoro > procesos en curso > música sonando);
// al pasar el puntero (o pulsarla) se despliega con todo ello y sus controles. Qué se muestra: islandShow
// (musica · pomodoro · descargas · reunion). Sin nada en marcha se esconde, o enseña la hora con islandAlways.
// El dictado no entra: su píldora (modules/dictado) sigue donde estaba y se aparta de la isla (OsdStack.island).
// Se pone en el sitio superior del OSD (services/OsdStack.qml: respeta la barra, su reserva y osdOffset) y en la capa
// «Top», así que una ventana a pantalla completa la tapa. Apagada no crea ninguna ventana.
// IPC:  qs -p <repo>/config/quickshell ipc call isla expand | collapse | state
// Con barMode «integrada» (Ajustes › Barra › Forma) la isla va dentro de la barra, en su hueco central: plegada mide lo
// que la barra, sin nada en marcha se encoge a un punto, y al desplegarse crece hacia el escritorio sin pisar las píldoras
// de los lados (OsdStack.barLeft/barRight). Eso solo con la barra arriba o abajo y siempre visible (Settings.barIslandSlot); si no,
// flota como siempre. Con ese modo la isla está siempre activa.
// Ajustes › Barra › Isla dinámica.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    readonly property bool integrated: Settings.barIslandSlot(Shell.screen)    // dentro de la barra
    readonly property bool on: Settings.get("island", false) === true || Settings.barMode === "integrada"
    readonly property bool always: Settings.get("islandAlways", false) === true
    readonly property var wanted: Settings.get("islandShow", ["musica", "pomodoro", "descargas", "reunion"]) ?? []
    property bool pinned: false             // desplegada por IPC o por un clic
    property bool hover: false              // el puntero está encima (con un respiro al salir para que no parpadee)
    readonly property bool expanded: pinned || hover

    // Qué actividades hay, por prioridad. Solo la lista de claves (como texto) para que las filas no se rehagan cada segundo;
    // lo que cambia (cuenta atrás, porcentaje…) lo lee cada fila de info(clave).
    readonly property string keysRaw: {
        const k = [], ev = Events.next, p = Media.active;
        if (wanted.includes("reunion") && ev && !ev.allDay && ev.start - Time.now <= 10 * 60000) k.push("reunion");
        if (wanted.includes("pomodoro") && Pomodoro.running) k.push("pomodoro");
        if (wanted.includes("descargas") && Jobs.items.length > 0) k.push("descargas");
        if (wanted.includes("musica") && p && p.isPlaying) k.push("musica");
        return k.join(",");
    }
    readonly property var keys: keysRaw ? keysRaw.split(",") : []
    readonly property bool shown: on && !Shell.locked && (keys.length > 0 || always || integrated)
    readonly property bool dot: integrated && keys.length === 0 && !always    // sin nada en marcha: un punto en la barra

    function pct(v): string { return v >= 0 ? Math.round(v * 100) + " %" : ""; }
    function info(k): var {
        if (k === "reunion") {
            const ev = Events.next;
            return ev ? { icon: "calendar", title: ev.title, sub: ev.start <= Time.now ? "En curso" : Events.relative(ev.start), progress: -1, view: "agenda", link: ev.link } : { title: "", sub: "", progress: -1 };
        }
        if (k === "pomodoro")
            return { icon: "clock", title: Pomodoro.label + (Pomodoro.activity ? " · " + Pomodoro.activity : ""), sub: Pomodoro.time, progress: Pomodoro.progress, view: "w-pomodoro" };
        if (k === "descargas") {
            const j = Jobs.items, v = j.length ? j.reduce((a, x) => a + Math.max(0, x.progress), 0) / j.length : -1;
            return { icon: "download", title: j.length === 1 ? j[0].title : j.length + " procesos en curso", sub: j.length === 1 ? (j[0].detail || pct(v)) : pct(v), progress: j.some(x => x.progress >= 0) ? v : -1, view: "w-descargas" };
        }
        if (k === "musica") {
            const p = Media.active;
            return { icon: "music", title: p?.trackTitle || "Reproduciendo", sub: p?.trackArtist ?? "", art: p?.trackArtUrl ?? "", progress: -1, view: "musica" };
        }
        return { icon: "clock", title: Time.hhmm, sub: Time.longDate, progress: -1, view: "agenda" };
    }

    Timer { id: leave; interval: 260; onTriggered: root.hover = false }
    IpcHandler {
        target: "isla"
        function expand(): void { root.pinned = true; }
        function collapse(): void { root.pinned = false; root.hover = false; }
        function state(): string { return (root.shown ? "visible" : "oculta") + " · " + (root.expanded ? "desplegada" : "plegada") + " · " + (root.keysRaw || "sin actividad"); }
    }

    PanelWindow {
        id: win
        screen: Shell.screen
        visible: root.on && (root.shown || pill.opacity > 0.01)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hf-isla"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        // Integrada: pegada a la barra (arriba o abajo, con su margen); si no, bajo ella en el sitio superior del OSD
        readonly property bool low: root.integrated && Settings.barPos === "abajo"
        // Integrada: centrada en el hueco entre las píldoras de la barra (no en la pantalla, que las pisaría al desplegarse)
        readonly property real gapL: OsdStack.barLeft + 12
        readonly property real gapR: OsdStack.barRight - 12
        anchors { top: !low; bottom: low; left: root.integrated }
        margins { top: root.integrated ? Settings.barOffset : OsdStack.edge("arriba"); bottom: Settings.barOffset; left: Math.max(0, (gapL + gapR) / 2 - 220) }
        implicitWidth: 440
        implicitHeight: root.integrated ? 212 : 20 + 24 + 3 * 52 + 2 * 8 + 40
        mask: Region { item: pill }
        Binding { target: OsdStack; property: "island"; value: root.shown && !root.integrated ? 32 : 0 }
        // Ancho libre entre las píldoras de la barra (si no, el de siempre)
        readonly property real room: root.integrated ? Math.max(56, gapR - gapL) : 400

        readonly property int rows: Math.max(1, Math.min(3, root.keys.length))
        readonly property var top: root.info(root.keys.length ? root.keys[0] : "")

        Glass {
            id: pill
            kind: "panel"
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.low ? win.height - height : root.integrated ? 0 : 20
            opacity: root.shown ? 1 : 0
            readonly property real base: root.integrated ? Settings.barThickness : 32
            width: root.expanded ? Math.min(400, win.room) : root.dot ? base : Math.min(win.room, Math.max(120, Math.min(300, compact.implicitWidth + 28)))
            height: root.expanded ? Math.max(base, 24 + (root.keys.length ? win.rows * 52 + (win.rows - 1) * 8 : 54)) : base
            // En la barra, las esquinas de sus píldoras (como Bar.pillRadius); suelta, una cápsula
            radius: root.expanded ? Theme.r(24) : root.integrated ? Math.min((Settings.get("rounding", null) ?? Theme.winRadius) + Math.max(0, Math.min(4, Number(Settings.get("barRoundExtra", 4)) || 0)), height / 2) : height / 2
            Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            HoverHandler { onHoveredChanged: { if (hovered) { leave.stop(); root.hover = true; } else leave.restart(); } }
            TapHandler { onTapped: root.pinned = !root.pinned }

            // Plegada: lo más importante en una línea
            RowLayout {
                id: compact
                anchors.centerIn: parent
                spacing: 8
                opacity: root.expanded ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durShort } }
                Rectangle { visible: root.dot; implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.tv }
                Icon { visible: root.keys.length > 0; name: win.top.icon ?? "clock"; size: 14; color: Theme.p }
                Txt { visible: !root.dot; Layout.maximumWidth: 170; text: root.keys.length ? win.top.title : Time.hhmm; elide: Text.ElideRight; weight: Font.Medium; size: 12.5; tabular: !root.keys.length }
                Txt { visible: root.keys.length > 0 && !!win.top.sub && root.keys[0] !== "musica"; text: win.top.sub; muted: true; size: 12; tabular: true }
            }
            Rectangle {
                visible: !root.expanded && root.keys.length > 0 && win.top.progress >= 0
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 4 }
                width: (parent.width - 32) * win.top.progress; height: 2; radius: 1; color: Theme.p
            }

            // Desplegada: una fila por actividad (o la hora y la fecha si no hay nada)
            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 8
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durMedium } }
                ColumnLayout {
                    visible: root.keys.length === 0
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Txt { text: Time.hhmm; size: 24; weight: Font.Medium; tabular: true }
                    Txt { text: Time.longDate.charAt(0).toUpperCase() + Time.longDate.slice(1); muted: true; size: 12 }
                }
                Repeater {
                    model: root.keys.slice(0, 3)
                    Item {
                        id: row
                        required property string modelData
                        readonly property var d: root.info(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 52
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.pinned = false; Shell.open(row.d.view); } }
                        RowLayout {
                            anchors.fill: parent
                            spacing: 12
                            Item {
                                implicitWidth: 44; implicitHeight: 44
                                Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: Theme.r(10) } }
                                Rectangle { anchors.fill: parent; radius: Theme.r(10); color: Theme.s4 }
                                Icon { anchors.centerIn: parent; visible: art.status !== Image.Ready; name: row.d.icon ?? "clock"; size: 18; color: Theme.p }
                                Item {
                                    anchors.fill: parent
                                    visible: art.status === Image.Ready
                                    layer.enabled: visible
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                    Image { id: art; anchors.fill: parent; source: row.d.art ?? ""; sourceSize.width: 96; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Txt { Layout.fillWidth: true; text: row.d.title; weight: Font.DemiBold; elide: Text.ElideRight }
                                Txt { Layout.fillWidth: true; text: row.d.sub; muted: true; size: 11.5; tabular: true; elide: Text.ElideRight }
                                Rectangle {
                                    visible: row.d.progress >= 0
                                    Layout.fillWidth: true; implicitHeight: 3; radius: 1.5; color: Theme.fill2
                                    Rectangle { width: parent.width * row.d.progress; height: parent.height; radius: 1.5; color: Theme.p }
                                }
                            }
                            // Controles de cada actividad
                            IconBtn { visible: row.modelData === "musica"; icon: "prev"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Anterior"; opacity: Media.active?.canGoPrevious ? 1 : 0.35; onClicked: if (Media.active?.canGoPrevious) Media.active.previous() }
                            IconBtn { visible: row.modelData === "musica"; icon: Media.active?.isPlaying ? "pause" : "play"; iconSize: 16; implicitWidth: 30; implicitHeight: 30; tooltip: "Pausar"; onClicked: if (Media.active?.canTogglePlaying) Media.active.togglePlaying() }
                            IconBtn { visible: row.modelData === "musica"; icon: "next"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Siguiente"; opacity: Media.active?.canGoNext ? 1 : 0.35; onClicked: if (Media.active?.canGoNext) Media.active.next() }
                            IconBtn { visible: row.modelData === "pomodoro"; icon: Pomodoro.running ? "pause" : "play"; iconSize: 16; implicitWidth: 30; implicitHeight: 30; tooltip: Pomodoro.running ? "Pausar" : "Seguir"; onClicked: Pomodoro.toggle() }
                            IconBtn { visible: row.modelData === "pomodoro"; icon: "next"; iconSize: 15; implicitWidth: 30; implicitHeight: 30; tooltip: "Saltar al siguiente bloque"; onClicked: Pomodoro.skip() }
                            Btn { visible: row.modelData === "reunion" && !!row.d.link; kind: "primary"; h: 28; padX: 12; text: "Unirse"; onClicked: { Qt.openUrlExternally(row.d.link); root.pinned = false; } }
                        }
                    }
                }
            }
        }
    }
}
