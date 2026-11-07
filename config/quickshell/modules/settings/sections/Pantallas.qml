// Ajustes › Pantallas — disposición (arrastra los monitores), resolución, frecuencia, escala, giro (transform),
// pantalla principal (primaryMonitor → espacio 1), identificar, VRR, HDR y duplicar
// (Settings "monitors" → config/apply/monitors.py → hl.monitor; además se aplica al instante con hyprctl eval),
// y luz nocturna (Daemons.qml · hyprsunset, con vista previa al arrastrar la temperatura); el amanecer y el
// atardecer salen de services/Sun.qml (los comparte con el tema automático de Apariencia).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    property var mons: []
    property string selName: ""
    readonly property var sel: mons.find(m => m.name === selName) ?? mons.find(m => !m.disabled) ?? mons[0] ?? null
    readonly property var cfg: Settings.get("monitors", ({}))
    readonly property var mcfg: sel ? (cfg[sel.name] ?? {}) : {}
    property bool identifying: false

    function load() { mp.running = false; mp.running = true; }
    Process {
        id: mp
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.mons = JSON.parse(text).filter(m => m.name !== "HF-TRY" || true); } catch (e) {} } }
    }
    Timer { id: reload; interval: 1200; onTriggered: root.load() }

    // modos únicos "WxH" → [frecuencias]
    readonly property var modes: {
        const o = {};
        (sel?.availableModes ?? []).forEach(s => { const m = s.match(/^(\d+x\d+)@([\d.]+)Hz$/); if (!m) return; (o[m[1]] = o[m[1]] ?? []).includes(m[2]) || o[m[1]].push(m[2]); });
        return o;
    }
    readonly property string curRes: sel ? sel.width + "x" + sel.height : ""
    readonly property string curRate: sel ? Number(sel.refreshRate).toFixed(2) : ""
    // tamaño lógico (girada 90°/270° intercambia ancho y alto)
    function lw(m) { return (m.transform % 2 ? m.height : m.width) / m.scale; }
    function lh(m) { return (m.transform % 2 ? m.width : m.height) / m.scale; }
    readonly property string primary: Settings.get("primaryMonitor", "") || (mons.find(m => !m.disabled)?.name ?? "")
    function monLua(name, cur) {
        return cur.disabled ? "hl.monitor({ output = \"" + name + "\", disabled = true })" : "hl.monitor({ output = \"" + name + "\", mode = \"" + cur.mode + "\", position = \"" + cur.position + "\", scale = " + cur.scale
            + (cur.transform ? ", transform = " + cur.transform : "") + (cur.vrr ? ", vrr = 1" : "") + (cur.hdr ? ", cm = \"hdr\", bitdepth = 10" : "") + (cur.mirror ? ", mirror = \"" + cur.mirror + "\"" : "") + " })";
    }
    // what: si se da, el cambio es arriesgado (resolución, frecuencia, escala, giro…) → «¿Se ve bien?» de
    // services/Confirm.qml: sin «Mantener» en 15 s vuelve a la configuración de antes (también al momento con hyprctl)
    function setMon(patch, what) {
        if (!sel) return;
        const all = Object.assign({}, cfg);
        const live = { mode: curRes + "@" + curRate, position: sel.x + "x" + sel.y, scale: sel.scale, transform: sel.transform ?? 0 };
        const cur = Object.assign({}, live, all[sel.name] ?? {}, patch);
        const before = Object.assign({}, all[sel.name] ?? {}, live, { disabled: !!sel.disabled });
        all[sel.name] = cur;
        if (what) Confirm.change(what + " de " + sel.name, { monitors: all }, { undo: [["hyprctl", "eval", monLua(sel.name, before)]] });
        else Settings.set("monitors", all);
        Quickshell.execDetached(["hyprctl", "eval", monLua(sel.name, cur)]);
        reload.restart();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.3
            Layout.alignment: Qt.AlignTop
            title: "Disposición"
            headerRight: Row {
                spacing: 6
                Button { text: "Identificar"; onClicked: { root.identifying = true; idTimer.restart(); } }
                Button { text: "Detectar"; onClicked: root.load() }
            }
            Rectangle {
                id: canvas
                Layout.fillWidth: true
                implicitHeight: 200
                radius: Theme.r(6)
                color: Theme.bg
                clip: true
                readonly property var bounds: {
                    const ms = root.mons.filter(m => !m.disabled);
                    if (!ms.length) return { x: 0, y: 0, w: 1920, h: 1080 };
                    const x0 = Math.min(...ms.map(m => m.x)), y0 = Math.min(...ms.map(m => m.y));
                    const x1 = Math.max(...ms.map(m => m.x + root.lw(m))), y1 = Math.max(...ms.map(m => m.y + root.lh(m)));
                    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
                }
                readonly property real k: Math.min((width - 40) / bounds.w, (height - 40) / bounds.h)
                readonly property real ox: (width - bounds.w * k) / 2
                readonly property real oy: (height - bounds.h * k) / 2
                Repeater {
                    model: root.mons.filter(m => !m.disabled)
                    Rectangle {
                        id: mon
                        required property var modelData
                        required property int index
                        readonly property bool on: root.sel?.name === modelData.name
                        x: canvas.ox + (modelData.x - canvas.bounds.x) * canvas.k
                        y: canvas.oy + (modelData.y - canvas.bounds.y) * canvas.k
                        width: root.lw(modelData) * canvas.k
                        height: root.lh(modelData) * canvas.k
                        radius: Theme.r(4)
                        color: on ? Theme.pc : Theme.s4
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.p : Theme.o
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            Txt { Layout.alignment: Qt.AlignHCenter; text: String(mon.index + 1); size: 20; weight: Font.DemiBold; color: mon.on ? Theme.pcText : Theme.t }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: mon.modelData.name + (root.mons.length > 1 && root.primary === mon.modelData.name ? " · principal" : ""); size: 11; color: mon.on ? Theme.pcText : Theme.tv }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            drag.target: root.mons.length > 1 ? mon : null
                            onPressed: root.selName = mon.modelData.name
                            onReleased: {
                                if (root.mons.length < 2) return;
                                // posición real (ajustada a los bordes del resto)
                                let nx = Math.round((mon.x - canvas.ox) / canvas.k + canvas.bounds.x), ny = Math.round((mon.y - canvas.oy) / canvas.k + canvas.bounds.y);
                                root.mons.filter(m => m.name !== mon.modelData.name).forEach(o => {
                                    const ow = root.lw(o), oh = root.lh(o), w = root.lw(mon.modelData), h = root.lh(mon.modelData);
                                    [[o.x + ow, "x"], [o.x - w, "x"], [o.x, "x"], [o.y + oh, "y"], [o.y - h, "y"], [o.y, "y"]].forEach(([v, a]) => {
                                        if (a === "x" && Math.abs(nx - v) < 120) nx = v;
                                        if (a === "y" && Math.abs(ny - v) < 120) ny = v;
                                    });
                                });
                                root.setMon({ position: Math.round(nx) + "x" + Math.round(ny) });
                            }
                        }
                    }
                }
            }
            Flow {
                visible: root.mons.length > 1
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.mons
                    Chip { required property var modelData; mark: false; h: 26; text: modelData.name + (modelData.disabled ? " (apagada)" : ""); on: root.sel?.name === modelData.name; onClicked: root.selName = modelData.name }
                }
            }
            Mono {
                Layout.fillWidth: true
                text: root.sel ? "hl.monitor{ " + root.sel.name + ", " + root.curRes + "@" + Math.round(root.sel.refreshRate) + ", " + root.sel.x + "x" + root.sel.y + ", " + root.sel.scale + " }" : "sin monitores"
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: root.sel ? root.sel.name : "Monitor"
            headerRight: Txt { text: root.sel?.description?.split(" ").slice(0, 3).join(" ") ?? ""; muted: true; size: 11 }
            LabeledRow {
                label: "Resolución"; labelWidth: 90
                Dropdown {
                    model: Object.keys(root.modes).map(r => [r, r.replace("x", " × ") + (r === Object.keys(root.modes)[0] ? " (recomendada)" : "")])
                    current: root.curRes
                    placeholder: root.curRes
                    onPicked: k => root.setMon({ mode: k + "@" + root.modes[k][0] }, "Resolución")
                }
            }
            LabeledRow {
                visible: (root.modes[root.curRes] ?? []).length === 0
                label: "Frecuencia"; labelWidth: 90
                Txt { text: Math.round(root.sel?.refreshRate ?? 0) + " Hz"; weight: Font.Medium }
            }
            LabeledRow {
                visible: (root.modes[root.curRes] ?? []).length > 0
                label: "Frecuencia"; labelWidth: 90
                Seg {
                    model: (root.modes[root.curRes] ?? []).slice(0, 4).map(r => [r, Math.round(parseFloat(r)) + " Hz"])
                    current: (root.modes[root.curRes] ?? []).find(r => Math.abs(parseFloat(r) - parseFloat(root.curRate)) < 0.05) ?? ""
                    onPicked: k => root.setMon({ mode: root.curRes + "@" + k }, "Frecuencia")
                }
            }
            LabeledRow {
                label: "Escala"; labelWidth: 90
                Pills { model: [[1, "100 %"], [1.25, "125 %"], [1.5, "150 %"], [1.75, "175 %"], [2, "200 %"]]; current: root.sel?.scale ?? 1; onPicked: v => root.setMon({ scale: v }, "Escala") }
            }
            LabeledRow {
                label: "Orientación"; labelWidth: 90
                Seg {
                    model: [[0, "Normal"], [1, "90°"], [2, "180°"], [3, "270°"]]
                    current: (root.sel?.transform ?? 0) % 4
                    onPicked: k => { if (k !== (root.sel?.transform ?? 0) % 4) root.setMon({ transform: k }, "Orientación"); }
                }
            }
            SwRow {
                visible: root.mons.length > 1
                label: "Pantalla principal"; sub: "el espacio 1 se abre en ella"
                checked: root.primary === root.sel?.name
                enabled: !(root.sel?.disabled ?? false)
                onToggled: v => { if (v && root.sel) Settings.set("primaryMonitor", root.sel.name); }
            }
            SwRow {
                visible: root.mons.length > 1
                label: "Pantalla activada"; sub: root.sel?.disabled ? "apagada · actívala para usarla" : "desactívala para usar solo las demás"
                checked: !(root.sel?.disabled ?? false)
                onToggled: v => root.setMon({ disabled: !v }, v ? "Pantalla activada" : "Pantalla desactivada")
            }
            SwRow { label: "Frecuencia variable (VRR)"; sub: "misc:vrr · menos tirones en juegos"; mono: true; checked: !!root.mcfg.vrr || !!root.sel?.vrr; onToggled: v => root.setMon({ vrr: v }) }
            SwRow { label: "HDR"; sub: "cm = hdr · bitdepth = 10 (experimental)"; mono: true; checked: !!root.mcfg.hdr; onToggled: v => root.setMon({ hdr: v }) }
            SwRow {
                label: "Duplicar pantalla"; sub: root.mons.length > 1 ? "muestra lo mismo que " + (root.mons.find(m => m.name !== root.sel?.name)?.name ?? "") : "conecta otra pantalla"
                enabled: root.mons.length > 1
                checked: !!root.mcfg.mirror
                onToggled: v => root.setMon({ mirror: v ? root.mons.find(m => m.name !== root.sel?.name)?.name ?? "" : "" })
            }
        }
    }
    // ---------- luz nocturna ----------
    // Vista previa: mientras se arrastra la temperatura se aplica con hyprsunset; al soltar se guarda
    // nightTemp y se vuelve a como estaba (apagada si no estaba encendida).
    property int nlPreview: 0
    property bool nlWasOn: false
    Process {
        id: nlProbe
        command: [Paths.script("hf-sunset"), "status"]
        onExited: code => root.nlWasOn = code === 0
    }
    Timer {
        id: nlPush
        interval: 120
        onTriggered: {
            if (root.nlPreview <= 0) return;
            if (nlProbe.running) { restart(); return; }
            const t = String(root.nlPreview);
            Quickshell.execDetached([Paths.script("hf-sunset"), "set", String(root.nlPreview)]);
        }
    }
    function previewTemp(t: int): void {
        if (root.nlPreview === 0) { nlProbe.running = false; nlProbe.running = true; }
        root.nlPreview = t;
        if (!nlPush.running) nlPush.start();
    }
    function endPreview(): void {
        if (root.nlPreview === 0) return;
        const t = root.nlPreview;
        root.nlPreview = 0;
        nlPush.stop();
        Quickshell.execDetached(["sh", "-c", 'sleep 0.15; exec "$0" "$@"', Paths.script("hf-sunset")].concat(root.nlWasOn ? ["set", String(t)] : ["off"]));
        Settings.set("nightTemp", t);
    }
    Component.onDestruction: endPreview()

    Section {
        Layout.fillWidth: true
        title: "Luz nocturna"
        headerRight: Mono { text: "hyprsunset · nightLight" }
        readonly property string nl: Settings.get("nightLight", "off")
        Seg {
            Layout.fillWidth: true
            model: [["atardecer", "Del atardecer al amanecer"], ["horario", "Horario propio"], ["off", "Desactivada"]]
            current: Settings.get("nightLight", "off")
            onPicked: k => Settings.set("nightLight", k)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Txt { text: "Temperatura"; muted: true; Layout.preferredWidth: Math.max(90, implicitWidth) }
            Txt { text: "fría"; muted: true; size: 11.5 }
            SliderBar {
                id: tempSlider
                Layout.fillWidth: true
                icon: "moon"
                from: 6500; to: 2500           // a la derecha, más cálida
                value: root.nlPreview > 0 ? root.nlPreview : Settings.get("nightTemp", 4000)
                onMoved: v => {
                    const t = Math.max(2500, Math.min(6500, Math.round(v / 100) * 100));
                    if (dragging) root.previewTemp(t);
                    else Settings.set("nightTemp", t);       // rueda: sin vista previa
                }
                onReleased: root.endPreview()
            }
            Txt { text: "cálida"; muted: true; size: 11.5 }
            Rectangle {
                // color aproximado de la temperatura
                readonly property real k: (Math.max(2500, Math.min(6500, tempSlider.value)) - 2500) / 4000
                implicitWidth: 22; implicitHeight: 22; radius: 11
                color: Qt.rgba(1, 0.70 + 0.27 * k, 0.42 + 0.53 * k, 1)
                border.width: 1; border.color: Theme.ov
            }
            Txt { Layout.preferredWidth: 64; text: tempSlider.value + " K"; weight: Font.DemiBold; tabular: true; horizontalAlignment: Text.AlignRight }
        }
        Txt {
            Layout.fillWidth: true; Layout.leftMargin: 100
            muted: true; size: 11.5
            text: root.nlPreview > 0 ? "Vista previa · suelta para guardar" : "Arrastra para ver el tono en la pantalla al momento"
        }
        RowLayout {
            id: nlRow
            visible: Settings.get("nightLight", "off") === "horario"
            Layout.fillWidth: true
            spacing: 10
            readonly property var hours: Array.from({ length: 48 }, (_, i) => { const s = String(Math.floor(i / 2)).padStart(2, "0") + ":" + (i % 2 ? "30" : "00"); return [s, s]; })
            Txt { text: "Desde"; muted: true; Layout.preferredWidth: Math.max(90, implicitWidth) }
            Dropdown { Layout.preferredWidth: 90; model: nlRow.hours; current: Settings.get("nightFrom", "22:00"); onPicked: k => Settings.set("nightFrom", k) }
            Txt { text: "hasta"; muted: true }
            Dropdown { Layout.preferredWidth: 90; model: nlRow.hours; current: Settings.get("nightTo", "07:00"); onPicked: k => Settings.set("nightTo", k) }
            Item { Layout.fillWidth: true }
        }
        // Amanecer y atardecer: una sola fuente (services/Sun.qml) para la luz nocturna y el tema automático
        ColumnLayout {
            id: sunBox
            readonly property bool used: Settings.get("nightLight", "off") === "atardecer"
                || (Settings.get("themeMode", "oscuro") === "auto" && Settings.get("themeSchedule", "horas") === "sol")
            visible: used
            Layout.fillWidth: true
            spacing: 6
            SwRow {
                label: "Calcular la salida y la puesta del sol"
                sub: !sunBox.used ? "" : !Sun.auto ? "a mano: elige las horas abajo"
                    : Sun.computed ? "Hoy en " + Sun.where + ": amanece a las " + Sun.sunrise + " y anochece a las " + Sun.sunset
                    : "Sin ubicación todavía · pon tu ciudad en Escritorio o permite la ubicación por IP en Privacidad"
                key: "sunAuto"; def: true
            }
            RowLayout {
                id: sunRow
                visible: !sunBox.used ? false : !Sun.computed
                Layout.fillWidth: true
                spacing: 10
                Txt { text: "Atardecer"; muted: true; Layout.preferredWidth: Math.max(90, implicitWidth) }
                Dropdown { Layout.preferredWidth: 90; model: nlRow.hours; current: Settings.get("sunset", "19:00"); onPicked: k => Settings.set("sunset", k) }
                Txt { text: "amanecer"; muted: true }
                Dropdown { Layout.preferredWidth: 90; model: nlRow.hours; current: Settings.get("sunrise", "07:00"); onPicked: k => Settings.set("sunrise", k) }
                Item { Layout.fillWidth: true }
            }
        }
        LinkRow {
            label: "Tema claro y oscuro automático"; section: "apariencia"; sectionLabel: "Apariencia"; target: "Modo"
            value: Settings.get("themeMode", "oscuro") !== "auto" ? "Desactivado"
                : Settings.get("themeSchedule", "horas") === "sol" ? "Según el sol"
                : "Claro de " + Settings.get("lightFrom", 7) + ":00 a " + Settings.get("lightTo", 19) + ":00"
        }
        LinkRow { label: "Tamaño del texto"; section: "apariencia"; sectionLabel: "Apariencia"; target: "Tamaño del texto"; value: Settings.get("fontScale", 1) === 1 ? "Normal" : "×" + String(Settings.get("fontScale", 1)).replace(".", ",") }
    }

    // Identificar: número grande en cada pantalla
    Timer { id: idTimer; interval: 3000; onTriggered: root.identifying = false }
    Variants {
        model: root.identifying ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            implicitWidth: 200; implicitHeight: 160
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hf-identify"
            Rectangle {
                anchors.fill: parent
                radius: Theme.r(14)
                color: Theme.p
                Column {
                    anchors.centerIn: parent
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.mons.findIndex(m => m.name === modelData.name) + 1); size: 56; weight: Font.Bold; color: Theme.pText }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: Theme.pText }
                }
            }
        }
    }
}
