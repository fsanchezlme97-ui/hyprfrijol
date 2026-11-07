// Ajustes › Aplicaciones — acceso al Centro de aplicaciones (vista "herramientas", catálogo
// config/tools/catalog.json) y al asistente de bienvenida (vista "bienvenida"), con lo instalado por categoría,
// las fuentes de software de esta distro (repos, AUR, Flatpak, AppImage) y una búsqueda que abre la tienda.
// Misma lógica que la tienda y la Bienvenida: services/Pkg.qml. Arriba, las apps de HyprFrijol por nivel (ui/AppTiers.qml → scripts/hf-apps).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    Component.onCompleted: Pkg.refresh()

    function iconOf(t): string {
        for (const n of [].concat(t.icon ?? [])) { const p = Quickshell.iconPath(n, true); if (p) return p; }
        return "";
    }
    readonly property var tools: Pkg.tools
    readonly property var instMap: { const m = {}; tools.forEach(t => m[t.id] = Pkg.isToolInstalled(t)); return m; }
    readonly property int nInstalled: tools.filter(t => instMap[t.id]).length
    readonly property int nUpdates: tools.filter(t => instMap[t.id] && Pkg.updateFor(t)).length
    readonly property var cats: (Pkg.catalog.categories ?? []).filter(c => !["top", "nuevo", "sel"].includes(c.key)).map(c => {
        const all = tools.filter(t => c.key === "gnome" ? t.gnome : t.cat === c.key);     // «Apps de GNOME»: las principales (flag g)
        return { key: c.key, label: c.label, glyph: c.glyph, total: all.length, inst: all.filter(t => instMap[t.id]).length };
    })
    readonly property var suggestions: tools.filter(t => t.star && !instMap[t.id] && iconOf(t) !== "").slice(0, 8)
    readonly property bool hasGearLever: Pkg.gearlever || !!Pkg.installed["it.mijorus.gearlever"]

    function openCenter(arg): void { Shell.open("herramientas", arg ?? ""); }

    // ---------- portada ----------
    Section {
        Layout.fillWidth: true
        pad: 20
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 64; implicitHeight: 64; radius: Theme.r(14)
                color: Theme.pc
                Icon { anchors.centerIn: parent; name: "package"; size: 30; stroke: 1.6; color: Theme.pcText }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Txt { text: "Centro de aplicaciones"; size: 19; weight: Font.DemiBold }
                Txt {
                    Layout.fillWidth: true
                    text: root.tools.length + " apps elegidas para " + (Pkg.distroName || "Linux") + " + Hyprland. Cada una se instala de la mejor fuente disponible "
                        + "(" + Pkg.orderText + ") y puedes cambiarla. Marca las que quieras o elige un paquete (Oficina, Creativo, Gamer…): "
                        + "se instalan en una terminal donde ves cada comando" + (Pkg.snapper ? ", y antes se crea un punto de restauración." : ".")
                    muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    Field {
                        id: q
                        Layout.fillWidth: true
                        Layout.maximumWidth: 360
                        h: 36
                        placeholder: "Buscar una app o un paquete…"
                        onAccepted: if (text.trim()) { root.openCenter("q:" + text.trim()); text = ""; }
                    }
                    Button { h: 36; kind: "primary"; text: "Abrir el centro"; onClicked: root.openCenter(q.text.trim() ? "q:" + q.text.trim() : "") }
                    Button { h: 36; text: "Volver a ver la bienvenida"; onClicked: Shell.open("bienvenida") }
                    Item { Layout.fillWidth: true }
                }
                Txt { Layout.fillWidth: true; Layout.topMargin: 2; text: "También con Super + Shift + I o escribiendo «instalar» en Spotlight"; muted: true; size: 11.5; wrapMode: Text.WordWrap }
            }
        }
    }

    // ---------- apps de hyprfrijol por nivel (install/apps.json · scripts/hf-apps) ----------
    AppTiers { Layout.fillWidth: true }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        // ---------- instaladas por categoría ----------
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Instaladas del catálogo"
            headerRight: Txt { text: root.nInstalled + " de " + root.tools.length; muted: true; tabular: true }
            Repeater {
                model: root.cats
                Rectangle {
                    id: cr
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.r(6)
                    color: cma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10
                        Txt { Layout.preferredWidth: 16; text: cr.modelData.glyph; color: Theme.tv; horizontalAlignment: Text.AlignHCenter }
                        Txt { Layout.fillWidth: true; text: cr.modelData.label; elide: Text.ElideRight }
                        Rectangle {   // barra de progreso
                            implicitWidth: 80; implicitHeight: 4; radius: Theme.r(2)
                            color: Theme.s4
                            Rectangle { width: parent.width * (cr.modelData.total ? cr.modelData.inst / cr.modelData.total : 0); height: parent.height; radius: parent.radius; color: Theme.p }
                        }
                        Txt { Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; text: cr.modelData.inst + " / " + cr.modelData.total; muted: true; tabular: true; size: 12 }
                    }
                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openCenter("cat:" + cr.modelData.key) }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            // ---------- fuentes de software ----------
            Section {
                Layout.fillWidth: true
                title: "Fuentes de software"
                headerRight: Txt { text: Pkg.distroName || ""; muted: true }
                InfoRow {
                    separator: false
                    glyph: "R"; lit: true
                    label: "Repositorios (" + Pkg.pmName + ")"
                    sub: "Primera opción: paquetes de " + (Pkg.distroName || "tu distro") + (Pkg.family === "fedora" ? "; añade RPM Fusion o COPR si hace falta" : "")
                }
                InfoRow {
                    visible: Pkg.family === "arch"
                    glyph: "AUR"; lit: !!Pkg.aur
                    label: "AUR"
                    sub: Pkg.aur ? "Con " + Pkg.aur + " · segunda opción" : "Sin ayudante: se instala paru la primera vez que haga falta"
                    Button { visible: Pkg.probed && !Pkg.aur; h: 30; text: "Instalar paru"; onClicked: Pkg.run(Pkg.helperCmds(), "Instalar paru") }
                }
                InfoRow {
                    glyph: "FP"; lit: Pkg.flatpak
                    label: "Flatpak · Flathub"
                    sub: Pkg.flatpak ? "Activo · si la app no está en los repos" + (Pkg.family === "arch" ? " ni en AUR" : "") : "No está instalado"
                    Button { visible: Pkg.probed && !Pkg.flatpak; h: 30; text: "Activar"; onClicked: Pkg.run(Pkg.flatpakCmds(), "Activar Flatpak") }
                }
                InfoRow {
                    glyph: "AI"; lit: root.hasGearLever
                    label: "AppImage · Gear Lever"
                    sub: root.hasGearLever ? "Gear Lever integra los AppImage en el menú" : "Instala Gear Lever para integrar los AppImage"
                    Button { visible: !root.hasGearLever; h: 30; text: "Elegir Gear Lever"; onClicked: root.openCenter("gearlever") }
                }
                InfoRow {
                    visible: root.nUpdates > 0
                    icon: "download"; lit: true
                    label: root.nUpdates + (root.nUpdates === 1 ? " app del catálogo tiene actualización" : " apps del catálogo tienen actualización")
                    sub: "Según la última comprobación"
                    Button { h: 30; kind: "primary"; text: "Ver actualizaciones"; onClicked: Shell.open("actualizaciones") }
                }
            }
            // ---------- recomendadas que aún no tienes ----------
            Section {
                Layout.fillWidth: true
                title: "Recomendadas que aún no tienes"
                visible: root.suggestions.length > 0
                Repeater {
                    model: root.suggestions
                    Rectangle {
                        id: sr
                        required property var modelData
                        readonly property var src: Pkg.source(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.r(6)
                        color: sma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 12
                            Image {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                source: root.iconOf(sr.modelData)
                                sourceSize: Qt.size(60, 60)
                                asynchronous: true; smooth: true; mipmap: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Txt { Layout.fillWidth: true; text: sr.modelData.name; weight: Font.DemiBold; elide: Text.ElideRight }
                                Txt { Layout.fillWidth: true; text: sr.modelData.desc; muted: true; size: 11.5; elide: Text.ElideRight }
                            }
                            Rectangle {
                                visible: !!sr.src
                                implicitWidth: sl.implicitWidth + 12; implicitHeight: 18; radius: Theme.r(4)
                                // mismos colores y nombres que las insignias del Centro de aplicaciones (Pkg.hue / longLabels)
                                color: Qt.alpha(Pkg.hue(sr.src?.key ?? ""), Theme.light ? 0.15 : 0.22)
                                border.width: 1; border.color: Qt.alpha(Pkg.hue(sr.src?.key ?? ""), 0.55)
                                Txt { id: sl; anchors.centerIn: parent; text: Pkg.longLabels[sr.src?.key] ?? sr.src?.label ?? ""; size: 10; weight: Font.Bold
                                    color: Theme.light ? Qt.darker(Pkg.hue(sr.src?.key ?? ""), 1.55) : Qt.lighter(Pkg.hue(sr.src?.key ?? ""), 1.5) }
                            }
                        }
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openCenter("app:" + sr.modelData.id) }     // abre su ficha
                    }
                }
            }
        }
    }
}
