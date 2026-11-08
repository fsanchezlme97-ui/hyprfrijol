// «Firmar documentos»: abre un PDF (o una imagen), coloca tu firma —de una foto con el fondo quitado o dibujada
// con el ratón— y textos (nombre, fecha), y exporta «<nombre>-firmado.pdf». Biblioteca de firmas en
// ~/.local/share/hyprfrijol/firmas. Todo el trabajo lo hace scripts/hf-sign (PyMuPDF, o Poppler + cairo;
// ImageMagick para limpiar la foto).
// Se abre con la vista "firmar" (Spotlight › «Firmar documentos», Shell.open("firmar", "/ruta/doc.pdf")) o por IPC:
//   qs -p <repo>/config/quickshell ipc call firmar open [/ruta/doc.pdf] · … firmar close
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Scope {
    id: root
    property bool open: false
    property string pendingDoc: ""

    function show(path): void {
        if (path) pendingDoc = path;
        open = true;
    }

    Connections {
        target: Shell
        function onOpened(v) {
            if (v !== "firmar") return;
            root.show(typeof Shell.arg === "string" ? Shell.arg : "");
            Shell.close();
        }
    }
    IpcHandler {
        target: "firmar"
        function open(path: string): void { root.show(path); }
        function close(): void { root.open = false; }
        // pruebas / atajos: poner la firma n.º i de la biblioteca, un texto, exportar, limpiar una foto, dibujar
        function state(): string { return root.open ? "abierta" : "cerrada"; }
        function addSignature(i: int): void { root.action("firma", String(i)); }
        function addText(t: string): void { root.action("texto", t); }
        function exportPdf(): void { root.action("exportar", ""); }
        function photo(path: string): void { root.action("foto", path); }
        function draw(): void { root.action("dibujar", ""); }
    }
    signal action(string what, string arg)

    LazyLoader {
        active: root.open
        FloatingWindow {
            id: win
            title: "Firmar documentos"
            readonly property var scr: Shell.screen
            implicitWidth: Math.min(1240, Math.round((scr?.width ?? 1920) * 0.9))
            implicitHeight: Math.min(820, Math.round((scr?.height ?? 1080) * 0.88))
            minimumSize: Qt.size(Math.min(900, implicitWidth), Math.min(560, implicitHeight))
            visible: true
            color: Theme.blur ? Theme.winSolid : Theme.s1
            onVisibleChanged: if (!visible) root.open = false

            readonly property string cmd: Paths.script("hf-sign")
            readonly property string cache: Paths.cache + "/firmar"
            // ---------- estado ----------
            property var st: ({ backend: "", magick: true })
            property var lib: []
            property string doc: ""                 // documento abierto
            property var info: ({ pages: 0, sizes: [] })
            property int page: 0
            property var pageImg: ({})              // página → png
            property var items: []                  // { id, page, kind: img|text, src, x, y, w, h, text, color, aspect }
            property int nextId: 1
            property int sel: -1
            property real zoom: 1
            property string ink: Settings.get("signInk", "#1a2b6d")
            property string fullName: ""
            property string msg: ""
            property string outPath: ""
            property bool busy: false
            property string dialog: ""              // "" | foto | dibujo
            readonly property string inkHex: ink === "original" ? "#1a1a1a" : ink
            readonly property string docName: doc.split("/").pop()

            // ---------- procesos ----------
            Component {
                id: jobComp
                Process {
                    id: job
                    property var cb: null
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let r = text.trim();
                            try { r = JSON.parse(r); } catch (e) {}
                            if (job.cb) job.cb(r);
                            job.destroy();
                        }
                    }
                    Component.onCompleted: running = true
                }
            }
            function run(args, cb): void { jobComp.createObject(win, { command: args, cb: cb ?? null }); }
            function sign(args, cb): void { run([cmd].concat(args), cb); }

            function refreshLib(): void { sign(["list"], r => { if (Array.isArray(r)) win.lib = r; }); }
            function stamp(): string { return Date.now().toString(36); }

            Component.onCompleted: {
                run(["mkdir", "-p", cache]);
                sign(["status"], r => { if (r && r.backend !== undefined) win.st = r; });
                refreshLib();
                run(["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"], r => win.fullName = String(r || "").trim() || Quickshell.env("USER"));
                if (root.pendingDoc) { openDoc(root.pendingDoc); root.pendingDoc = ""; }
            }
            Connections {
                target: root
                function onPendingDocChanged() { if (root.pendingDoc) { win.openDoc(root.pendingDoc); root.pendingDoc = ""; } }
                function onAction(what, arg) {
                    if (what === "firma") { const it = libGrid.children.filter(c => c.modelData)[Number(arg)]; if (it) it.place(); }
                    else if (what === "texto") win.addText(arg === "fecha" ? win.today() : arg);
                    else if (what === "exportar") win.exportPdf();
                    else if (what === "foto") photo.load(arg);
                    else if (what === "dibujar") { pad.clear(); win.dialog = "dibujo"; }
                }
            }

            function openDoc(path): void {
                path = String(path).replace(/^file:\/\//, "");
                path = decodeURIComponent(path);
                msg = ""; outPath = ""; busy = true;
                sign(["info", path], r => {
                    busy = false;
                    if (!r || r.error) { msg = r?.error ?? "No pude abrir el documento"; return; }
                    win.doc = path; win.info = r; win.items = []; win.pageImg = {}; win.sel = -1; win.zoom = 1;
                    win.goPage(0);
                });
            }
            function goPage(n): void {
                if (n < 0 || n >= info.pages) return;
                page = n; sel = -1;
                if (pageImg[n]) return;
                const out = cache + "/pagina-" + n + "-" + stamp() + ".png";
                busy = true;
                sign(["render", doc, String(n), out, "--width", "1600"], r => {
                    busy = false;
                    if (r && r.path) { const m = Object.assign({}, win.pageImg); m[n] = r.path; win.pageImg = m; }
                    else msg = r?.error ?? "No pude mostrar la página";
                });
            }
            function pickDoc(): void {
                // Selector del portal (GTK) o zenity: scripts/hf-pickfile
                run([Paths.script("hf-pickfile"), "--title", "Abrir documento para firmar", "--filter", "PDF e imágenes|*.pdf *.png *.jpg *.jpeg *.webp"],
                    r => { if (String(r).trim()) win.openDoc(String(r).trim().split("\n")[0]); });
            }
            function pageAspect(): real { const s = info.sizes[page] ?? [595, 842]; return s[0] / s[1]; }

            // ---------- elementos ----------
            function addImage(src, aspect): void {
                if (!doc) { msg = "Abre primero un documento"; return; }
                const w = 0.28, h = w * pageAspect() / Math.max(0.1, aspect);
                const id = nextId++;
                items = items.concat([{ id: id, page: page, kind: "img", src: src, x: 0.5 - w / 2, y: 0.72, w: w, h: h, aspect: aspect }]);
                sel = id;
            }
            function addText(t): void {
                if (!doc || !t) return;
                const id = nextId++;
                items = items.concat([{ id: id, page: page, kind: "text", text: t, x: 0.55, y: 0.8, w: 0, h: 0.02, color: inkHex }]);
                sel = id;
            }
            function update(id, patch): void { items = items.map(i => i.id === id ? Object.assign({}, i, patch) : i); }
            function remove(id): void { items = items.filter(i => i.id !== id); if (sel === id) sel = -1; }
            function today(): string {
                const m = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
                const d = new Date();
                return d.getDate() + " de " + m[d.getMonth()] + " de " + d.getFullYear();
            }
            function exportPdf(): void {
                if (!doc || !items.length) return;
                busy = true; msg = ""; outPath = "";
                const spec = { input: doc, items: items.map(i => ({ page: i.page, kind: i.kind, src: i.src, text: i.text, color: i.color, x: i.x, y: i.y, w: i.w, h: i.h })) };
                sign(["apply", JSON.stringify(spec)], r => {
                    busy = false;
                    if (r && r.output) { win.outPath = r.output; win.msg = "Guardado: " + r.output.split("/").pop(); }
                    else win.msg = r?.error ?? "No se pudo exportar";
                });
            }

            Shortcut { sequence: "Ctrl+W"; onActivated: root.open = false }
            Shortcut { sequence: "Ctrl+O"; onActivated: win.pickDoc() }
            Shortcut { sequence: "Ctrl+S"; onActivated: win.exportPdf() }
            Shortcut { sequence: "Delete"; enabled: win.sel >= 0 && win.dialog === "" && !nameField.input.activeFocus; onActivated: win.remove(win.sel) }
            Shortcut { sequence: "PgDown"; onActivated: win.goPage(win.page + 1) }
            Shortcut { sequence: "PgUp"; onActivated: win.goPage(win.page - 1) }
            Shortcut { sequence: "Escape"; onActivated: { if (win.dialog) win.dialog = ""; else win.sel = -1; } }

            DropArea {
                anchors.fill: parent
                onDropped: d => { if (d.hasUrls && d.urls.length) win.openDoc(String(d.urls[0])); }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ================= barra lateral =================
                Rectangle {
                    Layout.preferredWidth: 290
                    Layout.fillHeight: true
                    color: Theme.glassy ? Qt.alpha(Theme.bg, 0.35) : Theme.mica ? Qt.alpha(Theme.bg, 0.5) : Theme.bg
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Txt { text: "Firmar documentos"; size: 18; weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; text: "Pulsa una firma para ponerla en la página; arrástrala y cambia su tamaño desde la esquina."; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            Txt { text: "Tus firmas"; weight: Font.DemiBold; Layout.fillWidth: true }
                            Txt { text: win.lib.length ? String(win.lib.length) : ""; muted: true; size: 11.5 }
                        }
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120
                            clip: true
                            contentHeight: libGrid.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            QQC.ScrollBar.vertical: QQC.ScrollBar {}
                            GridLayout {
                                id: libGrid
                                width: parent.width
                                columns: 2
                                columnSpacing: 8; rowSpacing: 8
                                Repeater {
                                    model: win.lib
                                    Rectangle {
                                        id: card
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 74
                                        radius: Theme.r(8)
                                        function place() { win.addImage(card.modelData.path, thumb.implicitWidth / Math.max(1, thumb.implicitHeight)); }
                                        color: "#fbfaf7"                       // papel: la tinta oscura se ve en modo oscuro
                                        border.width: cma.containsMouse ? 2 : 1
                                        border.color: cma.containsMouse ? Theme.p : Theme.ov
                                        Image {
                                            id: thumb
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            source: "file://" + card.modelData.path
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: false
                                            mipmap: true
                                        }
                                        MouseArea {
                                            id: cma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: card.place()
                                        }
                                        Rectangle {
                                            visible: cma.containsMouse || dma.containsMouse
                                            anchors { top: parent.top; right: parent.right; margins: 4 }
                                            width: 22; height: 22; radius: 11
                                            color: dma.containsMouse ? Theme.danger : Qt.alpha("#000000", 0.45)
                                            Icon { anchors.centerIn: parent; name: "trash"; size: 12; color: "#ffffff" }
                                            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: win.sign(["delete", card.modelData.path], () => win.refreshLib()) }
                                        }
                                    }
                                }
                            }
                            Txt {
                                visible: win.lib.length === 0
                                width: parent.width
                                y: 10
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap; elide: Text.ElideNone
                                muted: true; size: 11.5
                                text: "Aún no tienes firmas.\nHazle una foto a tu firma en un papel blanco o dibújala."
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Button { Layout.fillWidth: true; text: "Desde una foto…"; enabled: win.st.magick !== false; onClicked: photo.pick() }
                            Button { Layout.fillWidth: true; text: "Dibujar…"; onClicked: { pad.clear(); win.dialog = "dibujo"; } }
                        }

                        Divider { vertical: false; Layout.fillWidth: true; Layout.topMargin: 4 }
                        Txt { text: "Color de la tinta"; weight: Font.DemiBold }
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: [["#1a1a1a", "Negro"], ["#1a2b6d", "Azul"], ["#2449b8", "Azul claro"], ["original", "Original"]]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool on: win.ink === modelData[0]
                                    implicitWidth: 28; implicitHeight: 28; radius: 14
                                    color: modelData[0] === "original" ? "transparent" : modelData[0]
                                    border.width: on ? 3 : 1
                                    border.color: on ? Theme.p : Theme.ov
                                    Txt { visible: parent.modelData[0] === "original"; anchors.centerIn: parent; text: "A"; size: 11; weight: Font.Bold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.ink = parent.modelData[0]; Settings.set("signInk", win.ink); } }
                                    QQC.ToolTip.visible: tma.containsMouse
                                    QQC.ToolTip.text: modelData[1]
                                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }
                            }
                            Txt { text: (win.ink === "original" ? "la de la foto" : ""); muted: true; size: 11 }
                        }

                        Divider { vertical: false; Layout.fillWidth: true; Layout.topMargin: 4 }
                        Txt { text: "Texto"; weight: Font.DemiBold }
                        Field {
                            id: nameField
                            Layout.fillWidth: true
                            icon: ""
                            placeholder: "Tu nombre"
                            text: win.fullName
                            onAccepted: win.addText(text.trim())
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Button { Layout.fillWidth: true; text: "+ Nombre"; enabled: !!win.doc && nameField.text.trim() !== ""; onClicked: win.addText(nameField.text.trim()) }
                            Button { Layout.fillWidth: true; text: "+ Fecha"; enabled: !!win.doc; onClicked: win.addText(win.today()) }
                        }

                        // motor / instalar
                        Rectangle {
                            visible: win.st.backend !== "pymupdf"
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            implicitHeight: bcol.implicitHeight + 16
                            radius: Theme.r(8)
                            color: Qt.alpha(Theme.p, 0.1)
                            ColumnLayout {
                                id: bcol
                                x: 10; y: 8; width: parent.width - 20
                                spacing: 6
                                Txt {
                                    Layout.fillWidth: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                                    text: win.st.backend === "poppler" ? "Usando Poppler + cairo: el PDF firmado pierde enlaces y formularios. PyMuPDF lo conserva tal cual."
                                        : "Para exportar el PDF firmado hace falta PyMuPDF."
                                }
                                Button {
                                    kind: "primary"; text: "Instalar PyMuPDF"
                                    onClicked: Pkg.install([{ key: "repo", pkg: win.st.pkg || "python-pymupdf", name: "PyMuPDF" }], "Instalar PyMuPDF")
                                }
                            }
                        }
                        Rectangle {
                            visible: win.st.magick === false
                            Layout.fillWidth: true
                            implicitHeight: mcol.implicitHeight + 16
                            radius: Theme.r(8)
                            color: Qt.alpha(Theme.danger, 0.1)
                            ColumnLayout {
                                id: mcol
                                x: 10; y: 8; width: parent.width - 20
                                Txt { Layout.fillWidth: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: "Para quitar el fondo de las fotos hace falta ImageMagick." }
                                Button { kind: "primary"; text: "Instalar ImageMagick"; onClicked: Pkg.install([{ key: "repo", pkg: win.st.magickPkg || "imagemagick", name: "ImageMagick" }], "Instalar ImageMagick") }
                            }
                        }
                    }
                }

                // ================= documento =================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    // barra de herramientas
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        spacing: 8
                        Button { text: "Abrir documento…"; onClicked: win.pickDoc() }
                        Txt { Layout.fillWidth: true; text: win.docName; weight: Font.Medium; Layout.leftMargin: 4 }
                        IconBtn { visible: win.info.pages > 1; icon: "chevron_left"; enabled: win.page > 0; onClicked: win.goPage(win.page - 1) }
                        Txt { visible: win.info.pages > 0; text: "Página " + (win.page + 1) + " de " + win.info.pages; tabular: true; muted: true }
                        IconBtn { visible: win.info.pages > 1; icon: "chevron_right"; enabled: win.page < win.info.pages - 1; onClicked: win.goPage(win.page + 1) }
                        Item { implicitWidth: 6 }
                        IconBtn { visible: !!win.doc; icon: "minus"; onClicked: win.zoom = Math.max(0.5, win.zoom - 0.25) }
                        Txt { visible: !!win.doc; text: Math.round(win.zoom * 100) + " %"; tabular: true; muted: true; size: 11.5
                            MouseArea { anchors.fill: parent; onClicked: win.zoom = 1 } }
                        IconBtn { visible: !!win.doc; icon: "plus"; onClicked: win.zoom = Math.min(3, win.zoom + 0.25) }
                        Item { implicitWidth: 6 }
                        Button {
                            kind: "primary"
                            text: win.busy ? "Trabajando…" : "Exportar PDF firmado"
                            enabled: !!win.doc && win.items.length > 0 && !win.busy && win.st.backend !== ""
                            onClicked: win.exportPdf()
                        }
                    }
                    // mensaje (guardado / error)
                    Rectangle {
                        visible: win.msg !== ""
                        Layout.fillWidth: true
                        Layout.leftMargin: 12; Layout.rightMargin: 12
                        implicitHeight: 38
                        radius: Theme.r(8)
                        color: win.outPath ? Qt.alpha(Theme.p, 0.12) : Qt.alpha(Theme.danger, 0.12)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 8
                            spacing: 10
                            Icon { name: win.outPath ? "check" : "alert"; size: 14; color: win.outPath ? Theme.p : Theme.danger }
                            Txt { Layout.fillWidth: true; text: win.msg }
                            Button { visible: !!win.outPath; kind: "link"; text: "Abrir"; onClicked: Qt.openUrlExternally("file://" + win.outPath) }
                            Button { visible: !!win.outPath; kind: "link"; text: "Mostrar en la carpeta"; onClicked: Qt.openUrlExternally("file://" + win.outPath.replace(/\/[^/]*$/, "")) }
                            IconBtn { icon: "x"; onClicked: { win.msg = ""; } }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 12
                        radius: Theme.r(10)
                        color: Theme.glassy ? Qt.alpha(Theme.bg, 0.5) : Theme.s3
                        clip: true

                        // vacío
                        ColumnLayout {
                            visible: !win.doc
                            anchors.centerIn: parent
                            spacing: 10
                            Icon { Layout.alignment: Qt.AlignHCenter; name: "file"; size: 44; color: Theme.tv; stroke: 1.4 }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: "Abre un PDF o una imagen para firmarlo"; size: 15; weight: Font.Medium }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: "o arrástralo aquí · se guarda como «nombre-firmado.pdf» junto al original"; muted: true; size: 12 }
                            Button { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; kind: "primary"; text: "Abrir documento…"; onClicked: win.pickDoc() }
                        }

                        Flickable {
                            id: flick
                            visible: !!win.doc
                            anchors.fill: parent
                            contentWidth: Math.max(width, paper.width + 48)
                            contentHeight: Math.max(height, paper.height + 48)
                            boundsBehavior: Flickable.StopAtBounds
                            QQC.ScrollBar.vertical: QQC.ScrollBar {}
                            QQC.ScrollBar.horizontal: QQC.ScrollBar {}
                            MouseArea { width: flick.contentWidth; height: flick.contentHeight; onClicked: win.sel = -1 }

                            Rectangle {
                                id: paper
                                readonly property real fitW: Math.min(flick.width - 48, (flick.height - 48) * win.pageAspect())
                                width: Math.max(100, fitW * win.zoom)
                                height: width / win.pageAspect()
                                x: Math.max(24, (flick.contentWidth - width) / 2)
                                y: Math.max(24, (flick.contentHeight - height) / 2)
                                color: "#ffffff"
                                layer.enabled: false
                                Rectangle { anchors.fill: parent; anchors.margins: -1; z: -1; color: "transparent"; border.width: 1; border.color: Qt.alpha("#000000", 0.18) }
                                Image {
                                    anchors.fill: parent
                                    source: win.pageImg[win.page] ? "file://" + win.pageImg[win.page] : ""
                                    fillMode: Image.Stretch
                                    asynchronous: true
                                    cache: false
                                    mipmap: true
                                }
                                MouseArea { anchors.fill: parent; onClicked: win.sel = -1 }

                                Repeater {
                                    model: win.items
                                    Item {
                                        id: pi
                                        required property var modelData
                                        readonly property bool isText: modelData.kind === "text"
                                        readonly property bool selected: win.sel === modelData.id
                                        visible: modelData.page === win.page
                                        x: modelData.x * paper.width
                                        y: modelData.y * paper.height
                                        width: isText ? txt.implicitWidth + 4 : modelData.w * paper.width
                                        height: modelData.h * paper.height
                                        Image {
                                            visible: !pi.isText
                                            anchors.fill: parent
                                            source: pi.isText ? "" : "file://" + pi.modelData.src
                                            fillMode: Image.Stretch
                                            mipmap: true
                                            cache: false
                                        }
                                        Text {
                                            id: txt
                                            visible: pi.isText
                                            x: 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: pi.modelData.text ?? ""
                                            color: pi.modelData.color ?? "#1a1a1a"
                                            font.family: "Helvetica"
                                            font.pixelSize: Math.max(4, pi.height * 0.78)
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            color: "transparent"
                                            radius: 3
                                            border.width: pi.selected ? 1.5 : (ima.containsMouse ? 1 : 0)
                                            border.color: Theme.p
                                        }
                                        MouseArea {
                                            id: ima
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            drag.target: pi
                                            drag.threshold: 0
                                            drag.minimumX: -pi.width / 2; drag.maximumX: paper.width - pi.width / 2
                                            drag.minimumY: -pi.height / 2; drag.maximumY: paper.height - pi.height / 2
                                            onPressed: win.sel = pi.modelData.id
                                            onReleased: win.update(pi.modelData.id, { x: pi.x / paper.width, y: pi.y / paper.height })
                                        }
                                        // asa: tamaño (proporcional)
                                        Rectangle {
                                            visible: pi.selected
                                            width: 12; height: 12; radius: 6
                                            x: parent.width - 6 + 3; y: parent.height - 6 + 3
                                            color: Theme.p
                                            border.width: 2; border.color: "#ffffff"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                cursorShape: Qt.SizeFDiagCursor
                                                preventStealing: true
                                                property real sx; property real sw; property real sh
                                                onPressed: m => { const p = mapToItem(paper, m.x, m.y); sx = p.x; sw = pi.width; sh = pi.height; }
                                                onPositionChanged: m => {
                                                    if (!pressed) return;
                                                    const p = mapToItem(paper, m.x, m.y);
                                                    const k = Math.max(0.15, (sw + p.x - sx) / sw);
                                                    pi.height = Math.max(6, sh * k);
                                                    if (!pi.isText) pi.width = Math.max(10, sw * k);
                                                }
                                                onReleased: win.update(pi.modelData.id, pi.isText ? { h: pi.height / paper.height }
                                                                                                   : { w: pi.width / paper.width, h: pi.height / paper.height })
                                            }
                                        }
                                        // quitar
                                        Rectangle {
                                            visible: pi.selected
                                            width: 20; height: 20; radius: 10
                                            x: parent.width - 4; y: -16
                                            color: Theme.danger
                                            Icon { anchors.centerIn: parent; name: "x"; size: 11; color: "#ffffff" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.remove(pi.modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                        Txt {
                            visible: win.busy
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 12 }
                            text: "Trabajando…"; muted: true
                        }
                    }
                    Txt {
                        visible: !!win.doc
                        Layout.leftMargin: 14; Layout.bottomMargin: 10
                        muted: true; size: 11
                        text: win.items.length === 0 ? "Elige una firma de la izquierda o añade tu nombre y la fecha."
                            : win.items.length + (win.items.length === 1 ? " elemento" : " elementos") + " · Supr quita el seleccionado · Av Pág / Re Pág cambian de página"
                    }
                }
            }

            // ================= diálogos =================
            Rectangle {
                id: scrim
                anchors.fill: parent
                visible: win.dialog !== ""
                color: Qt.alpha("#000000", 0.4)
                MouseArea { anchors.fill: parent; onClicked: {} }
            }

            // ---------- firma desde una foto ----------
            Rectangle {
                id: photo
                visible: win.dialog === "foto"
                anchors.centerIn: parent
                width: Math.min(parent.width - 60, 860)
                height: Math.min(parent.height - 60, 560)
                radius: Theme.r(14)
                color: Theme.s1
                border.width: 1; border.color: Theme.ov
                property string src: ""
                property string result: ""
                property string err: ""
                property bool working: false
                property real strength: 0.5
                function pick(): void {
                    win.run([Paths.script("hf-pickfile"), "--title", "Foto de tu firma", "--filter", "Imágenes|*.png *.jpg *.jpeg *.webp *.heic"],
                        r => { if (String(r).trim()) photo.load(String(r).trim().split("\n")[0]); });
                }
                function load(path): void { src = path; result = ""; err = ""; nameIn.text = ""; win.dialog = "foto"; process(); }
                function process(): void {
                    if (!src) return;
                    working = true; err = "";
                    const out = win.cache + "/limpia-" + win.stamp() + ".png";
                    win.sign(["clean", src, out, "--ink", win.ink, "--strength", strength.toFixed(2)], r => {
                        photo.working = false;
                        if (r && r.path) photo.result = r.path; else { photo.result = ""; photo.err = r?.error ?? "No se pudo procesar"; }
                    });
                }
                Connections { target: win; function onInkChanged() { if (win.dialog === "foto") photo.process(); } }
                Timer { id: reproc; interval: 250; onTriggered: photo.process() }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    Txt { text: "Firma desde una foto"; size: 17; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; muted: true; size: 12; wrapMode: Text.WordWrap; text: "Mejor con la firma en un papel blanco, buena luz y sin otras líneas cerca. Se quita el papel y las sombras y queda solo el trazo." }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Theme.r(8); color: Theme.s3; clip: true
                            Image { anchors.fill: parent; anchors.margins: 8; source: photo.src ? "file://" + photo.src : ""; fillMode: Image.PreserveAspectFit; asynchronous: true; autoTransform: true }
                            Txt { anchors { left: parent.left; top: parent.top; margins: 8 } text: "Foto"; size: 11; muted: true }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Theme.r(8); clip: true
                            color: "#ffffff"
                            // cuadrícula: se ve la transparencia
                            Grid {
                                anchors.fill: parent
                                columns: Math.ceil(width / 16)
                                Repeater {
                                    model: Math.ceil(parent.width / 16) * Math.ceil(parent.height / 16)
                                    Rectangle { required property int index; width: 16; height: 16
                                        readonly property int cols: Math.ceil(parent.width / 16)
                                        color: (Math.floor(index / cols) + index % cols) % 2 ? "#f1f1f1" : "#ffffff" }
                                }
                            }
                            Image { anchors.fill: parent; anchors.margins: 16; source: photo.result ? "file://" + photo.result : ""; fillMode: Image.PreserveAspectFit; cache: false; mipmap: true }
                            Txt { anchors { left: parent.left; top: parent.top; margins: 8 } text: "Resultado"; size: 11; color: "#666666" }
                            Txt { visible: photo.working; anchors.centerIn: parent; text: "Quitando el fondo…"; color: "#444444" }
                            Txt { visible: !!photo.err && !photo.working; anchors.centerIn: parent; width: parent.width - 40; wrapMode: Text.WordWrap; elide: Text.ElideNone; horizontalAlignment: Text.AlignHCenter; text: photo.err; color: "#B3261E" }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Txt { text: "Sensibilidad"; muted: true }
                        SliderBar {
                            Layout.preferredWidth: 220
                            implicitHeight: 22
                            icon: "contrast"
                            value: photo.strength
                            onMoved: v => { photo.strength = v; reproc.restart(); }
                        }
                        Txt { Layout.fillWidth: true; muted: true; size: 11; text: photo.strength < 0.35 ? "solo trazos marcados" : photo.strength > 0.7 ? "recoge trazos finos (y algo de ruido)" : "equilibrada" }
                        Txt { text: "Tinta: " + (win.ink === "original" ? "la de la foto" : "la elegida a la izquierda"); muted: true; size: 11 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Field { id: nameIn; Layout.preferredWidth: 240; icon: ""; placeholder: "Nombre (opcional)" }
                        Item { Layout.fillWidth: true }
                        Button { text: "Otra foto…"; onClicked: photo.pick() }
                        Button { text: "Cancelar"; onClicked: win.dialog = "" }
                        Button {
                            kind: "primary"; text: "Guardar firma"
                            enabled: !!photo.result && !photo.working
                            onClicked: win.sign(["save", photo.result, nameIn.text.trim()], r => { win.dialog = ""; win.refreshLib(); })
                        }
                    }
                }
            }

            // ---------- dibujar ----------
            Rectangle {
                id: drawDlg
                visible: win.dialog === "dibujo"
                anchors.centerIn: parent
                width: Math.min(parent.width - 60, 760)
                height: Math.min(parent.height - 60, 470)
                radius: Theme.r(14)
                color: Theme.s1
                border.width: 1; border.color: Theme.ov
                property real lw: 3
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    Txt { text: "Dibuja tu firma"; size: 17; weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.r(8)
                        color: "#fbfaf7"
                        Rectangle { x: 40; width: parent.width - 80; y: parent.height * 0.72; height: 1; color: "#c9c4b8" }
                        Txt { x: 40; y: parent.height * 0.72 + 6; text: "Firma sobre la línea"; size: 11; color: "#9a948a" }
                        Canvas {
                            id: pad
                            anchors.fill: parent
                            property var strokes: []
                            property var cur: []
                            function clear() { strokes = []; cur = []; requestPaint(); }
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                c.lineCap = "round"; c.lineJoin = "round";
                                c.strokeStyle = win.inkHex; c.lineWidth = drawDlg.lw;
                                for (const s of strokes.concat(cur.length ? [cur] : [])) {
                                    if (s.length < 2) continue;
                                    c.beginPath();
                                    c.moveTo(s[0], s[1]);
                                    for (let i = 2; i < s.length - 2; i += 2) {
                                        const mx = (s[i] + s[i + 2]) / 2, my = (s[i + 1] + s[i + 3]) / 2;
                                        c.quadraticCurveTo(s[i], s[i + 1], mx, my);
                                    }
                                    c.lineTo(s[s.length - 2], s[s.length - 1]);
                                    c.stroke();
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.CrossCursor
                                onPressed: m => { pad.cur = [m.x, m.y, m.x + 0.1, m.y]; pad.requestPaint(); }
                                onPositionChanged: m => { if (pressed) { pad.cur = pad.cur.concat([m.x, m.y]); pad.requestPaint(); } }
                                onReleased: { pad.strokes = pad.strokes.concat([pad.cur]); pad.cur = []; pad.requestPaint(); }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Txt { text: "Grosor"; muted: true }
                        Seg {
                            model: [[2, "Fino"], [3, "Medio"], [4.5, "Grueso"]]
                            current: drawDlg.lw
                            onPicked: k => { drawDlg.lw = k; pad.requestPaint(); }
                        }
                        Field { id: drawName; Layout.preferredWidth: 200; icon: ""; placeholder: "Nombre (opcional)" }
                        Item { Layout.fillWidth: true }
                        Button { text: "Borrar"; onClicked: pad.clear() }
                        Button { text: "Cancelar"; onClicked: win.dialog = "" }
                        Button {
                            kind: "primary"; text: "Guardar firma"
                            enabled: pad.strokes.length > 0
                            onClicked: {
                                const spec = JSON.stringify({ w: pad.width, h: pad.height, width: drawDlg.lw, strokes: pad.strokes });
                                const out = win.cache + "/dibujo-" + win.stamp() + ".png";
                                win.run(["sh", "-c", "printf '%s' \"$1\" | \"$0\" draw - \"$2\" --ink \"$3\" >/dev/null && \"$0\" save \"$2\" \"$4\"",
                                         win.cmd, spec, out, win.inkHex, drawName.text.trim()], r => { win.dialog = ""; drawName.text = ""; win.refreshLib(); });
                            }
                        }
                    }
                }
            }
        }
    }
}
