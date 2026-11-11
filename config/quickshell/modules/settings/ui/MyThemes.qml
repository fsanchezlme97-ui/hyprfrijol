// Ajustes › Apariencia › Mis temas: los temas propios (scripts/hf-theme; pares oscuro + claro con group "propio"
// en ~/.config/hyprfrijol/palettes-user.json, que Apariencia ya lee como userPals) y el creador: códigos hex o una
// imagen (paleta con los códigos escritos → tesseract; foto → matugen) → vista previa oscura y clara con el
// contraste ya corregido → Guardar o Descartar. Cada tema se exporta a Descargas y se importa desde un .json.
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
    // La vista previa como dos paletas emparejadas, para PaletteCard
    readonly property var previewPals: preview ? ({ "_nuevo": Object.assign({ name: preview.name, pair: "_nuevo-claro" }, preview.dark),
                                                    "_nuevo-claro": Object.assign({ name: preview.name, pair: "_nuevo", variant: true }, preview.light) }) : ({})

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
        run(a, j => { preview = j; say(""); });
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
                    spacing: 10
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
        spacing: 6
        RowLayout {
            spacing: 8
            Repeater {
                model: [["_nuevo", "oscuro"], ["_nuevo-claro", "claro"]]
                PaletteCard {
                    required property var modelData
                    width: 178
                    key: modelData[0]
                    pals: Object.assign({}, root.previewPals, { [modelData[0]]: Object.assign({}, root.previewPals[modelData[0]] ?? {}, { pair: undefined, variant: undefined }) })
                    current: ""
                }
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
                    const p = root.preview;
                    saver.command = ["sh", "-c", 'printf "%s" "$1" | "$2" save -', "sh", JSON.stringify(p), Paths.script("hf-theme")];
                    saver.running = true;
                }
            }
            Button { text: "Descartar"; onClicked: { root.preview = null; root.image = ""; } }
        }
    }
    Process {
        id: saver
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.error) { root.say(j.error, true); return; }
                    root.preview = null; root.image = ""; nameField.text = ""; hexField.text = "";
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
