// «Apps de GNOME recomendadas» (Centro de aplicaciones, categoría "gnome"): las apps principales de GNOME
// (flag "g" del catálogo) con un botón que marca todas las que faltan, y debajo las alternativas de KDE (flag "k").
// Mismas apps que el paquete «Esenciales» de la Bienvenida y Ajustes › Aplicaciones.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Flickable {
    id: gv
    property var store: null
    // Primero las de uso diario (categoría «Apps básicas»), luego navegador, terminal y monitor
    readonly property var gnome: Pkg.tools.filter(t => t.gnome && (store?.pass(t) ?? true)).map((t, i) => [t, i])
        .sort((a, b) => (a[0].cat === "base" ? 0 : 1) - (b[0].cat === "base" ? 0 : 1) || a[1] - b[1]).map(x => x[0])
    readonly property var kde: Pkg.tools.filter(t => t.kde && (store?.pass(t) ?? true))
    // Recuento y «Instalar todas» con todas (no solo las que deja ver el filtro)
    readonly property var gMissing: Pkg.tools.filter(t => t.gnome && !Pkg.isToolInstalled(t))
    readonly property var kMissing: Pkg.tools.filter(t => t.kde && !Pkg.isToolInstalled(t))
    readonly property int gTotal: Pkg.tools.filter(t => t.gnome).length
    readonly property int cols: width >= 1080 ? 3 : 2
    readonly property real cw: Math.floor((width - 16) / cols)
    contentWidth: width
    contentHeight: col.implicitHeight + 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: gv.contentHeight > gv.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }

    function selectAll(list): void {
        const s = Object.assign({}, store.sel);
        list.forEach(t => s[t.id] = true);
        store.sel = s;
    }

    ColumnLayout {
        id: col
        width: gv.width - 10
        spacing: 12
        // ---------- portada ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.rightMargin: 8
            implicitHeight: hero.implicitHeight + 36
            radius: Theme.r(8)
            color: Qt.alpha(Theme.p, Theme.light ? 0.08 : 0.12)
            border.width: 1
            border.color: Qt.alpha(Theme.p, 0.35)
            RowLayout {
                id: hero
                x: 20; y: 18; width: parent.width - 40
                spacing: 16
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 56; implicitHeight: 56; radius: Theme.r(14)
                    color: Theme.pc
                    Txt { anchors.centerIn: parent; text: "◉"; size: 26; color: Theme.pcText }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Txt { text: "Apps de GNOME recomendadas"; size: 18; weight: Font.DemiBold }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap; elide: Text.ElideNone; muted: true
                        text: "Archivos, imágenes, documentos, vídeos, música, calendario… Las apps oficiales de GNOME son ligeras, nativas de Wayland "
                            + "y encajan con el estilo del escritorio. Son las que HyprFrijol usa como predeterminadas."
                    }
                    Txt { text: (gv.gTotal - gv.gMissing.length) + " de " + gv.gTotal + " instaladas" + (gv.gnome.length < gv.gTotal ? " · el filtro oculta " + (gv.gTotal - gv.gnome.length) : ""); size: 12; weight: Font.DemiBold; color: Theme.p }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8
                    Button {
                        Layout.fillWidth: true
                        h: 36; kind: "primary"
                        enabled: gv.gMissing.length > 0
                        text: gv.gMissing.length ? "Instalar todas las recomendadas (" + gv.gMissing.length + ")" : "Ya tienes todas"
                        onClicked: gv.selectAll(gv.gMissing)
                    }
                    Txt { Layout.alignment: Qt.AlignHCenter; visible: gv.gMissing.length > 0; text: "Las marca abajo para que las revises"; muted: true; size: 11 }
                }
            }
        }
        // ---------- GNOME ----------
        Flow {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: gv.gnome
                StoreCard { required property var modelData; tool: modelData; store: gv.store; width: gv.cw; height: 104 }
            }
        }
        // ---------- KDE ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.rightMargin: 8
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Txt { text: "Alternativas de KDE"; size: 16; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: "Si prefieres apps Qt/KDE (más opciones, otro estilo), estas hacen lo mismo. Instala unas u otras, no hace falta tener las dos."; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
            Button { h: 32; enabled: gv.kMissing.length > 0; text: gv.kMissing.length ? "Marcar las de KDE (" + gv.kMissing.length + ")" : "Ya tienes todas"; onClicked: gv.selectAll(gv.kMissing) }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: gv.kde
                StoreCard { required property var modelData; tool: modelData; store: gv.store; width: gv.cw; height: 104 }
            }
        }
    }
}
