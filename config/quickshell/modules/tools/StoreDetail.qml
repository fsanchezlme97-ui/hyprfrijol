// Ficha de una app dentro del Centro de aplicaciones (se abre al pulsar una tarjeta; «Volver» o Esc regresa):
// icono, nombre, resumen, capturas, descripción larga, de dónde instalarla (con qué significa cada fuente),
// versión, tamaño, licencia, web, votos de AUR… y alternativas. Los datos los trae StoreInfo (Flathub, AUR, pacman,
// metainfo local) en segundo plano; mientras tanto se ve lo del catálogo.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Item {
    id: dt
    property var tool: null
    property var store: null
    signal back()
    readonly property var t: tool ?? ({})
    readonly property bool catalogApp: !!t.pkgs && !String(t.id ?? "").startsWith("s:")
    readonly property bool inst: catalogApp ? Pkg.isToolInstalled(t) : (t.installed || Pkg.isInstalled(t.pkg ?? ""))
    readonly property bool on: (catalogApp ? !!store?.sel[t.id] : !!store?.extra[t.id]) && !inst
    readonly property var upd: inst && catalogApp ? Pkg.updateFor(t) : null
    readonly property var srcs: catalogApp ? Pkg.sources(t) : []
    readonly property var cur: catalogApp ? Pkg.source(t) : (t.key ? t : null)
    readonly property string curKey: cur?.key ?? ""
    readonly property string catLabel: (Pkg.catalog.categories ?? []).find(c => c.key === t.cat)?.label ?? "Búsqueda"
    readonly property string compat: t.preview ? "Nativa · no oficial" : t.alpha ? "Por verificar" : t.web ? "Navegador" : t.term ? "Terminal" : t.xw ? "XWayland" : catalogApp ? "Wayland nativa" : ""
    // Alternativas: de la misma categoría (las de GNOME ↔ KDE primero entre sí)
    readonly property var alts: !catalogApp ? [] : Pkg.tools.filter(x => x.id !== t.id && x.cat === t.cat)
        .sort((a, b) => ((b.gnome || b.kde) && (t.gnome || t.kde) ? 1 : 0) - ((a.gnome || a.kde) && (t.gnome || t.kde) ? 1 : 0) || (b.star ? 1 : 0) - (a.star ? 1 : 0))
        .slice(0, 8)

    StoreInfo { id: info; tool: dt.tool }

    Shortcut { sequence: "Escape"; enabled: dt.visible; onActivated: dt.back() }
    Shortcut { sequence: "Left"; enabled: dt.visible; onActivated: shots.step(-1) }
    Shortcut { sequence: "Right"; enabled: dt.visible; onActivated: shots.step(1) }

    Flickable {
        id: fl
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 36
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: fl.contentHeight > fl.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
        Connections { target: dt; function onToolChanged() { fl.contentY = 0; } }

        ColumnLayout {
            id: col
            x: 18; y: 14
            width: fl.width - 36
            spacing: 16

            // ---------- volver ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Button { h: 30; text: "‹  Volver"; onClicked: dt.back() }
                Txt { text: dt.catLabel + "  ›  " + (dt.t.name ?? ""); muted: true; Layout.fillWidth: true }
                BusyIndicator { visible: info.loading; running: visible; implicitWidth: 20; implicitHeight: 20 }
                Txt { visible: info.loading; text: "Cargando detalles…"; muted: true; size: 11.5 }
            }

            // ---------- cabecera ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                StoreIcon { Layout.alignment: Qt.AlignTop; tool: dt.t; store: dt.store; size: 96; fallback: info.iconUrl }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Txt { text: dt.t.name ?? ""; size: 26; weight: Font.DemiBold }
                        Txt { visible: !!dt.t.star; text: "★ recomendada"; size: 12; color: Theme.ter }
                    }
                    Txt { Layout.fillWidth: true; text: dt.t.desc || info.summary; size: 14; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    Txt { visible: !!info.summary && info.summary !== dt.t.desc; Layout.fillWidth: true; text: info.summary; muted: true; size: 12.5; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 8
                        StoreBadge { tool: dt.catalogApp ? dt.t : null; key: dt.catalogApp ? "" : (dt.t.key ?? ""); big: true }
                        Txt { visible: dt.compat !== ""; text: dt.compat; size: 12; weight: Font.DemiBold; color: dt.t.xw || dt.t.preview ? Theme.ter : Theme.p }
                        Txt { visible: !!info.developer; text: "·  " + info.developer; muted: true; size: 12 }
                        Txt { visible: !!dt.t.alt && dt.t.alt !== "—"; text: "·  alternativa a " + dt.t.alt; muted: true; size: 12 }
                    }
                    // Aviso tras instalar (catalog.json «hint»)
                    Rectangle {
                        visible: !!dt.t.hint
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        implicitHeight: hintTxt.implicitHeight + 16
                        radius: Theme.r(8)
                        color: Qt.alpha(Theme.p, 0.1)
                        border.width: 1
                        border.color: Qt.alpha(Theme.p, 0.25)
                        Txt { id: hintTxt; x: 12; y: 8; width: parent.width - 24; text: "ⓘ  " + (dt.t.hint ?? ""); size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    Button {
                        visible: !dt.inst && !!dt.cur && dt.curKey !== "none"
                        Layout.fillWidth: true
                        h: 36; kind: "primary"
                        text: dt.curKey === "web" ? "Añadir como web app" : dt.curKey === "url" || dt.curKey === "appimage" ? "Ir a la descarga" : "Instalar"
                        onClicked: Pkg.install([dt.t], "Instalar " + dt.t.name)
                    }
                    Button {
                        visible: !dt.inst
                        Layout.fillWidth: true
                        h: 32
                        text: dt.on ? "✓ En la selección" : "+ Añadir a la selección"
                        onClicked: dt.catalogApp ? dt.store.toggle(dt.t.id) : dt.store.toggleExtra(dt.t)
                    }
                    Button { visible: !!dt.upd; Layout.fillWidth: true; h: 36; kind: "primary"; text: "Actualizar a " + (dt.upd?.to ?? ""); onClicked: Pkg.update(dt.t) }
                    Button { visible: dt.inst && dt.catalogApp && (!!Pkg.entryOf(dt.t) || !!dt.t.bin); Layout.fillWidth: true; h: 36; kind: dt.upd ? "outline" : "primary"; text: "Abrir"; onClicked: Pkg.launch(dt.t) }
                    Button { visible: dt.inst && Pkg.uninstallCmd(dt.catalogApp ? dt.t : Object.assign({}, dt.t)) !== ""; Layout.fillWidth: true; h: 32; text: "Desinstalar"
                        onClicked: Pkg.uninstall(dt.catalogApp ? dt.t : Object.assign({}, dt.t)) }
                    Txt { visible: dt.inst; Layout.alignment: Qt.AlignHCenter; text: "Instalada" + (Pkg.installedVia(dt.t) ? " desde " + (Pkg.longLabels[Pkg.installedVia(dt.t).key] ?? "") : ""); size: 11.5; color: Theme.p; weight: Font.DemiBold }
                }
            }

            // ---------- capturas ----------
            StoreShots {
                id: shots
                Layout.fillWidth: true
                // sin capturas se queda en una franja con el aviso
                Layout.preferredHeight: info.shots.length === 0 && !loading ? 64 : Math.round(Math.min(440, Math.max(260, dt.width * 0.36)))
                model: info.shots
                loading: info.fhState === "loading" || !info.localDone
                emptyText: info.fhState === "err" ? "No se pudo conectar con Flathub para ver las capturas (¿sin conexión?)"
                    : info.flatpakId ? "Esta app no tiene capturas publicadas"
                    : "Sin capturas: esta app no tiene ficha en Flathub" + (dt.inst ? "" : " · si trae las suyas, se verán al instalarla")
            }

            // ---------- descripción + información ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12
                    Txt { text: "Acerca de " + (dt.t.name ?? ""); size: 16; weight: Font.DemiBold }
                    Txt {
                        Layout.fillWidth: true
                        text: info.description || ("<p>" + (dt.t.desc ?? "") + "</p>")
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap; elide: Text.ElideNone
                        size: 13; lineHeight: 1.15
                        onLinkActivated: l => Qt.openUrlExternally(l)
                    }
                    Txt {
                        visible: info.fhState === "err" || info.aurState === "err"
                        Layout.fillWidth: true
                        text: "No se pudieron descargar algunos detalles (" + [info.fhState === "err" ? "Flathub" : "", info.aurState === "err" ? "AUR" : ""].filter(Boolean).join(" y ")
                            + "). Comprueba la conexión; se reintentará al volver a abrir la ficha."
                        color: Theme.danger; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                    ColumnLayout {
                        visible: !!info.release?.description
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8
                        Txt { text: "Novedades de la versión " + (info.release?.version ?? ""); size: 14; weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; text: info.release?.description ?? ""; textFormat: Text.StyledText; wrapMode: Text.WordWrap; elide: Text.ElideNone; muted: true; size: 12.5; lineHeight: 1.1 }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 330
                    Layout.maximumWidth: 330
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    // De dónde instalarla
                    Txt { text: "Instalar desde"; size: 14; weight: Font.DemiBold }
                    Repeater {
                        model: dt.srcs
                        StoreSourceRow {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            src: modelData; tool: dt.t; first: index === 0
                            version: info.versionFor(modelData.key)
                            onPicked: Pkg.setSource(dt.t.id, modelData.key)
                        }
                    }
                    Txt { visible: !dt.catalogApp && !!dt.t.key; Layout.fillWidth: true; text: Pkg.explain[dt.t.key] ?? ""; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    // Datos
                    Txt { Layout.topMargin: 12; text: "Información"; size: 14; weight: Font.DemiBold }
                    Repeater {
                        model: info.rows(dt.curKey)
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12
                            Txt { Layout.preferredWidth: 104; Layout.alignment: Qt.AlignTop; text: modelData[0]; muted: true; size: 12 }
                            Txt { Layout.fillWidth: true; text: modelData[1]; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: modelData[0] === "Aviso" ? Theme.danger : Theme.t }
                        }
                    }
                    Txt { visible: info.rows(dt.curKey).length === 0 && !info.loading; text: "Sin más datos de esta fuente"; muted: true; size: 12 }
                    // Enlaces
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8
                        Repeater {
                            model: [
                                info.homepage ? ["Web del proyecto", info.homepage] : null,
                                info.fh ? ["Ver en Flathub", "https://flathub.org/apps/" + info.flatpakId] : null,
                                info.aurInfo ? ["Ver en AUR", "https://aur.archlinux.org/packages/" + info.aurPkg] : null,
                                info.pac?.Repository && info.pac.Repository !== "cachyos" ? ["Ver en Arch", "https://archlinux.org/packages/?q=" + encodeURIComponent(info.pac.Name)] : null,
                                info.fh?.urls?.bugtracker ? ["Informar de un fallo", info.fh.urls.bugtracker] : null,
                                dt.curKey === "web" || dt.curKey === "url" || dt.curKey === "appimage" ? ["Abrir " + dt.cur.pkg.replace(/^https?:\/\//, "").replace(/\/$/, ""), dt.cur.pkg] : null
                            ].filter(Boolean)
                            Button { required property var modelData; h: 28; text: modelData[0] + "  ↗"; onClicked: Qt.openUrlExternally(modelData[1]) }
                        }
                    }
                }
            }

            // ---------- alternativas ----------
            ColumnLayout {
                visible: dt.alts.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 12
                Txt { text: "Alternativas en «" + dt.catLabel + "»"; size: 16; weight: Font.DemiBold }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: dt.alts
                        StoreMini { required property var modelData; tool: modelData; store: dt.store; onPicked: dt.store.openDetail(modelData) }
                    }
                }
            }
        }
    }
}
