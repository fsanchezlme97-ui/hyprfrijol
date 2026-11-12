// Centro de aplicaciones › «Instaladas» (Tools.qml, cat:instaladas; antes en Ajustes › Aplicaciones): todas las apps con lanzador (scripts/hf-apps installed:
// paquete de la distro, AUR, Flatpak o AppImage de hyprfrijol), con búsqueda y «Desinstalar». La orden se abre en una
// terminal (Pkg.runInTerminal), donde el gestor de paquetes pide la contraseña y confirmación. Lo que hyprfrijol
// necesita (niveles required/base de install/packages.tsv, el compositor, el shell, el kernel, la terminal…) sale
// como «Protegida», sin botón. Avisa si el paquete trae más apps o si otros paquetes dependen de él.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 8
    property var apps: []
    property bool loaded: false
    property string query: ""
    property bool showAll: false
    readonly property int limit: 12
    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        return q ? apps.filter(a => a.name.toLowerCase().includes(q) || (a.pkg ?? "").toLowerCase().includes(q) || (a.comment ?? "").toLowerCase().includes(q)) : apps;
    }
    readonly property var visibleApps: showAll || query.trim() ? filtered : filtered.slice(0, limit)
    readonly property string count: apps.length + " apps · " + apps.filter(a => a.cmd).length + " se pueden desinstalar"

    function refresh(): void { lister.running = false; lister.running = true; }
    Component.onCompleted: refresh()
    Process {
        id: lister
        command: [Paths.script("hf-apps"), "installed", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.apps = JSON.parse(text || "{}").apps ?? []; } catch (e) { console.warn("[apps] hf-apps installed: " + e); }
                root.loaded = true;
            }
        }
    }
    // Tras desinstalar (la terminal va aparte): volver a mirar unas cuantas veces
    Timer { id: again; interval: 8000; repeat: true; property int n: 0; onTriggered: { root.refresh(); Pkg.refresh(); if (++n >= 8) { n = 0; stop(); } } }

    function iconOf(n): string {
        if (!n) return "";
        if (n.startsWith("/")) return "file://" + n;
        return Quickshell.iconPath(n, true) || "";
    }
    function uninstall(a): void {
        Pkg.runInTerminal(a.cmd, "Desinstalar " + a.name);
        again.n = 0; again.restart();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field {
            Layout.fillWidth: true
            Layout.maximumWidth: 360
            h: 32
            placeholder: "Buscar entre las instaladas…"
            onTextChanged: root.query = text
        }
        Button { h: 32; text: "Actualizar"; onClicked: root.refresh() }
        Item { Layout.fillWidth: true }
        Txt { text: root.loaded ? root.count : "Buscando…"; muted: true; size: 11.5; tabular: true }
    }
    Repeater {
        model: root.visibleApps
        Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property var a: modelData
            readonly property string warn: a.protected ? "" : [
                a.also.length ? "El paquete " + a.pkg + " también trae: " + a.also.join(", ") : "",
                a.requiredBy.length ? "Lo necesitan otros paquetes (" + a.requiredBy.slice(0, 4).join(", ") + (a.requiredBy.length > 4 ? "…" : "") + "): el gestor no dejará quitarlo solo" : ""
            ].filter(Boolean).join(" · ")
            Layout.fillWidth: true
            implicitHeight: 50
            radius: Theme.r(6)
            color: rma.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
            Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.ov }
            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 12
                Image {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    source: root.iconOf(row.a.icon)
                    sourceSize: Qt.size(56, 56)
                    asynchronous: true; smooth: true; mipmap: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Txt { text: row.a.name; weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 300 }
                        Rectangle {
                            readonly property string key: ({ "AUR": "aur", "Flatpak": "flatpak", "AppImage": "appimage", "Local": "url" })[row.a.source] ?? "repo"
                            implicitWidth: sl.implicitWidth + 12; implicitHeight: 18; radius: Theme.r(4)
                            color: Qt.alpha(Pkg.hue(key), Theme.light ? 0.15 : 0.22)
                            border.width: 1; border.color: Qt.alpha(Pkg.hue(key), 0.55)
                            Txt { id: sl; anchors.centerIn: parent; text: row.a.source; size: 10; weight: Font.Bold
                                color: Theme.light ? Qt.darker(Pkg.hue(parent.key), 1.55) : Qt.lighter(Pkg.hue(parent.key), 1.5) }
                        }
                        Mono { visible: !!row.a.pkg; text: row.a.pkg; size: 11; Layout.fillWidth: true }
                        Item { visible: !row.a.pkg; Layout.fillWidth: true }
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: row.a.protected ? "Protegida: " + row.a.protected : row.warn || row.a.comment || (row.a.kind === "local" ? "Lanzador propio (web app o creado a mano): se quita en Web apps o en ~/.local/share/applications" : "")
                        color: row.warn && !row.a.protected ? Theme.danger : Theme.tv
                        size: 11.5; elide: Text.ElideRight
                    }
                }
                Button {
                    visible: !!row.a.cmd
                    h: 30
                    text: "Desinstalar"
                    onClicked: root.uninstall(row.a)
                }
                Txt { visible: !!row.a.protected; text: "Protegida"; muted: true; size: 12 }
            }
        }
    }
    Txt {
        Layout.fillWidth: true
        visible: root.loaded && root.filtered.length === 0
        text: root.query.trim() ? "Ninguna app instalada coincide con «" + root.query.trim() + "»" : "No encontré apps instaladas"
        muted: true; size: 12
    }
    Button {
        visible: !root.query.trim() && root.filtered.length > root.limit
        h: 30
        text: root.showAll ? "Ver menos" : "Ver todas (" + root.filtered.length + ")"
        onClicked: root.showAll = !root.showAll
    }
}
