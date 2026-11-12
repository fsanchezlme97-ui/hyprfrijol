// Ajustes › Fondos › Unsplash: buscar fotos en unsplash.com (texto; sin texto, su tema «Wallpapers»; populares o
// recientes), «Añadir a mis fondos» o «Poner», usarlo como origen del cambio automático (wallpaperSource =
// "unsplash"), clave de la API (obligatoria y gratuita: llavero o archivo 600, nunca settings.json) y caché con
// límite (unsplashCacheMB). Cada foto lleva el nombre de su autor (lo piden las normas de Unsplash).
// Todo lo hace scripts/hf-unsplash; esta tarjeta solo enseña y llama (como ui/WallhavenCard).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"

Section {
    id: root
    title: "Unsplash"
    property var results: []
    property int page: 1
    property int lastPage: 1
    property string err: ""
    property bool searching: false
    property string msg: ""
    property var key: ({ stored: false, where: "", hint: "" })
    property var cache: ({ files: 0, bytes: 0, limit_mb: 500 })
    property string working: ""            // id en curso
    readonly property bool useIt: Settings.get("wallpaperSource", "carpeta") === "unsplash"
    readonly property string order: Settings.get("unsplashOrder", "popular")
    readonly property string cmd: Paths.script("hf-unsplash")
    headerRight: Sw { checked: root.useIt; enabled: root.key.stored; onToggled: v => Settings.set("wallpaperSource", v ? "unsplash" : "carpeta") }

    function mb(b): string { return (Number(b || 0) / 1048576).toFixed(b > 104857600 ? 0 : 1).replace(".", ",") + " MB"; }
    function search(p): void {
        page = p || 1;
        if (p === 1 || !p) results = [];
        err = ""; searching = true;
        sp.command = [cmd, "search", "--q", q.text.trim(), "--order", order, "--page", String(page)];
        sp.running = false; sp.running = true;
    }
    function act(op, id): void {
        if (ap.running) return;
        working = id; msg = "";
        ap.op = op;
        ap.command = [cmd, op, id];
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
                    if (!root.err && !root.results.length) root.err = "Sin resultados";
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
                    : j.ok ? "Añadida a tus fondos" : (j.error ?? "No se pudo añadir");
                root.working = "";
                cp.running = false; cp.running = true;
            }
        }
        onExited: root.working = ""
    }
    Process {
        id: ks
        running: true
        command: [root.cmd, "key", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.key = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: kset
        property string value: ""
        command: [root.cmd, "key", "set"]
        environment: ({ HF_UNSPLASH_KEY_IN: kset.value })
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
        command: [root.cmd, "key", "clear"]
        onExited: { root.msg = "Clave borrada"; ks.running = false; ks.running = true; if (root.useIt) Settings.set("wallpaperSource", "carpeta"); }
    }
    Process {
        id: cp
        running: true
        command: [root.cmd, "cache"]
        stdout: StdioCollector { onStreamFinished: { try { root.cache = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: cclear
        command: [root.cmd, "cache", "clear"]
        onExited: { cp.running = false; cp.running = true; root.msg = "Caché vaciada"; }
    }

    Txt {
        Layout.fillWidth: true
        text: !root.key.stored ? "Unsplash pide una clave gratuita: entra en unsplash.com/developers, crea una aplicación («New Application») y pega aquí su «Access Key»."
            : root.useIt ? "El cambio automático (y «Al azar») trae fotos nuevas de Unsplash; sin conexión usa las que ya bajó."
            : "Busca fotos en unsplash.com. Actívalo arriba para que el cambio automático las traiga de ahí."
        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
    // Clave primero: sin ella no se puede buscar
    LabeledRow {
        label: "Access Key"; labelWidth: 80
        RowLayout {
            spacing: 6
            Field {
                id: keyField
                Layout.fillWidth: true
                h: 28
                icon: "key"
                textSize: 12
                placeholder: root.key.stored ? "Guardada (" + root.key.hint + ") · " + root.key.where : "Pégala aquí (unsplash.com/developers)"
                input.echoMode: TextInput.Password
                onAccepted: if (text.trim()) { kset.value = text.trim(); kset.running = true; }
            }
            Button { text: "Guardar"; h: 28; enabled: keyField.text.trim() !== ""; onClicked: { kset.value = keyField.text.trim(); kset.running = true; } }
            Button { visible: root.key.stored; text: "Borrar"; h: 28; onClicked: kclear.running = true }
            Button { visible: !root.key.stored; text: "Abrir la web"; h: 28; onClicked: Qt.openUrlExternally("https://unsplash.com/oauth/applications/new") }
        }
    }
    RowLayout {
        visible: root.key.stored
        Layout.fillWidth: true
        spacing: 8
        Field {
            id: q
            Layout.fillWidth: true
            h: 30
            placeholder: "Buscar (en inglés va mejor); vacío = el tema «Wallpapers» de Unsplash"
            text: Settings.get("unsplashQuery", "")
            onAccepted: { Settings.set("unsplashQuery", text.trim()); root.search(1); }
        }
        Button { text: root.searching ? "Buscando…" : "Buscar"; kind: "primary"; enabled: !root.searching; onClicked: { Settings.set("unsplashQuery", q.text.trim()); root.search(1); } }
    }
    LabeledRow {
        visible: root.key.stored
        label: "Orden"; labelWidth: 80
        Seg {
            h: 28
            model: [["popular", "Populares"], ["latest", "Recientes"]]
            current: root.order
            onPicked: k => Settings.set("unsplashOrder", k)
        }
    }

    // Resultados (con el autor de cada foto)
    GridLayout {
        visible: root.results.length > 0
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 6; rowSpacing: 6
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
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 17; color: Qt.rgba(0, 0, 0, 0.55)
                    Txt {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 5 }
                        text: th.modelData.author ?? ""; size: 9.5; color: "#FFFFFF"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (th.modelData.authorUrl) Qt.openUrlExternally(th.modelData.authorUrl)
                    }
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
    LabeledRow {
        visible: root.key.stored
        label: "Caché"; labelWidth: 80
        RowLayout {
            spacing: 8
            Txt { text: root.cache.files + (root.cache.files === 1 ? " foto · " : " fotos · ") + root.mb(root.cache.bytes) + " de " + root.cache.limit_mb + " MB"; muted: true; size: 11.5; tabular: true; Layout.fillWidth: true }
            Pills { fill: false; h: 26; model: [200, 500, 1000, 2000]; current: Settings.get("unsplashCacheMB", 500); onPicked: v => Settings.set("unsplashCacheMB", v) }
            Button { text: "Vaciar"; h: 26; enabled: root.cache.files > 0; onClicked: cclear.running = true }
        }
    }
    Txt {
        Layout.fillWidth: true
        text: "Buscar se conecta a unsplash.com. La clave va en el llavero del sistema (o en un archivo solo tuyo), nunca en settings.json; la IA no la ve. Las fotos se bajan a la medida de tu pantalla."
        muted: true; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
}
