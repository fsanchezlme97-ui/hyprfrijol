// Selector de fondos (vista "fondos", Super + Shift + W).
// Vista previa a pantalla completa del fondo elegido (fundido cruzado, WallBackdrop) y, abajo, su nombre, origen,
// resolución y colores, una tira de miniaturas centrada en la elegida (WallTile) y la botonera
// (pantalla · Aleatorio · Movimiento · Según la hora · Mis fondos · Wallhaven · Cancelar · Aplicar).
// Fondos: tu carpeta (~/Imágenes/Fondos o Wallpapers) + los de hyprfrijol (assets/wallpapers) + la caché de Wallhaven
// si es el origen elegido. `hf-wallpaper gallery` da la lista al momento y luego las miniaturas que falten
// (~/.cache/hyprfrijol/thumbs, en paralelo); el modelo se actualiza en su sitio, sin rehacer las miniaturas.
// La vista previa es solo del selector: el fondo de verdad cambia al aplicar (Cancelar no toca nada).
// Teclas: ← → (o rueda) cambiar · Re Pág / Av Pág de 5 en 5 · Inicio/Fin · escribir busca por nombre ("/" también)
// · R aleatorio · Intro aplicar · Esc cancelar (o salir de la búsqueda).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "fondos"
    place: "fill"
    margin: 0
    closeOnOutside: false

    ListModel { id: gallery }       // { path, thumb, name, video, origin, res, colors, rev }
    property int sel: 0
    property int dataRev: 0          // sube con cada cambio del modelo (para los bindings de `cur`)
    property string monitor: ""      // "" = todas
    property bool showHoras: false
    property bool showAdd: false
    property bool listing: false
    property bool userMoved: false
    property string pendingSelect: ""   // ruta que hay que elegir cuando aparezca (fondo añadido o de Wallhaven)
    property string query: ""
    property bool searching: false
    readonly property int count: gallery.count
    readonly property string current: (curFile.text() || "").trim()
    readonly property var cur: {
        dataRev;
        if (sel < 0 || sel >= gallery.count) return null;
        const e = gallery.get(sel);
        return { path: e.path, thumb: e.thumb, name: e.name, video: e.video, origin: e.origin, res: e.res, colors: e.colors, rev: e.rev };
    }
    // Origen en línea del cambio automático: "wallhaven" · "unsplash" · "" (la carpeta)
    readonly property string online: ["wallhaven", "unsplash"].includes(Settings.get("wallpaperSource", "carpeta")) ? Settings.get("wallpaperSource", "carpeta") : ""
    readonly property bool whOn: online !== ""
    readonly property bool webOrigin: !!cur && (cur.origin === "wallhaven" || cur.origin === "unsplash")
    // Autor de la foto de Unsplash elegida (sus normas piden nombrarlo)
    property var credit: ({})
    onCurChanged: { credit = ({}); if (cur && cur.origin === "unsplash") { creditProc.command = [Paths.script("hf-unsplash"), "credit", cur.path]; creditProc.running = true; } }
    Process {
        id: creditProc
        stdout: StdioCollector { onStreamFinished: { try { win.credit = JSON.parse(text); } catch (e) {} } }
    }

    // Tamaños (a 1080 p de alto: miniaturas de 224×140, la elegida a ×1,38)
    readonly property real k: Math.max(0.75, Math.min(1.3, height / 1080))
    readonly property real tileW: Math.round(224 * k)
    readonly property real tileH: Math.round(140 * k)
    readonly property real gap: Math.round(14 * k)
    readonly property real big: 1.38

    // Nombres bonitos para los fondos incluidos
    readonly property var names: ({ amanecer: "Atardecer", lago: "Lago", bosque: "Bosque", bruma: "Bruma", noche: "Noche",
                                    niebla: "Niebla", lineas: "Líneas", orbes: "Orbes", dunas: "Dunas" })
    function prettyName(path: string): string {
        const base = path.split("/").pop().replace(/\.[^.]+$/, "");
        if (names[base]) return names[base];
        const s = base.replace(/[_-]+/g, " ").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function isVideo(p: string): bool { return /\.(mp4|webm|mkv|mov|gif)$/i.test(p); }
    function fold(s: string): string { return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }
    function originLabel(o: string): string { return o === "incluido" ? "Incluido" : o === "wallhaven" ? "Wallhaven" : o === "unsplash" ? "Unsplash" : "Mis fondos"; }

    function reload(): void { galleryProc.running = false; galleryProc.running = true; }
    function go(i: int): void { if (count) { userMoved = true; sel = Math.max(0, Math.min(count - 1, i)); } }
    function step(d: int): void { if (count) { userMoved = true; sel = (sel + d + count) % count; } }
    function random(): void {
        if (count < 2) return;
        let r = sel; while (r === sel) r = Math.floor(Math.random() * count);
        go(r);
    }
    function apply(): void {
        if (!cur) return;
        const args = [Paths.script("hf-wallpaper")];
        if (monitor !== "") args.push("-o", monitor);
        args.push(cur.path);
        Quickshell.execDetached(args);
        Shell.close();
    }
    function cycleColors(): void {
        const m = Settings.get("colorMode", "auto");
        Settings.set("colorMode", m === "auto" ? "elegir" : m === "elegir" ? "mono" : "auto");
    }
    readonly property string colorName: {
        const m = Settings.get("colorMode", "auto");
        return m === "auto" ? "automáticos" : m === "mono" ? "monocromo" : Theme.paletteName;
    }
    // Búsqueda por nombre: salta a la primera coincidencia (sin filtrar la tira)
    function search(q: string): void {
        query = q;
        if (q === "") return;
        const f = fold(q);
        for (let i = 0; i < count; i++) {
            const e = gallery.get(i);
            if (fold(e.name).includes(f) || fold(e.path.split("/").pop()).includes(f)) { go(i); return; }
        }
    }

    // Lista: llega por líneas. Primero todas (en orden), luego "." y después las que faltaban, ya con miniatura.
    property int fill: 0
    property var where: ({})
    function onLine(line: string): void {
        if (line === ".") {
            while (gallery.count > fill) gallery.remove(gallery.count - 1);
            listing = false;
            if (sel >= gallery.count) sel = Math.max(0, gallery.count - 1);
            dataRev++;
            if (!userMoved) placeStrip(false);
            return;
        }
        const c = line.split("\t");
        if (c.length < 2) return;
        const o = { path: c[0], thumb: c[1], res: c[2] ?? "", colors: (c[3] ?? "").trim(), origin: c[4] || "mio",
                    name: prettyName(c[0]), video: isVideo(c[0]), rev: 0 };
        if (listing) {
            if (fill < gallery.count) {
                const e = gallery.get(fill);
                o.rev = e.rev;
                if (e.path !== o.path || e.res !== o.res || e.colors !== o.colors || e.thumb !== o.thumb) gallery.set(fill, o);
            } else gallery.append(o);
            where[o.path] = fill;
            const pick = pendingSelect !== "" ? pendingSelect : (userMoved ? "" : current);
            if (pick !== "" && o.path === pick) { sel = fill; if (pendingSelect !== "") { pendingSelect = ""; userMoved = true; } }
            fill++;
        } else {
            const i = where[o.path];
            if (i === undefined || i >= gallery.count) return;
            o.rev = gallery.get(i).rev + 1;     // la miniatura es nueva: que la vuelva a leer
            gallery.set(i, o);
        }
        dataRev++;
    }

    onShownChanged: if (shown) {
        showAdd = false; showHoras = Settings.get("wallpaperHora", false) === true; monitor = "";
        searching = false; query = ""; userMoved = false;
        curFile.reload();
        placeStrip(false);
        // Con la lista ya cargada (reabrir), refrescarla después del primer fotograma
        if (count === 0) reload(); else refresh.restart();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    Timer { id: refresh; interval: 120; onTriggered: win.reload() }
    FileView { id: curFile; path: Paths.state + "/wallpaper-path"; printErrors: false }
    Process {
        id: galleryProc
        command: [Paths.script("hf-wallpaper"), "gallery"]
        onStarted: { win.listing = true; win.fill = 0; win.where = {}; }
        stdout: SplitParser { onRead: line => win.onLine(line) }
        // por si el script falla antes de la línea "." (después de leer lo que quede en stdout)
        onExited: Qt.callLater(() => { if (win.listing && !running) win.onLine("."); })
    }
    Process {
        id: addProc
        stdout: StdioCollector { onStreamFinished: { const l = text.trim().split("\n").pop(); if (l) win.pendingSelect = l; } }
        onExited: win.reload()
    }
    Process {
        id: whProc
        command: [Paths.script("hf-" + (win.online || "wallhaven")), "next"]
        stdout: StdioCollector { onStreamFinished: { const l = text.trim(); if (l) win.pendingSelect = l; } }
        onExited: win.reload()
    }

    // ── Escenario: ocupa la pantalla entera (también bajo la barra) ─────
    Item {
        id: stage
        x: -win.panel.x; y: -win.panel.y
        width: win.width; height: win.height

        WallBackdrop {
            id: backdrop
            anchors.fill: parent
            thumb: win.cur && win.cur.res !== "" ? "file://" + win.cur.thumb + (win.cur.rev ? "?" + win.cur.rev : "") : ""
            full: win.cur && !win.cur.video ? "file://" + win.cur.path : ""
            mono: Settings.get("colorMode", "auto") === "mono" && Settings.get("monoFondo", true) !== false
            onRequested: probe.previewAsked()
            onShownReady: hi => { if (!hi) probe.previewReady(); }
        }
        // Fondo en vídeo: se reproduce encima de su fotograma cuando te paras en él (un momento de espera para no
        // abrir un decodificador por cada paso al recorrer la lista)
        Loader {
            id: videoPrev
            anchors.fill: parent
            property string want: win.cur && win.cur.video ? win.cur.path : ""
            property string src: ""
            onWantChanged: { src = ""; if (want !== "") videoDelay.restart(); }
            Timer { id: videoDelay; interval: 350; onTriggered: videoPrev.src = videoPrev.want }
            active: src !== "" && !Theme.still
            source: Qt.resolvedUrl("../../components/VideoLoop.qml")
            onLoaded: item.source = Qt.binding(() => videoPrev.src)
        }
        // Velo de abajo para que se lea lo de encima (colores del tema: vale en claro y en oscuro)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.62
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.bg, 0) }
                GradientStop { position: 0.38; color: Qt.alpha(Theme.bg, 0.55) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.bg, 0.94) }
            }
        }
        // Rueda (o panel táctil) en cualquier sitio: un paso por muesca
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            property real acc: 0
            onWheel: w => {
                const dlt = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? -w.angleDelta.x : w.angleDelta.y;
                acc += dlt;
                while (Math.abs(acc) >= 120) { win.step(acc > 0 ? -1 : 1); acc -= acc > 0 ? 120 : -120; }
            }
        }

        // ── Parte de abajo ───────────────────────────────────────────────
        ColumnLayout {
            id: bottom
            width: parent.width
            anchors { bottom: parent.bottom; bottomMargin: Math.max(16, win.mB + 18) }
            spacing: Math.round(14 * win.k)
            // Entrada: sube un poco (solo traslación)
            transform: Translate {
                y: win.shown ? 0 : 28
                Behavior on y { NumberAnimation { duration: Theme.durIn * 0.7; easing.type: Easing.OutCubic } }
            }

            // Nombre, origen, resolución y colores dominantes
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: stage.width - 96
                spacing: 8
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Txt {
                        text: win.cur ? win.cur.name : (win.listing ? "Buscando fondos…" : "No hay fondos: añade los tuyos con «Mis fondos»")
                        size: 30; weight: Font.DemiBold
                        Layout.maximumWidth: stage.width * 0.6
                    }
                    Txt {
                        visible: win.count > 0
                        text: (win.sel + 1) + " / " + win.count
                        size: 13; muted: true; tabular: true
                        Layout.alignment: Qt.AlignBaseline
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 26
                    spacing: 6
                    opacity: win.cur ? 1 : 0
                    Chip { text: win.cur ? win.originLabel(win.cur.origin) : ""; icon: win.webOrigin ? "globe" : win.cur && win.cur.origin === "mio" ? "folder" : "image" }
                    Chip { visible: !!win.cur && win.cur.video; text: "Vídeo"; icon: "play" }
                    Chip { visible: !!win.cur && win.cur.res !== "" && win.cur.res !== "?"; text: win.cur ? win.cur.res.replace("x", " × ") : ""; tabular: true }
                    Chip { visible: !!win.cur && win.cur.path === win.current; text: "Puesto ahora"; icon: "check"; accent: true }
                    // Colores dominantes (de la miniatura)
                    Row {
                        visible: sw.count > 0
                        Layout.leftMargin: 6
                        spacing: -5
                        Repeater {
                            id: sw
                            model: win.cur && win.cur.colors ? win.cur.colors.split(" ").filter(x => x) : []
                            delegate: Rectangle {
                                required property string modelData
                                width: 22; height: 22; radius: 11
                                color: modelData
                                border.width: 2; border.color: Theme.bg
                            }
                        }
                    }
                    Chip { visible: !!win.credit.author; text: "Foto de " + (win.credit.author ?? "") + " en Unsplash" }
                    Btn {
                        visible: win.webOrigin
                        Layout.leftMargin: 6
                        kind: "ghost"; h: 26; icon: "download"; text: "Guardar en mis fondos"
                        onClicked: { addProc.command = [Paths.script("hf-wallpaper"), "add", win.cur.path]; addProc.running = true; }
                    }
                }
            }

            // Tira de miniaturas: tamaño fijo, se desplaza con contentX (OutCubic) y reutiliza los delegados
            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.preferredHeight: win.tileH * win.big + 24
                orientation: ListView.Horizontal
                spacing: win.gap
                interactive: false
                reuseItems: true
                cacheBuffer: (win.tileW + win.gap) * 4
                model: gallery
                // Márgenes de media tira a cada lado: así la primera y la última también quedan centradas sin salirse
                // de los límites (si no, el ListView recoloca contentX)
                header: Item { width: Math.max(0, (strip.width - win.tileW) / 2); height: 1 }
                footer: Item { width: Math.max(0, (strip.width - win.tileW) / 2); height: 1 }
                delegate: WallTile {
                    sel: win.sel
                    tileW: win.tileW; tileH: win.tileH; big: win.big
                    height: strip.height
                    isCurrent: path === win.current
                    onPicked: i => win.go(i)
                    onActivated: i => { win.go(i); win.apply(); }
                    onCreated: probe.delegateCreated()
                }
                onWidthChanged: win.placeStrip(false)
                NumberAnimation { id: scroll; target: strip; property: "contentX"; duration: Theme.dur; easing.type: Easing.OutCubic }
            }

            // Horario de «Según la hora»
            Bar {
                visible: win.showHoras
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [["06:00", "Atardecer", 360, 600], ["10:00", "Bruma", 600, 1050], ["17:30", "Lago", 1050, 1200], ["20:00", "Noche", 1200, 1800]]
                    delegate: Rectangle {
                        id: hr
                        required property var modelData
                        readonly property int m: Time.now.getHours() * 60 + Time.now.getMinutes()
                        readonly property bool on: modelData[2] === 1200 ? (m >= 1200 || m < 360) : (m >= modelData[2] && m < modelData[3])
                        implicitWidth: 112; implicitHeight: 44; radius: Theme.r(8)
                        color: on ? Theme.selBg : "transparent"
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 1
                            Txt { Layout.alignment: Qt.AlignHCenter; text: modelData[0]; size: 13; weight: Font.DemiBold; tabular: true; color: hr.on ? Theme.selText : Theme.t }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: modelData[1]; size: 11; muted: true }
                        }
                    }
                }
                Txt { text: "Cambia el fondo según la hora, con fundido"; size: 11; muted: true; Layout.leftMargin: 8; Layout.rightMargin: 8 }
            }

            // Añadir fondos propios
            Glass {
                visible: win.showAdd
                Layout.alignment: Qt.AlignHCenter
                kind: "panel"; radius: Theme.r(14); big: false
                implicitWidth: 640; implicitHeight: 112
                Rectangle {
                    anchors { fill: parent; margins: 8 }
                    radius: Theme.r(10)
                    color: drop.containsDrag ? Qt.alpha(Theme.p, 0.12) : "transparent"
                    border.width: 1.5
                    border.color: drop.containsDrag ? Theme.p : Theme.ov
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 4
                        Icon { Layout.alignment: Qt.AlignHCenter; name: "upload"; size: 20; color: Theme.tv }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: "Suelta imágenes o vídeos aquí"; size: 13; weight: Font.Medium }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: "JPG, PNG, WebP, MP4, WebM · se copian a ~/Imágenes/Fondos"; size: 11; muted: true }
                    }
                    Btn {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                        kind: "ghost"; h: 26; icon: "folder"; text: "Abrir carpeta"
                        onClicked: Quickshell.execDetached(["sh", "-c", 'd="$(xdg-user-dir PICTURES)/Fondos"; [ -d "$d" ] || d="$(xdg-user-dir PICTURES)/Wallpapers"; mkdir -p "$d"; xdg-open "$d"'])
                    }
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: d => {
                            const files = d.urls.map(u => decodeURIComponent(u.toString().replace(/^file:\/\//, "")))
                                                .filter(f => /\.(jpe?g|png|webp|mp4|webm|mkv|mov|gif)$/i.test(f));
                            if (!files.length) return;
                            addProc.command = [Paths.script("hf-wallpaper"), "add"].concat(files);
                            addProc.running = true;
                        }
                    }
                }
            }

            // Botonera
            Bar {
                Layout.alignment: Qt.AlignHCenter
                Segmented {
                    visible: Quickshell.screens.length > 1
                    h: 30
                    current: win.monitor
                    model: [{ key: "", label: "Todas" }].concat(Quickshell.screens.map(s => ({ key: s.name, label: s.name })))
                    onPicked: key => win.monitor = key
                }
                Sep { visible: Quickshell.screens.length > 1 }
                Btn { kind: "ghost"; icon: "shuffle"; text: "Aleatorio"; onClicked: win.random() }
                Btn {
                    // Estado visible y efecto al momento (antes solo cambiaba el ajuste y el fondo se quedaba quieto
                    // en el siguiente arranque sin que se notara por qué)
                    readonly property bool on: Settings.get("wallpaperMotion", true) !== false
                    kind: on ? "tonal" : "ghost"; icon: on ? "play" : "pause"
                    text: on ? "En movimiento" : "Fondo quieto"
                    onClicked: {
                        Settings.set("wallpaperMotion", !on);
                        Quickshell.execDetached(["sh", "-c", 'sleep 0.6; exec "$1" restore', "sh", Paths.script("hf-wallpaper")]);
                    }
                }
                Btn {
                    readonly property bool on: Settings.get("wallpaperHora", false) === true
                    kind: on ? "tonal" : "ghost"; icon: "clock"; text: "Según la hora"
                    onClicked: { win.showAdd = false; win.showHoras = !on; Settings.set("wallpaperHora", !on); if (!on) Quickshell.execDetached([Paths.script("hf-wallpaper"), "hora"]); }
                }
                Btn { kind: win.showAdd ? "tonal" : "ghost"; icon: "plus"; text: "Mis fondos"; onClicked: { win.showAdd = !win.showAdd; win.showHoras = false; } }
                Btn {
                    visible: win.whOn
                    kind: "ghost"; icon: "download"; text: whProc.running ? "Buscando…" : win.online === "unsplash" ? "Traer de Unsplash" : "Traer de Wallhaven"
                    enabled: !whProc.running
                    onClicked: whProc.running = true
                }
                Btn { kind: "ghost"; icon: "palette"; text: "Colores: " + win.colorName; onClicked: win.cycleColors() }
                Sep {}
                Btn { kind: "ghost"; text: "Cancelar"; onClicked: Shell.close() }
                Btn { kind: "primary"; icon: "check"; text: win.monitor === "" ? "Aplicar" : "Aplicar en " + win.monitor; onClicked: win.apply() }
            }

            // Atajos (o lo que se está buscando)
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: win.searching ? "Buscar: " + win.query + "▏   ·   Esc deja de buscar"
                    : "← → elegir  ·  Intro aplicar  ·  Esc cancelar  ·  escribe para buscar  ·  R al azar"
                size: 11.5; muted: !win.searching
                tabular: true
            }
        }
    }

    // Piezas pequeñas
    component Sep: Rectangle { implicitWidth: 1; implicitHeight: 18; color: Theme.ov; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 2; Layout.rightMargin: 2 }
    component Bar: Glass {
        kind: "panel"; radius: Theme.r(14); big: false
        default property alias inner: lay.data
        implicitWidth: lay.implicitWidth + 12
        implicitHeight: lay.implicitHeight + 12
        RowLayout { id: lay; anchors.centerIn: parent; spacing: 4 }
    }
    component Chip: Rectangle {
        id: chip
        property string text
        property string icon
        property bool accent: false
        property bool tabular: false
        implicitHeight: 24
        implicitWidth: cr.implicitWidth + 16
        radius: Theme.ctl(24)
        color: accent ? Theme.selBg : Theme.fill2
        RowLayout {
            id: cr
            anchors.centerIn: parent
            spacing: 5
            Icon { visible: chip.icon !== ""; name: chip.icon; size: 12; color: chip.accent ? Theme.selText : Theme.tv }
            Txt { text: chip.text; size: 11.5; weight: Font.Medium; tabular: chip.tabular; color: chip.accent ? Theme.selText : Theme.t }
        }
    }

    // Colocar la tira en la elegida: con animación al navegar, al momento al abrir o al llegar la lista
    function stripX(i: int): real { return i * (tileW + gap) - (strip.width - tileW) / 2; }
    function placeStrip(animate: bool): void {
        const x = stripX(sel);
        scroll.stop();
        if (!animate || Theme.dur <= 0) { strip.contentX = x; return; }
        scroll.from = strip.contentX; scroll.to = x; scroll.restart();
    }
    onSelChanged: placeStrip(shown && !listing || userMoved)

    // Teclado
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            switch (e.key) {
            case Qt.Key_Left: win.step(-1); break;
            case Qt.Key_Right: case Qt.Key_Tab: win.step(1); break;
            case Qt.Key_Backtab: win.step(-1); break;
            case Qt.Key_PageUp: win.go(win.sel - 5); break;
            case Qt.Key_PageDown: win.go(win.sel + 5); break;
            case Qt.Key_Home: win.go(0); break;
            case Qt.Key_End: win.go(win.count - 1); break;
            case Qt.Key_Return: case Qt.Key_Enter: win.apply(); break;
            case Qt.Key_Escape:
                if (win.searching) { win.searching = false; win.query = ""; } else Shell.close();
                break;
            case Qt.Key_Backspace:
                if (!win.searching) return;
                win.search(win.query.slice(0, -1));
                if (win.query === "") win.searching = false;
                break;
            default:
                if (ctrl && e.key === Qt.Key_F || !win.searching && e.text === "/") { win.searching = true; win.query = ""; break; }
                if (ctrl || e.text === "" || e.text < " ") return;
                if (!win.searching) {
                    // Sin búsqueda en marcha, H/L/R/Espacio son atajos (estilo vim, al azar, aplicar)
                    if (e.key === Qt.Key_H) { win.step(-1); break; }
                    if (e.key === Qt.Key_L) { win.step(1); break; }
                    if (e.key === Qt.Key_R) { win.random(); break; }
                    if (e.key === Qt.Key_Space) { win.apply(); break; }
                    win.searching = true;
                }
                win.search(win.query + e.text);
            }
            e.accepted = true;
        }
    }

    FrameProbe { id: probe; target: win; shown: win.shown }
}
