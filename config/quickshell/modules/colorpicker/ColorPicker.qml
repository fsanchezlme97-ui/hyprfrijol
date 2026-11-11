// Selector de color (vista "color"; Super + Mayús + C, Spotlight, ajustes rápidos).
//   · Congela la pantalla (hf-capture freeze) y muestra una lupa de píxeles centrada en el cursor con el color
//     debajo. Clic o Intro = elegir (flechas: mover 1 px, Mayús ×10). Se copia en el formato preferido.
//   · Después, tarjeta con el color en HEX / RGB / HSL / OKLCH (clic = copiar y queda como preferido) y el
//     historial de recientes (~/.local/state/hyprfrijol/colores.json).
//   · Sin grim usa hyprpicker; sin ninguno, ofrece instalar hyprpicker (Pkg).
//   Shell.open("color")  ·  Shell.open("color", "historial") abre solo la tarjeta
//   qs … ipc call color pick X Y   (elige el píxel X,Y de la pantalla congelada; para pruebas)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"
import "../capture"

Scope {
    id: root
    property bool loaded: false     // ver components/Overlay (carga diferida)
    Component.onCompleted: Qt.callLater(() => root.loaded = true)
    readonly property bool shown: loaded && Shell.view === "color"
    property string stage: "off"               // off | congelando | elegir | tarjeta
    property string frozen: ""
    property var screenUsed: Shell.screen
    property real px: 0                        // punto lógico que se mira
    property real py: 0
    property color cur: "black"                // color bajo el cursor
    property color picked: "#000000"
    property bool hasPick: false
    property var history: []                   // ["#RRGGBB", …] (más reciente primero)
    property string format: "hex"              // formato preferido (el que se copia al elegir)
    property bool ready: false                 // lienzo con la imagen ya pintado
    property string toast: ""
    property string missing: ""                // "hyprpicker" si no hay con qué elegir
    readonly property var formats: [["hex", "HEX"], ["rgb", "RGB"], ["hsl", "HSL"], ["oklch", "OKLCH"]]

    // ── Formatos ──────────────────────────────────────────────────────
    function h2(v: real): string { return Math.round(v * 255).toString(16).padStart(2, "0").toUpperCase(); }
    function hex(c): string { return "#" + h2(c.r) + h2(c.g) + h2(c.b); }
    function fmt(c, f: string): string {
        const r = c.r, g = c.g, b = c.b;
        if (f === "hex") return hex(c);
        if (f === "rgb") return "rgb(" + Math.round(r * 255) + ", " + Math.round(g * 255) + ", " + Math.round(b * 255) + ")";
        if (f === "hsl") {
            const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn;
            let h = 0, s = 0;
            if (d > 0) {
                s = d / (1 - Math.abs(2 * l - 1));
                h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
                h = (h * 60 + 360) % 360;
            }
            return "hsl(" + Math.round(h) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)";
        }
        // OKLCH (Björn Ottosson): sRGB → lineal → LMS → OKLab → LCh
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const R = lin(r), G = lin(g), B = lin(b);
        const l_ = Math.cbrt(0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B);
        const m_ = Math.cbrt(0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B);
        const s_ = Math.cbrt(0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B);
        const L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
        const A = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
        const Bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
        const C = Math.sqrt(A * A + Bb * Bb);
        let H = Math.atan2(Bb, A) * 180 / Math.PI;
        if (H < 0) H += 360;
        return "oklch(" + (L * 100).toFixed(1) + "% " + C.toFixed(3) + " " + (C < 0.0005 ? "0" : H.toFixed(1)) + ")";
    }
    function lum(c): real { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    function inkOn(c): color { return lum(c) > 0.55 ? "#111111" : "#FFFFFF"; }

    function copy(t: string): void {
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", t]);
        toast = "Copiado " + t; toastTimer.restart();
    }
    function choose(c): void {
        picked = c; hasPick = true;
        const h = hex(c);
        history = [h].concat(history.filter(x => x !== h)).slice(0, 30);
        save();
        copy(fmt(c, format));
        stage = "tarjeta";
        dropFrozen();
    }
    function setFormat(f: string): void { format = f; save(); }

    // ── Historial ──────────────────────────────────────────────────────
    FileView {
        id: store
        path: Paths.state + "/colores.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.history = (d.history ?? []).filter(x => /^#[0-9A-F]{6}$/i.test(x));
                root.format = ["hex", "rgb", "hsl", "oklch"].includes(d.format) ? d.format : "hex";
            } catch (e) {}
        }
    }
    function save(): void { store.setText(JSON.stringify({ format: format, history: history }, null, 1)); }

    // ── Apertura ───────────────────────────────────────────────────────

    onShownChanged: {
        if (!shown) { stage = "off"; dropFrozen(); missing = ""; return; }
        screenUsed = Shell.screen;
        if (Shell.arg === "historial") {
            if (!hasPick && history.length) { picked = history[0]; hasPick = true; }
            stage = "tarjeta"; return;
        }
        startPick();
    }
    function startPick(): void {
        stage = "congelando"; ready = false; missing = "";
        freezeTimer.restart();
    }
    function dropFrozen(): void {
        if (frozen) Quickshell.execDetached(["rm", "-f", frozen]);
        frozen = ""; ready = false;
    }
    Timer { id: freezeTimer; interval: Theme.durOut + 60; onTriggered: { freezeProc.command = [Paths.script("hf-capture"), "freeze", root.screenUsed.name]; freezeProc.running = true; } }
    Process {
        id: freezeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (!root.shown) { if (p) Quickshell.execDetached(["rm", "-f", p]); return; }
                if (!p) { pickerProc.running = true; return; }       // sin grim: hyprpicker
                root.frozen = p;
                root.px = (root.screenUsed?.width ?? 0) / 2; root.py = (root.screenUsed?.height ?? 0) / 2;
                root.stage = "elegir";
            }
        }
    }
    // Plan B: hyprpicker (su propia lupa)
    Process {
        id: pickerProc
        command: ["sh", "-c", "command -v hyprpicker >/dev/null || { echo FALTA; exit 0; }; hyprpicker -n -f hex 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === "FALTA") { root.missing = "hyprpicker"; root.stage = "tarjeta"; return; }
                const m = t.match(/#?([0-9a-fA-F]{6})/);
                if (m) root.choose(Qt.color("#" + m[1]));
                else Shell.close();
            }
        }
    }

    // ── Ventana ────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        screen: root.screenUsed
        visible: root.shown && (root.stage === "elegir" && root.frozen !== "" || root.stage === "tarjeta")
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hfx-color"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        // Lienzo oculto (debajo de la imagen) para leer el color de cada píxel
        Canvas {
            id: cv
            width: win.width; height: win.height
            visible: root.frozen !== ""
            renderStrategy: Canvas.Immediate
            renderTarget: Canvas.Image
            readonly property string src: root.frozen ? "file://" + root.frozen : ""
            onSrcChanged: { root.ready = false; if (src) loadImage(src); }
            onImageLoaded: requestPaint()
            onPaint: {
                if (!src || !isImageLoaded(src)) return;
                const ctx = getContext("2d");
                ctx.drawImage(src, 0, 0, width, height);
                root.ready = true;
                root.sample();
            }
        }
        Image {
            id: bg
            anchors.fill: parent
            visible: root.frozen !== ""
            source: root.frozen ? "file://" + root.frozen : ""
            asynchronous: false
            cache: true
        }
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.stage === "tarjeta" ? (root.frozen ? 0.45 : 0.3) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // Sin cursor: la lupa está centrada en él (en los bordes la lupa se aparta y vuelve la cruz)
            readonly property bool edge: root.px < loupe.width / 2 + 4 || root.px > win.width - loupe.width / 2 - 4
                                         || root.py < loupe.height / 2 + 4 || root.py > win.height - loupe.height / 2 - 40
            cursorShape: root.stage === "elegir" ? (edge ? Qt.CrossCursor : Qt.BlankCursor) : Qt.ArrowCursor
            onPositionChanged: m => { if (root.stage === "elegir") { root.px = m.x; root.py = m.y; root.sample(); } }
            onClicked: m => {
                if (root.stage === "elegir") {
                    if (m.button === Qt.RightButton) { Shell.close(); return; }
                    root.px = m.x; root.py = m.y; root.sample();
                    if (root.ready) root.choose(root.cur);
                } else if (!card.contains(mapToItem(card, m.x, m.y))) Shell.close();
            }
        }

        // Lupa centrada en el punto, con el color debajo
        Item {
            visible: root.stage === "elegir"
            x: Math.max(4, Math.min(win.width - width - 4, Math.round(root.px - loupe.width / 2)))
            y: Math.max(4, Math.min(win.height - height - 40, Math.round(root.py - loupe.height / 2)))
            width: loupe.width; height: loupe.height
            Loupe {
                id: loupe
                source: bg.source
                screenW: win.width; screenH: win.height
                px: root.px; py: root.py
                zoom: 10; cells: 15; grid: true
                frame: root.lum(root.cur) > 0.55 ? "black" : "white"
            }
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; top: loupe.bottom; topMargin: 8 }
                width: chipRow.implicitWidth + 16; height: 28; radius: Theme.ctl(28)
                color: Qt.rgba(0, 0, 0, 0.75)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle { width: 14; height: 14; radius: 7; color: root.cur; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.6); anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: root.ready ? root.fmt(root.cur, root.format) : "…"; color: "white"; size: 12; font.family: Theme.mono; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Txt {
            visible: root.stage === "elegir"
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 72 }
            text: "Clic o Intro para elegir · flechas para afinar (Mayús ×10) · Esc salir"
            size: 11.5; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.55)
        }

        // ── Tarjeta ───────────────────────────────────────────────────
        Glass {
            id: card
            visible: root.stage === "tarjeta"
            kind: "popup"
            width: 380
            height: cardCol.implicitHeight + 32
            anchors.centerIn: parent
            scale: visible ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
            ColumnLayout {
                id: cardCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Icon { name: "drop"; size: 16; color: Theme.p }
                    Txt { Layout.fillWidth: true; text: "Selector de color"; weight: Font.DemiBold; size: 14 }
                    IconBtn { icon: "x"; implicitWidth: 28; implicitHeight: 28; onClicked: Shell.close() }
                }
                // Falta con qué elegir
                ColumnLayout {
                    visible: root.missing !== ""
                    Layout.fillWidth: true
                    spacing: 8
                    Txt { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Para elegir colores de la pantalla hace falta grim o hyprpicker." }
                    Btn { kind: "primary"; icon: "download"; text: "Instalar hyprpicker"
                          onClicked: { Pkg.install([{ key: "repo", pkg: "hyprpicker", name: "hyprpicker" }], "Instalar hyprpicker"); Shell.close(); } }
                }
                // Muestra grande
                Rectangle {
                    visible: root.hasPick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    radius: Theme.r(12)
                    color: root.picked
                    border.width: 1; border.color: Theme.ov
                    Txt {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                        text: root.hex(root.picked); size: 20; weight: Font.DemiBold; font.family: Theme.mono
                        color: root.inkOn(root.picked)
                    }
                }
                // Formatos
                ColumnLayout {
                    visible: root.hasPick
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: root.formats
                        Rectangle {
                            id: frow
                            required property var modelData
                            readonly property string val: root.fmt(root.picked, modelData[0])
                            readonly property bool pref: root.format === modelData[0]
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.r(8)
                            color: fma.containsMouse ? Theme.fill2 : "transparent"
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                                spacing: 10
                                Txt { text: frow.modelData[1]; muted: true; size: 11; weight: Font.DemiBold; Layout.preferredWidth: 46 }
                                Txt { Layout.fillWidth: true; text: frow.val; font.family: Theme.mono; size: 12.5; elide: Text.ElideRight }
                                Txt { visible: frow.pref; text: "al elegir"; size: 10.5; color: Theme.p }
                                Icon { name: "copy"; size: 14; color: fma.containsMouse ? Theme.t : Theme.tv }
                            }
                            MouseArea {
                                id: fma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.copy(frow.val); root.setFormat(frow.modelData[0]); }
                            }
                        }
                    }
                }
                // Recientes
                ColumnLayout {
                    visible: root.history.length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { Layout.fillWidth: true; text: "Recientes"; muted: true; size: 11.5; weight: Font.DemiBold }
                        Txt {
                            text: "Borrar"; size: 11.5; color: clrMa.containsMouse ? Theme.t : Theme.tv
                            MouseArea { id: clrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.history = []; root.save(); } }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.history
                            Rectangle {
                                id: sw
                                required property string modelData
                                width: 28; height: 28; radius: Theme.r(7)
                                color: modelData
                                border.width: Qt.colorEqual(root.picked, modelData) ? 2 : 1
                                border.color: Qt.colorEqual(root.picked, modelData) ? Theme.p : Theme.ov
                                scale: swMa.containsMouse ? 1.1 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                MouseArea {
                                    id: swMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: m => {
                                        if (m.button === Qt.RightButton) { root.history = root.history.filter(x => x !== sw.modelData); root.save(); return; }
                                        root.picked = sw.modelData; root.hasPick = true;
                                        root.copy(root.fmt(root.picked, root.format));
                                    }
                                }
                            }
                        }
                    }
                }
                Txt {
                    visible: !root.hasPick && !root.history.length && root.missing === ""
                    Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
                    text: "Aún no has elegido ningún color."
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Txt { Layout.fillWidth: true; text: root.toast; size: 11.5; color: Theme.p; elide: Text.ElideRight }
                    Btn { visible: root.missing === ""; kind: "primary"; icon: "drop"; text: "Elegir otro"; onClicked: root.startPick() }
                }
            }
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                const k = e.key, st = (e.modifiers & Qt.ShiftModifier) ? 10 : 1;
                if (k === Qt.Key_Escape) Shell.close();
                else if (root.stage === "elegir") {
                    if (k === Qt.Key_Left) root.px = Math.max(0, root.px - st);
                    else if (k === Qt.Key_Right) root.px = Math.min(win.width - 1, root.px + st);
                    else if (k === Qt.Key_Up) root.py = Math.max(0, root.py - st);
                    else if (k === Qt.Key_Down) root.py = Math.min(win.height - 1, root.py + st);
                    else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && root.ready) { root.choose(root.cur); e.accepted = true; return; }
                    else return;
                    root.sample();
                } else if (root.stage === "tarjeta") {
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) root.startPick();
                    else if (k >= Qt.Key_1 && k <= Qt.Key_4 && root.hasPick) { const f = root.formats[k - Qt.Key_1][0]; root.copy(root.fmt(root.picked, f)); root.setFormat(f); }
                    else return;
                } else return;
                e.accepted = true;
            }
        }
        onVisibleChanged: if (visible) Qt.callLater(() => keys.forceActiveFocus())
    }

    function sample(): void {
        if (!ready) return;
        const x = Math.max(0, Math.min(cv.width - 1, Math.floor(px))), y = Math.max(0, Math.min(cv.height - 1, Math.floor(py)));
        const d = cv.getContext("2d").getImageData(x, y, 1, 1).data;
        cur = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1);
    }
    Timer { id: toastTimer; interval: 2200; onTriggered: root.toast = "" }

    // IPC "color" (en modules/Modules.qml, siempre cargado; llama a estas funciones)
    function ipcPick(x: int, y: int): void { if (stage === "elegir" && ready) { px = x; py = y; sample(); choose(cur); } }
    function ipcCurrent(): string { return hasPick ? hex(picked) : ""; }
    function ipcState(): string { return stage + (ready ? " ready" : ""); }
    readonly property bool busyState: stage !== "off" || toast !== ""
}
