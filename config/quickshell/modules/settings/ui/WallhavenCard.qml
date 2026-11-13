// Ajustes › Fondos › Wallhaven: buscar en wallhaven.cc (texto, categorías, solo aptos por defecto, al menos la
// resolución de tu pantalla, orden «lo mejor» / al azar…), «Añadir a mis fondos» o «Poner», usarlo como origen del
// cambio automático (wallpaperSource = "wallhaven": hf-wallpaper next/random traen uno nuevo), clave de la API
// (opcional, llavero o archivo 600, nunca settings.json) y caché con límite (wallhavenCacheMB).
// Todo lo hace scripts/hf-wallhaven; esta tarjeta solo enseña y llama.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"

Section {
    id: root
    title: "Wallhaven"
    property var results: []
    property int page: 1
    property int lastPage: 1
    property string err: ""
    property bool searching: false
    property string msg: ""
    property var key: ({ stored: false, where: "", hint: "" })
    property var cache: ({ files: 0, bytes: 0, limit_mb: 500 })
    property string working: ""            // id en curso
    readonly property bool useIt: Settings.get("wallpaperSource", "carpeta") === "wallhaven"
    readonly property var cats: Settings.get("wallhavenCategories", ["general"])
    readonly property var purity: Settings.get("wallhavenPurity", ["sfw"])
    readonly property string sorting: Settings.get("wallhavenSorting", "toplist")
    headerRight: Sw { checked: root.useIt; onToggled: v => Settings.set("wallpaperSource", v ? "wallhaven" : "carpeta") }

    function mb(b): string { return (Number(b || 0) / 1048576).toFixed(b > 104857600 ? 0 : 1).replace(".", ",") + " MB"; }
    function toggleIn(key, list, v, keepOne): void {
        let l = list.includes(v) ? list.filter(x => x !== v) : list.concat([v]);
        if (keepOne && !l.length) l = [keepOne];
        Settings.set(key, l);
    }
    function search(p): void {
        page = p || 1;
        if (p === 1 || !p) results = [];
        err = ""; searching = true;
        sp.command = [Paths.script("hf-wallhaven"), "search", "--q", q.text.trim(), "--categories", cats.join(","), "--purity", purity.join(","),
                      "--sorting", sorting, "--range", Settings.get("wallhavenTopRange", "1M"), "--atleast", Settings.get("wallhavenMinRes", "auto"),
                      "--page", String(page)];
        sp.running = false; sp.running = true;
    }
    function act(op, id): void {
        if (ap.running) return;
        working = id; msg = "";
        ap.op = op;
        ap.command = [Paths.script("hf-wallhaven"), op, id];
        ap.running = true;
    }
    Process {
        id: sp
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                try {
                    const j = JSON.parse(text);
                    root.err = j.error ?? "";
                    root.results = root.page > 1 ? root.results.concat(j.results ?? []) : (j.results ?? []);
                    root.lastPage = j.last_page ?? 1;
                    if (!root.err && !root.results.length) root.err = "Sin resultados con estos filtros";
                } catch (e) { root.err = "No se pudo buscar"; }
            }
        }
    }
    Process {
        id: ap
        property string op: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let j = {};
                try { j = JSON.parse(text.split("\n")[0]); } catch (e) {}
                root.msg = ap.op === "set" ? (j.ok === false ? j.error : "Poniendo el fondo…")
                    : j.ok ? "Añadido a tus fondos" : (j.error ?? "No se pudo añadir");
                root.working = "";
                cp.running = false; cp.running = true;
            }
        }
        onExited: root.working = ""
    }
    Process {
        id: ks
        running: true
        command: [Paths.script("hf-wallhaven"), "key", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.key = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: kset
        property string value: ""
        command: [Paths.script("hf-wallhaven"), "key", "set"]
        environment: ({ HF_WALLHAVEN_KEY_IN: kset.value })
        stdout: StdioCollector {
            onStreamFinished: {
                kset.value = "";
                try { const j = JSON.parse(text); root.msg = j.ok ? (j.where === "llavero" ? "Clave guardada en el llavero" : "Clave guardada en un archivo privado") : j.error; if (j.ok) keyField.text = ""; }
                catch (e) { root.msg = "No se pudo guardar la clave"; }
                ks.running = false; ks.running = true;
            }
        }
    }
    Process {
        id: kclear
        command: [Paths.script("hf-wallhaven"), "key", "clear"]
        onExited: { root.msg = "Clave borrada"; ks.running = false; ks.running = true; }
    }
    Process {
        id: cp
        running: true
        command: [Paths.script("hf-wallhaven"), "cache"]
        stdout: StdioCollector { onStreamFinished: { try { root.cache = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: cclear
        command: [Paths.script("hf-wallhaven"), "cache", "clear"]
        onExited: { cp.running = false; cp.running = true; root.msg = "Caché vaciada"; }
    }

    Txt {
        Layout.fillWidth: true
        text: root.useIt ? "El cambio automático (y «Al azar») trae fondos nuevos de wallhaven.cc con estos filtros; sin conexión usa los que ya bajó."
                         : "Busca fondos en wallhaven.cc. Actívalo arriba para que el cambio automático los traiga de ahí."
        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field {
            id: q
            Layout.fillWidth: true
            h: 30
            placeholder: "Buscar (en inglés va mejor: mountains, minimal, space…)"
            text: Settings.get("wallhavenQuery", "")
            onAccepted: { Settings.set("wallhavenQuery", text.trim()); root.search(1); }
        }
        Button { text: root.searching ? "Buscando…" : "Buscar"; kind: "primary"; enabled: !root.searching; onClicked: { Settings.set("wallhavenQuery", q.text.trim()); root.search(1); } }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [["general", "General"], ["anime", "Anime"], ["people", "Personas"]]
            Chip {
                required property var modelData
                h: 26; text: modelData[1]; on: root.cats.includes(modelData[0])
                onClicked: root.toggleIn("wallhavenCategories", root.cats, modelData[0], "general")
            }
        }
        Item { width: 10; height: 1 }
        Chip { h: 26; text: "Aptos (SFW)"; on: true; onClicked: {} }
        Chip {
            h: 26; text: "Atrevidos"; on: root.purity.includes("sketchy")
            onClicked: root.toggleIn("wallhavenPurity", root.purity, "sketchy", "sfw")
        }
        Chip {
            visible: root.key.stored
            h: 26; text: "NSFW"; on: root.purity.includes("nsfw")
            onClicked: root.toggleIn("wallhavenPurity", root.purity, "nsfw", "sfw")
        }
    }
    LabeledRow {
        label: "Orden"; labelWidth: 80
        Seg {
            h: 28
            model: [["toplist", "Lo mejor"], ["random", "Al azar"], ["date_added", "Recientes"], ["favorites", "Favoritos"]]
            current: root.sorting
            onPicked: k => Settings.set("wallhavenSorting", k)
        }
    }
    LabeledRow {
        visible: root.sorting === "toplist"
        label: "De"; labelWidth: 80
        Seg {
            h: 28
            model: [["1w", "La semana"], ["1M", "El mes"], ["3M", "3 meses"], ["1y", "El año"]]
            current: Settings.get("wallhavenTopRange", "1M")
            onPicked: k => Settings.set("wallhavenTopRange", k)
        }
    }
    LabeledRow {
        label: "Tamaño"; labelWidth: 80
        Seg {
            h: 28
            model: [["auto", "Mi pantalla"], ["1920x1080", "1080p"], ["2560x1440", "1440p"], ["3840x2160", "4K"]]
            current: Settings.get("wallhavenMinRes", "auto")
            onPicked: k => Settings.set("wallhavenMinRes", k)
        }
    }

    // Resultados
    GridLayout {
        visible: root.results.length > 0
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8; rowSpacing: 8
        Repeater {
            model: root.results
            Rectangle {
                id: th
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 74
                radius: Theme.r(6)
                color: Theme.fill2
                clip: true
                Image {
                    anchors.fill: parent
                    source: th.modelData.thumb ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(300, 200)
                }
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 4 }
                    height: 16; width: rt.implicitWidth + 8; radius: 4; color: Qt.rgba(0, 0, 0, 0.55)
                    Txt { id: rt; anchors.centerIn: parent; text: th.modelData.resolution ?? ""; size: 9.5; color: "#FFFFFF"; tabular: true }
                }
                MouseArea { id: thm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                Row {
                    visible: thm.containsMouse || root.working === th.modelData.id
                    anchors { right: parent.right; top: parent.top; margins: 4 }
                    spacing: 4
                    Rectangle {
                        width: 22; height: 22; radius: 6; color: Qt.rgba(0, 0, 0, 0.6)
                        Icon { anchors.centerIn: parent; name: root.working === th.modelData.id ? "refresh" : "plus"; size: 12; color: "#FFFFFF" }
                        MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act("add", th.modelData.id) }
                        HoverTip { shown: addMa.containsMouse; text: "Añadir a mis fondos" }
                    }
                    Rectangle {
                        width: 22; height: 22; radius: 6; color: Qt.rgba(0, 0, 0, 0.6)
                        Icon { anchors.centerIn: parent; name: "image"; size: 12; color: "#FFFFFF" }
                        MouseArea { id: setMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act("set", th.modelData.id) }
                        HoverTip { shown: setMa.containsMouse; text: "Poner de fondo" }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Txt {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.err || root.msg
            color: root.err ? Theme.danger : Theme.p
            size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Button { visible: root.results.length > 0 && root.page < root.lastPage; text: "Más"; h: 26; enabled: !root.searching; onClicked: root.search(root.page + 1) }
    }

    // Clave y caché
    LabeledRow {
        label: "Clave de API"; labelWidth: 80
        RowLayout {
            spacing: 8
            Field {
                id: keyField
                Layout.fillWidth: true
                h: 28
                icon: "key"
                textSize: 12
                placeholder: root.key.stored ? "Guardada (" + root.key.hint + ") · " + root.key.where : "Opcional: para NSFW y tus filtros de cuenta"
                input.echoMode: TextInput.Password
                onAccepted: if (text.trim()) { kset.value = text.trim(); kset.running = true; }
            }
            Button { text: "Guardar"; h: 28; enabled: keyField.text.trim() !== ""; onClicked: { kset.value = keyField.text.trim(); kset.running = true; } }
            Button { visible: root.key.stored; text: "Borrar"; h: 28; onClicked: kclear.running = true }
        }
    }
    LabeledRow {
        label: "Caché"; labelWidth: 80
        RowLayout {
            spacing: 8
            Txt { text: root.cache.files + (root.cache.files === 1 ? " fondo · " : " fondos · ") + root.mb(root.cache.bytes) + " de " + root.cache.limit_mb + " MB"; muted: true; size: 11.5; tabular: true; Layout.fillWidth: true }
            Pills { fill: false; h: 26; model: [200, 500, 1000, 2000]; current: Settings.get("wallhavenCacheMB", 500); onPicked: v => Settings.set("wallhavenCacheMB", v) }
            Button { text: "Vaciar"; h: 26; enabled: root.cache.files > 0; onClicked: cclear.running = true }
        }
    }
    Txt {
        Layout.fillWidth: true
        text: "Buscar se conecta a wallhaven.cc. La clave va en el llavero del sistema (o en un archivo solo tuyo), nunca en settings.json; la IA no la ve."
        muted: true; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
}
