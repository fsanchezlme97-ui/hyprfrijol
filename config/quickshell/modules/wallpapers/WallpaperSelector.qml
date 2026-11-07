// Selector de fondos (vista "fondos", Super + Shift + W), como SelectorFondos del diseño:
// tiras inclinadas con la tarjeta grande del fondo elegido, vista previa a pantalla completa al instante,
// botonera (← → · Aleatorio · Movimiento · Colores · Cancelar · Aplicar), pantallas, «Según la hora» y «Mis fondos».
// Fondos: tu carpeta (~/Imágenes/Fondos o Wallpapers) + los de hyprfrijol (assets/wallpapers).
// Miniaturas en ~/.cache/hyprfrijol/thumbs (hf-wallpaper thumbs, con ImageMagick).
// Teclas: ← → (o rueda) cambiar · Inicio/Fin · R aleatorio · Intro aplicar · Esc cancelar.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "fondos"
    place: "fill"
    margin: 0
    closeOnOutside: false

    property var items: []          // [{ path, thumb, name, video, own }]
    property int sel: 0
    property string monitor: ""     // "" = todas
    property bool showHoras: false
    property bool showAdd: false
    property bool loading: false
    readonly property var cur: items[sel] ?? null
    readonly property string current: (curFile.text() || "").trim()

    // Nombres bonitos para los fondos incluidos (como en el diseño)
    readonly property var names: ({ amanecer: "Atardecer", lago: "Lago", bosque: "Bosque", bruma: "Bruma", noche: "Noche",
                                    niebla: "Niebla", lineas: "Líneas", orbes: "Orbes", dunas: "Dunas" })
    function prettyName(path: string): string {
        const base = path.split("/").pop().replace(/\.[^.]+$/, "");
        if (names[base]) return names[base];
        const s = base.replace(/[_-]+/g, " ").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function isVideo(p: string): bool { return /\.(mp4|webm|mkv|mov|gif)$/i.test(p); }

    function reload(): void { loading = true; thumbsProc.running = false; thumbsProc.running = true; }
    function step(d: int): void { if (items.length) sel = (sel + d + items.length) % items.length; }
    function random(): void {
        if (items.length < 2) return;
        let r = sel; while (r === sel) r = Math.floor(Math.random() * items.length);
        sel = r;
    }
    function apply(): void {
        if (!cur) return;
        const args = [Paths.script("hf-wallpaper")];
        if (monitor !== "") args.push("-o", monitor);
        args.push(cur.path);
        Quickshell.execDetached(args);
        Shell.close();
    }
    function cycleColors(): void {
        const m = Settings.get("colorMode", "auto");
        Settings.set("colorMode", m === "auto" ? "elegir" : m === "elegir" ? "mono" : "auto");
    }
    readonly property string colorName: {
        const m = Settings.get("colorMode", "auto");
        return m === "auto" ? "automáticos" : m === "mono" ? "monocromo" : Theme.paletteName;
    }

    onShownChanged: if (shown) {
        showAdd = false; showHoras = Settings.get("wallpaperHora", false) === true; monitor = "";
        curFile.reload();
        reload();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    FileView { id: curFile; path: Paths.state + "/wallpaper-path"; printErrors: false }
    Process {
        id: thumbsProc
        command: [Paths.script("hf-wallpaper"), "thumbs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [p, t] = l.split("\t");
                    return { path: p, thumb: t, name: win.prettyName(p), video: win.isVideo(p), own: !p.startsWith(Paths.assets) };
                });
                win.items = list;
                const i = list.findIndex(x => x.path === win.current);
                win.sel = i >= 0 ? i : 0;
                win.loading = false;
            }
        }
    }
    Process { id: addProc; onExited: win.reload() }

    // ── Vista previa a pantalla completa (al instante) ─────────────────────
    Item {
        id: preview
        x: -win.panel.x; y: -win.panel.y
        width: win.width; height: win.height
        Image {
            id: big
            anchors.fill: parent
            source: win.cur ? "file://" + (win.isVideo(win.cur.path) ? win.cur.thumb : win.cur.path) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(parent.width / 2, parent.height / 2)   // está desenfocada: basta con media resolución
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: big
            blurEnabled: true
            blur: 0.2
            blurMax: 20
            saturation: Settings.get("colorMode", "auto") === "mono" && Settings.get("monoFondo", true) !== false ? -1 : 0
            opacity: big.status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        }
        Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.25 }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: w => win.step(w.angleDelta.y > 0 || w.angleDelta.x > 0 ? -1 : 1)
        }
    }

    // ── Tiras inclinadas ──────────────────────────────────────────────────
    readonly property real skew: Math.tan(8 * Math.PI / 180)
    Item {
        id: strips
        width: parent.width
        height: 480
        // centrado y subido como en el diseño (translateY(-66%) desde el centro)
        y: win.height / 2 - height * 0.66 - win.panel.y
        // Ventana de tiras que caben en pantalla, equilibrada alrededor de la elegida
        readonly property var vis: {
            const n = win.items.length, cap = Math.max(2, Math.floor((width - 120 - 776) / 78));
            let left = Math.min(win.sel, Math.floor(cap / 2));
            const right = Math.min(n - 1 - win.sel, cap - left);
            left = Math.min(win.sel, cap - right);
            const r = [];
            for (let i = win.sel - left; i <= win.sel + right; i++) r.push(i);
            return r;
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: strips.vis
                delegate: Item {
                    id: strip
                    required property int modelData
                    required property int index
                    readonly property var it: win.items[modelData]
                    readonly property bool on: modelData === win.sel
                    readonly property int d: Math.abs(modelData - win.sel)
                    readonly property real ml: index === 0 ? 0 : (on || modelData - 1 === win.sel ? 28 : -14)
                    width: (on ? 720 : 92) + ml
                    height: 480
                    z: on ? 100 : 99 - d
                    Behavior on width { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                    Item {
                        id: card
                        x: strip.ml
                        width: strip.width - strip.ml
                        height: strip.on ? 440 : 400
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on height { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -win.skew, 0, win.skew * card.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        RectangularShadow {
                            anchors.fill: parent
                            offset.y: strip.on ? 24 : 10
                            blur: strip.on ? 60 : 30
                            color: Qt.rgba(0, 0, 0, strip.on ? 0.45 : 0.3)
                        }
                        Item {
                            anchors.fill: parent
                            clip: true
                            Image {
                                // contra-inclinada para que la imagen no se deforme
                                width: parent.width + win.skew * parent.height
                                height: parent.height
                                x: -win.skew * parent.height / 2
                                source: strip.it ? "file://" + strip.it.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.height: 480
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, win.skew, 0, -win.skew * card.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: strip.on ? 2 : 1
                            border.color: strip.on ? Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, 0.85) : Qt.rgba(1, 1, 1, 0.18)
                        }
                        // ▶ Animado
                        Rectangle {
                            visible: strip.on && !!strip.it && strip.it.video
                            anchors { top: parent.top; right: parent.right; margins: 12 }
                            width: animTxt.implicitWidth + 16; height: 22; radius: Theme.r(6)
                            color: Qt.rgba(0, 0, 0, 0.55)
                            Txt { id: animTxt; anchors.centerIn: parent; text: "▶ Animado"; size: 11; color: "white" }
                        }
                        // Actual
                        Rectangle {
                            visible: strip.on && !!strip.it && strip.it.path === win.current
                            anchors { top: parent.top; left: parent.left; margins: 12 }
                            width: curTxt.implicitWidth + 16; height: 22; radius: Theme.r(6)
                            color: Qt.rgba(0, 0, 0, 0.55)
                            Txt { id: curTxt; anchors.centerIn: parent; text: "✓ Actual"; size: 11; color: "white" }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: strip.on ? win.apply() : (win.sel = strip.modelData)
                        }
                    }
                }
            }
        }
        Txt {
            visible: win.items.length === 0
            anchors.centerIn: parent
            text: win.loading ? "Preparando miniaturas…" : "No hay fondos. Añade imágenes con «+ Mis fondos»."
            color: "white"; size: 14
        }
    }

    // ── Parte de abajo ────────────────────────────────────────────────────
    component Sep: Rectangle { implicitWidth: 1; implicitHeight: 18; color: Theme.ov; Layout.alignment: Qt.AlignVCenter }
    component Bar: Glass {
        kind: "panel"; radius: Theme.r(12); big: false
        default property alias inner: lay.data
        implicitWidth: lay.implicitWidth + 8
        implicitHeight: lay.implicitHeight + 8
        RowLayout { id: lay; anchors.centerIn: parent; spacing: 4 }
    }
    component MonIcon: Rectangle {
        property real w: 16
        implicitWidth: w; implicitHeight: Math.round(w * 0.62)
        radius: 2; color: "transparent"; border.width: 1.4; border.color: Theme.t
    }

    ColumnLayout {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Math.max(8, 70 - win.mB) }
        spacing: 10

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Txt { text: win.cur ? win.cur.name : ""; size: 22; weight: Font.Medium; color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.15) }
            Txt { text: win.items.length ? (win.sel + 1) + " / " + win.items.length : ""; size: 12; color: Qt.rgba(1, 1, 1, 0.75); tabular: true; Layout.alignment: Qt.AlignBaseline }
        }

        Bar {
            Layout.alignment: Qt.AlignHCenter
            Btn { kind: "ghost"; text: "←"; onClicked: win.step(-1) }
            Btn { kind: "ghost"; text: "→"; onClicked: win.step(1) }
            Sep {}
            Btn { kind: "ghost"; text: "Aleatorio"; onClicked: win.random() }
            Btn {
                readonly property bool on: Settings.get("animado", true) !== false
                kind: on ? "tonal" : "ghost"; text: "▶ Movimiento"
                onClicked: Settings.set("animado", !on)
            }
            Btn { kind: "ghost"; text: "Colores: " + win.colorName; onClicked: win.cycleColors() }
            Sep {}
            Btn { kind: "ghost"; text: "Cancelar"; onClicked: Shell.close() }
            Btn { kind: "primary"; text: "Aplicar"; onClicked: win.apply() }
        }

        Bar {
            Layout.alignment: Qt.AlignHCenter
            Txt { text: "Pantalla"; muted: true; Layout.leftMargin: 8; Layout.rightMargin: 4 }
            Repeater {
                model: [{ name: "", label: "Todas", w: 22 }].concat(Quickshell.screens.length > 1 ? Quickshell.screens.map(s => ({
                    name: s.name, w: s.width >= 2400 ? 16 : 12,
                    label: s.name + (s.model ? " · " + s.model : "")
                })) : [])
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: win.monitor === modelData.name
                    implicitHeight: 30; implicitWidth: mr.implicitWidth + 20; radius: Theme.r(7)
                    color: on ? Theme.fill2 : "transparent"
                    RowLayout { id: mr; anchors.centerIn: parent; spacing: 8; MonIcon { w: modelData.w } Txt { text: modelData.label } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.monitor = modelData.name }
                }
            }
            Sep {}
            Btn {
                readonly property bool on: Settings.get("wallpaperHora", false) === true
                kind: on ? "tonal" : "ghost"; text: "◐ Según la hora"
                onClicked: { win.showAdd = false; win.showHoras = !on; Settings.set("wallpaperHora", !on); if (!on) Quickshell.execDetached([Paths.script("hf-wallpaper"), "hora"]); }
            }
            Btn { kind: win.showAdd ? "tonal" : "ghost"; text: "+ Mis fondos"; onClicked: { win.showAdd = !win.showAdd; win.showHoras = false; } }
        }

        // Horario de «Según la hora»
        Bar {
            visible: win.showHoras
            Layout.alignment: Qt.AlignHCenter
            Repeater {
                model: [["06:00", "Atardecer", 360, 600], ["10:00", "Bruma", 600, 1050], ["17:30", "Lago", 1050, 1200], ["20:00", "Noche", 1200, 1800]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property int m: Time.now.getHours() * 60 + Time.now.getMinutes()
                    readonly property bool on: modelData[2] === 1200 ? (m >= 1200 || m < 360) : (m >= modelData[2] && m < modelData[3])
                    implicitWidth: 118; implicitHeight: 44; radius: Theme.r(8)
                    color: on ? Theme.fill2 : "transparent"
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 1
                        Txt { Layout.alignment: Qt.AlignHCenter; text: modelData[0]; size: 13; weight: Font.DemiBold; tabular: true }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: modelData[1]; size: 11; muted: true }
                    }
                }
            }
            Txt { text: "Cambia el fondo según la hora con fundido"; size: 11; muted: true; Layout.leftMargin: 8; Layout.rightMargin: 8 }
        }

        // Añadir fondos propios
        Glass {
            visible: win.showAdd
            Layout.alignment: Qt.AlignHCenter
            kind: "panel"; radius: Theme.r(12); big: false
            implicitWidth: 640; implicitHeight: 118
            Rectangle {
                anchors { fill: parent; margins: 10 }
                radius: Theme.r(8)
                color: drop.containsDrag ? Qt.rgba(Theme.p.r, Theme.p.g, Theme.p.b, 0.12) : "transparent"
                border.width: 1.5
                border.color: drop.containsDrag ? Theme.p : Theme.ov
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 4
                    Icon { Layout.alignment: Qt.AlignHCenter; name: "upload"; size: 20; color: Theme.tv }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "Suelta imágenes o vídeos aquí"; size: 13; weight: Font.Medium }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "JPG, PNG, WebP, MP4, WebM · se copian a ~/Imágenes/Fondos"; size: 11; muted: true }
                }
                Btn {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                    kind: "ghost"; h: 26; icon: "folder"; text: "Abrir carpeta"
                    onClicked: Quickshell.execDetached(["sh", "-c", 'd="$(xdg-user-dir PICTURES)/Fondos"; [ -d "$d" ] || d="$(xdg-user-dir PICTURES)/Wallpapers"; mkdir -p "$d"; xdg-open "$d"'])
                }
                DropArea {
                    id: drop
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: d => {
                        const files = d.urls.map(u => decodeURIComponent(u.toString().replace(/^file:\/\//, "")))
                                            .filter(f => /\.(jpe?g|png|webp|mp4|webm|mkv|mov|gif)$/i.test(f));
                        if (!files.length) return;
                        addProc.command = [Paths.script("hf-wallpaper"), "add"].concat(files);
                        addProc.running = true;
                    }
                }
            }
        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "Super + Shift + W · ← → cambiar · Enter aplicar · Esc cancelar · la vista previa se aplica al instante"
            size: 11.5; color: Qt.rgba(1, 1, 1, 0.8)
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
    }

    // Teclado
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            switch (e.key) {
            case Qt.Key_Left: case Qt.Key_H: win.step(-1); break;
            case Qt.Key_Right: case Qt.Key_L: case Qt.Key_Tab: win.step(1); break;
            case Qt.Key_Home: win.sel = 0; break;
            case Qt.Key_End: win.sel = Math.max(0, win.items.length - 1); break;
            case Qt.Key_R: win.random(); break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.apply(); break;
            default: return;
            }
            e.accepted = true;
        }
        Keys.onEscapePressed: Shell.close()
    }
}
