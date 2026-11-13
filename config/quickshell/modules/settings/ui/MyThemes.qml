// Ajustes › Apariencia › Mis temas: los temas propios (scripts/hf-theme; pares oscuro + claro con group "propio"
// en ~/.config/hyprfrijol/palettes-user.json, que Apariencia ya lee como userPals) y el creador: códigos hex o una
// imagen (paleta con los códigos escritos → tesseract; foto → matugen) → vista previa oscura y clara con el
// contraste ya corregido → Guardar o Descartar. Cada tema se exporta a Descargas y se importa desde un .json.
// La vista previa es la barra y el centro de control con esos colores (ThemeMockup), en oscuro y en claro.
// «Editar colores» cambia cada papel (fondo, acento, texto…) a mano; cada cambio pasa por `hf-theme check` (contraste
// corregido y sus notas) y lo que se ve es lo que se guarda. «Editar» en un tema guardado lo abre aquí; si se guarda
// con otro nombre, sustituye al anterior ("replace").
//   MyThemes { pals: root.pals; current: root.paletteKey; themeMode: root.themeMode; onPicked: (k, mode) => … }
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"

Section {
    id: root
    title: "Mis temas"
    property var pals: ({})
    property string current: ""
    property string themeMode: "oscuro"
    signal picked(string key, string mode)
    readonly property var own: Object.keys(pals).filter(k => pals[k].group === "propio" && !pals[k].variant)

    property var preview: null       // salida de «hf-theme make»
    property string msg: ""
    property bool msgErr: false
    property string image: ""
    property string editingKey: ""   // tema guardado que se está editando ("" = uno nuevo)
    property bool editColors: false
    property string editSide: "dark"
    readonly property var roles: [
        ["bg", "Fondo"], ["s1", "Superficie"], ["s3", "Tarjetas"], ["s4", "Controles"],
        ["p", "Acento"], ["onP", "Texto sobre el acento"], ["pc", "Botones"], ["onPc", "Texto de los botones"],
        ["sc", "Selección"], ["onSc", "Texto de la selección"], ["ter", "Terciario"],
        ["t", "Texto"], ["tv", "Texto secundario"], ["o", "Bordes"], ["ov", "Separadores"]
    ]
    // Un color cambiado a mano: se pinta ya y, medio segundo después, `hf-theme check` corrige el contraste
    function setRole(side, k, hex) {
        if (!preview || !/^#[0-9A-Fa-f]{6}$/.test(hex)) return;
        const p = Object.assign({}, preview);
        p[side] = Object.assign({}, p[side], { [k]: hex.toUpperCase() });
        preview = p;
        checkT.restart();
    }
    Timer {
        id: checkT
        interval: 500
        onTriggered: {
            checker.command = ["sh", "-c", 'printf "%s" "$1" | "$2" check -', "sh", JSON.stringify(root.preview), Paths.script("hf-theme")];
            checker.running = true;
        }
    }
    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.error) { root.say(j.error, true); return; }
                    root.preview = Object.assign({}, root.preview, { dark: j.dark, light: j.light, notes: j.notes, minContrast: j.minContrast });
                } catch (e) {}
            }
        }
    }
    function editSaved(k) {
        const d = pals[k], l = pals[d?.pair] ?? {};
        if (!d) return;
        const pick = o => { const r = {}; for (const [key] of roles) if (o[key]) r[key] = o[key]; return r; };
        preview = { key: k, name: d.name, origen: d.origen || "hex", dark: Object.assign(pick(d), { light: false }),
                    light: Object.assign(pick(l), { light: true }), notes: [], minContrast: 0 };
        editingKey = k;
        nameField.text = d.name ?? "";
        editColors = true;
        say("");
        checkT.restart();
    }

    function run(args, onDone) { job.onDone = onDone; job.command = [Paths.script("hf-theme")].concat(args); job.running = true; }
    function say(t, err) { msg = t; msgErr = !!err; }
    Process {
        id: job
        property var onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null;
                try { j = JSON.parse(text); } catch (e) { root.say("No se pudo leer la respuesta de hf-theme.", true); return; }
                if (j && j.error) { root.say(j.error, true); return; }
                if (job.onDone) job.onDone(j);
            }
        }
    }
    Process {
        id: picker
        property string mode: "image"
        command: [Paths.script("hf-pickfile"), "--title", mode === "image" ? "Imagen para el tema" : "Tema de HyprFrijol",
                  "--filter", mode === "image" ? "Imágenes|*.png *.jpg *.jpeg *.webp" : "Temas|*.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (!f) return;
                if (picker.mode === "image") { root.image = f; root.make(); }
                else root.run(["import", f], j => root.say("Importado" + (j.notes?.length ? ": " + j.notes.join(" · ") : ".")));
            }
        }
    }
    function make() {
        say("Creando…");
        const a = ["make"];
        if (nameField.text.trim()) a.push("--name", nameField.text.trim());
        if (image) a.push("--image", image); else a.push("--hex", hexField.text);
        run(a, j => { preview = j; editingKey = ""; say(""); });
    }

    headerRight: RowLayout {
        spacing: 12
        Button { kind: "link"; text: "Importar…"; onClicked: { picker.mode = "json"; picker.running = true; } }
        Mono { text: root.own.length + (root.own.length === 1 ? " tema" : " temas") }
    }

    // Los guardados
    Flow {
        visible: root.own.length > 0
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: root.own
            ColumnLayout {
                id: mt
                required property string modelData
                width: 178
                spacing: 4
                PaletteCard {
                    Layout.fillWidth: true
                    key: mt.modelData
                    pals: root.pals
                    current: root.current
                    themeMode: root.themeMode
                    onPicked: (k, mode) => root.picked(k, mode)
                }
                RowLayout {
                    spacing: 12
                    Button {
                        kind: "link"; text: "Editar"
                        onClicked: root.editSaved(mt.modelData)
                    }
                    Button {
                        kind: "link"; text: "Exportar"
                        onClicked: root.run(["export", mt.modelData],
                                            j => root.say("Guardado en " + j.file))
                    }
                    Button {
                        kind: "link"; text: "Borrar"
                        onClicked: root.run(["remove", mt.modelData], () => root.say("Tema borrado."))
                    }
                }
            }
        }
    }

    // Crear
    Txt {
        Layout.fillWidth: true
        text: "Crea un tema con tus colores: pega de 1 a 8 códigos (#RRGGBB) o elige una imagen. Una paleta con los códigos escritos "
            + "se lee tal cual; de una foto se sacan sus colores. Sale en oscuro y en claro, con el contraste corregido para que todo se lea."
        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field { id: nameField; Layout.preferredWidth: 180; h: 30; icon: ""; placeholder: "Nombre"; input.maximumLength: 40 }
        Field {
            id: hexField
            Layout.fillWidth: true; h: 30; icon: "palette"
            placeholder: root.image ? root.image.split("/").pop() : "#1E1219 #CEB2BD #D9B8A6"
            onTextChanged: if (text) root.image = ""
            onAccepted: root.make()
        }
        Button { text: "Imagen…"; onClicked: { picker.mode = "image"; picker.running = true; } }
        Button { kind: "primary"; text: "Crear"; enabled: !job.running && (root.image !== "" || /#?[0-9A-Fa-f]{6}/.test(hexField.text)); onClicked: root.make() }
    }

    // Vista previa
    ColumnLayout {
        visible: root.preview !== null
        Layout.fillWidth: true
        spacing: 8
        Txt {
            visible: root.editingKey !== ""
            text: "Editando «" + (root.preview?.name ?? "") + "»"
            weight: Font.DemiBold
        }
        Flow {
            Layout.fillWidth: true
            spacing: 12
            ThemeMockup { width: 300; pal: root.preview?.dark ?? {}; label: "Oscuro" }
            ThemeMockup { width: 300; pal: root.preview?.light ?? {}; label: "Claro" }
        }
        // Editar colores: cada papel con su muestra y su código
        ColumnLayout {
            visible: root.editColors
            Layout.fillWidth: true
            spacing: 8
            Seg {
                fill: false
                model: [["dark", "Oscuro"], ["light", "Claro"]]
                current: root.editSide
                onPicked: k => root.editSide = k
            }
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor(width / 230))
                rowSpacing: 8; columnSpacing: 16
                Repeater {
                    model: root.roles
                    RowLayout {
                        id: rl
                        required property var modelData
                        readonly property string k: modelData[0]
                        readonly property string hex: root.preview?.[root.editSide]?.[k] ?? ""
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: Theme.r(5)
                            color: rl.hex || "transparent"
                            border.width: 1; border.color: Qt.alpha(Theme.t, 0.25)
                        }
                        Txt { Layout.fillWidth: true; text: rl.modelData[1]; size: 11.5; elide: Text.ElideRight }
                        Field {
                            id: hexIn
                            Layout.preferredWidth: 92
                            h: 26; icon: ""; textSize: 11.5
                            input.font.family: Theme.mono
                            input.maximumLength: 7
                            text: rl.hex
                        }
                        // Intro o salir del campo: se aplica (si es un código válido) y el campo vuelve a seguir al color
                        Connections {
                            target: hexIn.input
                            function onEditingFinished() {
                                const v = hexIn.text.trim().replace(/^#?/, "#").toUpperCase();
                                if (v !== rl.hex) root.setRole(root.editSide, rl.k, v);
                                hexIn.text = Qt.binding(() => rl.hex);
                            }
                        }
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                text: "Escribe el código (#RRGGBB) y pulsa Intro. Si un texto no se leería bien, se ajusta solo y lo verás en la nota de abajo."
                muted: true; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
        Txt {
            Layout.fillWidth: true
            text: root.preview ? (root.preview.origen === "paleta" ? "Colores leídos de la imagen. " : root.preview.origen === "imagen" ? "Colores sacados de la foto. " : "")
                                 + "Contraste mínimo del texto: " + root.preview.minContrast + ":1"
                                 + (root.preview.notes?.length ? " · " + root.preview.notes.join(" · ") : "") : ""
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        RowLayout {
            spacing: 8
            Button {
                kind: "primary"; text: "Guardar y usar"
                onClicked: {
                    const p = Object.assign({}, root.preview, nameField.text.trim() ? { name: nameField.text.trim() } : {},
                                            root.editingKey ? { replace: root.editingKey } : {});
                    saver.command = ["sh", "-c", 'printf "%s" "$1" | "$2" save -', "sh", JSON.stringify(p), Paths.script("hf-theme")];
                    saver.running = true;
                }
            }
            Button { text: root.editColors ? "Ocultar colores" : "Editar colores"; onClicked: root.editColors = !root.editColors }
            Button { text: "Descartar"; onClicked: { root.preview = null; root.image = ""; root.editingKey = ""; root.editColors = false; } }
        }
    }
    Process {
        id: saver
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.error) { root.say(j.error, true); return; }
                    root.preview = null; root.image = ""; nameField.text = ""; hexField.text = ""; root.editingKey = ""; root.editColors = false;
                    root.say("Guardado.");
                    root.picked(j.key, "");
                } catch (e) { root.say("No se pudo guardar.", true); }
            }
        }
    }
    Txt {
        visible: root.msg !== ""
        Layout.fillWidth: true
        text: root.msg
        color: root.msgErr ? Theme.danger : Theme.tv
        size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
}
