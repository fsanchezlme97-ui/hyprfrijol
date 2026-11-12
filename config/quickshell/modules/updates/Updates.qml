// Centro de actualizaciones (vista "actualizaciones"), como Actualizaciones del diseño:
// grupos Sistema (pacman) · AUR (paru) · Flatpak · Firmware (fwupd), desplegables, con el punto de
// restauración de Snapper antes de instalar (aparece en el menú de arranque con limine-snapper-sync).
// Datos: scripts/hf-updates (check / cached). «Instalar ahora» abre una terminal con
//   [sudo snapper create …] && paru -Syu [&& flatpak update]   — la contraseña la escribes tú.
// «Instalar y apagar» hace lo mismo y apaga al terminar.
// Teclas: R comprobar otra vez · Intro instalar ahora · Esc cerrar.
// updatesMode (Ajustes › Sistema): «avisar» comprueba en segundo plano (a los 5 min de entrar y cada 6 h) y avisa
// cuando hay más que la última vez; «auto» además instala Flatpak solo (lo del sistema necesita tu contraseña,
// así que avisa igual); «manual» no comprueba nada hasta que abres la vista.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "actualizaciones"
    morphs: true                // se transforma desde/hacia el panel que estaba abierto (components/Morph)
    place: "center"
    panelWidth: 640
    panelHeight: card.implicitHeight
    dim: false

    property var info: ({})
    property bool checking: false
    property var expandedKeys: ({ pacman: true })
    readonly property bool snapshot: Settings.get("updatesSnapshot", true) !== false
    readonly property int total: info.total ?? 0
    readonly property bool hasSnapper: info.has?.snapper ?? true

    // Paquetes que conviene destacar (y si piden reinicio)
    readonly property var notes: [
        [/^linux(-|$)/, "núcleo · reinicio", true], [/^(nvidia|nvidia-)/, "controlador · reinicio", true],
        [/^(systemd|glibc|dbus)/, "sistema · reinicio", true], [/^(mesa|vulkan-|lib32-mesa)/, "gráficos", false],
        [/^(hyprland|aquamarine|hyprutils|hyprlang|hyprgraphics)/, "compositor", false], [/^(quickshell)/, "shell", false],
        [/^(pipewire|wireplumber)/, "audio", false], [/^(firefox|chromium|google-chrome|brave)/, "navegador", false],
        [/^(qt6-|qt5-)/, "Qt", false], [/^(limine|grub|snapper)/, "arranque", false]
    ]
    function noteOf(name: string): var { return notes.find(n => n[0].test(name)) ?? null; }
    function sorted(list): var {
        const rank = p => { const n = noteOf(p.name); return n ? (n[2] ? 2 : 1) : 0; };
        return (list ?? []).slice().sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name));
    }
    readonly property bool needsReboot: (info.pacman ?? []).some(p => noteOf(p.name)?.[2])

    readonly property var groups: [
        { key: "pacman", glyph: "A", tone: "p", name: "Sistema (pacman)", show: true,
          meta: needsReboot ? "reinicio necesario" : "" },
        { key: "aur", glyph: "U", tone: "sc", name: "AUR (" + (info.has?.paru === false ? "yay" : "paru") + ")", show: true, meta: "revisa PKGBUILD" },
        { key: "flatpak", glyph: "F", tone: "ter", name: "Flatpak", show: info.has?.flatpak ?? false, meta: "sin reinicio" },
        { key: "firmware", glyph: "⚙", tone: "s4", name: "Firmware (fwupd)", show: info.has?.fwupd ?? true, meta: "se aplica al reiniciar" }
    ].filter(g => g.show)

    readonly property string ago: {
        if (!info.checked) return checking ? "comprobando…" : "sin comprobar";
        const m = Math.floor((Time.now.getTime() / 1000 - info.checked) / 60);
        return "comprobado " + (m < 1 ? "ahora" : m < 60 ? "hace " + m + " min" : m < 1440 ? "hace " + Math.floor(m / 60) + " h" : "hace " + Math.floor(m / 1440) + " d");
    }

    function check(): void { checking = true; checker.running = false; checker.running = true; }
    function install(poweroff: bool): void {
        const args = [Paths.script("hf-updates"), "run"];
        if (snapshot && hasSnapper) args.push("--snapshot");
        if (poweroff) args.push("--poweroff");
        Quickshell.execDetached(args);
        Shell.close();
    }

    onShownChanged: if (shown) {
        cached.running = true;
        Qt.callLater(() => keys.forceActiveFocus());
    }

    // La comprobación en segundo plano y el aviso están en UpdatesCheck.qml (siempre cargado; esta vista es diferida)

    Process {
        id: cached
        command: [Paths.script("hf-updates"), "cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.info = JSON.parse(text) || {}; } catch (e) { win.info = {}; }
                // Si es de hace más de 30 min (o no hay), comprobar otra vez
                if (!win.info.checked || Date.now() / 1000 - win.info.checked > 1800) win.check();
            }
        }
    }
    Process {
        id: checker
        command: [Paths.script("hf-updates"), "check"]
        stdout: StdioCollector {
            onStreamFinished: { try { win.info = JSON.parse(text) || {}; } catch (e) {} win.checking = false; }
        }
        onExited: win.checking = false
    }

    Glass {
        id: card
        kind: "popup"
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 36

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 12

            // Cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: Theme.r(8)
                    color: Theme.p
                    Icon { anchors.centerIn: parent; name: "refresh"; color: Theme.pText; size: 16
                           RotationAnimator on rotation { running: win.checking; from: 0; to: 360; duration: 1100; loops: Animation.Infinite
                                                          onRunningChanged: if (!running && target) target.rotation = 0 } }   // que no se quede torcido al acabar
                }
                ColumnLayout {
                    spacing: 1
                    Txt { text: "Actualizaciones"; size: 16; weight: Font.DemiBold }
                    Txt {
                        text: (win.checking && !win.info.checked ? "Buscando actualizaciones…"
                              : win.total === 0 ? "Todo está al día" : win.total === 1 ? "1 actualización" : win.total + " actualizaciones")
                              + " · " + win.ago
                        size: 11.5; muted: true
                    }
                }
                Item { Layout.fillWidth: true }
                IconBtn { icon: "refresh"; onClicked: win.check(); opacity: win.checking ? 0.4 : 1 }
                IconBtn { icon: "x"; onClicked: Shell.close() }
            }

            // Grupos
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(groupsCol.implicitHeight, 430)
                contentHeight: groupsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: groupsCol
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: win.groups
                        delegate: Rectangle {
                            id: grp
                            required property var modelData
                            readonly property var items: win.sorted(win.info[modelData.key])
                            readonly property bool expanded: !!win.expandedKeys[modelData.key] && items.length > 0
                            property bool all: false
                            readonly property int limit: 8
                            Layout.fillWidth: true
                            implicitHeight: 40 + (expanded ? list.implicitHeight + 8 : 0)
                            radius: Theme.r(8)
                            color: Theme.fill2
                            clip: true
                            Behavior on implicitHeight { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

                            RowLayout {
                                id: head
                                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10 }
                                height: 40
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: Theme.r(6)
                                    color: Theme[grp.modelData.tone] ?? Theme.s4
                                    Txt {
                                        anchors.centerIn: parent; text: grp.modelData.glyph; size: 11; weight: Font.Bold
                                        color: grp.modelData.tone === "p" ? Theme.pText : grp.modelData.tone === "sc" ? Theme.scText : grp.modelData.tone === "ter" ? Theme.bg : Theme.t
                                    }
                                }
                                Txt { Layout.fillWidth: true; text: grp.modelData.name; weight: Font.Medium }
                                Txt { visible: grp.items.length > 0; text: grp.modelData.meta; size: 11; muted: true }
                                Rectangle {
                                    Layout.preferredWidth: Math.max(36, cnt.implicitWidth + 16); Layout.preferredHeight: 22; radius: Theme.r(6)
                                    color: Theme.ov
                                    Txt { id: cnt; anchors.centerIn: parent; text: win.checking && !win.info.checked ? "…" : grp.items.length; size: 11.5; tabular: true }
                                }
                                Txt { text: grp.expanded ? "▾" : "▸"; muted: true; opacity: grp.items.length ? 1 : 0.3; Layout.preferredWidth: 10 }
                            }
                            MouseArea {
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                height: 40
                                cursorShape: grp.items.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: { const o = Object.assign({}, win.expandedKeys); o[grp.modelData.key] = !o[grp.modelData.key]; win.expandedKeys = o; }
                            }
                            Column {
                                id: list
                                anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 44; rightMargin: 10 }
                                spacing: 2
                                Repeater {
                                    model: grp.expanded ? (grp.all ? grp.items : grp.items.slice(0, grp.limit)) : []
                                    delegate: Row {
                                        required property var modelData
                                        readonly property var note: win.noteOf(modelData.name)
                                        spacing: 0
                                        Txt { width: 160; text: modelData.name; weight: Font.Medium; size: 12 }
                                        Txt { width: 170; text: modelData.from ? modelData.from + " → " + modelData.to : modelData.to; size: 12; muted: true; tabular: true }
                                        Txt { width: list.width - 330; text: parent.note ? parent.note[1] : ""; size: 12; muted: true }
                                    }
                                }
                                Txt {
                                    visible: grp.expanded && grp.items.length > grp.limit
                                    text: grp.all ? "Ver menos" : "Ver las " + grp.items.length + " →"
                                    size: 12; color: Theme.p; height: 22
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: grp.all = !grp.all }
                                }
                            }
                        }
                    }
                }
            }

            // Punto de restauración
            Rectangle {
                visible: win.hasSnapper
                Layout.fillWidth: true
                implicitHeight: snapCol.implicitHeight + 22
                radius: Theme.r(8)
                color: "transparent"
                border.width: 1
                border.color: Theme.ov
                ColumnLayout {
                    id: snapCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: 6
                    RowLayout {
                        spacing: 10
                        Toggle { implicitWidth: 30; implicitHeight: 18; checked: win.snapshot; onToggled: v => Settings.set("updatesSnapshot", v) }
                        Txt {
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            text: "Crear punto de restauración antes de instalar <font color='" + Theme.tv + "'>(Snapper" + (win.info.has?.limine ? " · en el menú de arranque" : "") + ")</font>"
                            size: 12.5
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        size: 11; muted: !win.snapshot
                        color: win.snapshot ? Theme.tv : Theme.danger
                        text: win.snapshot
                              ? "Si algo falla, eliges el punto «antes de actualizar» en el menú de arranque" + (win.info.has?.limine ? " (Limine)" : "") + " y vuelves a como estaba."
                              : "Sin punto de restauración no podrás volver atrás desde el arranque."
                    }
                }
            }

            // Acciones
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt {
                    Layout.fillWidth: true
                    visible: !!(win.info.errors?.pacman)
                    text: "pacman: " + (win.info.errors?.pacman ?? "")
                    size: 11; color: Theme.danger; elide: Text.ElideRight
                }
                Item { Layout.fillWidth: true; visible: !(win.info.errors?.pacman) }
                Btn { text: "Instalar y apagar"; h: 34; padX: 14; enabled: win.total > 0; onClicked: win.install(true) }
                Btn { kind: "primary"; text: "Instalar ahora"; h: 34; padX: 16; enabled: win.total > 0; onClicked: win.install(false) }
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_R) { win.check(); e.accepted = true; }
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && win.total > 0) { win.install(false); e.accepted = true; }
        }
        Keys.onEscapePressed: Shell.close()
    }
}
