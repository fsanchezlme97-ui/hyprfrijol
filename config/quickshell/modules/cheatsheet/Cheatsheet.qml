// Chuleta de atajos (vista "atajos", Super + / y Super + ').
// Lee `hyprctl binds -j` cada vez que se abre: muestra todos los atajos con descripción, agrupados
// (Aplicaciones, Shell, Ventanas, Espacios, Captura, Multimedia, Sesión…), con las teclas como en el teclado español.
// Escribe para filtrar · Esc cerrar. Los atajos se cambian en Ajustes › Teclado y atajos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"

Overlay {
    id: win
    view: "atajos"
    morphs: true                // se transforma desde/hacia el panel que estaba abierto (components/Morph)
    place: "center"
    panelWidth: 1000
    panelHeight: 640

    property var binds: []        // [{ keys: [["Super","E"], …], desc }]
    property string query: ""

    // ── Teclas legibles ──────────────────────────────────────────────────
    readonly property var keyNames: ({
        "RETURN": "Intro", "SPACE": "Espacio", "TAB": "Tab", "ESCAPE": "Esc", "PRINT": "Impr Pant", "BACKSPACE": "Retroceso",
        "DELETE": "Supr", "INSERT": "Insert", "HOME": "Inicio", "END": "Fin", "PAGE_UP": "RePág", "PAGE_DOWN": "AvPág",
        "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓", "PERIOD": ".", "COMMA": ",", "SLASH": "/", "BACKSLASH": "\\",
        "MINUS": "-", "EQUAL": "=", "SEMICOLON": ";", "APOSTROPHE": "'", "GRAVE": "º", "BRACKETLEFT": "`", "BRACKETRIGHT": "+",
        "MOUSE:272": "Clic izquierdo", "MOUSE:273": "Clic derecho", "MOUSE:274": "Clic central", "MOUSE:275": "Botón atrás",
        "MOUSE:276": "Botón adelante", "MOUSE_DOWN": "Rueda ↓", "MOUSE_UP": "Rueda ↑",
        "XF86AUDIORAISEVOLUME": "Vol +", "XF86AUDIOLOWERVOLUME": "Vol −", "XF86AUDIOMUTE": "Silencio", "XF86AUDIOMICMUTE": "Micro",
        "XF86AUDIOPLAY": "▶", "XF86AUDIOPAUSE": "❚❚", "XF86AUDIONEXT": "▶▶", "XF86AUDIOPREV": "◀◀",
        "XF86MONBRIGHTNESSUP": "Brillo +", "XF86MONBRIGHTNESSDOWN": "Brillo −"
    })
    // Teclas por código físico (teclado español)
    readonly property var codeNames: ({ 20: "'", 21: "¡", 47: "ñ", 48: "´", 49: "º", 51: "ç", 34: "`", 35: "+", 59: ",", 60: ".", 61: "-", 94: "<" })

    function keysOf(b): var {
        const k = [];
        const m = b.modmask;
        if (m & 64) k.push("Super");
        if (m & 4) k.push("Ctrl");
        if (m & 8) k.push("Alt");
        if (m & 1) k.push("Mayús");
        let key = b.key || "";
        if (!key && b.keycode) key = codeNames[b.keycode] ?? ("código " + b.keycode);
        else if (/^code:\d+$/.test(key)) key = codeNames[+key.slice(5)] ?? key;
        else key = keyNames[key.toUpperCase()] ?? (key.length === 1 ? key.toUpperCase() : key);
        if (key) k.push(key);
        return k;
    }

    // ── Categorías (por el texto de la descripción) ───────────────────────
    readonly property var categories: [
        ["voz", "Voz y asistente", /dictado|voz|hablar con|asistente/i],
        ["apps", "Aplicaciones", /terminal|archivos|navegador|editor|ofim|mezclador|administrador de tareas|hypr ajustes/i],
        ["captura", "Captura y pantalla", /captura|recortar|zona|ocr|traducir|color|grabar|lupa|zoom/i],
        ["multimedia", "Multimedia", /silenciar|pista|reproducir|volumen|brillo|micr/i],
        ["espacios", "Espacios de trabajo", /espacio|scratchpad/i],
        ["ventanas", "Ventanas", /ventana|columna|maximizar|pantalla completa|flotante|fijar|divisi|mitad|restaurar|mover|foco|tamaño|proporci|cerrar|forzar/i],
        ["sesion", "Sesión", /bloquear|suspender|energ|salir|apagar|reiniciar el equipo/i],
        ["shell", "Shell y paneles", /./]
    ]
    function categoryOf(desc: string): string {
        for (const c of categories) if (c[2].test(desc)) return c[0];
        return "shell";
    }

    // Secciones visibles (filtradas) repartidas en 3 columnas equilibradas
    readonly property var columns: {
        const q = query.trim().toLowerCase();
        const by = {};
        for (const b of binds) {
            if (q && !(b.desc.toLowerCase().includes(q) || b.keys.map(k => k.join(" ")).join(" ").toLowerCase().includes(q))) continue;
            const c = categoryOf(b.desc);
            (by[c] = by[c] ?? []).push(b);
        }
        const order = ["shell", "apps", "ventanas", "espacios", "captura", "multimedia", "sesion"];
        const cols = [[], [], []], load = [0, 0, 0];
        for (const id of order) {
            if (!by[id]) continue;
            const title = categories.find(c => c[0] === id)[1];
            const i = load.indexOf(Math.min(...load));
            cols[i].push({ title: title, items: by[id] });
            load[i] += by[id].length + 2;
        }
        return cols;
    }

    function load(json: string): void {
        let arr = [];
        try { arr = JSON.parse(json); } catch (e) { return; }
        const merged = [], byDesc = {};
        let ws = false, wsMove = false;
        for (const b of arr) {
            if (b.submap) continue;
            if (!b.has_description || !b.description) {
                if (/^[1-9]$/.test(b.key) && b.modmask === 64) ws = true;
                if (/^[1-9]$/.test(b.key) && b.modmask === 65) wsMove = true;
                continue;
            }
            const keys = keysOf(b);
            if (byDesc[b.description]) {
                const prev = byDesc[b.description];
                if (!prev.keys.some(k => k.join("+") === keys.join("+"))) prev.keys.push(keys);
                continue;
            }
            const item = { desc: b.description, keys: [keys] };
            byDesc[b.description] = item;
            merged.push(item);
        }
        if (ws) merged.push({ desc: "Ir al espacio 1…9", keys: [["Super", "1…9"]] });
        if (wsMove) merged.push({ desc: "Mover la ventana al espacio 1…9", keys: [["Super", "Mayús", "1…9"]] });
        binds = merged;
    }

    onShownChanged: if (shown) {
        search.text = ""; query = "";
        reader.running = false; reader.running = true;
        Qt.callLater(() => search.focusInput());
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: win.load(text) }
    }

    component KeyCap: Rectangle {
        property string label: ""
        implicitWidth: Math.max(20, capTxt.implicitWidth + 10)
        implicitHeight: 20
        radius: Theme.r(5)
        color: Theme.fill2
        border.width: 1
        border.color: Theme.border
        Txt { id: capTxt; anchors.centerIn: parent; text: parent.label; size: 10.5; weight: Font.Medium }
    }

    Glass {
        anchors.fill: parent
        kind: "popup"

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon { name: "keyboard"; size: 17; color: Theme.p }
                ColumnLayout {
                    spacing: 0
                    Txt { text: "Atajos de teclado"; size: 14; weight: Font.DemiBold }
                    Txt { text: win.binds.length + " atajos · se leen de Hyprland al abrir"; size: 11; muted: true }
                }
                Item { Layout.fillWidth: true }
                Field {
                    id: search
                    Layout.preferredWidth: 280
                    h: 32
                    placeholder: "Filtrar… (captura, ventana, Mayús)"
                    onTextChanged: win.query = text
                    onKeyPressed: e => { if (e.key === Qt.Key_Escape) { Shell.close(); e.accepted = true; } }
                }
                IconBtn { icon: "x"; onClicked: Shell.close() }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: colsRow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: colsRow
                    width: flick.width
                    spacing: 18
                    Repeater {
                        model: win.columns
                        ColumnLayout {
                            id: column
                            required property var modelData
                            Layout.preferredWidth: (colsRow.width - 36) / 3
                            Layout.alignment: Qt.AlignTop
                            spacing: 14
                            Repeater {
                                model: column.modelData
                                ColumnLayout {
                                    id: section
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Txt { text: section.modelData.title; size: 11; weight: Font.DemiBold; color: Theme.p; bottomPadding: 4 }
                                    Repeater {
                                        model: section.modelData.items
                                        RowLayout {
                                            id: line
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 26
                                            spacing: 8
                                            Txt { Layout.fillWidth: true; text: line.modelData.desc; size: 12 }
                                            Row {
                                                spacing: 4
                                                Repeater {
                                                    model: line.modelData.keys.slice(0, 2)
                                                    Row {
                                                        id: combo
                                                        required property var modelData
                                                        required property int index
                                                        spacing: 3
                                                        Txt { visible: combo.index > 0; text: "o"; size: 10.5; muted: true; height: 20 }
                                                        Repeater {
                                                            model: combo.modelData
                                                            KeyCap { required property string modelData; label: modelData }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Txt {
                visible: win.query !== "" && win.columns.every(c => c.length === 0)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Ningún atajo coincide con «" + win.query + "»"
                muted: true
            }

            RowLayout {
                Layout.fillWidth: true
                Txt { Layout.fillWidth: true; text: "Super + / o Super + ' para abrir esta chuleta · Esc cerrar"; size: 11; muted: true }
                Btn {
                    text: "Cambiar atajos…"
                    onClicked: Shell.open("ajustesapp", "teclado")
                }
            }
        }
    }
}
