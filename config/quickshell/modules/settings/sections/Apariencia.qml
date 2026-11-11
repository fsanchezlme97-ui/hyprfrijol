// Ajustes › Apariencia — fondo, estilo Math (con o sin transparencia), color (automático / paleta /
// pastel / monocromo), movimiento (animPreset + animSpeed), ventanas (shadows, activeBorder),
// modo claro/oscuro (a mano, a unas horas lightFrom/lightTo o según el sol: themeSchedule + services/Sun.qml),
// tipografía (fontFamily, fontScale), esquinas, espacio entre ventanas, escala y efectos.
// Todo pasa por Settings → hf-apply.
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    // Paletas del repo + las importadas por el usuario (hf-plugin theme: temas de Omarchy → palettes-user.json)
    property var basePals: ({})
    property var userPals: ({})
    readonly property var pals: Object.assign({}, basePals, userPals)
    FileView {
        path: Paths.root + "/config/themes/palettes.json"
        printErrors: false
        onLoaded: { try { root.basePals = JSON.parse(text()); } catch (e) {} }
    }
    FileView {
        path: Paths.userDir + "/palettes-user.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); root.userPals = j && typeof j === "object" ? j : {}; } catch (e) {} }
        onLoadFailed: root.userPals = {}
    }
    Wallpapers { id: wp }
    // Color de las carpetas que eligió 17-theme-apps.py (el más cercano al acento)
    property string folderColor: ""
    FileView {
        path: Paths.state + "/icon-folders"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.folderColor = text().trim()
    }
    readonly property var folderNames: ({ blue: "Azul", indigo: "Índigo", violet: "Violeta", magenta: "Magenta", pink: "Rosa",
        red: "Rojo", carmine: "Carmín", deeporange: "Naranja intenso", orange: "Naranja", paleorange: "Naranja pálido",
        yellow: "Amarillo", green: "Verde", teal: "Verde azulado", cyan: "Cian", darkcyan: "Cian oscuro", nordic: "Nórdico",
        breeze: "Breeze", bluegrey: "Gris azulado", brown: "Marrón", palebrown: "Marrón claro", grey: "Gris", black: "Negro", white: "Blanco" })
    // ¿Siguen las apps Qt el tema? (qt6ct; o, de alternativa, el tema de Plasma, que lee kdeglobals)
    property bool qtReady: true
    Process {
        id: qtCheck
        running: true
        command: ["sh", "-c", "ls /usr/lib/qt6/plugins/platformthemes/ /usr/lib64/qt6/plugins/platformthemes/ /usr/lib/*-linux-gnu/qt6/plugins/platformthemes/ 2>/dev/null | grep -qiE 'qt6ct|KDEPlasma'"]
        onExited: code => root.qtReady = code === 0
    }

    readonly property string colorMode: Settings.get("colorMode", "auto")
    readonly property string themeMode: Settings.get("themeMode", "oscuro")
    readonly property string paletteKey: Settings.get("palette", "grafito")
    // Paletas que se pueden elegir (las variantes claras van con su pareja; «mono» y «atardecer» son internas)
    readonly property var palKeys: Object.keys(pals).filter(k => !["mono", "monoclaro", "atardecer"].includes(k) && !pals[k].variant)
    property string palGroup: "todas"
    property string palQuery: ""
    function norm(s) { return String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, ""); }
    readonly property var palShown: palKeys.filter(k => {
        const p = pals[k];
        const g = p.group ?? "";
        if (palGroup === "originales" && g !== "") return false;
        if (palGroup === "pastel" && g !== "pastel") return false;
        if (palGroup === "populares" && g !== "popular") return false;
        if (palGroup === "omarchy" && g !== "omarchy") return false;
        if (palGroup === "claras" && !(p.light || (p.pair && pals[p.pair]?.light))) return false;
        if (palGroup === "oscuras" && !(!p.light || (p.pair && !pals[p.pair]?.light))) return false;
        return palQuery === "" || norm(p.name).includes(norm(palQuery)) || norm(k).includes(norm(palQuery));
    })
    readonly property string schedule: Settings.get("themeSchedule", "horas")
    // Sun solo se consulta si se usa (si no, ni se pregunta la ubicación)
    readonly property bool useSun: themeMode === "auto" && schedule === "sol"
    readonly property var hours: Array.from({ length: 24 }, (_, i) => [i, String(i).padStart(2, "0") + ":00"])

    // Familias instaladas que pueden escribir texto en español (fc-list :lang=es), sin repetir y en orden
    // alfabético. Así no salen las fuentes de iconos (FontAwesome, Material Symbols, emoji…), que como
    // tipografía del sistema dejan las letras en la fuente de reserva y con otro tamaño.
    property var fonts: []
    Process {
        running: true
        command: ["sh", "-c", "fc-list :lang=es family 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                text.split("\n").forEach(l => { const f = l.split(",")[0].trim(); if (f && !f.startsWith(".")) seen[f] = true; });
                root.fonts = Object.keys(seen).sort((a, b) => a.localeCompare(b, "es", { sensitivity: "base" }));
            }
        }
    }
    readonly property string fontFamily: Settings.get("fontFamily", "Inter")

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        // ---------- Fondo ----------
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.fillHeight: true
            title: "Fondo de pantalla"
            headerRight: Button { kind: "link"; text: "Ver todos ›"; onClicked: Shell.open("fondos") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: wp.files.slice(0, 6)
                    Thumb {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        file: modelData
                        selected: wp.current === modelData
                        onClicked: wp.set(modelData)
                    }
                }
            }
            // El cambio automático del fondo (cada cuánto, orden, según la hora) se elige en Fondos de pantalla
            LinkRow {
                readonly property int m: Settings.get("wallpaperRotateMin", 0)
                label: "Cambio automático"
                value: (m > 0 ? (m >= 1440 ? "Diario" : m >= 60 ? "Cada " + m / 60 + " h" : "Cada " + m + " min") : Settings.get("wallpaperOnStart", false) ? "Al iniciar" : "Nunca")
                    + (Settings.get("wallpaperHora", false) ? " · según la hora" : Settings.get("wallpaperRandom", false) && (m > 0 || Settings.get("wallpaperOnStart", false)) ? " · al azar" : "")
                section: "fondos"; sectionLabel: "Fondos de pantalla"
            }
            Mono {
                Layout.fillWidth: true
                text: "hf-wallpaper " + (wp.current ? wp.name(wp.current) : "—") + " → matugen → hf-apply"
            }
        }

        // ---------- Estilo visual ----------
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Estilo · Math"
            StylePreview { Layout.fillWidth: true; implicitHeight: 150; wallpaper: wp.current; video: wp.isVideo(wp.current) }
            // Estilo único Math (Material 3); la transparencia es lo que antes era el estilo SkySoul
            SwRow {
                label: "Transparencia"
                sub: Settings.get("reduceTransparency", false) || Settings.get("highContrast", false)
                    ? "sin efecto: Accesibilidad reduce la transparencia"
                    : "paneles de cristal, muy desenfocados, con un resplandor del acento · algo más de GPU"
                checked: Theme.glassy || Settings.get("transparencia", false)
                onToggled: v => Confirm.change("Transparencia", { transparencia: v })
            }
            LabeledRow {
                label: "Color"; labelWidth: 70
                Seg {
                    model: [["auto", "Automático"], ["elegir", "Elegir"], ["mono", "Monocromo"]]
                    current: root.colorMode
                    onPicked: k => Settings.set("colorMode", k)
                }
            }
            // Detalle del modo de color
            RowLayout {
                visible: root.colorMode === "auto"
                Layout.leftMargin: 80
                spacing: 6
                Repeater {
                    model: [Theme.p, Theme.pc, Theme.sc, Theme.ter, Theme.s4]
                    Rectangle { required property color modelData; width: 22; height: 22; radius: 11; color: modelData; border.width: 1; border.color: Theme.ov }
                }
                Txt { Layout.leftMargin: 6; muted: true; size: 11.5; text: "Tomado del fondo «" + (wp.current ? wp.name(wp.current) : "—") + "»" }
            }
            // Paleta elegida (la lista completa, con búsqueda y grupos, va en «Paleta de colores», debajo)
            RowLayout {
                visible: root.colorMode === "elegir"
                Layout.leftMargin: 80
                spacing: 6
                Repeater {
                    model: [Theme.p, Theme.pc, Theme.sc, Theme.ter, Theme.s4]
                    Rectangle { required property color modelData; width: 22; height: 22; radius: 11; color: modelData; border.width: 1; border.color: Theme.ov }
                }
                Txt { Layout.leftMargin: 6; muted: true; size: 11.5; text: (root.pals[root.paletteKey]?.name ?? Theme.paletteName).replace(" · claro", "") + " · " + root.palKeys.length + " paletas abajo" }
            }
            // Acento: el de la paleta o uno propio (sustituye al color principal en todo el tema)
            LabeledRow {
                label: "Acento"; labelWidth: 70
                AccentPicker { }
            }
            RowLayout {
                visible: root.colorMode === "mono"
                Layout.fillWidth: true
                Layout.leftMargin: 80
                spacing: 10
                Seg {
                    model: [["oscuro", "Oscuro"], ["claro", "Claro"]]
                    current: root.themeMode === "claro" ? "claro" : "oscuro"
                    fill: false
                    onPicked: k => Settings.set("themeMode", k)
                }
                Item { Layout.fillWidth: true }
                Txt { text: "Fondo en blanco y negro"; weight: Font.Medium }
                Sw { checked: Settings.get("monoFondo", true); onToggled: v => Settings.set("monoFondo", v) }
            }
            Txt {
                visible: root.colorMode === "mono"
                Layout.fillWidth: true
                Layout.leftMargin: 80
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Grises neutros con un acento azul, como el modo oscuro (o claro) de Chrome."
            }
            LabeledRow {
                visible: root.colorMode !== "mono"
                label: "Modo"; labelWidth: 70
                Seg {
                    model: [["oscuro", "Oscuro"], ["claro", "Claro"], ["auto", "Automático"]]
                    current: root.themeMode
                    onPicked: k => Settings.set("themeMode", k)
                }
            }
            // Automático: a unas horas o con el sol (la misma fuente que la luz nocturna de Pantallas)
            LabeledRow {
                visible: root.colorMode !== "mono" && root.themeMode === "auto"
                label: "Cuándo"; labelWidth: 70
                Seg {
                    model: [["horas", "A unas horas"], ["sol", "Según la salida y puesta del sol"]]
                    current: root.schedule
                    onPicked: k => Settings.set("themeSchedule", k)
                }
            }
            RowLayout {
                visible: root.colorMode !== "mono" && root.themeMode === "auto" && root.schedule === "horas"
                Layout.leftMargin: 80
                spacing: 8
                Txt { text: "Claro de"; muted: true }
                Dropdown { Layout.preferredWidth: 86; model: root.hours; current: Settings.get("lightFrom", 7); onPicked: k => Settings.set("lightFrom", k) }
                Txt { text: "a"; muted: true }
                Dropdown { Layout.preferredWidth: 86; model: root.hours; current: Settings.get("lightTo", 19); onPicked: k => Settings.set("lightTo", k) }
                Txt { text: "· oscuro el resto"; muted: true; size: 11.5 }
            }
            ColumnLayout {
                visible: root.colorMode !== "mono" && root.useSun
                Layout.leftMargin: 80
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true; weight: Font.Medium
                    text: !root.useSun ? "" : Sun.polar === "dia" ? "Hoy el sol no se pone: claro todo el día"
                        : Sun.polar === "noche" ? "Hoy no sale el sol: oscuro todo el día"
                        : "Claro de " + Sun.sunrise + " (amanecer) a " + Sun.sunset + " (atardecer)"
                }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: !root.useSun ? "" : Sun.computed ? "Calculado para " + Sun.where + " · el mismo horario que la luz nocturna"
                        : !Sun.auto ? "Horas a mano de Pantallas › Luz nocturna"
                        : "Aún sin ubicación: se usan las horas de Pantallas › Luz nocturna. Pon tu ciudad o permite la ubicación por IP en Privacidad."
                }
            }
            SwRow {
                visible: root.colorMode !== "mono" && root.themeMode === "auto"
                label: "Cambiar también el fondo"; sub: "al pasar a claro u oscuro"; key: "themeWallpaper"
            }
        }
    }

    // ---------- Paleta de colores (modo «Elegir») ----------
    Section {
        visible: root.colorMode === "elegir"
        Layout.fillWidth: true
        title: "Paleta de colores"
        headerRight: Mono { text: "palette = " + root.paletteKey }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Field {
                Layout.preferredWidth: 220
                placeholder: "Buscar paleta…"
                onTextChanged: root.palQuery = text.trim()
            }
            Pills {
                Layout.fillWidth: true
                fill: false
                h: 28
                model: [["todas", "Todas"], ["originales", "Originales"], ["populares", "Populares"], ["pastel", "Pastel"], ["oscuras", "Oscuras"], ["claras", "Claras"]].concat(Object.keys(root.userPals).length ? [["omarchy", "Importadas"]] : [])
                current: root.palGroup
                onPicked: k => root.palGroup = k
            }
            Item { Layout.fillWidth: true }
            Txt { muted: true; size: 11.5; text: root.palShown.length + " de " + root.palKeys.length }
        }
        Item {
            id: palGrid
            Layout.fillWidth: true
            readonly property int cols: Math.max(2, Math.floor((width + 8) / 178))
            readonly property real cw: (width - (cols - 1) * 8) / cols
            implicitHeight: palFlow.implicitHeight
            Flow {
                id: palFlow
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.palShown
                    PaletteCard {
                        required property string modelData
                        width: palGrid.cw
                        key: modelData
                        pals: root.pals
                        current: root.paletteKey
                        themeMode: root.themeMode
                        onPicked: (k, mode) => Settings.setMany(mode === "" ? { colorMode: "elegir", palette: k } : { colorMode: "elegir", palette: k, themeMode: mode })
                    }
                }
            }
        }
        Txt {
            visible: root.palShown.length === 0
            muted: true
            text: "Ninguna paleta coincide con «" + root.palQuery + "»"
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Las que tienen pareja (Catppuccin, Nord, Gruvbox, Rosé Pine…) cambian a su versión clara u oscura con el modo; las demás (☀/☾) lo fijan. Con «Aplicar el tema a las apps», el terminal usa sus 16 colores."
        }
    }

    // ---------- Movimiento y ventanas ----------
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            id: mov
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.fillHeight: true
            title: "Movimiento"
            readonly property string preset: Settings.get("animado", true) === false ? "ninguno" : Settings.get("animPreset", "fluido")
            headerRight: Mono { text: "hl.animation · hl.curve" }
            MotionDemo { Layout.fillWidth: true }
            LabeledRow {
                label: "Animaciones"; labelWidth: 80
                Seg {
                    model: [["fluido", "Fluido"], ["equilibrado", "Equilibrado"], ["rapido", "Rápido"], ["minimo", "Mínimo"], ["ninguno", "Ninguna"]]
                    current: mov.preset
                    textSize: 11.5
                    onPicked: k => Settings.setMany({ animPreset: k, animado: k !== "ninguno" })
                }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 90
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: ({
                    fluido: "Movimiento elástico y suave, algo más largo, como en iOS o macOS: las ventanas aparecen con un leve rebote y los espacios se deslizan.",
                    equilibrado: "El de siempre: entrada rápida que frena al final y un rebote corto al abrir ventanas.",
                    rapido: "Ágil y sin rebotes: casi la mitad de largo. Para quien quiere que todo responda ya.",
                    minimo: "Solo fundidos: nada se desplaza ni cambia de tamaño.",
                    ninguno: "Sin animaciones en ventanas, espacios ni paneles."
                })[mov.preset] ?? ""
            }
            LabeledRow {
                label: "Velocidad"; labelWidth: 80
                enabled: mov.preset !== "ninguno" && !Theme.reduceMotion
                opacity: enabled ? 1 : 0.5
                Pills {
                    Layout.fillWidth: true
                    model: [[0.7, "Lenta"], [0.85, "Pausada"], [1, "Normal"], [1.25, "Ágil"], [1.5, "Rápida"]]
                    current: Settings.get("animSpeed", 1)
                    onPicked: v => Settings.set("animSpeed", v)
                }
            }
            LinkRow {
                visible: Theme.reduceMotion
                label: "Reducir movimiento está activado"; value: "Sin animaciones"
                section: "accesibilidad"; sectionLabel: "Accesibilidad"
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.fillHeight: true
            title: "Ventanas"
            headerRight: Mono { text: "decoration.shadow · col.active_border" }
            WindowLookPreview { Layout.fillWidth: true }
            LabeledRow {
                label: "Sombras"; labelWidth: 80
                Seg {
                    model: [["ninguna", "Ninguna"], ["suaves", "Suaves"], ["marcadas", "Marcadas"]]
                    current: Settings.get("shadows", "suaves")
                    onPicked: k => Settings.set("shadows", k)
                }
            }
            LabeledRow {
                label: "Resaltado"; labelWidth: 80
                Seg {
                    model: [["sutil", "Sutil"], ["color", "Color"], ["brillo", "Brillo"], ["ninguno", "Ninguno"]]
                    current: Settings.get("activeBorder", "sutil")
                    onPicked: k => Settings.set("activeBorder", k)
                }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 90
                muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Resaltado de la ventana activa: " + ({
                    sutil: "borde fino con un toque del color de acento; las demás ventanas, casi sin borde.",
                    color: "borde de 2 px con un degradado del color de acento.",
                    brillo: "borde fino y un halo suave del color de acento alrededor.",
                    ninguno: "sin borde; las sombras separan las ventanas."
                })[Settings.get("activeBorder", "sutil")] ?? ""
            }
        }
    }

    // ---------- Tipografía ----------
    Section {
        Layout.fillWidth: true
        title: "Tipografía"
        headerRight: Mono { text: "fontFamily · fontScale = " + Settings.get("fontScale", 1) + " · appFontPx = " + Settings.get("appFontPx", 12) + " · termFontPx = " + Settings.get("termFontPx", 13) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 22
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 10
                LabeledRow {
                    label: "Fuente"; labelWidth: 120
                    RowLayout {
                        spacing: 8
                        Dropdown {
                            Layout.fillWidth: true
                            fontPreview: true
                            searchable: true
                            popupWidth: Math.max(width, 300)
                            model: (root.fonts.includes(root.fontFamily) ? root.fonts : [root.fontFamily].concat(root.fonts)).map(f => [f, f])
                            current: root.fontFamily
                            onPicked: k => Settings.set("fontFamily", k)
                        }
                        Button { visible: root.fontFamily !== "Inter"; text: "Inter"; onClicked: Settings.set("fontFamily", "Inter") }
                    }
                }
                LabeledRow {
                    label: "Tamaño del texto"; labelWidth: 120
                    Pills {
                        model: [[0.75, "9"], [0.9, "11"], [1, "12.5"], [1.1, "14"], [1.25, "16"], [1.4, "18"], [1.6, "20"]]
                        current: Settings.get("fontScale", 1)
                        onPicked: v => Settings.set("fontScale", v)
                    }
                }
                Txt {
                    Layout.fillWidth: true; Layout.leftMargin: 130
                    muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "En píxeles, el texto normal del shell."
                }
                LabeledRow {
                    label: "Texto de las apps"; labelWidth: 120
                    Pills {
                        model: [[11, "11"], [12, "12"], [13, "13"], [14, "14"], [15, "15"], [16, "16"]]
                        current: Settings.get("appFontPx", 12)
                        onPicked: v => Settings.set("appFontPx", v)
                    }
                }
                Txt {
                    Layout.fillWidth: true; Layout.leftMargin: 130
                    muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "En píxeles, menús, pestañas y barras de las apps GTK y de Chrome, con la fuente de arriba. Windows usa 12 y macOS 13. Necesita «Aplicar el tema a las apps»; Chrome lo toma al volver a abrirlo."
                }
                LabeledRow {
                    label: "Texto de la terminal"; labelWidth: 120
                    Pills {
                        model: [[12, "12"], [13, "13"], [14, "14"], [15, "15"], [16, "16"], [18, "18"]]
                        current: Settings.get("termFontPx", 13)
                        onPicked: v => Settings.set("termFontPx", v)
                    }
                }
                Txt {
                    Layout.fillWidth: true; Layout.leftMargin: 130
                    muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "En píxeles, el texto de kitty (font_size " + (Settings.get("termFontPx", 13) * 0.75) + " pt). Windows Terminal y la Terminal de macOS usan unos 13. Se aplica al momento a todas las ventanas de kitty."
                }
            }
            // Vista previa con la fuente elegida
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: prev.implicitHeight + 24
                radius: Theme.r(8)
                color: Theme.s4
                ColumnLayout {
                    id: prev
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Txt { Layout.fillWidth: true; text: "Aa Bb Ññ 0123"; size: 22; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; text: "El veloz murciélago hindú comía feliz cardillo y kiwi."; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    Txt { Layout.fillWidth: true; text: "La cigüeña tocaba el saxofón detrás del palenque de paja."; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                }
            }
        }
    }

    // ---------- Redondeo ----------
    Section {
        Layout.fillWidth: true
        title: "Redondeo"
        headerRight: Mono { text: "rounding = " + (Settings.get("rounding", null) ?? Theme.winRadius) + " · rounding_power" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 22
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                Txt { text: "Interfaz (paneles, botones, barra)"; weight: Font.DemiBold }
                Pills {
                    Layout.fillWidth: true
                    model: [["recto", "Recto"], ["sobrio", "Sobrio"], ["auto", "Normal"], ["redondo", "Redondo"], ["maximo", "Máximo"]]
                    current: Settings.get("roundness", "auto")
                    onPicked: v => Confirm.change("Redondeo de la interfaz", { roundness: v })
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                Txt { text: "Forma de las esquinas"; weight: Font.DemiBold }
                Pills {
                    Layout.fillWidth: true
                    model: [["auto", "Según estilo"], ["circular", "Circular"], ["continua", "Continua"], ["squircle", "Squircle"]]
                    current: Settings.get("roundingShape", "auto")
                    onPicked: v => Confirm.change("Forma de las esquinas", { roundingShape: v })
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Txt { text: "Esquinas de las ventanas"; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt { muted: true; size: 11.5; text: Settings.get("rounding", null) === null ? "Automático: " + Theme.winRadius + " px con este estilo" : Settings.get("rounding") + " px" }
            }
            Pills {
                Layout.fillWidth: true
                model: [["auto", "Auto"], [0, "0"], [4, "4"], [8, "8"], [12, "12"], [16, "16"], [20, "20"], [24, "24"], [32, "32"]]
                current: Settings.get("rounding", null) ?? "auto"
                onPicked: v => Confirm.change("Esquinas de las ventanas", { rounding: v === "auto" ? null : v })
            }
        }
    }

    Section {
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            spacing: 22
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                RowLayout { Txt { text: "Espacio entre ventanas"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { text: "gaps_in = " + Settings.get("gapsIn", 4) } }
                Pills { Layout.fillWidth: true; model: [0, 1, 2, 4, 6, 8, 12]; current: Settings.get("gapsIn", 4); onPicked: v => Settings.set("gapsIn", v) }
                RowLayout { Txt { text: "Espacio con el borde y la barra"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { text: "gaps_out = " + Settings.get("gapsOut", 4) } }
                Pills { Layout.fillWidth: true; model: [0, 1, 2, 4, 6, 8, 12, 20]; current: Settings.get("gapsOut", 4); onPicked: v => Settings.set("gapsOut", v) }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                RowLayout { Txt { text: "Escala de la interfaz"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { text: "monitor scale" } }
                Pills { Layout.fillWidth: true; model: [[1, "1×"], [1.25, "1.25×"], [1.5, "1.5×"], [2, "2×"]]; current: Settings.get("uiScale", 1); onPicked: v => Confirm.change("Escala de la interfaz", { uiScale: v }) }
            }
        }
        Item { implicitHeight: 2 }
        LinkRow { label: "Quitar efectos en juegos"; value: Settings.get("gameNoFx", true) ? "Activado" : "Desactivado"; section: "energia"; sectionLabel: "Energía y rendimiento" }
    }
    // ---------- Tema en las apps ----------
    Section {
        Layout.fillWidth: true
        title: "Tema en las apps"
        headerRight: Mono { text: "config/apply/17-theme-apps.py" }
        SwRow {
            separator: false
            label: "Aplicar el tema a las apps"
            sub: "Los colores de la paleta y el acento en el terminal, las apps GTK y Qt y btop; cambian al momento"
            key: "themeApps"; def: false
        }
        GridLayout {
            visible: Settings.get("themeApps", false)
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 22
            rowSpacing: 0
            SwRow { Layout.preferredWidth: 1; label: "Terminal (kitty)"; sub: "Esquema completo: 16 colores, selección y pestañas"; key: "themeKitty"; def: true }
            SwRow { Layout.preferredWidth: 1; label: "Apps GTK y GNOME"; sub: "Nautilus, Loupe, Papers… · libadwaita y GTK 3"; key: "themeGtk"; def: true }
            SwRow {
                Layout.preferredWidth: 1
                label: "Apps Qt"
                sub: root.qtReady ? "OBS, VLC, qBittorrent… · paleta de qt6ct" : "Falta qt6ct para que las apps Qt lo sigan"
                key: "themeQt"; def: true
                trailing: Button {
                    visible: !root.qtReady
                    text: "Instalar"
                    onClicked: { Pkg.install([{ key: "repo", pkg: "qt6ct", name: "qt6ct" }], "Tema de Qt (qt6ct)"); qtCheck.running = true; }
                }
            }
            SwRow { Layout.preferredWidth: 1; label: "btop"; sub: "Tema «hyprfrijol» con los colores de la paleta"; key: "themeBtop"; def: true }
        }
        SwRow {
            label: "Iconos Papirus con carpetas del color de acento"
            sub: Settings.get("themeIcons", true) ? "Carpetas: " + (root.folderNames[root.folderColor] ?? (root.folderColor || "—")) + " · tema de usuario, sin permisos de administrador" : "No se cambia el tema de iconos"
            key: "themeIcons"; def: true
            trailing: Dropdown {
                visible: Settings.get("themeIcons", true)
                width: 190
                model: [["acento", "Según el acento"], ["papirus", "Como Papirus"]].concat(Object.keys(root.folderNames).map(k => [k, root.folderNames[k]]))
                current: Settings.get("iconFolders", "acento")
                onPicked: k => Settings.set("iconFolders", k)
            }
        }
    }
}
