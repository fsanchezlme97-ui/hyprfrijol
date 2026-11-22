// Ajustes › Apariencia — fondo, estilo Math (con o sin transparencia), paleta de colores (cada paleta fija
// su modo oscuro/claro y su acento), movimiento (animPreset + animSpeed), ventanas (shadows, activeBorder),
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

    readonly property string colorMode: Settings.get("colorMode", "elegir")
    readonly property string themeMode: Settings.get("themeMode", "oscuro")
    readonly property string paletteKey: Settings.get("palette", "oxocarbon")
    // Temas que se pueden elegir: cada paleta fija su modo (oscuro o claro); las parejas se muestran por separado
    readonly property var palKeys: Object.keys(pals).filter(k => k !== "atardecer")
    property string palGroup: "oscuro"
    property string palQuery: ""
    function norm(s) { return String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, ""); }
    onPalShownChanged: palCar.reset()
    readonly property var palShown: palKeys.filter(k => {
        const p = pals[k];
        if (p.group === "propio") return false;     // los propios van en «Mis temas» (ui/MyThemes.qml)
        if (palGroup === "oscuro" && p.light) return false;
        if (palGroup === "claro" && !p.light) return false;
        return palQuery === "" || norm(p.name).includes(norm(palQuery)) || norm(k).includes(norm(palQuery));
    })

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

    // Preajustes de transparencia/cristal: aplican todos los sliders de golpe
    readonly property var glassPresets: ({
        "default":   { label: "Por defecto",         glassOpacity: 0.40, glassOpacityLight: 0.56, glassMaxOpacity: 0.74, sheenOpacity: 1.0, rimOpacity: 1.0, winOpacity: 0.94, blurSize: 8,  blurPasses: 3, blurNoise: 0.015, blurContrast: 0.95, blurBrightness: 0.90, blurBrightnessLight: 1.05, blurVibrancy: 0.35, blurVibrancyDarkness: 0.20 },
        "aurora":    { label: "Aurora",              glassOpacity: 0.30, glassOpacityLight: 0.48, glassMaxOpacity: 0.65, sheenOpacity: 0.9, rimOpacity: 1.1, winOpacity: 0.88, blurSize: 10, blurPasses: 3, blurNoise: 0.012, blurContrast: 0.93, blurBrightness: 0.92, blurBrightnessLight: 1.08, blurVibrancy: 0.55, blurVibrancyDarkness: 0.18 },
        "glass":     { label: "Vidrio clásico",      glassOpacity: 0.32, glassOpacityLight: 0.46, glassMaxOpacity: 0.70, sheenOpacity: 0.8, rimOpacity: 0.9, winOpacity: 0.90, blurSize: 12, blurPasses: 3, blurNoise: 0.012, blurContrast: 0.94, blurBrightness: 0.88, blurBrightnessLight: 1.05, blurVibrancy: 0.35, blurVibrancyDarkness: 0.15 }
    })
    readonly property var glassPresetKeys: Object.keys(glassPresets)
    function glassPresetMatch(key) {
        const p = glassPresets[key];
        if (!p) return false;
        return ["glassOpacity","glassOpacityLight","glassMaxOpacity","sheenOpacity","rimOpacity","winOpacity","blurSize","blurPasses","blurNoise","blurContrast","blurBrightness","blurBrightnessLight","blurVibrancy","blurVibrancyDarkness"]
            .every(k => Settings.get(k, p[k]) === p[k]);
    }
    readonly property string currentGlassPreset: {
        for (const k of glassPresetKeys) if (glassPresetMatch(k)) return k;
        return "";
    }
    function applyGlassPreset(key) {
        const p = glassPresets[key];
        if (!p) return;
        const obj = { glassPreset: key };
        for (const k of ["glassOpacity","glassOpacityLight","glassMaxOpacity","sheenOpacity","rimOpacity","winOpacity","blurSize","blurPasses","blurNoise","blurContrast","blurBrightness","blurBrightnessLight","blurVibrancy","blurVibrancyDarkness"])
            obj[k] = p[k];
        Confirm.change("Preset de transparencia: " + p.label, obj);
    }

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
            Mono { tech: true;
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
                    : "barra, dock, paneles y notificaciones de vidrio esmerilado, translúcidos y muy desenfocados · algo más de GPU"
                checked: Theme.glassy || Settings.get("transparencia", false)
                onToggled: v => Confirm.change("Transparencia", { transparencia: v })
            }

            ColumnLayout {
                visible: Theme.glassy
                Layout.fillWidth: true
                spacing: 4
                LabeledRow {
                    label: "Preajuste"; labelWidth: 70
                    Dropdown {
                        popupWidth: 220
                        model: root.glassPresetKeys.map(k => [k, root.glassPresets[k].label]).concat([["", "Personalizado"]])
                        current: root.currentGlassPreset || ""
                        onPicked: k => { if (k) root.applyGlassPreset(k); }
                    }
                }
                SwRow {
                    label: "Claro u oscuro según el fondo"
                    sub: "el cristal se vuelve claro sobre fondos claros y oscuro sobre oscuros; las apps siguen la paleta"
                    key: "glassWallpaper"; def: true
                }
                LabeledRow {
                    label: "Filo del cristal"; labelWidth: 70
                    Seg {
                        model: [["luz", "Con luz"], ["plano", "Plano"]]
                        current: Settings.get("glassRim", "luz")
                        onPicked: k => Confirm.change("Filo del cristal", { glassRim: k })
                    }
                }

                Expander {
                    title: "Opacidad"
                    subtitle: "base y tope para que el texto se lea sobre fondos de cualquier tono"
                    open: false
                    LabeledRow { label: "Opacidad en oscuro"; labelWidth: 130
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 1; value: Settings.get("glassOpacity", 0.40); onMoved: v => Settings.set("glassOpacity", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("glassOpacity", 0.40) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Opacidad en claro"; labelWidth: 130
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 1; value: Settings.get("glassOpacityLight", 0.56); onMoved: v => Settings.set("glassOpacityLight", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("glassOpacityLight", 0.56) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Opacidad máxima"; labelWidth: 130
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 1; value: Settings.get("glassMaxOpacity", 0.74); onMoved: v => Settings.set("glassMaxOpacity", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("glassMaxOpacity", 0.74) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        Layout.leftMargin: 142
                        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        text: "0 % es transparente y 100 % es opaco. El tope se usa cuando el fondo junto a la barra es del tono contrario al cristal, para que el texto se siga leyendo."
                    }
                }

                Expander {
                    title: "Desenfoque del fondo"
                    subtitle: "tamaño, pasadas, brillo, ruido y vibrancy del blur de Hyprland"
                    open: false
                    LabeledRow { label: "Tamaño"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 16; value: Settings.get("blurSize", 8); onMoved: v => Settings.set("blurSize", Math.round(v)) }
                            Txt { text: Settings.get("blurSize", 8); tabular: true; Layout.preferredWidth: 28 }
                        }
                    }
                    LabeledRow { label: "Pasadas"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 1; to: 5; value: Settings.get("blurPasses", 3); onMoved: v => Settings.set("blurPasses", Math.round(v)) }
                            Txt { text: Settings.get("blurPasses", 3); tabular: true; Layout.preferredWidth: 28 }
                        }
                    }
                    LabeledRow { label: "Brillo en oscuro"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0.5; to: 1.5; value: Settings.get("blurBrightness", 0.90); onMoved: v => Settings.set("blurBrightness", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("blurBrightness", 0.90) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Brillo en claro"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0.5; to: 1.5; value: Settings.get("blurBrightnessLight", 1.05); onMoved: v => Settings.set("blurBrightnessLight", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("blurBrightnessLight", 1.05) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Ruido"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 0.1; value: Settings.get("blurNoise", 0.015); onMoved: v => Settings.set("blurNoise", Math.round(v * 1000) / 1000) }
                            Txt { text: Settings.get("blurNoise", 0.015).toFixed(3); tabular: true; Layout.preferredWidth: 46 }
                        }
                    }
                    LabeledRow { label: "Contraste"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0.5; to: 1.5; value: Settings.get("blurContrast", 0.95); onMoved: v => Settings.set("blurContrast", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("blurContrast", 0.95) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Vibrancy"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 1; value: Settings.get("blurVibrancy", 0.35); onMoved: v => Settings.set("blurVibrancy", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("blurVibrancy", 0.35) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Oscuridad vibrancy"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 1; value: Settings.get("blurVibrancyDarkness", 0.20); onMoved: v => Settings.set("blurVibrancyDarkness", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("blurVibrancyDarkness", 0.20) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                }

                Expander {
                    title: "Brillo del cristal"
                    subtitle: "resplandor plano y filo de luz del borde"
                    open: false
                    LabeledRow { label: "Resplandor"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 2; value: Settings.get("sheenOpacity", 1.0); onMoved: v => Settings.set("sheenOpacity", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("sheenOpacity", 1.0) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                    LabeledRow { label: "Filo de luz"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0; to: 2; value: Settings.get("rimOpacity", 1.0); onMoved: v => Settings.set("rimOpacity", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("rimOpacity", 1.0) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                }

                Expander {
                    title: "Ventanas grandes"
                    subtitle: "opacidad del fondo de Ajustes, Centro de aplicaciones y otras ventanas del shell"
                    open: false
                    LabeledRow { label: "Opacidad"; labelWidth: 100
                        RowLayout { Layout.fillWidth: true; spacing: 12
                            SliderBar { Layout.fillWidth: true; from: 0.3; to: 1; value: Settings.get("winOpacity", 0.94); onMoved: v => Settings.set("winOpacity", Math.round(v * 100) / 100) }
                            Txt { text: Math.round(Settings.get("winOpacity", 0.94) * 100) + "%"; tabular: true; Layout.preferredWidth: 40 }
                        }
                    }
                }
            }

            // Paleta elegida (la lista completa, con búsqueda y grupos, va en «Paleta de colores», debajo)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [Theme.p, Theme.pc, Theme.sc, Theme.ter, Theme.s4]
                    Rectangle { required property color modelData; width: 22; height: 22; radius: 11; color: modelData; border.width: 1; border.color: Theme.ov }
                }
                Txt { Layout.leftMargin: 8; muted: true; size: 11.5; text: (root.pals[root.paletteKey]?.name ?? Theme.paletteName).replace(" · claro", "") + " · el modo lo fija la paleta" }
            }
            // Acento: automático según la paleta, colores del tema, blanco o personalizado
            LabeledRow {
                label: "Acento"; labelWidth: 70
                AccentPicker { }
            }
        }
    }

    // ---------- Paleta de colores ----------
    Section {
        Layout.fillWidth: true
        title: "Paleta de colores"
        headerRight: Mono { tech: true; text: "palette = " + root.paletteKey }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Field {
                Layout.preferredWidth: 220
                placeholder: "Buscar paleta…"
                onTextChanged: root.palQuery = text.trim()
            }
            Pills {
                Layout.fillWidth: true
                fill: false
                h: 28
                model: [["oscuro", "Oscuro"], ["claro", "Claro"]]
                current: root.palGroup
                onPicked: k => root.palGroup = k
            }
            Item { Layout.fillWidth: true }
            Txt {
                muted: true; size: 11.5
                text: root.palShown.length + " a la vista"
            }
        }
        // Sin tope de temas: dos filas que se desplazan en horizontal (ui/HCarousel.qml) si no caben
        HCarousel {
            id: palCar
            Layout.fillWidth: true
            Grid {
                rows: Math.min(3, Math.max(1, root.palShown.length))
                flow: Grid.TopToBottom
                spacing: 8
                Repeater {
                    model: root.palShown
                    PaletteCard {
                        id: pCard
                        required property string modelData
                        width: 170
                        key: modelData
                        // la elegida, a la vista (al abrir, al filtrar y al elegirla)
                        onOnChanged: if (on) palCar.reveal(pCard)
                        Component.onCompleted: if (on) Qt.callLater(() => palCar.reveal(pCard))
                        pals: root.pals
                        current: root.paletteKey
                        themeMode: root.themeMode
                        onPicked: (k, mode) => Settings.setMany({ colorMode: "elegir", palette: k, themeMode: mode })
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
            text: "Cada paleta fija su modo: las que tienen pareja (Catppuccin, Nord, Gruvbox, Rosé Pine…) aparecen como dos tarjetas, una en Oscuro y otra en Claro. Con «Aplicar el tema a las apps», el terminal usa sus 16 colores."
        }
    }

    // Temas propios y creador (scripts/hf-theme)
    MyThemes {
        Layout.fillWidth: true
        pals: root.pals
        current: root.paletteKey
        themeMode: root.themeMode
        onPicked: (k, mode) => Settings.setMany(mode === "" ? { colorMode: "elegir", palette: k } : { colorMode: "elegir", palette: k, themeMode: mode })
    }

    // ---------- Tema en las apps ----------
    Section {
        Layout.fillWidth: true
        title: "Tema en las apps"
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
            columnSpacing: 24
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

    // ---------- Tipografía ----------
    Section {
        Layout.fillWidth: true
        title: "Tipografía"
        headerRight: Mono { tech: true; text: "fontFamily · fontScale = " + Settings.get("fontScale", 1) + " · appFontPx = " + Settings.get("appFontPx", 12) + " · termFontPx = " + Settings.get("termFontPx", 13) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 12
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
        headerRight: Mono { tech: true; text: "rounding = " + (Settings.get("rounding", null) ?? Theme.winRadius) + " · rounding_power" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
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
        SwRow {
            label: "Esquinas de la pantalla redondeadas"
            sub: "cada monitor con las esquinas en curva, del doble del radio de las ventanas · se quitan con una ventana a pantalla completa y salen en las capturas"
            key: "screenCorners"; def: false
        }
    }

    // ---------- Espacio y escala ----------
    Section {
        Layout.fillWidth: true
        title: "Espacio y escala"
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                RowLayout { Txt { text: "Espacio entre ventanas"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { tech: true; text: "gaps_in = " + Settings.get("gapsIn", 4) } }
                Pills { Layout.fillWidth: true; model: [0, 1, 2, 4, 6, 8, 12]; current: Settings.get("gapsIn", 4); onPicked: v => Settings.set("gapsIn", v) }
                RowLayout { Txt { text: "Espacio con el borde y la barra"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { tech: true; text: "gaps_out = " + Settings.get("gapsOut", 4) } }
                Pills { Layout.fillWidth: true; model: [0, 1, 2, 4, 6, 8, 12, 20]; current: Settings.get("gapsOut", 4); onPicked: v => Settings.set("gapsOut", v) }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                spacing: 8
                RowLayout { Txt { text: "Escala de la interfaz"; weight: Font.DemiBold; Layout.fillWidth: true } Mono { tech: true; text: "monitor scale" } }
                Pills { Layout.fillWidth: true; model: [[1, "1×"], [1.25, "1.25×"], [1.5, "1.5×"], [2, "2×"]]; current: Settings.get("uiScale", 1); onPicked: v => Confirm.change("Escala de la interfaz", { uiScale: v }) }
            }
        }
    }

    // ---------- Movimiento, ventanas y rendimiento de los efectos ----------
    Section {
        Layout.fillWidth: true
        title: "Animaciones y efectos"
        LinkRow { label: "Movimiento, sombras, resaltado y desenfoque"; section: "animaciones"; sectionLabel: "Animaciones y efectos"; target: "Animaciones" }
        LinkRow { label: "Quitar efectos en juegos"; value: Settings.get("gameNoFx", true) ? "Activado" : "Desactivado"; section: "animaciones"; sectionLabel: "Animaciones y efectos"; target: "Desenfoque y rendimiento" }
    }
}
