// Escritorio. Ajuste "deskIcons": "todos" (por defecto) = iconos clásicos sobre el fondo en todos los espacios
// (DeskIcons.qml, capa inferior) · "ordenado" (antes "flotante") = escritorio ordenado por grupos a la derecha ·
// "no". Dock (Dock.qml): donde las ventanas flotan (modo «flotante» de "windowMode", services/WinMode.qml, o la
// excepción de los ajustes rápidos) y en todos los espacios con "dockInTiling"; "dockBehavior" = fijo / auto /
// inteligente.
// - Dock: apps fijadas (ajuste "dockApps", ids .desktop) + las abiertas (también las minimizadas). Clic: ir a
//   su ventana o abrirla; en la activa: minimizar; en una minimizada: restaurarla; clic central: nueva ventana;
//   clic derecho: menú (DockMenu.qml). Abajo, «Aplicaciones» (Spotlight).
// - Escritorio: archivos de xdg-user-dir DESKTOP agrupados por Tipo / Fecha / Nombre (ajuste "deskSort").
//   Clic abre el archivo; clic derecho lo muestra en la carpeta. Arrastra un grupo por su título para
//   reordenarlo (ajuste "deskOrder"). Se actualiza solo cada pocos segundos mientras está visible.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    readonly property string sortKey: Settings.get("deskSort", "tipo")
    readonly property var pinned: DockPins.pinned     // services/DockPins.qml (también lo usa el Spotlight)
    readonly property bool dry: Quickshell.env("HF_TRY") === "1"

    // ---------- archivos del escritorio ----------
    // Ajuste "deskIcons": "todos" (iconos clásicos sobre el fondo) · "ordenado" (o el antiguo "flotante":
    // escritorio ordenado por grupos) · "no".
    readonly property string deskMode: { const v = Settings.get("deskIcons", "todos"); return v === "flotante" ? "ordenado" : v; }
    property string deskDir: ""
    property var files: []        // [{ n, dir, t (s), path, label, icon? }]
    property bool scanned: false
    property string lastScan: ""
    Process {
        id: scan
        command: ["sh", "-c", 'd="${HF_DESKTOP_DIR:-$(xdg-user-dir DESKTOP 2>/dev/null)}"; [ -n "$d" ] || d="$HOME/Desktop"; printf "%s\\n" "$d"; '
                 + '[ -d "$d" ] || exit 0; find -H "$d" -mindepth 1 -maxdepth 1 ! -name ".*" -printf "%Y\\t%T@\\t%f\\n" 2>/dev/null; '
                 + 'for f in "$d"/*.desktop; do [ -f "$f" ] || continue; '
                 + 'printf "E\\t%s\\t%s\\t%s\\n" "${f##*/}" "$(sed -n "s/^Icon=//p" "$f" | head -n1)" "$(sed -n "s/^Name=//p" "$f" | head -n1)"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root.lastScan && root.scanned) return;   // sin cambios: no recrear los iconos
                root.lastScan = text;
                const lines = text.split("\n");
                root.deskDir = (lines.shift() ?? "").trim();
                const entries = {};
                for (const l of lines.filter(l => l.startsWith("E\t"))) {
                    const [, file, icon, name] = l.split("\t");
                    entries[file] = { icon: icon ?? "", name: name ?? "" };
                }
                root.files = lines.filter(l => l.includes("\t") && !l.startsWith("E\t")).map(l => {
                    const [y, t, ...n] = l.split("\t");
                    const name = n.join("\t");
                    const e = entries[name];
                    const f = { n: name, dir: y === "d", t: Number(t), path: root.deskDir + "/" + name,
                                label: e?.name || name, entryIcon: e?.icon ?? "" };
                    f.thumb = !f.dir && /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(name);
                    return f;
                });
                root.scanned = true;
            }
        }
    }
    Timer {
        running: root.deskMode !== "no"
        repeat: true; interval: 4000; triggeredOnStart: true
        onTriggered: scan.running = true
    }
    // Orden del escritorio clásico: carpetas primero, luego por nombre
    readonly property var sortedFiles: files.slice().sort((a, b) => (b.dir - a.dir)
        || a.label.localeCompare(b.label, "es", { numeric: true, sensitivity: "base" }))

    function fileUrl(p: string): string { return "file://" + p.split("/").map(encodeURIComponent).join("/"); }
    // Icono del tema por tipo (nombres freedesktop, del más concreto al genérico)
    readonly property var extIcons: ({
        pdf: ["application-pdf"], epub: ["application-epub+zip", "x-office-document"],
        doc: ["application-msword", "x-office-document"], docx: ["application-vnd.openxmlformats-officedocument.wordprocessingml.document", "x-office-document"],
        odt: ["application-vnd.oasis.opendocument.text", "x-office-document"], rtf: ["application-rtf", "x-office-document"],
        xls: ["application-vnd.ms-excel", "x-office-spreadsheet"], xlsx: ["application-vnd.openxmlformats-officedocument.spreadsheetml.sheet", "x-office-spreadsheet"],
        ods: ["application-vnd.oasis.opendocument.spreadsheet", "x-office-spreadsheet"], csv: ["text-csv", "x-office-spreadsheet"],
        ppt: ["application-vnd.ms-powerpoint", "x-office-presentation"], pptx: ["x-office-presentation"], odp: ["application-vnd.oasis.opendocument.presentation", "x-office-presentation"],
        md: ["text-markdown", "text-x-generic"], txt: ["text-plain", "text-x-generic"], log: ["text-x-log", "text-x-generic"],
        html: ["text-html"], htm: ["text-html"], json: ["application-json", "text-x-generic"], xml: ["application-xml", "text-xml"],
        yml: ["application-x-yaml", "text-x-generic"], yaml: ["application-x-yaml", "text-x-generic"], toml: ["text-x-generic"],
        sh: ["application-x-shellscript", "text-x-script"], py: ["text-x-python", "text-x-script"], js: ["application-javascript", "text-x-script"],
        lua: ["text-x-lua", "text-x-script"], c: ["text-x-csrc"], cpp: ["text-x-c++src"], rs: ["text-rust", "text-x-script"], qml: ["text-x-qml", "text-x-script"],
        zip: ["application-zip", "application-x-archive"], gz: ["application-x-compressed-tar", "application-x-archive"], xz: ["application-x-xz-compressed-tar", "application-x-archive"],
        zst: ["application-x-zstd-compressed-tar", "application-x-archive"], tar: ["application-x-tar", "application-x-archive"], "7z": ["application-x-7z-compressed", "application-x-archive"],
        rar: ["application-vnd.rar", "application-x-rar", "application-x-archive"], iso: ["application-x-cd-image"],
        appimage: ["application-x-executable"], deb: ["application-x-deb", "package-x-generic"], rpm: ["application-x-rpm", "package-x-generic"],
        flatpakref: ["application-vnd.flatpak.ref", "package-x-generic"], torrent: ["application-x-bittorrent"],
        stl: ["model-stl", "application-sla", "model"], "3mf": ["model-3mf", "model"], gcode: ["text-x-gcode", "text-x-generic"],
        ttf: ["font-x-generic"], otf: ["font-x-generic"], svg: ["image-svg+xml", "image-x-generic"], blend: ["application-x-blender"],
        kra: ["application-x-krita", "image-x-generic"], xcf: ["image-x-xcf", "image-x-generic"], psd: ["image-vnd.adobe.photoshop", "image-x-generic"]
    })
    function iconFor(f): string {
        if (f.dir) return Quickshell.iconPath("folder", true) || Quickshell.iconPath("inode-directory", true);
        if (f.entryIcon) {
            if (f.entryIcon.startsWith("/")) return fileUrl(f.entryIcon);
            const p = Quickshell.iconPath(f.entryIcon, true);
            if (p) return p;
        }
        const e = (/\.([^.]+)$/.exec(f.n)?.[1] ?? "").toLowerCase();
        const k = kind(f);
        const names = (extIcons[e] ?? []).concat(e === "desktop" ? ["application-x-desktop", "application-x-executable"]
            : k === "img" ? ["image-x-generic"] : k === "media" ? (/^(mp3|flac|ogg|opus|wav|m4a)$/.test(e) ? ["audio-x-generic"] : ["video-x-generic"])
            : k === "doc" ? ["x-office-document", "text-x-generic"] : [], ["unknown", "text-x-generic"]);
        for (const n of names) { const p = Quickshell.iconPath(n, true); if (p) return p; }
        return "";
    }

    function ext(f): string {
        if (f.dir) return "";
        const m = /\.([^.]+)$/.exec(f.n);
        const e = (m ? m[1] : "").toLowerCase();
        if (kind(f) === "img") return "IMG";
        if (e === "desktop" || e === "appimage" || e === "flatpakref") return "APP";
        return e.slice(0, 4).toUpperCase();
    }
    function kind(f): string {
        if (f.dir) return "dir";
        const e = (/\.([^.]+)$/.exec(f.n)?.[1] ?? "").toLowerCase();
        if (/^(png|jpe?g|gif|svg|webp|heic|heif|bmp|avif|tiff?|jxl|xcf|kra|psd)$/.test(e)) return "img";
        if (/^(pdf|docx?|odt|ods|odp|xlsx?|pptx?|md|txt|csv|rtf|epub|tex|html?|json|org)$/.test(e)) return "doc";
        if (/^(mp4|mkv|webm|mov|avi|mp3|flac|ogg|opus|wav|m4a)$/.test(e)) return "media";
        return "other";
    }
    function initialGroup(f): string {
        const c = f.n.normalize("NFD").charAt(0).toUpperCase();
        if (c >= "G" && c <= "O") return "G – O";
        if (c >= "P" && c <= "Z") return "P – Z";
        return "A – F";
    }
    readonly property var groupDefs: ({
        tipo: ["Carpetas", "Documentos", "Imágenes", "Vídeo y audio", "Otros"],
        fecha: ["Hoy", "Esta semana", "Anteriores"],
        nombre: ["A – F", "G – O", "P – Z"]
    })
    function groupOf(f): string {
        if (sortKey === "fecha") {
            const d = new Date(f.t * 1000), now = new Date();
            if (d.toDateString() === now.toDateString()) return "Hoy";
            return (now - d) < 7 * 86400000 ? "Esta semana" : "Anteriores";
        }
        if (sortKey === "nombre") return initialGroup(f);
        return ({ dir: "Carpetas", doc: "Documentos", img: "Imágenes", media: "Vídeo y audio", other: "Otros" })[kind(f)];
    }
    readonly property var groups: {
        const defs = groupDefs[sortKey] ?? groupDefs.tipo;
        const order = (Settings.get("deskOrder", ({}))[sortKey] ?? []).filter(g => defs.includes(g));
        const names = order.concat(defs.filter(g => !order.includes(g)));
        const cmp = (a, b) => a.localeCompare(b, "es", { numeric: true, sensitivity: "base" });
        return names.map(g => {
            const items = files.filter(f => groupOf(f) === g)
                .sort((a, b) => sortKey === "fecha" ? b.t - a.t : (b.dir - a.dir) || cmp(a.n, b.n));
            return { title: g, items: items };
        }).filter(g => g.items.length);
    }
    function moveGroup(from: string, to: string): void {
        if (from === to) return;
        const names = groups.map(g => g.title).filter(g => g !== from);
        names.splice(names.indexOf(to), 0, from);
        const all = Object.assign({}, Settings.get("deskOrder", ({})));
        all[sortKey] = names;
        Settings.set("deskOrder", all);
    }
    function openFile(f): void {
        if (dry) { console.info("[escritorio] (HF_TRY) xdg-open " + f.path); return; }
        Quickshell.execDetached(["xdg-open", f.path]);
    }
    function reveal(f): void {
        if (dry) { console.info("[escritorio] (HF_TRY) mostrar " + f.path); return; }
        Quickshell.execDetached(["sh", "-c", 'dbus-send --session --dest=org.freedesktop.FileManager1 --type=method_call /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:"file://$1" string:"" || xdg-open "$(dirname "$1")"', "sh", f.path]);
    }

    // ---------- dock ----------
    readonly property var running: {
        HyprClients.refreshes;
        const m = new Map();
        for (const c of HyprClients.byRecent.concat(WinMode.minimized)) {
            const e = HyprClients.entryFor(c.class);
            const id = e?.id ?? c.class;
            if (!m.has(id)) m.set(id, { id: id, entry: e, cls: c.class, wins: [] });
            m.get(id).wins.push(c);
        }
        return m;
    }
    readonly property var dockItems: {
        const out = pinned.map(id => {
            const r = running.get(id);
            return { id: id, entry: DesktopEntries.byId(id), wins: r?.wins ?? [], cls: r?.cls ?? "", pinned: true };
        });
        for (const [id, r] of running)
            if (!pinned.includes(id)) out.push({ id: id, entry: r.entry, wins: r.wins, cls: r.cls, pinned: false });
        return out;
    }
    // Clic en una app: abrirla · ir a su ventana (mejor una del espacio actual) · si ya es la activa, minimizarla ·
    // si todas están minimizadas, traer la última minimizada al espacio actual
    function activate(d): void {
        if (!d.wins.length) { launch(d); return; }
        const live = d.wins.filter(w => !WinMode.isMin(w));
        const active = live.find(w => w.address === HyprClients.activeAddress);
        if (active) { WinMode.minimize(active.address); return; }
        if (live.length) {
            const cur = Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1;
            const here = live.find(w => w.workspace?.id === cur) ?? live[0];
            Shell.dispatch('hl.dsp.focus({ window = "address:' + here.address + '" })');
            return;
        }
        const order = WinMode.minOrder;
        const last = d.wins.slice().sort((a, b) => order.indexOf(b.address) - order.indexOf(a.address))[0];
        WinMode.restore(last.address);
    }
    function launch(d): void {
        if (dry) { console.info("[dock] (HF_TRY) abrir " + d.id); return; }
        if (d.entry) d.entry.execute();
        else Quickshell.execDetached(["gtk-launch", d.id]);
    }
    // IPC (scripts y pruebas):  qs ipc call dock click 0 · dock menu 0 · dock items
    signal menuRequested(int index)
    IpcHandler {
        target: "dock"
        function click(i: int): void { const d = root.dockItems[i]; if (d) root.activate(d); }
        function menu(i: int): void { root.menuRequested(i); }
        function items(): string {
            return root.dockItems.map((d, i) => i + " " + d.id + " " + d.wins.map(w => WinMode.isMin(w) ? "min" : (w.fullscreen ?? 0) === 1 ? "max" : "win").join(",")).join("\n");
        }
    }
    function togglePin(d): void {
        const cur = pinned.slice();
        const i = cur.indexOf(d.id);
        if (i >= 0) cur.splice(i, 1); else if (d.entry) cur.push(d.entry.id);
        Settings.set("dockApps", cur);
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            readonly property var hmon: Hyprland.monitorFor(modelData)
            readonly property int wsId: hmon?.activeWorkspace?.id ?? -1
            // Escritorio ordenado ("deskIcons" = "ordenado") · dock: donde las ventanas flotan (o en todos, "dockInTiling")
            readonly property bool active: { WinMode.deskIcons; return WinMode.isDeskWs(wsId) && !Shell.focusMode; }
            readonly property bool dockShown: { WinMode.mode; WinMode.overrides; WinMode.dockInTiling; return wsId > 0 && WinMode.dockOn(wsId) && !Shell.focusMode; }
            readonly property bool deskOn: active && root.deskMode !== "no"

            // ===== Iconos clásicos sobre el fondo (resto de espacios) =====
            DeskIcons {
                screen: perScreen.modelData
                desk: root
                shown: root.deskMode === "todos" && !Shell.focusMode
                leftReserve: perScreen.dockShown && Settings.get("dockBehavior", "inteligente") !== "fijo" ? 6 + 54 + 4 : 0
            }

            // ===== Escritorio ordenado (capa inferior, debajo de las ventanas) =====
            PanelWindow {
                id: desk
                screen: perScreen.modelData
                visible: perScreen.deskOn || deskFade.running
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "hf-desk"
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                anchors { top: true; bottom: true; right: true }
                implicitWidth: 372 + 12
                mask: Region { item: deskCol }

                Item {
                    id: deskCol
                    anchors { fill: parent; margins: 6 }
                    opacity: perScreen.deskOn ? 1 : 0
                    Behavior on opacity { NumberAnimation { id: deskFade; duration: Theme.dur } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Cabecera: ordenado por
                        Glass {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            kind: "panel"
                            radius: Theme.r(8)
                            shadow: false
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 6
                                Txt { text: "Escritorio · ordenado por"; muted: true; Layout.fillWidth: true }
                                Repeater {
                                    model: [{ k: "tipo", l: "Tipo" }, { k: "fecha", l: "Fecha" }, { k: "nombre", l: "Nombre" }]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool on: root.sortKey === modelData.k
                                        Layout.preferredHeight: 22
                                        Layout.preferredWidth: sl.implicitWidth + 18
                                        radius: Theme.r(5)
                                        color: on ? Theme.fill2 : sma.containsMouse ? Qt.alpha(Theme.fill2, 0.5) : "transparent"
                                        Txt { id: sl; anchors.centerIn: parent; text: parent.modelData.l; weight: Font.Medium; muted: !parent.on }
                                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("deskSort", parent.modelData.k) }
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: flick
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, deskCol.height - 30 - 8 - 8 - foot.height)
                            contentHeight: groupsCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            ColumnLayout {
                                id: groupsCol
                                width: flick.width
                                spacing: 8

                                // Vacío
                                Glass {
                                    visible: root.scanned && root.files.length === 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 96
                                    kind: "bar"
                                    radius: Theme.r(8)
                                    shadow: false
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Icon { Layout.alignment: Qt.AlignHCenter; name: "folder"; size: 22; color: Theme.tv }
                                        Txt { Layout.alignment: Qt.AlignHCenter; text: "Tu escritorio está vacío"; weight: Font.DemiBold }
                                        Txt {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Lo que guardes en " + root.deskDir.replace(Paths.home, "~") + " aparecerá aquí"
                                            muted: true; size: 11.5
                                        }
                                    }
                                }

                                Repeater {
                                    model: root.groups
                                    delegate: Glass {
                                        id: grp
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: gcol.implicitHeight + 14
                                        kind: "bar"
                                        radius: Theme.r(8)
                                        shadow: false
                                        opacity: hdrMa.drag.active ? 0.6 : 1
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.r(8)
                                            color: "transparent"
                                            border.width: gdrop.containsDrag ? 2 : 0
                                            border.color: Theme.p
                                        }
                                        DropArea {
                                            id: gdrop
                                            anchors.fill: parent
                                            keys: ["hf-desk-group"]
                                            onDropped: d => root.moveGroup(d.source.title, grp.modelData.title)
                                        }
                                        ColumnLayout {
                                            id: gcol
                                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; topMargin: 8 }
                                            spacing: 4
                                            Item {
                                                id: hdr
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 16
                                                readonly property string title: grp.modelData.title
                                                Drag.active: hdrMa.drag.active
                                                Drag.keys: ["hf-desk-group"]
                                                Drag.hotSpot.y: 8
                                                Txt {
                                                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                                    text: grp.modelData.title; size: 11.5; weight: Font.DemiBold }
                                                Txt {
                                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                                    text: grp.modelData.items.length; size: 11.5; muted: true; tabular: true }
                                                MouseArea {
                                                    id: hdrMa
                                                    anchors.fill: parent
                                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    drag.target: hdr
                                                    drag.axis: Drag.YAxis
                                                    onReleased: { hdr.Drag.drop(); hdr.x = 0; hdr.y = 0; }
                                                }
                                            }
                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: 4
                                                columnSpacing: 2
                                                rowSpacing: 2
                                                Repeater {
                                                    model: grp.modelData.items
                                                    delegate: Rectangle {
                                                        id: fileItem
                                                        required property var modelData
                                                        readonly property string k: root.kind(modelData)
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        Layout.preferredHeight: 78
                                                        radius: Theme.r(6)
                                                        color: fma.containsMouse ? Theme.fill2 : "transparent"
                                                        readonly property string src: fileItem.modelData.thumb ? root.fileUrl(fileItem.modelData.path) : root.iconFor(fileItem.modelData)
                                                        Column {
                                                            anchors { top: parent.top; topMargin: 7; horizontalCenter: parent.horizontalCenter }
                                                            spacing: 4
                                                            Item {
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                width: 34; height: 34
                                                                Image {
                                                                    id: fIcon
                                                                    anchors.fill: parent
                                                                    source: fileItem.src
                                                                    sourceSize: Qt.size(68, 68)
                                                                    fillMode: Image.PreserveAspectFit
                                                                    asynchronous: true; smooth: true; mipmap: true
                                                                    visible: status === Image.Ready
                                                                }
                                                                // Sin icono en el tema: etiqueta de tipo
                                                                Rectangle {
                                                                    visible: !fIcon.visible
                                                                    anchors.centerIn: parent
                                                                    width: 32; height: 24; radius: Theme.r(4)
                                                                    color: fileItem.k === "dir" ? Theme.p : fileItem.k === "img" ? Theme.ter : Theme.s4
                                                                    Txt {
                                                                        anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
                                                                        text: root.ext(fileItem.modelData)
                                                                        size: 9; weight: Font.DemiBold
                                                                        color: fileItem.k === "dir" ? Theme.pText : fileItem.k === "img" ? Theme.bg : Theme.t
                                                                    }
                                                                }
                                                            }
                                                            Txt {
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                width: fileItem.width - 6
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignTop
                                                                text: fileItem.modelData.label ?? fileItem.modelData.n
                                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                                maximumLineCount: 2
                                                                lineHeight: 0.95
                                                                size: 11
                                                            }
                                                        }
                                                        MouseArea {
                                                            id: fma
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: e => e.button === Qt.RightButton ? root.reveal(fileItem.modelData) : root.openFile(fileItem.modelData)
                                                        }
                                                    }
                                                }
                                                // Rellena la fila para que las columnas no se estiren
                                                Repeater {
                                                    model: (4 - grp.modelData.items.length % 4) % 4
                                                    delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Glass {
                            id: foot
                            Layout.fillWidth: true
                            Layout.preferredHeight: footTxt.implicitHeight + 12
                            visible: root.files.length > 0
                            kind: "bar"
                            radius: Theme.r(8)
                            shadow: false
                            Txt {
                                id: footTxt
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                                text: "Los archivos nuevos se colocan solos en su grupo · arrastra un grupo para reordenarlo"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                                muted: true
                                size: 11
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ===== Dock (por encima de las ventanas) · Dock.qml =====
            Dock {
                screen: perScreen.modelData
                desk: root
                shown: perScreen.dockShown
                wsId: perScreen.wsId
            }
        }
    }
}
