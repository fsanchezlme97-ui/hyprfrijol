// Ajustes › Bloqueo e inicio de sesión: tema, fondo y piezas de la pantalla de bloqueo (modules/lock/LockFace.qml,
// con vista previa en vivo) y del login (greeter/quickshell: lo copia hf-greeter-sync --auto a live/greeter.json).
// Claves: lockPalette lockBg lockWallpaper lockScene lockDim lockLayout lockClock lockWidgets · greeterPalette
// greeterBg greeterWallpaper greeterScene greeterCurtain greeterMotion greeterWidgets.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../../lock"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12

    // Paletas de Apariencia: las del repo y las tuyas (temas propios e importados)
    property var basePals: ({})
    property var userPals: ({})
    readonly property var pals: Object.assign({}, basePals, userPals)
    FileView { path: Paths.root + "/config/themes/palettes.json"; printErrors: false; onLoaded: { try { root.basePals = JSON.parse(text()); } catch (e) {} } }
    FileView {
        path: Paths.userDir + "/palettes-user.json"
        printErrors: false; watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); root.userPals = j && typeof j === "object" ? j : {}; } catch (e) {} }
        onLoadFailed: root.userPals = {}
    }
    readonly property var palModel: [["", "Como el escritorio (" + Theme.paletteName + ")"]].concat(
        Object.keys(pals).sort((a, b) => String(pals[a].name ?? a).localeCompare(String(pals[b].name ?? b))).map(k => [k, pals[k].name ?? k]))
    Wallpapers { id: wp }
    readonly property var scenes: [["amanecer", "Amanecer"], ["lago", "Lago"], ["bosque", "Bosque"], ["noche", "Noche"], ["bruma", "Bruma"]]

    function toggleIn(key, def, item): void {
        const a = (Settings.get(key, def) ?? []).slice();
        const i = a.indexOf(item);
        if (i >= 0) a.splice(i, 1); else a.push(item);
        Settings.set(key, a);
        if (key.startsWith("greeter")) gsync.restart();
    }
    function setG(key, v): void { Settings.set(key, v); gsync.restart(); }
    // Elegir una imagen de otra carpeta (selector del sistema)
    property string pickFor: ""
    function pick(key): void { pickFor = key; picker.running = true; }
    Process {
        id: picker
        command: [Paths.script("hf-pickfile"), "--title", "Imagen de fondo", "--filter", "Imágenes|*.png *.jpg *.jpeg *.webp *.avif"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split("\n")[0]; if (f) root.pickFor.startsWith("greeter") ? root.setG(root.pickFor, f) : Settings.set(root.pickFor, f); } }
    }

    // El login lee una copia (greetd no ve tu carpeta): se copia sola al cambiar algo, sin contraseña, si ya está instalado
    Timer { id: gsync; interval: 1200; onTriggered: Quickshell.execDetached([Paths.script("hf-greeter-sync"), "--auto"]) }
    property string gState: ""     // ok | viejo | sin (no instalado / sin live/) | otro (otro login)
    Process {
        id: gcheck
        running: true
        command: ["sh", "-c", "grep -qs hyprland-greeter /etc/greetd/config.toml || { echo otro; exit; }; d=/etc/greetd/quickshell; [ -w \"$d/live\" ] || { echo sin; exit; }; cmp -s \"$d/shell.qml\" \"$1/greeter/quickshell/shell.qml\" && echo ok || echo viejo", "sh", Paths.root]
        stdout: StdioCollector { onStreamFinished: root.gState = text.trim() }
    }

    // Fila de miniaturas: «como el escritorio» + fondos de la colección + «otra imagen…»
    component WallPick: ColumnLayout {
        id: wpk
        property string key: ""
        property bool videos: false
        readonly property string cur: Settings.get(key, "")
        Layout.fillWidth: true
        spacing: 8
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Chip { text: "Fondo del escritorio"; on: wpk.cur === ""; onClicked: wpk.key.startsWith("greeter") ? root.setG(wpk.key, "") : Settings.set(wpk.key, "") }
            Chip { text: "Otra imagen…"; on: false; mark: false; onClicked: root.pick(wpk.key) }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4; columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: (wpk.videos ? wp.files : wp.images).slice(0, 8)
                Thumb {
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    file: modelData
                    tick: wp.tick
                    selected: wpk.cur === modelData
                    onClicked: wpk.key.startsWith("greeter") ? root.setG(wpk.key, modelData) : Settings.set(wpk.key, modelData)
                }
            }
        }
        Txt {
            visible: wpk.cur !== "" && !wp.files.includes(wpk.cur)
            Layout.fillWidth: true; muted: true; size: 11.5; elide: Text.ElideMiddle
            text: "Imagen: " + wpk.cur
        }
    }

    // ---------- Bloqueo ----------
    Section {
        Layout.fillWidth: true
        title: "Pantalla de bloqueo"
        headerRight: Button { text: "Bloquear ahora"; onClicked: Quickshell.execDetached(["loginctl", "lock-session"]) }

        // Vista previa en vivo (la misma cara que el bloqueo, sin PAM ni teclado)
        Item {
            id: pv
            Layout.fillWidth: true
            implicitHeight: Math.round(width * 9 / 16)
            Rectangle {
                id: frame
                anchors.fill: parent
                radius: Theme.r(10)
                color: Theme.bg
                clip: true
                LockFace {
                    width: 1440; height: 810
                    scale: frame.width / 1440
                    transformOrigin: Item.TopLeft
                    preview: true
                    ctl: QtObject {
                        property string password: ""
                        property string state: ""
                        property string message: ""
                        property bool hasFace: false
                        property bool hasFprint: false
                        property bool forceScene: false
                        property date lockedAt: new Date()
                        property bool caps: false
                        readonly property string userName: Quickshell.env("USER") ?? ""
                        readonly property string realName: userName
                        signal shake()
                        signal clearInput()
                        function submit(): void {}
                        function checkCaps(): void {}
                    }
                }
            }
            Rectangle { anchors.fill: parent; radius: frame.radius; color: "transparent"; border.width: 1; border.color: Theme.border }
        }

        LabeledRow {
            label: "Tema"; labelWidth: 120
            Dropdown { Layout.fillWidth: true; model: root.palModel; current: Settings.get("lockPalette", ""); onPicked: k => Settings.set("lockPalette", k) }
        }
        LabeledRow {
            label: "Fondo"; labelWidth: 120
            Seg {
                model: [["fondo", "Imagen"], ["desenfocado", "Desenfocada"], ["paisaje", "Paisaje"], ["color", "Color liso"]]
                current: Settings.get("lockBg", "fondo")
                onPicked: k => Settings.set("lockBg", k)
            }
        }
        WallPick { key: "lockWallpaper"; visible: ["fondo", "desenfocado"].includes(Settings.get("lockBg", "fondo")) }
        LabeledRow {
            visible: Settings.get("lockBg", "fondo") === "paisaje"
            label: "Paisaje"; labelWidth: 120
            Seg { model: root.scenes; current: Settings.get("lockScene", "amanecer"); onPicked: k => Settings.set("lockScene", k) }
        }
        LabeledRow {
            visible: Settings.get("lockBg", "fondo") !== "color"
            label: "Oscurecer"; labelWidth: 120
            Pills { fill: false; model: [[0, "No"], [20, "20 %"], [40, "40 %"], [60, "60 %"]]; current: Settings.get("lockDim", 0); onPicked: k => Settings.set("lockDim", k) }
        }
        LabeledRow {
            label: "Disposición"; labelWidth: 120
            Seg { model: [["izquierda", "Izquierda"], ["centro", "Centro"], ["derecha", "Derecha"]]; current: Settings.get("lockLayout", "izquierda"); onPicked: k => Settings.set("lockLayout", k) }
        }
        LabeledRow {
            label: "Reloj"; labelWidth: 120
            Seg { model: [["fino", "Fino"], ["grueso", "Grueso"], ["pequeno", "Pequeño"], ["oculto", "Sin reloj"]]; current: Settings.get("lockClock", "fino"); onPicked: k => Settings.set("lockClock", k) }
        }
        LabeledRow {
            label: "Mostrar"; labelWidth: 120
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [["fecha", "Fecha"], ["clima", "Tiempo"], ["musica", "Música"], ["bateria", "Batería"], ["nomolestar", "No molestar"]]
                    Chip {
                        required property var modelData
                        text: modelData[1]
                        on: Settings.get("lockWidgets", ["fecha", "musica", "bateria", "nomolestar"]).includes(modelData[0])
                        onClicked: root.toggleIn("lockWidgets", ["fecha", "musica", "bateria", "nomolestar"], modelData[0])
                    }
                }
            }
        }
        LinkRow { label: "Cuándo se bloquea"; target: "Bloqueo de pantalla"; value: Settings.get("idleLock", 5) > 0 ? "Tras " + Settings.get("idleLock", 5) + " min" : "Nunca"; section: "privacidad"; sectionLabel: "Privacidad y seguridad" }
    }

    // ---------- Login ----------
    Section {
        Layout.fillWidth: true
        title: "Inicio de sesión"
        headerRight: Button {
            visible: root.gState === "ok" || root.gState === "viejo"
            text: "Ver el login"
            // Vista previa a pantalla completa con tus ajustes ya copiados; Esc la cierra
            onClicked: Quickshell.execDetached(["sh", "-c", "\"$1\" --auto; HF_GREETER_PREVIEW=1 HF_GREETER_CONFIG=/etc/greetd/quickshell/live/greeter.json exec qs -p \"$2\"",
                                                "sh", Paths.script("hf-greeter-sync"), Paths.root + "/greeter/quickshell"])
        }
        Txt {
            visible: root.gState !== "ok" && root.gState !== ""
            Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 12
            color: root.gState === "otro" ? Theme.tv : Theme.ter
            text: root.gState === "otro" ? "Tu equipo no usa el login de HyprFrijol (greetd): estos ajustes no tendrán efecto."
                : root.gState === "viejo" ? "El login instalado es de una versión anterior: actualízalo para que use todo lo de aquí (pide la contraseña una vez)."
                : "Falta instalar el login de HyprFrijol con tu tema (pide la contraseña una vez; después se copia solo)."
        }
        Button {
            visible: root.gState === "viejo" || root.gState === "sin"
            text: root.gState === "viejo" ? "Actualizar el login…" : "Instalar el login…"
            onClicked: { Pkg.runInTerminal(Paths.script("hf-greeter-sync"), "Login de HyprFrijol"); gLater.restart(); }
        }
        Timer { id: gLater; interval: 8000; repeat: true; property int n: 0; onTriggered: { gcheck.running = false; gcheck.running = true; if (++n > 15 || root.gState === "ok") { stop(); n = 0; } } }

        LabeledRow {
            label: "Tema"; labelWidth: 120
            Dropdown { Layout.fillWidth: true; model: root.palModel; current: Settings.get("greeterPalette", ""); onPicked: k => root.setG("greeterPalette", k) }
        }
        LabeledRow {
            label: "Fondo"; labelWidth: 120
            Seg { model: [["fondo", "Imagen o vídeo"], ["paisaje", "Paisaje"]]; current: Settings.get("greeterBg", "fondo"); onPicked: k => root.setG("greeterBg", k) }
        }
        WallPick { key: "greeterWallpaper"; videos: true; visible: Settings.get("greeterBg", "fondo") === "fondo" }
        LabeledRow {
            visible: Settings.get("greeterBg", "fondo") === "paisaje"
            label: "Paisaje"; labelWidth: 120
            Seg { model: [["", "Automático"]].concat(root.scenes); current: Settings.get("greeterScene", ""); onPicked: k => root.setG("greeterScene", k) }
        }
        SwRow {
            label: "Pantalla de reposo"; sub: "reloj grande hasta que pulses una tecla; si no, el formulario directamente"
            checked: Settings.get("greeterCurtain", true); onToggled: v => root.setG("greeterCurtain", v)
        }
        SwRow {
            label: "Fondo en movimiento"; sub: "con un vídeo de fondo; apágalo si el equipo tarda en mostrar el login"
            checked: Settings.get("greeterMotion", true); onToggled: v => root.setG("greeterMotion", v)
        }
        LabeledRow {
            label: "Mostrar"; labelWidth: 120
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [["reloj", "Reloj"], ["fecha", "Fecha"], ["equipo", "Nombre del equipo"], ["bateria", "Batería"], ["red", "Red"], ["teclado", "Distribución del teclado"], ["energia", "Apagar y reiniciar"]]
                    Chip {
                        required property var modelData
                        text: modelData[1]
                        on: Settings.get("greeterWidgets", ["reloj", "fecha", "equipo", "bateria", "red", "teclado", "energia"]).includes(modelData[0])
                        onClicked: root.toggleIn("greeterWidgets", ["reloj", "fecha", "equipo", "bateria", "red", "teclado", "energia"], modelData[0])
                    }
                }
            }
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "El estilo, la tipografía y tu foto se toman de Apariencia y Usuarios. La accesibilidad (lector de pantalla, teclado en pantalla) siempre está a mano en el login."
        }
    }
}
