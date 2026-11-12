// Ajustes › Aplicaciones › «Apps de HyprFrijol»: el catálogo por nivel (install/apps.json) con su estado y
// botones de instalar/quitar. Solo enseña: el trabajo lo hace scripts/hf-apps (lo mismo que install.sh --apps=…
// y la IA). Instala en una terminal donde ves cada comando (appsInstallMode "terminal", por defecto) o con
// pkexec y una barra de progreso («@@ i/n paso» de hf-apps --progress) (appsInstallMode "pkexec").
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"

Section {
    id: root
    title: "Apps de HyprFrijol"
    headerRight: Txt {
        text: (info.familyLabel ? info.familyLabel + (info.simulated ? " (simulada)" : "") + " · " : "") + (info.verified ? "catálogo comprobado el " + fmtDate(info.verified) : "")
        muted: true; size: 11.5
    }

    property var info: ({})
    property string tier: "serie"
    property string busy: ""           // id de la app (o «tier:x») que se instala con pkexec
    property real progress: 0
    property real progressCeil: -1      // final del paso en curso: la barra avanza sola hasta ahí mientras tarda
    property string progressText: ""
    readonly property string mode: Settings.get("appsInstallMode", "terminal")
    readonly property var tiers: info.tiers ?? []
    readonly property var apps: (info.apps ?? []).filter(a => a.tier === tier)
    readonly property var tierInfo: tiers.find(t => t.key === tier) ?? {}
    readonly property var missing: apps.filter(a => !a.installed && !a.alt_of && a.source)
    readonly property var nameOf: { const m = {}; (info.apps ?? []).forEach(a => m[a.id] = a.name); return m; }

    function fmtDate(d: string): string {
        const p = String(d).split("-");
        const mes = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        return p.length === 3 ? Number(p[2]) + " de " + mes[Number(p[1]) - 1] + " de " + p[0] : d;
    }
    function reload(): void { lister.running = false; lister.running = true; }
    function iconOf(a): string {
        for (const d of (a.desktop ?? [])) { const p = Quickshell.iconPath(d.replace(/\.desktop$/, ""), true); if (p) return p; }
        return Quickshell.iconPath(a.id, true) || "";
    }
    // hf-apps <acción> <objetivo>: en la terminal, o con pkexec y progreso
    function act(action: string, target: string, title: string): void {
        const cmd = [Paths.script("hf-apps"), action, target];
        if (mode === "pkexec") {
            busy = target; progress = 0; progressCeil = 0.08; progressText = "Preparando…";
            worker.command = cmd.concat(["--pkexec", "--yes", "--progress"]);
            worker.running = true;
        } else {
            Pkg.runInTerminal(cmd.map(x => "'" + x.replace(/'/g, "'\\''") + "'").join(" "), title);
            poll.n = 0; poll.restart();
        }
    }

    Component.onCompleted: reload()
    Process {
        id: lister
        command: [Paths.script("hf-apps"), "list", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text); } catch (e) { console.warn("[apps] hf-apps list: " + e); } } }
    }
    Process {
        id: worker
        stdout: SplitParser {
            onRead: l => {
                const m = /^@@ (\d+)\/(\d+) (.*)$/.exec(l);
                // «@@ i/n» avisa al EMPEZAR el paso i: hecho (i−1)/n; mientras dura, avanza despacio hacia i/n
                if (m) {
                    const i = Number(m[1]), n = Number(m[2]);
                    root.progress = n ? Math.max(0, i - 1) / n : 0;
                    root.progressCeil = n && i > 0 ? i / n : -1;
                    root.progressText = m[3];
                }
                else if (/^@@ sistema: /.test(l)) root.progressText = l.slice(12);
                else if (/^\s*✗/.test(l)) root.progressText = l.trim();
            }
        }
        onExited: (code) => { if (code === 0) root.progress = 1; root.progressCeil = -1; root.progressText = code === 0 ? "Listo" : "Terminó con errores (código " + code + ")"; root.busy = ""; root.reload(); }
    }
    // En modo terminal no sabemos cuándo acaba: se vuelve a mirar el estado cada 15 s durante 3 min
    Timer { id: poll; interval: 15000; repeat: true; property int n: 0; onTriggered: { root.reload(); if (++n >= 12) stop(); } }

    // ---------- niveles ----------
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Seg {
            fill: false
            model: root.tiers.map(t => [t.key, t.label])
            current: root.tier
            onPicked: k => root.tier = k
        }
        Item { Layout.fillWidth: true }
        Button {
            h: 30; kind: "primary"
            visible: root.missing.length > 0
            enabled: root.busy === ""
            text: "Instalar " + (root.missing.length === root.apps.filter(a => !a.alt_of).length ? "todo el nivel" : "las " + root.missing.length + " que faltan")
            onClicked: root.act("install", root.tier, "Instalar apps: " + (root.tierInfo.label ?? root.tier))
        }
    }
    Txt { Layout.fillWidth: true; text: root.tierInfo.desc ?? ""; muted: true; size: 11.5; wrapMode: Text.WordWrap }

    // ---------- progreso (pkexec) ----------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.busy !== "" || (root.progressText !== "" && root.mode === "pkexec")
        spacing: 4
        Txt { Layout.fillWidth: true; text: root.progressText; size: 11.5; elide: Text.ElideRight }
        Progress {
            Layout.fillWidth: true
            value: root.progress
            ceiling: root.progressCeil
            period: 500
            creepMs: 45000
            busy: root.busy !== ""
            track: Theme.s4
        }
    }

    // ---------- apps del nivel ----------
    Repeater {
        model: root.apps
        Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property var a: modelData
            readonly property bool working: root.busy === a.id || root.busy === root.tier
            Layout.fillWidth: true
            implicitHeight: 54
            radius: Theme.r(6)
            color: rma.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
            Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.ov }
            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: row.a.alt_of ? 26 : 6; anchors.rightMargin: 6
                spacing: 12
                Item {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    Image {
                        id: ico
                        anchors.fill: parent
                        source: root.iconOf(row.a)
                        sourceSize: Qt.size(60, 60)
                        asynchronous: true; smooth: true; mipmap: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent; visible: !ico.visible; radius: Theme.r(8); color: Theme.s3
                        Txt { anchors.centerIn: parent; text: row.a.name.charAt(0); weight: Font.DemiBold; color: Theme.tv }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        Txt { text: row.a.name; weight: Font.DemiBold }
                        Rectangle {
                            visible: row.a.status !== "" && row.a.status !== "estable"
                            implicitWidth: st.implicitWidth + 10; implicitHeight: 16; radius: Theme.r(4)
                            color: Qt.alpha(row.a.status === "experimental" ? "#D08A2E" : "#8A63D2", Theme.light ? 0.15 : 0.25)
                            Txt { id: st; anchors.centerIn: parent; text: row.a.status; size: 9.5; weight: Font.Bold }
                        }
                        Txt { text: row.a.task + (row.a.alt_of ? " · alternativa a " + (root.nameOf[row.a.alt_of] ?? row.a.alt_of) : ""); muted: true; size: 11.5; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Txt { Layout.fillWidth: true; text: row.a.desc; muted: true; size: 11.5; elide: Text.ElideRight }
                }
                Rectangle {   // fuente (como las insignias del Centro de aplicaciones)
                    readonly property string key: row.a.installed ? row.a.via : row.a.source
                    readonly property string hkey: ({ native: "repo", vendor: "repo", flatpakBundle: "flatpak", build: "script", other: "repo" })[key] ?? key
                    visible: key !== ""
                    implicitWidth: sl.implicitWidth + 12; implicitHeight: 18; radius: Theme.r(4)
                    color: Qt.alpha(Pkg.hue(hkey), Theme.light ? 0.15 : 0.22)
                    border.width: 1; border.color: Qt.alpha(Pkg.hue(hkey), 0.55)
                    Txt { id: sl; anchors.centerIn: parent; text: row.a.installed ? row.a.viaLabel : row.a.sourceLabel; size: 10; weight: Font.Bold
                          color: Theme.light ? Qt.darker(Pkg.hue(parent.hkey), 1.55) : Qt.lighter(Pkg.hue(parent.hkey), 1.5) }
                    MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true }
                    HoverTip { shown: bma.containsMouse; text: (row.a.installed ? "Instalada (" + row.a.viaLabel + ")" : row.a.detail) + (row.a.note ? "\n" + row.a.note : "") }
                }
                Txt { visible: row.a.installed; text: "✓ Instalada"; size: 11.5; color: Theme.p; weight: Font.DemiBold }
                Txt { visible: !row.a.installed && !row.a.source; text: "Sin fuente aquí"; muted: true; size: 11.5 }
                Button {
                    visible: !row.a.installed && !!row.a.source
                    h: 28; text: row.working ? "Instalando…" : "Instalar"; kind: row.a.alt_of ? "outline" : "primary"
                    enabled: root.busy === ""
                    onClicked: root.act("install", row.a.id, "Instalar " + row.a.name)
                }
                Button {
                    visible: row.a.installed && row.a.via !== "other"
                    h: 28; text: "Quitar"
                    enabled: root.busy === ""
                    onClicked: root.act("remove", row.a.id, "Quitar " + row.a.name)
                }
            }
        }
    }

    // ---------- opciones ----------
    SwRow {
        label: "Preferir Flatpak"
        sub: "Instala desde Flathub aunque tu distro tenga el paquete (appsPreferFlatpak)"
        key: "appsPreferFlatpak"
        onToggled: v => { Settings.set("appsPreferFlatpak", v); Qt.callLater(root.reload); }
    }
    SwRow {
        label: "Hacer predeterminadas las de serie al instalarlas"
        sub: "Chrome para la web, Loupe para fotos, Papers para PDF, Showtime/Decibels para vídeo y música…"
        key: "appsAutoDefaults"; def: true
        onToggled: v => Settings.set("appsAutoDefaults", v)
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 10
        Txt { text: "Instalar"; weight: Font.DemiBold }
        Seg {
            fill: false
            model: [["terminal", "En una terminal"], ["pkexec", "Con pkexec y progreso"]]
            current: root.mode
            onPicked: k => Settings.set("appsInstallMode", k)
        }
        Item { Layout.fillWidth: true }
        Txt {
            text: (root.info.extension?.installed ? "Menú de Nautilus activo" : "Menú de Nautilus sin activar")
                + (root.info.extension && !root.info.extension.nautilusPython ? " · falta nautilus-python" : "")
            muted: true; size: 11.5
        }
        Button {
            h: 28
            visible: !(root.info.extension?.installed ?? true)
            text: "Activar el menú"
            onClicked: { extProc.running = true; }
        }
        Process { id: extProc; command: [Paths.script("hf-apps"), "extension"]; onExited: root.reload() }
    }
}
