// Ajustes › Web apps — lista compartida con el panel lateral (Settings "webapps", services/WebApps.qml):
//   [{ key, name, url, icon, mode, layout, zoom, panelWidth, tema, css, keybind, notify }]  · se abren con `hf-webapp open <clave>`.
// Modo de cada una (mode):
//   (panel     antes: pestaña del panel lateral; desde 0.8.8 se abre en el navegador)
//   ventana    ventana propia integrada (QtWebEngine, mismo perfil y ajustes)
//   navegador  navegador predeterminado en modo app (Chrome/Chromium/Brave/Vivaldi/Edge, con tus sesiones);
//              Firefox y derivados no tienen modo app → ventana normal
// Solo las integradas: diseño (móvil en anchos estrechos o escritorio), zoom (por web: el archivo <perfil>/zoom, que
// también cambia Ctrl +/−/0 en la ventana), ancho en el panel lateral (WebApps.panelWidth), tema y CSS propio.
// Catálogo de populares: services/webapps-catalog.json (icono Papirus, diseño, ancho mínimo, dominios propios).
// Cada una tiene su .desktop en ~/.local/share/applications/hf-webapp-<key>.desktop (`hf-webapp desktop`, aparece en
// Spotlight) y su atajo lo genera config/apply/60-binds.py.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property var apps: WebApps.list
    property string expanded: ""             // clave de la fila abierta
    property var usedKeys: ({})              // "SUPER + W" → descripción (hyprctl binds)
    // Sesión de prueba anidada (HF_NESTED): carpeta propia, para no ver ni tocar las web apps de la sesión real
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hf-webapp"
        + (Quickshell.env("HF_NESTED") === "1" ? "-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "prueba") : "")

    // Guarda la lista; las de modo «panel» tienen pestaña en el panel lateral (sidePanelApps) y las demás no
    function save(list) {
        const tabs = WebApps.panelApps.filter(k => k === "ia" || list.some(a => a.key === k && WebApps.modeOf(a) === "panel"));
        for (const a of list) if (a.mode === "panel" && !tabs.includes(a.key)) tabs.push(a.key);
        Settings.setMany({ webapps: list, sidePanelApps: tabs });
        desktopTimer.restart();
    }
    function update(i, patch) {
        const l = apps.slice();
        l[i] = Object.assign({}, l[i], patch);
        save(l);
        const k = l[i].key;
        // En vivo si ya está abierta (la ventana integrada relee zoom y CSS)
        if (patch.zoom !== undefined) Quickshell.execDetached([Paths.script("hf-webapp"), "cmd", k, "zoom", String(patch.zoom)]);
        if (patch.css !== undefined) Quickshell.execDetached(["sh", "-c", '[ -d "$1" ] && printf "%s" "$2" > "$1/$3.css"', "sh", runDir, patch.css, k]);
    }
    function move(i, d) {
        const j = i + d;
        if (j < 0 || j >= apps.length) return;
        const l = apps.slice(); const t = l[i]; l[i] = l[j]; l[j] = t;
        save(l);
    }
    function remove(i) {
        const k = apps[i].key;
        Quickshell.execDetached([Paths.script("hf-webapp"), "stop", k]);
        if (expanded === k) expanded = "";
        save(apps.filter((_, x) => x !== i));
    }
    function newKey(base) {
        let k = String(base).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "web";
        const b = k; let n = 2;
        while (apps.some(a => a.key === k) || k === "ia") k = b + (n++);
        return k;
    }
    function added(c) { return apps.some(a => WebApps.hostOf(a.url) === WebApps.hostOf(c.url)); }
    function addPreset(c) {
        if (added(c)) return;
        const a = { key: apps.some(x => x.key === c.key) || c.key === "ia" ? newKey(c.name) : c.key, name: c.name, url: c.url,
                    icon: c.icon ?? "", mode: c.mode === "ventana" ? "ventana" : "navegador", keybind: "", notify: c.notify !== false };
        save(apps.concat([a]));
        expanded = a.key;
    }
    function addCustom(name, url) {
        let u = url.trim(); if (!/^https?:\/\//.test(u)) u = "https://" + u;
        const n = name.trim() || WebApps.hostOf(u);
        const c = WebApps.catalog.find(x => WebApps.hostOf(x.url) === WebApps.hostOf(u));
        const a = { key: newKey(n), name: n, url: u, icon: c?.icon ?? "", mode: "navegador", keybind: "", notify: true };
        save(apps.concat([a]));
        expanded = a.key;
    }
    Timer { id: desktopTimer; interval: 600; onTriggered: Quickshell.execDetached([Paths.script("hf-webapp"), "desktop"]) }

    property var browser: ({ kind: "", cmd: "", name: "" })      // hf-webapp browser
    Process {
        running: true
        command: [Paths.script("hf-webapp"), "browser"]
        stdout: StdioCollector {
            onStreamFinished: { const f = text.trim().split("\t"); root.browser = { kind: f[0] ?? "otro", cmd: f[1] ?? "", name: f[2] ?? "" }; }
        }
    }
    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = {};
                    JSON.parse(text).forEach(b => {
                        const mods = [];
                        if (b.modmask & 64) mods.push("SUPER"); if (b.modmask & 4) mods.push("CTRL"); if (b.modmask & 8) mods.push("ALT"); if (b.modmask & 1) mods.push("SHIFT");
                        m[mods.concat([String(b.key).toUpperCase()]).join(" + ")] = b.description || b.dispatcher;
                    });
                    root.usedKeys = m;
                } catch (e) {}
            }
        }
    }

    // Icono de la web app (tema de iconos) o la inicial sobre un color del tema
    component AppIcon: Rectangle {
        id: ic
        property var app: ({})
        property real s: 32
        implicitWidth: s; implicitHeight: s
        radius: Theme.r(s / 4.5)
        readonly property string src: WebApps.iconOf(app)
        color: img.status === Image.Ready ? "transparent" : [Theme.pc, Theme.sc, Theme.s4][Math.abs(String(app?.name ?? "").charCodeAt(0) || 0) % 3]
        Image { id: img; anchors.fill: parent; source: ic.src; sourceSize: Qt.size(ic.s * 2, ic.s * 2); visible: status === Image.Ready; asynchronous: true }
        Txt {
            visible: img.status !== Image.Ready
            anchors.centerIn: parent
            text: String(ic.app?.name ?? "?").charAt(0).toUpperCase()
            size: ic.s * 0.42; weight: Font.Bold
            color: ic.color === Theme.pc ? Theme.pcText : ic.color === Theme.sc ? Theme.scText : Theme.t
        }
    }

    // ===================================================================== lista
    Section {
        Layout.fillWidth: true
        title: "Tus web apps"
        headerRight: Txt { muted: true; size: 11.5; text: root.apps.length + (root.apps.length === 1 ? " web app" : " web apps") + " · se abren en el navegador o en su ventana" }

        Txt {
            visible: root.apps.length === 0
            Layout.fillWidth: true
            text: "Aún no tienes web apps. Añade una del catálogo de abajo o con su dirección."
            muted: true; size: 12
        }
        RowLayout {
            visible: root.apps.length > 0
            Layout.fillWidth: true
            spacing: 10
            Item { Layout.preferredWidth: 22 }
            Txt { Layout.fillWidth: true; text: "App"; muted: true; size: 11.5 }
            Txt { Layout.preferredWidth: 170; text: "Se abre en"; muted: true; size: 11.5 }
            Txt { Layout.preferredWidth: 60; text: "Avisos"; muted: true; size: 11.5; horizontalAlignment: Text.AlignHCenter }
            Txt { visible: false; Layout.preferredWidth: 112; text: "Cerrar si no la usas"; muted: true; size: 11.5; elide: Text.ElideRight }   // solo tenía sentido en el panel lateral
            Item { Layout.preferredWidth: 88 }
        }

        Repeater {
            model: root.apps
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property string mode: WebApps.modeOf(modelData)
                readonly property bool integrated: mode !== "navegador"
                readonly property bool open: root.expanded === modelData.key
                readonly property var preset: WebApps.preset(modelData)
                readonly property string kb: String(modelData.keybind ?? "")
                // Cerrar por no usarla: solo las del panel y nunca las de mensajería (WhatsApp, Telegram…: no avisarían)
                readonly property bool canUnload: mode === "panel" && preset?.cat !== "Mensajería"
                // Zoom guardado por web (Ctrl +/− en la ventana o aquí); si no hay, el de Ajustes
                FileView { id: zoomFile; path: Paths.home + "/.local/share/hyprfrijol/webapps/" + row.modelData.key + "/zoom"; watchChanges: true; printErrors: false; onFileChanged: reload() }
                readonly property real zoomNow: parseFloat(zoomFile.text()) > 0 ? parseFloat(zoomFile.text()) : (modelData.zoom ?? (mode === "panel" ? WebApps.panelZoom : 1))
                readonly property string conflict: kb && root.usedKeys[kb.toUpperCase()] && !String(root.usedKeys[kb.toUpperCase()]).includes(modelData.name) ? root.usedKeys[kb.toUpperCase()] : ""
                Layout.fillWidth: true
                spacing: 0

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 10
                    // Reordenar
                    ColumnLayout {
                        Layout.preferredWidth: 22
                        spacing: 0
                        IconBtn { icon: "chevron_up"; iconSize: 11; implicitWidth: 22; implicitHeight: 18; fg: Theme.tv; opacity: row.index > 0 ? 1 : 0.25; onClicked: root.move(row.index, -1) }
                        IconBtn { icon: "chevron_down"; iconSize: 11; implicitWidth: 22; implicitHeight: 18; fg: Theme.tv; opacity: row.index < root.apps.length - 1 ? 1 : 0.25; onClicked: root.move(row.index, 1) }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = row.open ? "" : row.modelData.key }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        AppIcon { app: row.modelData }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            RowLayout {
                                spacing: 6
                                Txt { text: row.modelData.name; weight: Font.DemiBold }
                                Txt { visible: row.kb !== ""; text: row.kb.replace(/ \+ /g, " "); size: 10.5; color: Theme.tv }
                            }
                            Mono { Layout.fillWidth: true; text: row.modelData.url.replace(/^https?:\/\//, "").replace(/\/$/, ""); size: 10.5 }
                        }
                    }
                    }
                    Dropdown {
                        Layout.preferredWidth: 170
                        h: 30
                        model: WebApps.modes
                        current: row.mode
                        onPicked: k => root.update(row.index, { mode: k })
                    }
                    Item { Layout.preferredWidth: 60; implicitHeight: 26; Sw { anchors.centerIn: parent; checked: row.modelData.notify !== false; onToggled: v => root.update(row.index, { notify: v }) } }
                    Item {
                        visible: false      // «Cerrar si no la usas»: solo para las del panel lateral, que ya no existe
                        Layout.preferredWidth: 112; implicitHeight: 30
                        Dropdown {
                            visible: row.canUnload
                            anchors.fill: parent
                            h: 30
                            model: [["0", "Nunca"], ["15", "A los 15 min"], ["30", "A los 30 min"], ["60", "A la hora"]]
                            current: String(row.modelData.unload ?? 0)
                            onPicked: k => root.update(row.index, { unload: +k })
                        }
                        Txt { visible: !row.canUnload; anchors.centerIn: parent; text: "—"; muted: true }
                    }
                    RowLayout {
                        Layout.preferredWidth: 88; spacing: 2
                        IconBtn { icon: "external"; implicitWidth: 28; implicitHeight: 28; tooltip: "Abrir"; onClicked: WebApps.open(row.modelData.key) }
                        IconBtn { icon: "sliders"; implicitWidth: 28; implicitHeight: 28; tooltip: "Más opciones"; active: row.open; activeBg: Theme.selBg; activeFg: Theme.selText; onClicked: root.expanded = row.open ? "" : row.modelData.key }
                        IconBtn { icon: "trash"; implicitWidth: 28; implicitHeight: 28; tooltip: "Quitar"; onClicked: root.remove(row.index) }
                    }
                }

                // ---------------- opciones de la web app
                Rectangle {
                    visible: row.open
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12
                    implicitHeight: opts.implicitHeight + 24
                    radius: Theme.r(8)
                    color: "transparent"
                    border.width: 1; border.color: Theme.ov
                    ColumnLayout {
                        id: opts
                        x: 14; y: 12
                        width: parent.width - 28
                        spacing: 10
                        Txt {
                            visible: !!row.preset.note
                            Layout.fillWidth: true
                            text: "ⓘ " + (row.preset.note ?? "")
                            size: 11.5; color: Theme.ter; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Txt { Layout.preferredWidth: 110; text: "Nombre"; color: Theme.tv; size: 12 }
                            Field {
                                id: nameField
                                Layout.fillWidth: true; h: 30; icon: ""
                                text: row.modelData.name
                                function commit() { const t = text.trim(); if (t && t !== row.modelData.name) root.update(row.index, { name: t }); }
                                onAccepted: commit()
                                Connections { target: nameField.input; function onActiveFocusChanged() { if (!nameField.input.activeFocus) nameField.commit(); } }
                            }
                            Txt { text: "Atajo"; color: Theme.tv; size: 12; Layout.leftMargin: 8 }
                            KeyCapture { value: row.kb; onCaptured: k => root.update(row.index, { keybind: k }) }
                        }
                        Txt { visible: row.conflict !== ""; text: "⚠ Atajo ya usado: " + row.conflict; size: 11; color: Theme.danger }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            opacity: row.integrated ? 1 : 0.45
                            enabled: row.integrated
                            Txt { Layout.preferredWidth: 110; text: "Diseño"; color: Theme.tv; size: 12 }
                            Seg {
                                h: 28; textSize: 11.5
                                model: [["movil", "Móvil si es estrecha"], ["escritorio", "Siempre escritorio"]]
                                current: row.modelData.layout ?? row.preset.layout ?? "escritorio"
                                onPicked: k => root.update(row.index, { layout: k })
                            }
                            Item { Layout.fillWidth: true }
                            Txt { text: "Zoom"; color: Theme.tv; size: 12 }
                            IconBtn { icon: "minus"; iconSize: 12; implicitWidth: 28; implicitHeight: 28; onClicked: root.update(row.index, { zoom: Math.max(0.5, Math.round((row.zoomNow - 0.1) * 10) / 10) }) }
                            Txt { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignHCenter; text: Math.round(row.zoomNow * 100) + " %"; tabular: true; size: 12 }
                            IconBtn { icon: "plus"; iconSize: 12; implicitWidth: 28; implicitHeight: 28; onClicked: root.update(row.index, { zoom: Math.min(2, Math.round((row.zoomNow + 0.1) * 10) / 10) }) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: row.mode === "panel"
                            Txt { Layout.preferredWidth: 110; text: "Ancho en el panel"; color: Theme.tv; size: 12 }
                            Seg {
                                h: 28; textSize: 11.5
                                model: WebApps.widths
                                current: row.modelData.panelWidth ?? "auto"
                                onPicked: k => root.update(row.index, { panelWidth: k })
                            }
                            Item { Layout.fillWidth: true }
                            Txt {
                                muted: true; size: 11
                                text: (row.modelData.panelWidth ?? "auto") === "auto" ? "≈ " + WebApps.third(Shell.primaryScreen?.width ?? 1920) + " px" : ""
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            opacity: row.integrated ? 1 : 0.45
                            enabled: row.integrated
                            Txt { Layout.preferredWidth: 110; text: "Tema"; color: Theme.tv; size: 12 }
                            Seg {
                                h: 28; textSize: 11.5
                                model: [["sistema", "Como el escritorio"], ["oscuro", "Oscuro"], ["claro", "Claro"], ["web", "El de la web"]]
                                current: row.modelData.tema ?? "sistema"
                                onPicked: k => root.update(row.index, { tema: k })
                            }
                            Item { Layout.fillWidth: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: row.mode === "panel"
                            Txt { Layout.preferredWidth: 110; text: "Atrás / Adelante"; color: Theme.tv; size: 12 }
                            Sw {
                                checked: row.modelData.nav ?? (row.preset.cat !== "Mensajería")
                                onToggled: v => root.update(row.index, { nav: v })
                            }
                            Txt { Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.Wrap; text: "Botones en la cabecera del panel (también Alt + ← / Alt + →)" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: row.mode === "panel"
                            Txt { Layout.preferredWidth: 110; text: "Cerrar si no la usas"; color: Theme.tv; size: 12 }
                            Seg {
                                h: 28; textSize: 11.5
                                model: [["0", "Nunca"], ["15", "15 min"], ["30", "30 min"], ["60", "1 h"]]
                                current: String(row.modelData.unload ?? 0)
                                onPicked: k => root.update(row.index, { unload: +k })
                            }
                            Txt {
                                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.Wrap
                                text: (row.modelData.unload ?? 0) > 0
                                      ? "Libera memoria. Mientras esté cerrada no llegan sus avisos; nunca se cierra si suena o está en PiP"
                                      : "Siempre abierta en segundo plano (recomendado para WhatsApp y el correo)"
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            opacity: row.integrated ? 1 : 0.45
                            enabled: row.integrated
                            Txt { Layout.preferredWidth: 110; text: "CSS propio"; color: Theme.tv; size: 12 }
                            Field {
                                id: cssField
                                Layout.fillWidth: true; h: 30; icon: ""
                                placeholder: "p. ej. body { font-size: 15px }  — se aplica en vivo"
                                text: row.modelData.css ?? ""
                                function commit() { if (text !== (row.modelData.css ?? "")) root.update(row.index, { css: text }); }
                                onAccepted: commit()
                                Connections { target: cssField.input; function onActiveFocusChanged() { if (!cssField.input.activeFocus) cssField.commit(); } }
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; muted: true
                            text: row.integrated
                                ? "Integrada: sesión propia guardada en este equipo, enlaces de otras webs en tu navegador, descargas en Descargas. "
                                  + "En la ventana: Ctrl + / Ctrl − zoom (se guarda para esta web), Ctrl 0 restablecer. El tema se aplica al volver a abrirla."
                                : "Se abre con " + (root.browser.name || "tu navegador") + (root.browser.kind === "chromium" ? " en modo app (con tus sesiones)." : root.browser.kind === "firefox" ? " en una ventana normal (Firefox no tiene modo app)." : ".")
                        }
                    }
                }
            }
        }
    }

    // ===================================================================== añadir
    Section {
        Layout.fillWidth: true
        title: "Añadir web app"
        headerRight: Txt { muted: true; size: 11.5; text: "Populares" }
        Flow {
            id: catFlow
            Layout.fillWidth: true
            spacing: 8
            readonly property int cols: Math.max(1, Math.floor((width + spacing) / (150 + spacing)))
            readonly property real tileW: (width - spacing * (cols - 1)) / cols
            Repeater {
                model: WebApps.catalog
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool isAdded: root.added(modelData)
                    width: catFlow.tileW; height: 44
                    radius: Theme.r(8)
                    color: tileMa.containsMouse && !isAdded ? Theme.fill2 : "transparent"
                    border.width: 1; border.color: isAdded ? Theme.ov : Theme.border
                    opacity: isAdded ? 0.6 : 1
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                        spacing: 9
                        AppIcon { app: tile.modelData; s: 26 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Txt { Layout.fillWidth: true; text: tile.modelData.name; size: 12; weight: Font.DemiBold }
                            Txt { Layout.fillWidth: true; text: tile.isAdded ? "Añadida" : tile.modelData.cat; size: 10; muted: true }
                        }
                        Icon { name: tile.isAdded ? "check" : "plus"; size: 12; color: tile.isAdded ? Theme.p : Theme.tv }
                    }
                    MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: tile.isAdded ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: root.addPreset(tile.modelData) }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov; Layout.topMargin: 4 }
        Txt { text: "Otra web"; weight: Font.DemiBold; size: 12.5 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Field { id: nm; Layout.preferredWidth: 220; icon: ""; placeholder: "Nombre (p. ej. Trello)" }
            Field { id: url; Layout.fillWidth: true; icon: "globe"; placeholder: "Dirección web (https://…)"; onAccepted: add.clicked() }
            Button {
                id: add
                kind: "primary"; text: "Añadir"
                enabled: url.text.trim() !== ""
                onClicked: { root.addCustom(nm.text, url.text); nm.text = ""; url.text = ""; }
            }
        }
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11.5; muted: true; textFormat: Text.StyledText
            text: "Navegador predeterminado: <b>" + (root.browser.name || "ninguno") + "</b>"
                + (root.browser.kind === "chromium" ? " (admite modo app)" : root.browser.kind === "firefox" ? " (sin modo app: ventana normal)" : "")
                + ". Las integradas (panel lateral o ventana propia) tienen su propia sesión: la primera vez hay que iniciarla. "
                + "Google y las webs con DRM (Spotify, Netflix) funcionan mejor en el navegador."
        }
        RowLayout {
            Layout.fillWidth: true
            Mono { Layout.fillWidth: true; text: "~/.local/share/applications/hf-webapp-<clave>.desktop · aparecen en Spotlight" }
            Button { kind: "link"; text: "Cambiar navegador"; onClicked: Shell.open("ajustesapp", "predeterminadas") }
        }
    }
}
