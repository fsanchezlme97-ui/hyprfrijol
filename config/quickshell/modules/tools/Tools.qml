// Centro de aplicaciones (design «Herramientas»): catálogo de apps (config/tools/catalog.json) por categorías,
// con paquetes (perfiles), filtros, búsqueda y selección múltiple. Cada app puede venir de varias fuentes
// (Repos, AUR, Flatpak, AppImage, Web…): se elige la mejor para esta distro (services/Pkg.qml) y se puede cambiar
// en la insignia de la tarjeta. Las instaladas se pueden abrir, desinstalar o actualizar.
// La búsqueda mira el catálogo y, si no hay nada (o con Intro), también repos + AUR + Flathub en segundo plano.
// «Instalar» abre una terminal con los comandos de la distro — nunca instala sin que el usuario lo vea.
// Pulsar una tarjeta abre su ficha (StoreDetail: capturas, descripción, versión, fuentes…); la casilla la marca.
// La insignia dice de dónde se instala («Repos oficiales», «AUR», «Flatpak», «AppImage»…) y los chips «Fuente» filtran.
// La categoría «Apps de GNOME» (StoreGnome) junta las apps principales de GNOME y sus alternativas de KDE.
// Vista "herramientas": Shell.open("herramientas", "<id de app>") la deja preseleccionada; "cat:<clave>" abre
// esa categoría; "q:<texto>" busca; "app:<id>" abre su ficha. También por IPC, Ajustes › Aplicaciones y Spotlight:
//   qs -p <repo>/config/quickshell ipc call tools open        · … tools detail <id>
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Scope {
    id: root
    property bool open: false
    property string cat: "top"
    property var sel: ({ btrfsa: true, pika: true, bazaar: true })
    property var extra: ({})            // resultados de la búsqueda en vivo elegidos: id → resultado
    property bool onlyWayland: false
    property bool hideAlpha: false
    property bool details: false
    property string query: ""
    property string mode: "cat"         // cat | live (resultados de repos/AUR/Flathub)
    property var detail: null           // app cuya ficha está abierta (del catálogo o un resultado de búsqueda)
    property string srcFilter: "all"    // all | repo | aur | flatpak | other: apps que se pueden instalar desde esa fuente

    readonly property var catalog: Pkg.catalog
    function show(arg): void {
        arg = typeof arg === "string" ? arg : "";
        detail = null;
        if (arg.startsWith("q:")) { setQuery(arg.slice(2)); searchNow(); }
        else if (arg.startsWith("app:")) { setQuery(""); detail = Pkg.tool(arg.slice(4)); }
        else {
            setQuery("");
            if (arg.startsWith("cat:")) cat = arg.slice(4);
            else if (arg) {
                const t = Pkg.tools.find(x => x.id === arg);
                if (t) { const s = Object.assign({}, sel); s[t.id] = true; sel = s; cat = "sel"; }
            }
        }
        Pkg.refresh();
        open = true;
    }
    onOpenChanged: if (!open) setQuery("")
    Connections {
        target: Shell
        function onOpened(v) { if (v === "herramientas") { root.show(Shell.arg); Shell.close(); } }
    }
    IpcHandler {
        target: "tools"
        function open(): void { root.show(""); }
        function select(id: string): void { root.show(id); }
        function search(q: string): void { root.show("q:" + q); }
        function source(id: string, key: string): void { Pkg.setSource(id, key); }
        function detail(id: string): void { root.show("app:" + id); }
        function filter(key: string): void { root.srcFilter = key; }
        function category(key: string): void { root.show("cat:" + key); }
        function result(i: int): void { if (Pkg.results[i]) root.detail = Pkg.results[i]; }     // ficha de un resultado de la búsqueda en vivo
        function close(): void { root.open = false; }
    }

    readonly property var all: Pkg.tools
    function passBase(t) { return (!onlyWayland || (!t.xw && !t.alpha && !t.preview)) && (!hideAlpha || (!t.alpha && !t.preview)); }
    function pass(t) { return passBase(t) && srcPass(t, srcFilter); }
    function srcPass(t, f): bool {
        if (f === "all") return true;
        return Pkg.sources(t).some(s => f === "other" ? !["repo", "aur", "flatpak"].includes(s.key) : s.key === f);
    }
    function inCat(t, k) { return k === "top" ? t.star : k === "nuevo" ? t.isNew : k === "sel" ? !!sel[t.id] : k === "gnome" ? t.gnome || t.kde : t.cat === k; }
    function openDetail(t): void { if (t) detail = t; }
    function installed(t) { return Pkg.isToolInstalled(t); }
    function toggle(id) { const s = Object.assign({}, sel); if (s[id]) delete s[id]; else s[id] = true; sel = s; }
    function toggleExtra(r) { const e = Object.assign({}, extra); if (e[r.id]) delete e[r.id]; else e[r.id] = r; extra = e; }
    // Icono real: el de la app instalada o los nombres del catálogo ("icon"); "" = se ve la inicial
    function iconOf(t): string {
        DesktopEntries.applications.values.length;
        const names = [].concat(t.icon ?? (t.pkg ? [t.pkg] : []));     // resultados de búsqueda: el nombre del paquete
        if (installed(t)) { const e = Pkg.entryOf(t); if (e?.icon) names.unshift(e.icon); }
        for (const n of names) { const p = Quickshell.iconPath(n, true); if (p) return p; }
        return "";
    }
    readonly property var catMatches: {
        const q = query.trim().toLowerCase();
        return q ? all.filter(t => (t.name + " " + t.desc + " " + t.alt + " " + Object.values(t.pkgs ?? {}).join(" ")).toLowerCase().includes(q)).filter(t => pass(t)) : [];
    }
    readonly property var chosen: all.filter(t => sel[t.id]).concat(Object.values(extra))
    readonly property var toInstall: chosen.filter(t => t.pkgs ? !installed(t) : !t.installed)
    readonly property var cmds: Pkg.commands(toInstall) ?? []
    readonly property string liveLabel: Pkg.family === "arch" ? (Pkg.aur ? "Repos, AUR" : "Repos") + (Pkg.flatpak ? " y Flathub" : "") : "Repos" + (Pkg.flatpak ? " y Flathub" : "")

    function setQuery(q): void {
        query = q;
        const t = q.trim();
        if (t) detail = null;
        if (!t) { mode = "cat"; debounce.stop(); return; }
        if (catMatches.length === 0) { mode = "live"; debounce.restart(); }
        else if (mode === "live") debounce.restart();
    }
    Timer { id: debounce; interval: 400; onTriggered: Pkg.search(root.query) }
    function searchNow(): void { if (!query.trim()) return; mode = "live"; debounce.stop(); Pkg.search(query); }


    LazyLoader {
        active: root.open
        FloatingWindow {
            title: "Centro de aplicaciones"
            implicitWidth: Math.max(980, Math.min(1480, (Shell.screen?.width ?? 1440) - 160))
            implicitHeight: Math.max(600, Math.min(940, (Shell.screen?.height ?? 900) - 140))
            minimumSize: Qt.size(980, 600)
            visible: true
            color: Theme.glassy ? Theme.winSolid : Theme.s1   // igual que Ajustes (Theme.winSolid)
            onVisibleChanged: if (!visible) root.open = false
            Shortcut { sequence: "Ctrl+W"; onActivated: root.open = false }
            Shortcut { sequence: "Ctrl+F"; onActivated: search.focusInput() }
            Component.onCompleted: search.text = root.query
            Connections {
                target: root
                function onQueryChanged() { if (search.text !== root.query) search.text = root.query; }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                // ---------- categorías ----------
                Rectangle {
                    Layout.preferredWidth: 228
                    Layout.fillHeight: true
                    color: Theme.bg
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.topMargin: 16
                        spacing: 2
                        Txt { text: "Aplicaciones"; size: 17; weight: Font.DemiBold; Layout.leftMargin: 12 }
                        Txt { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.bottomMargin: 10; text: root.all.length + " apps actuales para " + (Pkg.distroName || "Linux") + " + Hyprland"; muted: true; size: 11.5; wrapMode: Text.WordWrap }
                        Flickable {
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          contentHeight: catCol.implicitHeight
                          clip: true
                          boundsBehavior: Flickable.StopAtBounds
                          ScrollBar.vertical: ScrollBar { policy: parent.contentHeight > parent.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                          ColumnLayout {
                            id: catCol
                            width: parent.width
                            spacing: 2
                          Repeater {
                            model: root.catalog.categories
                            Rectangle {
                                id: ci
                                required property var modelData
                                readonly property bool on: root.cat === modelData.key && root.query === "" && !root.detail
                                readonly property int n: root.all.filter(t => root.inCat(t, modelData.key) && root.pass(t)).length + (modelData.key === "sel" ? Object.keys(root.extra).length : 0)
                                Layout.fillWidth: true
                                implicitHeight: 33
                                radius: Theme.r(5)
                                color: on ? Theme.selBg : cm.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 12
                                    Txt { Layout.preferredWidth: 14; text: ci.modelData.glyph; size: 12; color: ci.on ? Theme.selText : Theme.tv; horizontalAlignment: Text.AlignHCenter }
                                    Txt { Layout.fillWidth: true; text: ci.modelData.label; color: ci.on ? Theme.selText : Theme.t; weight: ci.on ? Font.DemiBold : Font.Normal }
                                    Txt { text: ci.n; size: 11.5; tabular: true; color: ci.on ? Theme.selText : Theme.tv }
                                }
                                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.cat = ci.modelData.key; root.detail = null; search.text = ""; } }
                            }
                          }
                          }
                        }
                        // Fuentes de software de este sistema, en orden de preferencia
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: srcBox.implicitHeight + 24
                            radius: Theme.r(6)
                            color: Theme.s3
                            ColumnLayout {
                                id: srcBox
                                x: 12; y: 12; width: parent.width - 24
                                spacing: 6
                                Txt { text: "Fuentes"; weight: Font.DemiBold; size: 12 }
                                // Leyenda: qué es cada fuente (el tooltip de cada insignia lo explica más)
                                Repeater {
                                    model: [["repo", "revisados por la distro"], ["aur", "comunidad · se compila aquí"], ["flatpak", "Flathub · aislada (sandbox)"], ["appimage", "un archivo, sin instalar"]]
                                        .filter(m => m[0] !== "aur" || Pkg.family === "arch")
                                    RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 6
                                        StoreBadge { key: modelData[0] }
                                        Txt { Layout.fillWidth: true; text: modelData[1]; size: 10.5; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                                    }
                                }
                                Txt { Layout.fillWidth: true; Layout.topMargin: 2; size: 11; muted: true; wrapMode: Text.WordWrap; text: "Orden: " + Pkg.orderText }
                                Button { visible: Pkg.family === "arch" && Pkg.probed && !Pkg.aur; Layout.fillWidth: true; h: 28; text: "Instalar paru (AUR)"; onClicked: Pkg.run(Pkg.helperCmds(), "Instalar paru") }
                                Button { visible: Pkg.probed && !Pkg.flatpak; Layout.fillWidth: true; h: 28; text: "Activar Flatpak y Flathub"; onClicked: Pkg.run(Pkg.flatpakCmds(), "Activar Flatpak") }
                                Txt { Layout.fillWidth: true; Layout.topMargin: 4; size: 11; wrapMode: Text.WordWrap; textFormat: Text.StyledText; color: Theme.tv
                                    text: "<b><font color='" + Theme.p + "'>Wayland</font></b> nativa · <b><font color='" + Theme.ter + "'>XWayland</font></b> compatible · <b>Alfa</b> de prueba" }
                            }
                        }
                    }
                }

                // ---------- catálogo ----------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    ColumnLayout {
                        visible: !root.detail
                        Layout.fillWidth: true
                        Layout.margins: 18
                        Layout.bottomMargin: 10
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Txt {
                                Layout.fillWidth: true
                                text: root.query.trim() ? "Resultados para «" + root.query.trim() + "»" : (root.catalog.categories.find(c => c.key === root.cat)?.label ?? "")
                                size: 20; weight: Font.DemiBold
                            }
                            Field {
                                id: search
                                Layout.preferredWidth: 340; h: 34
                                placeholder: "Buscar apps o paquetes (Intro: también en " + root.liveLabel + ")"
                                onTextChanged: root.setQuery(text)
                                onAccepted: root.searchNow()
                                onKeyPressed: e => { if (e.key === Qt.Key_Escape && text) { text = ""; e.accepted = true; } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 6
                            // Buscando: catálogo / repos + AUR + Flathub
                            Seg {
                                visible: root.query.trim() !== ""
                                h: 28; fill: false
                                model: [["cat", "En el catálogo (" + root.catMatches.length + ")"],
                                        ["live", root.liveLabel + (Pkg.resultsFor === root.query.trim() && !Pkg.searching ? " (" + Pkg.results.length + ")" : "")]]
                                current: root.mode
                                onPicked: k => { if (k === "live") root.searchNow(); else root.mode = "cat"; }
                            }
                            Txt { visible: root.query.trim() === ""; text: "Paquetes:"; muted: true }
                            Repeater {
                                model: root.query.trim() === "" ? root.catalog.profiles : []
                                Chip {
                                    required property var modelData
                                    mark: false; h: 28
                                    text: "+ " + modelData.label
                                    on: modelData.ids.every(i => root.sel[i])
                                    onClicked: { const s = Object.assign({}, root.sel); const all = modelData.ids.every(i => s[i]); modelData.ids.forEach(i => { if (all) delete s[i]; else s[i] = true; }); root.sel = s; root.cat = "sel"; search.text = ""; }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Chip { visible: root.mode === "cat"; mark: false; h: 28; text: (root.onlyWayland ? "✓ " : "") + "Solo Wayland nativo"; on: root.onlyWayland; onClicked: root.onlyWayland = !root.onlyWayland }
                            Chip { visible: root.mode === "cat"; mark: false; h: 28; text: (root.hideAlpha ? "✓ " : "") + "Ocultar alfa"; on: root.hideAlpha; onClicked: root.hideAlpha = !root.hideAlpha }
                        }
                        // Fuente: solo las apps que se pueden instalar desde ahí (la insignia dice cuál se usará; se cambia en ella)
                        RowLayout {
                            visible: root.mode === "cat"
                            Layout.fillWidth: true
                            spacing: 6
                            Txt { text: "Fuente:"; muted: true }
                            Repeater {
                                model: [["all", "Todas"], ["repo", "Repos oficiales"], ["aur", "AUR"], ["flatpak", "Flatpak"], ["other", "Otras"]].filter(m => m[0] !== "aur" || Pkg.family === "arch")
                                Rectangle {
                                    id: fc
                                    required property var modelData
                                    readonly property bool on: root.srcFilter === modelData[0]
                                    readonly property int n: modelData[0] === "all" ? -1
                                        : root.all.filter(t => root.inCat(t, root.cat) && root.passBase(t) && root.srcPass(t, modelData[0])).length
                                    implicitHeight: 28
                                    implicitWidth: fcRow.implicitWidth + 22
                                    radius: Theme.ctl(28)
                                    color: on ? Theme.selBg : fcm.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                                    border.width: on ? 0 : 1
                                    border.color: Theme.o
                                    Row {
                                        id: fcRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle { visible: fc.modelData[0] !== "all"; width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Pkg.hue(fc.modelData[0] === "other" ? "appimage" : fc.modelData[0]) }
                                        Txt { text: fc.modelData[1] + (fc.n >= 0 && !root.query.trim() ? "  " + fc.n : ""); size: 12; weight: Font.DemiBold; color: fc.on ? Theme.selText : Theme.t }
                                    }
                                    MouseArea { id: fcm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.srcFilter = fc.modelData[0] }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Txt { text: root.srcFilter === "all" ? "Pulsa una app para ver capturas y detalles" : "Con esa fuente disponible · elígela en la insignia de cada app"; muted: true; size: 11.5 }
                        }
                    }
                    // ---------- ficha de una app ----------
                    StoreDetail {
                        visible: !!root.detail
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tool: root.detail
                        store: root
                        onBack: root.detail = null
                    }
                    // ---------- Apps de GNOME recomendadas ----------
                    StoreGnome {
                        visible: !root.detail && root.mode === "cat" && root.cat === "gnome" && !root.query.trim()
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 18
                        Layout.rightMargin: 6
                        store: root
                    }
                    Item {
                        id: gridBox
                        visible: !root.detail && root.mode === "cat" && (root.cat !== "gnome" || !!root.query.trim())
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 18
                        Layout.rightMargin: 6
                        // Filas enteras: el alto de la celda se ajusta y la vista mide justo N filas,
                        // así nunca queda una fila cortada por el pie; la rueda avanza fila a fila
                        readonly property int fitRows: Math.max(1, Math.floor(height / 104))
                        GridView {
                            id: grid
                            width: parent.width - 10
                            height: gridBox.fitRows * cellHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            readonly property int cols: width >= 1080 ? 3 : 2
                            cellWidth: Math.floor((width - 6) / cols)
                            cellHeight: Math.max(104, Math.floor(gridBox.height / gridBox.fitRows))
                            snapMode: GridView.SnapToRow
                            // Barra visible si hay más filas, fuera de las tarjetas
                            ScrollBar.vertical: ScrollBar {
                                parent: gridBox
                                x: grid.width + 1
                                y: grid.y
                                height: grid.height
                                policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            }
                            model: root.query.trim() ? root.catMatches : root.all.filter(t => root.inCat(t, root.cat)).filter(t => root.pass(t))
                            delegate: StoreCard {
                                required property var modelData
                                tool: modelData
                                store: root
                                width: grid.cellWidth
                                height: grid.cellHeight
                            }
                            Txt { anchors.centerIn: parent; visible: grid.count === 0; muted: true; text: root.cat === "sel" && !root.query ? "Aún no has elegido nada" : "Nada en el catálogo · pulsa Intro para buscar en " + root.liveLabel }
                        }
                    }
                    // ---------- resultados de repos / AUR / Flathub ----------
                    Item {
                        visible: root.mode === "live" && !root.detail
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 18
                        Layout.rightMargin: 12
                        ListView {
                            id: live
                            anchors.fill: parent
                            anchors.bottomMargin: 8
                            clip: true
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: live.contentHeight > live.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                            model: Pkg.resultsFor === root.query.trim() ? Pkg.results : []
                            delegate: Rectangle {
                                id: rr
                                required property var modelData
                                readonly property bool inst: modelData.installed || Pkg.isInstalled(modelData.pkg)
                                readonly property bool on: !!root.extra[modelData.id] && !inst
                                width: ListView.view.width - 12
                                implicitHeight: 58
                                radius: Theme.r(6)
                                color: on ? Qt.alpha(Theme.p, 0.10) : rma.containsMouse ? Qt.tint(Theme.s3, Qt.alpha(Theme.t, 0.04)) : Theme.s3
                                border.width: 1
                                border.color: on ? Theme.p : rma.containsMouse ? Theme.o : Theme.ov
                                MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openDetail(rr.modelData) }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 12
                                    Item { implicitWidth: 104; implicitHeight: 18; StoreBadge { key: rr.modelData.key } }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Txt { text: rr.modelData.name; weight: Font.DemiBold; Layout.maximumWidth: rr.width * 0.4; elide: Text.ElideRight }
                                            Mono { text: rr.modelData.version + (rr.modelData.repo && rr.modelData.repo !== "aur" && rr.modelData.repo !== "flathub" ? "  ·  " + rr.modelData.repo : "") + (rr.modelData.key === "flatpak" ? "  ·  " + rr.modelData.pkg : ""); Layout.fillWidth: true; size: 10.5 }
                                        }
                                        Txt { Layout.fillWidth: true; text: rr.modelData.desc || "Sin descripción"; muted: true; size: 12; elide: Text.ElideRight }
                                    }
                                    Rectangle {
                                        visible: rr.inst
                                        implicitWidth: it.implicitWidth + 10; implicitHeight: 16; radius: Theme.r(3)
                                        color: Theme.sc
                                        Txt { id: it; anchors.centerIn: parent; text: "INSTALADA"; size: 9.5; weight: Font.Bold; color: Theme.scText }
                                    }
                                    StoreBtn { visible: rr.inst; danger: true; text: "Desinstalar"; onClicked: Pkg.uninstall(Object.assign({}, rr.modelData)) }
                                    StoreBtn { visible: !rr.inst; text: "Instalar"; onClicked: Pkg.install([rr.modelData], "Instalar " + rr.modelData.name) }
                                    StoreCheck { visible: !rr.inst; on: rr.on; onClicked: root.toggleExtra(rr.modelData) }
                                }
                            }
                            footer: Item { width: live.width; height: live.count > 0 ? 40 : 0
                                Txt { anchors.centerIn: parent; visible: live.count >= 40; muted: true; size: 11.5; text: "Se muestran los 40 más relevantes · afina la búsqueda para ver otros" } }
                        }
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: live.count === 0
                            spacing: 10
                            BusyIndicator { Layout.alignment: Qt.AlignHCenter; visible: Pkg.searching; running: visible; implicitWidth: 32; implicitHeight: 32 }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                muted: true
                                text: root.query.trim().length < 2 ? "Escribe al menos 2 letras"
                                    : Pkg.searching ? "Buscando «" + root.query.trim() + "» en " + root.liveLabel + "…" : "Nada en " + root.liveLabel + " para «" + root.query.trim() + "»"
                            }
                        }
                    }
                    // ---------- barra de instalación ----------
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: footer.implicitHeight + 28
                        color: Theme.bg
                        Rectangle { width: parent.width; height: 1; color: Theme.ov }
                        RowLayout {
                            id: footer
                            x: 18; y: 14; width: parent.width - 36
                            spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Txt {
                                    Layout.fillWidth: true
                                    weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    readonly property int already: root.chosen.length - root.toInstall.length
                                    text: root.toInstall.length === 0 ? (already > 0 ? "Lo elegido ya está instalado" : "Elige apps o un paquete para instalarlas juntas")
                                        : root.toInstall.length + (root.toInstall.length === 1 ? " seleccionada · " : " seleccionadas · ") + root.toInstall.slice(0, 4).map(t => t.name).join(", ") + (root.toInstall.length > 4 ? "…" : "")
                                          + (already > 0 ? " · " + already + " ya instalada" + (already > 1 ? "s" : "") : "")
                                          + (Pkg.snapper ? " · antes se crea un punto de restauración" : "")
                                }
                                Repeater {
                                    model: root.details ? root.cmds : root.cmds.slice(0, 2)
                                    Mono { required property string modelData; Layout.fillWidth: true; text: modelData; color: Theme.tv }
                                }
                                Mono { visible: !root.details && root.cmds.length > 2; text: "… " + (root.cmds.length - 2) + " más"; }
                            }
                            Button { h: 34; text: root.details ? "Ocultar detalles" : "Ver detalles"; enabled: root.cmds.length > 0; onClicked: root.details = !root.details }
                            Button { h: 34; kind: "outline"; text: "Limpiar"; visible: root.chosen.length > 0; onClicked: { root.sel = ({}); root.extra = ({}); } }
                            Button {
                                h: 34; kind: "primary"
                                text: "Instalar seleccionadas (" + root.toInstall.length + ")"
                                enabled: root.toInstall.length > 0
                                onClicked: Pkg.install(root.toInstall, "Instalar aplicaciones")
                            }
                        }
                    }
                }
            }
        }
    }
}
