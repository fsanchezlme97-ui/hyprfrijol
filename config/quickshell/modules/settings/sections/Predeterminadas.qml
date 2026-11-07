// Ajustes › Apps predeterminadas e inicio — con qué app se abre cada tipo de archivo (xdg-mime / xdg-settings,
// vía scripts/hf-defaults), la terminal (ajuste "terminal") y las apps que arrancan al iniciar sesión
// (~/.config/autostart + /etc/xdg/autostart; las del sistema se desactivan con una copia Hidden=true).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var roles: ({})
    property var autostart: []
    property bool loaded: false
    readonly property var order: ["navegador", "correo", "calendario", "musica", "video", "fotos", "pdf", "texto", "archivos", "comprimidos"]
    readonly property var labels: ({ navegador: "Navegador web", correo: "Correo", calendario: "Calendario", musica: "Música", video: "Vídeo",
                                     fotos: "Fotos e imágenes", pdf: "Documentos PDF", texto: "Texto", archivos: "Archivos", comprimidos: "Archivos comprimidos" })
    // gestor de archivos elegido → ajuste fileManager (atajo Super + E, lo lee config/apply/15-apps.py)
    readonly property var fmKey: ({ "org.gnome.Nautilus.desktop": "nautilus", "org.kde.dolphin.desktop": "dolphin", "thunar.desktop": "thunar",
                                    "nemo.desktop": "nemo", "yazi.desktop": "yazi", "pcmanfm-qt.desktop": "pcmanfm" })

    function hl(args) { return [Paths.script("hf-defaults")].concat(args); }
    function reload(): void { lister.running = false; lister.running = true; }
    function reloadAuto(): void { auto.running = false; auto.running = true; }
    function act(args, after): void { runner.after = after; runner.command = hl(args); runner.running = true; }

    Process {
        id: lister
        running: true
        command: root.hl(["list"])
        stdout: StdioCollector { onStreamFinished: { try { root.roles = JSON.parse(text); root.loaded = true; } catch (e) {} } }
    }
    Process {
        id: auto
        running: true
        command: root.hl(["autostart"])
        stdout: StdioCollector { onStreamFinished: { try { root.autostart = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: runner
        property string after: ""
        onExited: { if (after === "list") root.reload(); else if (after === "auto") root.reloadAuto(); }
    }

    function iconFor(name: string): string {
        if (!name) return "";
        if (name.startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, true) || "";
    }
    readonly property var addable: {
        const have = autostart.map(a => a.id);
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && !have.includes(e.id + ".desktop"))
            .map(e => [e.id + ".desktop", e.name])
            .sort((a, b) => a[1].localeCompare(b[1]));
    }

    // ---------------- apps predeterminadas ----------------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Apps predeterminadas"
            headerRight: Mono { text: "xdg-mime · xdg-settings" }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "Con qué app se abre cada cosa al hacer doble clic o seguir un enlace. Solo aparecen las apps instaladas que saben abrirlo."
            }
            Repeater {
                model: root.order
                LabeledRow {
                    id: dr
                    required property string modelData
                    readonly property var info: root.roles[modelData] ?? { label: "", current: "", name: "", options: [], recommended: "" }
                    label: info.label || root.labels[modelData]; labelWidth: 140
                    Dropdown {
                        h: 32
                        model: dr.info.options.map(o => [o[0], o[1] + (o[0] === dr.info.recommended ? "  · recomendada" : "")])
                        current: dr.info.current
                        placeholder: !root.loaded ? "Cargando…" : dr.info.options.length ? (dr.info.name || (dr.info.current ? dr.info.current.replace(/\.desktop$/, "") : "Sin definir")) : "Ninguna instalada"
                        popupWidth: Math.max(width, 300)
                        onPicked: k => {
                            root.act(["set", dr.modelData, k], "list");
                            if (dr.modelData === "archivos") Settings.set("fileManager", root.fmKey[k] ?? ("gtk-launch " + k.replace(/\.desktop$/, "")));
                        }
                    }
                }
            }
            LabeledRow {
                label: "Terminal"; labelWidth: 140
                Dropdown {
                    h: 32
                    model: ["kitty", "ghostty", "foot", "alacritty", "wezterm", "gnome-console", "ptyxis", "konsole"].map(t => [t, t])
                    current: Settings.get("terminal", Pkg.terminal)
                    onPicked: k => Settings.set("terminal", k)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10
                Button {
                    text: "Usar las recomendadas"
                    onClicked: root.act(["recommended", "--force"], "list")
                }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "Apps de GNOME (Archivos, Loupe, Papers, Showtime…) si están instaladas. El navegador no se toca."
                }
            }
            RowLayout {   // las de serie de install/apps.json (también Chrome como navegador): scripts/hf-apps defaults
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: serieDefaults.running ? "Aplicando…" : "Usar las de serie"
                    enabled: !serieDefaults.running
                    onClicked: serieDefaults.running = true
                }
                Process { id: serieDefaults; command: [Paths.script("hf-apps"), "defaults"]; onExited: root.reload() }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "Las de serie de HyprFrijol que tengas: Chrome para la web, Loupe, Papers, Showtime, Decibels, Editor de texto, File Roller…"
                }
            }
        }
    }

    // ---------------- inicio ----------------
    ColumnLayout {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Al iniciar sesión"
            headerRight: Mono { text: "~/.config/autostart" }
            SwRow {
                separator: false
                label: "Abrir las apps de inicio"
                sub: "las de esta lista que estén activadas"
                key: "autostartApps"; def: true
            }
            Repeater {
                model: root.autostart
                Item {
                    id: ar
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 50
                    opacity: Settings.get("autostartApps", true) ? 1 : 0.55
                    Rectangle { width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        spacing: 10
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: Theme.r(6)
                            color: Theme.s4
                            Image {
                                id: ic
                                anchors.centerIn: parent
                                width: 22; height: 22
                                sourceSize: Qt.size(44, 44)
                                source: root.iconFor(ar.modelData.icon)
                                visible: status === Image.Ready
                            }
                            Txt { anchors.centerIn: parent; visible: !ic.visible; text: (ar.modelData.name || "?").charAt(0).toUpperCase(); weight: Font.DemiBold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt { Layout.fillWidth: true; text: ar.modelData.name; weight: Font.DemiBold }
                            Txt {
                                Layout.fillWidth: true; muted: true; size: 11.5
                                text: (ar.modelData.comment || ar.modelData.exec) + (ar.modelData.system && !ar.modelData.user ? " · del sistema" : "")
                            }
                        }
                        Button {
                            visible: ar.modelData.user && !ar.modelData.system
                            kind: "link"; text: "Quitar"
                            onClicked: root.act(["autostart-remove", ar.modelData.id], "auto")
                        }
                        Sw {
                            checked: ar.modelData.enabled
                            onToggled: v => root.act(["autostart-set", ar.modelData.id, v ? "true" : "false"], "auto")
                        }
                    }
                }
            }
            Txt {
                visible: root.autostart.length === 0
                Layout.fillWidth: true; muted: true
                text: "Ninguna app arranca sola."
            }
            LabeledRow {
                Layout.topMargin: 4
                label: "Añadir una app"; labelWidth: 120
                Dropdown {
                    h: 32
                    model: root.addable
                    current: ""
                    placeholder: "Elegir app…"
                    searchable: true
                    popupWidth: Math.max(width, 300)
                    onPicked: k => root.act(["autostart-add", k], "auto")
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "El shell ya arranca solo la barra, las notificaciones, el llavero y el portapapeles; esas entradas no aparecen aquí."
            }
        }
    }
}
