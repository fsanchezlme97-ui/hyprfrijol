// Bienvenida (design «Bienvenida», «BienvenidaEstilo», «BienvenidaHerramientas»): asistente de primer arranque
// en 6 pasos — idioma y región, estilo y color, fondo, barra, herramientas y resumen. Cada cambio se aplica al
// momento (Settings → hf-apply), así se ve detrás. Vista "bienvenida".
// Se abre solo la primera vez (si ~/.config/hyprfrijol/settings.json no tiene "welcomeDone") y al cerrarlo
// se marca como hecho. Para volver a verlo: Ajustes › Aplicaciones, Spotlight («bienvenida») o
//   qs -p <repo>/config/quickshell ipc call shell open bienvenida
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Scope {
    id: root
    property int step: parseInt(Quickshell.env("HF_WELCOME_STEP") || "0") || 0
    property var packs: ({ esen: true })
    property string fm: "nautilus"
    property var locales: []
    property var zones: []
    property string lang: ""
    property string region: ""
    property string zone: ""
    property bool installed: false
    readonly property var catalog: Pkg.catalog     // mismo catálogo y misma lógica que el Centro de aplicaciones

    readonly property var steps: ["Idioma y región", "Estilo y color", "Fondo", "Barra", "Aplicaciones", "Listo"]
    readonly property var titles: [
        ["Hola. Empecemos por lo básico", "Detectamos estos valores; cámbialos si hace falta."],
        ["¿Cómo quieres que se vea?", "Elige el estilo y cómo se eligen los colores."],
        ["Elige un fondo", "Puedes activar el cambio automático más tarde."],
        ["¿Dónde va la barra?", "Fija abajo aprovecha mejor la pantalla."],
        ["Instala lo que vas a usar", "Opcional. Primero de los repos de " + (Pkg.distroName || "tu distro") + (Pkg.family === "arch" ? ", luego AUR y Flathub." : ", luego Flathub.")],
        ["Todo listo", "Este es tu escritorio."]
    ]
    readonly property var packDefs: [["esen", "Esenciales"], ["ofi", "Oficina"], ["crea", "Creativo"], ["dev", "Desarrollador"], ["game", "Gamer"], ["ia", "IA local"]]
    readonly property var packProfile: ({ esen: "Esenciales", ofi: "Oficina", crea: "Creativo", dev: "Desarrollador", game: "Gamer", ia: "IA" })
    function profileTools(k) {
        const p = catalog.profiles.find(x => x.label === packProfile[k]);
        return p ? p.ids.map(id => Pkg.tool(id)).filter(Boolean) : [];
    }
    readonly property var fmTool: ({ nautilus: "nautilus", dolphin: "dolphin", yazi: "yazi" })
    readonly property var fmDesktop: ({ nautilus: "org.gnome.Nautilus.desktop", dolphin: "org.kde.dolphin.desktop", yazi: "yazi.desktop" })

    function finish(): void { Settings.set("welcomeDone", true); }
    function install(): void {
        const ids = {};
        Object.keys(packs).filter(k => packs[k]).forEach(k => profileTools(k).forEach(t => ids[t.id] = t));
        const f = Pkg.tool(fmTool[fm]); if (f) ids[f.id] = f;
        const tools = Object.values(ids).filter(t => !Pkg.isToolInstalled(t));
        const cmds = Pkg.commands(tools);
        // Después de instalar: las apps de GNOME recomendadas como predeterminadas (solo las instaladas;
        // el navegador no se toca) y el gestor de archivos elegido para las carpetas
        const post = [];
        if (packs.esen) post.push(Paths.script("hf-defaults") + " recommended --force >/dev/null");
        post.push("xdg-mime default " + fmDesktop[fm] + " inode/directory");
        Settings.set("fileManager", fm);
        const run = cmds.filter(c => !c.startsWith("#"));
        if (run.length) Pkg.runInTerminal(run.join(" && ") + "\n" + post.join("\n"), "Instalar aplicaciones");
        else Quickshell.execDetached(["sh", "-c", post.join("\n")]);
        installed = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "localectl list-locales 2>/dev/null; echo ---; timedatectl list-timezones 2>/dev/null; echo ---; timedatectl show -p Timezone --value; echo \"$LANG\"; locale 2>/dev/null | sed -n 's/^LC_TIME=\"\\{0,1\\}\\([^\"]*\\)\"\\{0,1\\}$/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n");
                root.locales = (parts[0] ?? "").split("\n").filter(l => l && l !== "C.UTF-8");
                root.zones = (parts[1] ?? "").split("\n").filter(Boolean);
                const tail = (parts[2] ?? "").split("\n");
                root.zone = tail[0] ?? ""; root.lang = tail[1] ?? ""; root.region = tail[2] || root.lang;
            }
        }
    }
    readonly property var langNames: ({ es: "Español", en: "English", pt: "Português", fr: "Français", de: "Deutsch", it: "Italiano", ca: "Català" })
    readonly property var countryNames: ({ ES: "España", MX: "México", AR: "Argentina", CO: "Colombia", PE: "Perú", CL: "Chile", VE: "Venezuela", EC: "Ecuador",
        US: "Estados Unidos", GB: "Reino Unido", BR: "Brasil", PT: "Portugal", FR: "Francia", DE: "Alemania", IT: "Italia", UY: "Uruguay", BO: "Bolivia", PY: "Paraguay",
        CR: "Costa Rica", GT: "Guatemala", DO: "Rep. Dominicana", PR: "Puerto Rico", PA: "Panamá", HN: "Honduras", SV: "El Salvador", NI: "Nicaragua", CU: "Cuba" })
    function localeLabel(l) {
        const m = String(l).match(/^([a-z]{2,3})_([A-Z]{2})/);
        return m ? (langNames[m[1]] ?? m[1]) + " (" + (countryNames[m[2]] ?? m[2]) + ")" : l;
    }

    // Primer arranque: lo abre modules/Modules.qml (este módulo se carga al abrir la vista «bienvenida»)
    function syncView() {
        if (Shell.view !== "bienvenida" && wz.wasShown) { wz.wasShown = false; root.finish(); }
        // Al volver a abrirlo (Ajustes › Aplicaciones, Spotlight) empieza desde el principio
        if (Shell.view === "bienvenida" && !wz.wasShown) { wz.wasShown = true; root.step = parseInt(Quickshell.env("HF_WELCOME_STEP") || "0") || 0; root.installed = false; }
    }
    Connections {
        target: Shell
        function onViewChanged() { root.syncView(); }
    }
    Component.onCompleted: syncView()

    Overlay {
        id: wz
        property bool wasShown: false
        view: "bienvenida"
        place: "center"
        dim: true
        closeOnOutside: false
        panelWidth: 780
        panelHeight: 500
        yOffset: -10

        Glass {
            anchors.fill: parent
            kind: "popup"
            RowLayout {
                anchors.fill: parent
                spacing: 0
                // ---------- pasos ----------
                ColumnLayout {
                    Layout.preferredWidth: 168
                    Layout.minimumWidth: 168
                    Layout.maximumWidth: 168
                    Layout.fillHeight: true
                    Layout.margins: 16
                    Layout.topMargin: 22
                    spacing: 4
                    Txt { text: "Bienvenido"; size: 17; weight: Font.DemiBold; Layout.leftMargin: 8; Layout.bottomMargin: 14 }
                    Repeater {
                        model: root.steps
                        Rectangle {
                            id: st
                            required property string modelData
                            required property int index
                            readonly property bool cur: index === root.step
                            readonly property bool done: index < root.step
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.r(6)
                            color: cur ? Theme.fill2 : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 10
                                Rectangle {
                                    implicitWidth: 20; implicitHeight: 20; radius: 10
                                    color: st.done ? Theme.p : "transparent"
                                    border.width: st.done ? 0 : 1.5
                                    border.color: st.cur ? Theme.p : Theme.o
                                    Txt { anchors.centerIn: parent; text: st.done ? "✓" : String(st.index + 1); size: 11; weight: Font.DemiBold; color: st.done ? Theme.pText : st.cur ? Theme.t : Theme.tv }
                                }
                                Txt { Layout.fillWidth: true; text: st.modelData; color: st.index <= root.step ? Theme.t : Theme.tv }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.step = st.index }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.ov }
                // ---------- contenido ----------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.topMargin: 24; Layout.bottomMargin: 18
                    spacing: 14
                    ColumnLayout {
                        spacing: 4
                        Txt { text: root.titles[root.step][0]; size: 19; weight: Font.DemiBold }
                        Txt { text: root.titles[root.step][1]; muted: true }
                    }
                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: [stepRegion, stepStyle, stepWall, stepBar, stepTools, stepDone][root.step]
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Button { h: 34; text: "Atrás"; opacity: root.step === 0 ? 0.4 : 1; onClicked: root.step = Math.max(0, root.step - 1) }
                        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Paso " + (root.step + 1) + " de 6 · los cambios se ven al instante detrás"; size: 11.5; muted: true; tabular: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        Button {
                            h: 34; kind: "primary"
                            text: root.step === 5 ? "Empezar" : root.step === 4 ? (Object.values(root.packs).some(v => v) ? "Instalar y seguir" : "Siguiente") : "Siguiente"
                            onClicked: {
                                if (root.step === 4 && !root.installed) root.install();
                                if (root.step === 5) { root.finish(); Shell.close(); }
                                else root.step++;
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- pasos ----------
    component Row44: Rectangle {
        id: r44
        property string k: ""
        default property alias content: slot.data
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.r(7)
        color: Theme.fill2
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
            Txt { text: r44.k; muted: true }
            Item { id: slot; implicitHeight: 32; Layout.fillWidth: true }
        }
    }
    Component {
        id: stepRegion
        ColumnLayout {
            spacing: 10
            Row44 {
                k: "Idioma"
                Dropdown {
                    anchors.fill: parent; flat: true; popupWidth: 280
                    model: root.locales.map(l => [l, root.localeLabel(l)])
                    current: root.lang
                    onPicked: l => { root.lang = l; Quickshell.execDetached(["localectl", "set-locale", "LANG=" + l, "LC_TIME=" + (root.region || l)]); }
                }
            }
            Row44 {
                k: "Región y formatos"
                Dropdown {
                    anchors.fill: parent; flat: true; popupWidth: 280
                    model: root.locales.map(l => [l, root.localeLabel(l)])
                    current: root.region
                    onPicked: l => { root.region = l; Quickshell.execDetached(["localectl", "set-locale", "LANG=" + (root.lang || l), "LC_TIME=" + l, "LC_NUMERIC=" + l, "LC_MONETARY=" + l, "LC_PAPER=" + l, "LC_MEASUREMENT=" + l]); }
                }
            }
            Row44 {
                k: "Teclado"
                Dropdown {
                    anchors.fill: parent; flat: true; popupWidth: 280
                    readonly property var kb: Settings.get("kbLayouts", ["latam", "us"])
                    model: [["latam", "Español (Latinoamérica)"], ["es", "Español (España)"], ["us", "English (US)"], ["us:intl", "English (US, internacional)"], ["gb", "English (UK)"], ["br", "Português (Brasil)"], ["pt", "Português"], ["fr", "Français"], ["de", "Deutsch"], ["it", "Italiano"]]
                    current: kb[0]
                    onPicked: k => Settings.set("kbLayouts", [k].concat(kb.filter(x => x !== k)).slice(0, 3))
                }
            }
            Row44 {
                k: "Zona horaria"
                Dropdown {
                    anchors.fill: parent; flat: true; popupWidth: 300; searchable: true
                    model: root.zones.map(z => [z, z.replace(/_/g, " ").replace("/", " · ")])
                    current: root.zone
                    onPicked: z => { root.zone = z; Quickshell.execDetached(["timedatectl", "set-timezone", z]); }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: stepStyle
        ColumnLayout {
            spacing: 12
            Txt { text: "Estilo de las superficies"; muted: true }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: [["aurora", "Aurora", "Vidrio esmerilado con un toque de color"], ["flat", "Material", "Sólido y ligero, como Android"],
                            ["mica", "Mica", "Casi opaco y sobrio, como Windows 11"], ["suave", "Suave", "Tarjetas pastel con sombras difusas"]]
                    Rectangle {
                        required property var modelData
                        readonly property bool on: Settings.get("estilo", "aurora") === modelData[0]
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: Theme.r(8)
                        color: modelData[0] === "aurora" ? Qt.alpha(Theme.s1, 0.35) : modelData[0] === "mica" ? Qt.alpha(Theme.s1, 0.8)
                             : modelData[0] === "suave" ? Qt.tint(Theme.s3, Qt.alpha(Theme.p, 0.12)) : Theme.s3
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.p : Theme.ov
                        ColumnLayout {
                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 11
                            spacing: 2
                            Txt { text: parent.parent.modelData[1]; weight: Font.DemiBold }
                            Txt { text: parent.parent.modelData[2]; size: 11.5; muted: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("estilo", parent.modelData[0]) }
                    }
                }
            }
            Txt { text: "Color"; muted: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [["auto", "Automático", Theme.p, Theme.pc], ["elegir", "Elegir", "#A9C1D9", "#2C3E50"], ["mono", "Monocromo", "#E8E8E8", "#3A3A3A"]]
                    Rectangle {
                        required property var modelData
                        readonly property bool on: Settings.get("colorMode", "auto") === modelData[0]
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Theme.r(8)
                        color: "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.p : Theme.ov
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12
                            spacing: 10
                            Row { spacing: 2; Rectangle { width: 12; height: 24; radius: Theme.r(3); color: parent.parent.parent.modelData[2] } Rectangle { width: 12; height: 24; radius: Theme.r(3); color: parent.parent.parent.modelData[3] } }
                            Txt { Layout.fillWidth: true; text: parent.parent.modelData[1]; weight: Font.Medium }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("colorMode", parent.modelData[0]) }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: stepWall
        ColumnLayout {
            spacing: 8
            Wallpapers { id: wp }
            readonly property var pick: {
                const pref = ["amanecer", "lago", "bruma"];
                const a = pref.map(n => wp.images.find(f => wp.name(f) === n)).filter(Boolean);
                return a.concat(wp.images.filter(f => !a.includes(f))).slice(0, 6);
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10; rowSpacing: 10
                Repeater {
                    model: parent.parent.pick
                    ColumnLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 4
                        Thumb { Layout.fillWidth: true; implicitHeight: 96; r: 8; file: parent.modelData; selected: wp.current === parent.modelData; onClicked: wp.set(parent.modelData) }
                        Txt { Layout.fillWidth: true; text: wp.name(parent.modelData); weight: Font.Medium; size: 12 }
                    }
                }
            }
            Txt { visible: wp.images.length === 0; muted: true; text: "No hay fondos todavía. Pon imágenes en ~/Imágenes/Fondos." }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: stepBar
        ColumnLayout {
            spacing: 8
            readonly property string cur: Settings.get("barPos", "abajo") === "abajo" && Settings.get("barMode", "fija") === "fija" ? "abajo"
                : Settings.get("barPos", "abajo") === "arriba" && Settings.get("barMode", "fija") !== "fija" ? "arriba" : Settings.get("barPos", "abajo") === "izquierda" ? "izq" : ""
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [["abajo", "Fija abajo", "abajo", "fija"], ["arriba", "Flotante arriba", "arriba", "flotante"], ["izq", "Lateral", "izquierda", "fija"]]
                    ColumnLayout {
                        id: bo
                        required property var modelData
                        readonly property bool on: parent.parent.cur === modelData[0]
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 96
                            radius: Theme.r(8)
                            color: Theme.fill2
                            border.width: bo.on ? 2 : 1
                            border.color: bo.on ? Theme.p : Theme.ov
                            Rectangle {
                                color: Theme.p
                                radius: bo.modelData[0] === "arriba" ? 4 : 0
                                x: bo.modelData[0] === "arriba" ? 6 : parent.border.width
                                y: bo.modelData[0] === "arriba" ? 6 : bo.modelData[0] === "abajo" ? parent.height - 10 - parent.border.width : parent.border.width
                                width: bo.modelData[0] === "izq" ? 10 : parent.width - x * 2
                                height: bo.modelData[0] === "izq" ? parent.height - parent.border.width * 2 : 10
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setMany({ barPos: bo.modelData[2], barMode: bo.modelData[3] }) }
                        }
                        Txt { text: bo.modelData[1]; weight: Font.Medium }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: stepTools
        ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Txt { text: "Gestor de archivos"; muted: true; Layout.preferredWidth: 116 }
                Segmented {
                    Layout.fillWidth: true
                    h: 38
                    model: [{ key: "nautilus", label: "Nautilus\n(recomendado)" }, { key: "dolphin", label: "Dolphin\n(alt. KDE)" }, { key: "yazi", label: "Yazi (terminal)" }]
                    current: root.fm
                    onPicked: k => root.fm = k
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: root.packDefs
                    Rectangle {
                        id: pk
                        required property var modelData
                        readonly property bool on: !!root.packs[modelData[0]]
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 62
                        radius: Theme.r(7)
                        color: on ? Qt.alpha(Theme.p, 0.12) : "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.p : Theme.ov
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                            spacing: 2
                            Item { Layout.fillHeight: true }
                            Txt { Layout.fillWidth: true; text: (pk.on ? "✓ " : "+ ") + pk.modelData[1]; weight: Font.DemiBold }
                            Txt { Layout.fillWidth: true; text: root.profileTools(pk.modelData[0]).map(t => t.name.replace(/ \(.*\)/, "")).slice(0, 4).join(", "); size: 11.5; muted: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                            Item { Layout.fillHeight: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const p = Object.assign({}, root.packs); p[pk.modelData[0]] = !pk.on; root.packs = p; root.installed = false; } }
                    }
                }
            }
            Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Se abre una terminal con el comando para que lo veas y confirmes" + (Pkg.snapper ? "; antes se crea un punto de restauración." : ".") + " Más apps en el Centro de aplicaciones (Ajustes › Aplicaciones)." }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: stepDone
        ColumnLayout {
            spacing: 6
            Repeater {
                model: [
                    ["Idioma", root.localeLabel(root.lang)],
                    ["Estilo", ({ aurora: "Aurora", flat: "Material", mica: "Mica", suave: "Suave", tonal: "Sólido" })[Settings.get("estilo", "aurora")] ?? "Aurora"],
                    ["Color", Settings.get("colorMode", "auto") === "auto" ? "Automático (del fondo)" : Settings.get("colorMode", "auto") === "mono" ? "Monocromo" : Theme.paletteName],
                    ["Barra", Settings.get("barPos", "abajo") === "izquierda" ? "Lateral" : (Settings.get("barMode", "fija") === "fija" ? "Fija " : "Flotante ") + Settings.get("barPos", "abajo")],
                    ["Archivos", ({ nautilus: "Nautilus", dolphin: "Dolphin", yazi: "Yazi" })[root.fm]],
                    ["Aplicaciones", root.packDefs.filter(p => root.packs[p[0]]).map(p => p[1]).join(", ") || "Ninguna"]
                ]
                Kv { required property var modelData; h: 34; k: modelData[0]; v: modelData[1]; bold: false }
            }
            Txt { Layout.fillWidth: true; Layout.topMargin: 6; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Todo se puede cambiar después en Ajustes (Super + I)" + (Pkg.snapper ? ". Antes de instalar se crea un punto de restauración." : ".") + " Este asistente vuelve a estar en Ajustes › Aplicaciones." }
            RowLayout {
                Layout.topMargin: 4
                spacing: 8
                Button { h: 32; text: "Abrir el centro de aplicaciones"; onClicked: { root.finish(); Shell.open("herramientas"); } }
                Button { h: 32; text: "Abrir Ajustes"; onClicked: { root.finish(); Shell.open("ajustesapp"); } }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
