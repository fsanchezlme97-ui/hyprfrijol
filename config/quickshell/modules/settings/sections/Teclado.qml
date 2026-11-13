// Ajustes › Teclado y atajos — distribuciones xkb (evdev.lst), cambio de distribución, repetición, Bloq Num,
// Bloq Mayús como Escape (config/apply/input.py) y atajos reales de Hyprland (hyprctl binds), reasignables
// para las acciones de config/apply/keybind-actions.json (config/apply/keybinds.py).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../ui"
import "../ui/keys.js" as KeyNames

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)

    // ---------- datos ----------
    property var layouts: []          // [{ key: "latam", label }, { key: "us:intl", label }]
    property var actions: ({})
    property var binds: []
    readonly property var es: ({ es: "Español (España)", latam: "Español (Latinoamérica)", us: "English (US)", gb: "English (UK)",
        fr: "Français", de: "Deutsch", it: "Italiano", pt: "Português", br: "Português (Brasil)", "us:intl": "English (US, internacional)",
        "us:altgr-intl": "English (US, intl. con AltGr)", "es:cat": "Català", "es:dvorak": "Español (Dvorak)", "us:dvorak": "English (Dvorak)", "us:colemak": "English (Colemak)" })
    readonly property var kb: Settings.get("kbLayouts", ["latam", "us"])
    function label(k) { return es[k] ?? (layouts.find(l => l.key === k)?.label ?? k); }
    function code(k) { const p = k.split(":"); return p[0].toUpperCase().slice(0, 3); }
    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        printErrors: false
        onLoaded: {
            const out = []; let sec = "";
            for (const l of text().split("\n")) {
                if (l.startsWith("! ")) { sec = l.slice(2).trim(); continue; }
                const m = l.match(/^\s+(\S+)\s+(.+)$/); if (!m) continue;
                if (sec === "layout") out.push({ key: m[1], label: m[2] });
                else if (sec === "variant") { const v = m[2].match(/^(\S+):\s*(.+)$/); if (v) out.push({ key: v[1] + ":" + m[1], label: v[2] }); }
            }
            root.layouts = out.sort((a, b) => a.label.localeCompare(b.label));
        }
    }
    FileView {
        path: Paths.root + "/config/apply/keybind-actions.json"
        printErrors: false
        onLoaded: { try { root.actions = JSON.parse(text()); } catch (e) {} }
    }
    function modsOf(mask) {
        const m = [];
        if (mask & 64) m.push("SUPER"); if (mask & 4) m.push("CTRL"); if (mask & 8) m.push("ALT"); if (mask & 1) m.push("SHIFT");
        return m;
    }
    function keyOf(k) { k = String(k); return ({ Return: "RETURN", space: "SPACE", Escape: "ESCAPE", Print: "PRINT", Tab: "TAB" })[k] ?? (k.length === 1 ? k.toUpperCase() : k); }
    Process {
        id: bindsProc
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const seen = {};
                    root.binds = JSON.parse(text).filter(b => !b.mouse && b.key && !/^XF86/.test(b.key))
                        .map(b => ({ keys: root.modsOf(b.modmask).concat([root.keyOf(b.key)]).join(" + "), desc: b.description || "", disp: String(b.dispatcher).replace(/^HL\.Dispatcher\(|\)$/g, "") }))
                        .filter(b => { const k = b.keys + b.desc; if (seen[k]) return false; seen[k] = true; return true; })
                        .sort((a, b) => (b.desc !== "") - (a.desc !== ""));
                } catch (e) { root.binds = []; }
            }
        }
    }
    readonly property var overrides: Settings.get("keybinds", ({}))
    function rebind(desc, from, to) {
        const o = Object.assign({}, overrides);
        if (!to) delete o[desc];
        else {
            const clash = binds.find(b => b.keys === to && b.desc !== desc);
            if (clash) Quickshell.execDetached(["notify-send", "-a", "Ajustes", "Atajo en uso", to + " ya hacía «" + (clash.desc || clash.disp) + "». Ahora hará «" + desc + "»."]);
            o[desc] = { from: overrides[desc]?.from ?? from, to: to };
        }
        Settings.set("keybinds", o);
        refresh.restart();
    }
    Timer { id: refresh; interval: 1500; onTriggered: { bindsProc.running = false; bindsProc.running = true; } }

    // ---------- columna izquierda ----------
    ColumnLayout {
        id: left
        Layout.preferredWidth: 420
        Layout.maximumWidth: 420
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Distribuciones"
            Repeater {
                model: root.kb
                Item {
                    id: lay
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 48
                    Rectangle { width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        Rectangle { implicitWidth: 34; implicitHeight: 24; radius: Theme.r(4); color: Theme.s4; Txt { anchors.centerIn: parent; text: root.code(lay.modelData); size: 11; weight: Font.DemiBold } }
                        Txt { Layout.fillWidth: true; text: root.label(lay.modelData) }
                        Txt { visible: lay.index === 0; text: "Principal"; muted: true; size: 11.5 }
                        Button { visible: lay.index > 0; kind: "link"; text: "Hacer principal"; onClicked: Settings.set("kbLayouts", [lay.modelData].concat(root.kb.filter(x => x !== lay.modelData))) }
                        IconBtn { visible: root.kb.length > 1; icon: "x"; onClicked: Settings.set("kbLayouts", root.kb.filter(x => x !== lay.modelData)) }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
            Dropdown {
                Layout.fillWidth: true
                flat: true
                alignLeft: true
                placeholder: "+ Agregar distribución"
                model: root.layouts.filter(l => !root.kb.includes(l.key)).map(l => ({ key: l.key, label: (root.es[l.key] ? root.es[l.key] + " · " : "") + l.label }))
                searchable: true
                popupWidth: 360
                current: ""
                onPicked: k => Settings.set("kbLayouts", root.kb.concat([k]).slice(0, 4))
            }
            LabeledRow {
                label: "Cambiar de distribución"; labelWidth: 150
                Dropdown {
                    model: [["grp:ctrls_toggle", "Ambos Ctrl"], ["grp:alt_shift_toggle", "Alt + Mayús"], ["grp:win_space_toggle", "Super + Espacio"], ["grp:ctrl_shift_toggle", "Ctrl + Mayús"],
                            ["grp:caps_toggle", "Bloq Mayús"], ["grp:rctrl_toggle", "Ctrl derecho"], ["", "Ninguno"]]
                    current: Settings.get("kbSwitch", "grp:ctrls_toggle")
                    onPicked: k => Settings.set("kbSwitch", k)
                }
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Escritura"
            LabeledRow {
                label: "Retardo de repetición"; labelWidth: 120
                Seg { model: [[250, "Corto"], [400, "Medio"], [600, "Largo"]]; current: Settings.get("kbRepeatDelay", 400); onPicked: k => Settings.set("kbRepeatDelay", k) }
            }
            LabeledRow {
                label: "Velocidad"; labelWidth: 120
                Seg { model: [[25, "Lenta"], [35, "Normal"], [45, "Rápida"], [60, "Muy rápida"]]; current: Settings.get("kbRepeatRate", 35); onPicked: k => Settings.set("kbRepeatRate", k) }
            }
            RowLayout {
                Layout.fillWidth: true
                Txt { text: "Prueba aquí:"; muted: true; Layout.preferredWidth: 120 }
                Field { Layout.fillWidth: true; icon: "keyboard"; placeholder: "Mantén pulsada una tecla…"; h: 30 }
            }
            SwRow { label: "Bloq Num al iniciar"; sub: "input:numlock_by_default"; mono: true; key: "numlock"; def: true }
            SwRow { label: "Bloq Mayús como Escape"; sub: "input:kb_options = caps:escape"; mono: true; key: "capsEscape"; def: false }
            LinkRow { label: "Portapapeles"; value: "pegar al elegir, tamaño y caducidad"; section: "portapapeles"; sectionLabel: "Productividad"; target: "Guardar hasta" }
        }
    }

    // ---------- atajos ----------
    Section {
        id: right
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        title: "Atajos"
        headerRight: Field { id: q; width: 240; h: 30; placeholder: "Buscar acción o tecla…" }
        readonly property var list: root.binds.filter(b => {
            const s = q.text.trim().toLowerCase();
            return !s || (b.desc + " " + b.keys + " " + b.disp).toLowerCase().includes(s);
        })
        Repeater {
            model: right.list.slice(0, q.text ? 60 : 24)
            Item {
                id: br
                required property var modelData
                readonly property bool canChange: root.actions[modelData.desc] !== undefined
                Layout.fillWidth: true
                implicitHeight: 46
                Rectangle { width: parent.width; height: 1; color: Theme.ov }
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    Txt { Layout.fillWidth: true; text: br.modelData.desc || br.modelData.disp; color: br.modelData.desc ? Theme.t : Theme.tv }
                    KeyCapture {
                        visible: br.canChange
                        value: br.modelData.keys
                        onCaptured: k => root.rebind(br.modelData.desc, br.modelData.keys, k)
                    }
                    Row {
                        visible: !br.canChange
                        spacing: 4
                        Repeater {
                            model: br.modelData.keys.split(" + ")
                            Rectangle {
                                required property string modelData
                                width: kt.implicitWidth + 12; height: 22; radius: Theme.r(4)
                                color: "transparent"; border.width: 1; border.color: Theme.o
                                Txt { id: kt; anchors.centerIn: parent; text: KeyNames.label(parent.modelData); size: 11.5; weight: Font.Medium }
                            }
                        }
                    }
                    Txt {
                        Layout.preferredWidth: 60
                        horizontalAlignment: Text.AlignRight
                        text: root.overrides[br.modelData.desc] ? "Restaurar" : br.canChange ? "Cambiar" : ""
                        muted: true; size: 12
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.overrides[br.modelData.desc]) root.rebind(br.modelData.desc, "", "")
                        }
                    }
                }
            }
        }
        Txt { visible: right.list.length === 0; muted: true; text: root.binds.length ? "Ningún atajo coincide" : "No se pudieron leer los atajos (hyprctl binds)" }
        Mono { tech: true;
            Layout.fillWidth: true
            text: right.list.length > 24 && !q.text ? (right.list.length - 24) + " más · busca para verlos · se guarda como hl.bind (config/apply/keybinds.py)" : "Se guarda como hl.unbind + hl.bind (config/apply/keybinds.py) · avisa si una tecla ya está en uso"
        }
    }
}
