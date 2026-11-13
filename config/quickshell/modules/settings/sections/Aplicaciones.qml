// Ajustes › Aplicaciones — acceso al Centro de aplicaciones (vista "herramientas", catálogo
// config/tools/catalog.json) y al asistente de bienvenida (vista "bienvenida"), con lo instalado por categoría,
// las fuentes de software de esta distro (repos, AUR, Flatpak, AppImage) y una búsqueda que abre la tienda. Las
// listas de apps (instaladas, por categoría, recomendadas) están en el propio Centro (categoría «Instaladas»): Ajustes
// es para ajustes.
// Misma lógica que la tienda y la Bienvenida: services/Pkg.qml. Las apps de HyprFrijol por nivel (ui/AppTiers.qml → scripts/hf-apps) están en el Centro (cat:hyprfrijol)
// («Instaladas en este equipo», con «Desinstalar», es ui/InstalledApps.qml dentro del Centro: Shell.open("herramientas", "cat:instaladas")).
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
    readonly property bool hasGearLever: Pkg.gearlever || !!Pkg.installed["it.mijorus.gearlever"]

    function openCenter(arg): void { Shell.open("herramientas", arg ?? ""); }

    // ---------- portada ----------
    Section {
        Layout.fillWidth: true
        pad: 20
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 64; implicitHeight: 64; radius: Theme.r(14)
                color: Theme.pc
                Icon { anchors.centerIn: parent; name: "package"; size: 30; stroke: 1.6; color: Theme.pcText }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
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
                    Button { h: 36; text: "Ver las instaladas"; onClicked: root.openCenter("cat:instaladas") }
                    Button { h: 36; text: "Apps de HyprFrijol"; onClicked: root.openCenter("cat:hyprfrijol") }
                    Button { h: 36; text: "Volver a ver la bienvenida"; onClicked: Shell.open("bienvenida") }
                    Item { Layout.fillWidth: true }
                }
                Txt { Layout.fillWidth: true; Layout.topMargin: 2; text: "También con Super + Shift + I o escribiendo «instalar» en Spotlight"; muted: true; size: 11.5; wrapMode: Text.WordWrap }
            }
        }
    }

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
}
