// Ajustes › Fondos de pantalla — colección (hf-wallpaper list; filtro Todos / Imágenes / Animados), cambio automático
// y fondos en movimiento (vídeos y GIF con mpvpaper: «Añadir fondo animado…» = hf-wallpaper pick-animated) y Wallhaven
// (ui/WallhavenCard: wallpaperSource, wallhaven*).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    Wallpapers { id: wp }
    readonly property int rot: Settings.get("wallpaperRotateMin", 0)
    readonly property bool auto: rot > 0 || Settings.get("wallpaperOnStart", false)
    property string filter: "todos"        // todos | imagenes | animados
    readonly property var shown: filter === "animados" ? wp.animated : filter === "imagenes" ? wp.images : wp.files
    readonly property bool hasPlayer: !!wp.deps["mpvpaper"]
    function installPlayer(): void {
        const t = Pkg.tool("mpvpaper");
        Pkg.install([t ?? { src: "AUR", pkg: "mpvpaper" }], "Fondos animados (mpvpaper)");
        depsLater.restart();
    }
    Timer { id: depsLater; interval: 20000; repeat: true; property int n: 0; onTriggered: { wp.refresh(); if (++n > 9 || root.hasPlayer) { stop(); n = 0; } } }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.25
            Layout.alignment: Qt.AlignTop
            title: "Colección"
            headerRight: Txt { muted: true; size: 11.5; text: wp.files.length + " fondos · " + wp.videos + " animados" }
            Seg {
                Layout.fillWidth: true
                h: 28
                model: [["todos", "Todos"], ["imagenes", "Imágenes"], ["animados", "Fondos animados"]]
                current: root.filter
                onPicked: k => root.filter = k
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: root.shown.slice(0, 12)
                    Thumb {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 92
                        file: modelData
                        tick: wp.tick
                        label: wp.name(modelData)
                        selected: wp.current === modelData
                        onClicked: wp.set(modelData)
                    }
                }
            }
            Txt { visible: root.shown.length > 12; muted: true; size: 11.5; text: "+ " + (root.shown.length - 12) + " más · ábrelos todos con Super + Mayús + W o desde la barra" }
            Txt {
                visible: root.shown.length === 0
                Layout.fillWidth: true
                muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: root.filter === "animados" ? "Aún no tienes fondos animados. Pulsa «Añadir fondo animado…» y elige un vídeo (.mp4, .webm, .mkv, .mov) o un GIF."
                    : "No hay fondos. Pon imágenes o vídeos en ~/Imágenes/Fondos o ~/Imágenes/Wallpapers."
            }
            Txt { visible: wp.error !== ""; Layout.fillWidth: true; text: wp.error; color: Theme.danger; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Button { text: "Abrir carpeta"; onClicked: Quickshell.execDetached(["sh", "-c", "d=\"$(xdg-user-dir PICTURES)\"; [ -d \"$d/Fondos\" ] && xdg-open \"$d/Fondos\" || { mkdir -p \"$d/Wallpapers\"; xdg-open \"$d/Wallpapers\"; }"]) }
                Button { text: "Al azar"; onClicked: Quickshell.execDetached([Paths.script("hf-wallpaper"), "random"]) }
                Button { text: wp.adding ? "Eligiendo…" : "Añadir fondo animado…"; enabled: !wp.adding; onClicked: wp.addAnimated() }
                IconBtn { icon: "refresh"; implicitWidth: 30; implicitHeight: 30; onClicked: wp.refresh() }
                Button { text: "Selector de fondos"; kind: "primary"; onClicked: Shell.open("fondos") }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Section {
                Layout.fillWidth: true
                title: "Cambio automático"
                headerRight: Sw {
                    checked: root.auto
                    onToggled: v => Settings.setMany({ wallpaperRotateMin: v ? 60 : 0, wallpaperOnStart: false })
                }
                LabeledRow {
                    label: "Cada"; labelWidth: 80
                    Seg {
                        model: [["15", "15 min"], ["60", "1 h"], ["240", "4 h"], ["1440", "Diario"], ["inicio", "Al iniciar"]]
                        current: Settings.get("wallpaperOnStart", false) && root.rot === 0 ? "inicio" : String(root.rot)
                        onPicked: k => Settings.setMany(k === "inicio" ? { wallpaperOnStart: true, wallpaperRotateMin: 0 } : { wallpaperOnStart: false, wallpaperRotateMin: parseInt(k) })
                    }
                }
                LabeledRow {
                    label: "Orden"; labelWidth: 80
                    Seg {
                        model: [["azar", "Aleatorio"], ["orden", "En orden"]]
                        current: Settings.get("wallpaperRandom", false) ? "azar" : "orden"
                        onPicked: k => Settings.set("wallpaperRandom", k === "azar")
                    }
                }
                LabeledRow {
                    label: "Transición"; labelWidth: 80
                    Seg {
                        model: [["fundido", "Fundido"], ["ninguna", "Ninguna"]]
                        current: Settings.get("wallpaperTransition", "fundido")
                        onPicked: k => Settings.set("wallpaperTransition", k)
                    }
                }
                SwRow { label: "Según la hora del día"; sub: "fondos claros de día y oscuros de noche"; key: "wallpaperHora" }
                SwRow { label: "No cambiar con pantalla completa"; sub: "espera a que salgas del juego o del vídeo"; key: "wallpaperNoFullscreen"; def: true }
                Mono { Layout.fillWidth: true; text: root.auto ? "hf-wallpaper " + (Settings.get("wallpaperRandom", false) ? "random" : "next") + (root.rot > 0 ? " · cada " + root.rot + " min" : " · al iniciar") : "hf-wallpaper restore · al iniciar sesión" }
            }
            Section {
                Layout.fillWidth: true
                title: "Fondos en movimiento"
                headerRight: Sw { checked: Settings.get("wallpaperMotion", true) && !Settings.get("reduceMotion", false); onToggled: v => Settings.set("wallpaperMotion", v) }
                Seg {
                    Layout.fillWidth: true
                    model: [["video", "Vídeo"], ["escena", "Escenas"]]
                    current: Settings.get("wallpaperMotionKind", "video")
                    onPicked: k => Settings.set("wallpaperMotionKind", k)
                }
                Txt {
                    Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: Settings.get("wallpaperMotionKind", "video") === "video"
                        ? "Vídeos (.mp4, .webm, .mkv, .mov) y GIF en bucle con mpvpaper, sin sonido. El color del tema se toma del primer cuadro."
                        : "Escenas de Wallpaper Engine (carpetas con project.json) con linux-wallpaperengine (instálalo desde Herramientas)."
                }
                // Reproductor: instalado o botón para instalarlo
                RowLayout {
                    Layout.fillWidth: true
                    visible: Settings.get("wallpaperMotionKind", "video") === "video"
                    spacing: 8
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: root.hasPlayer ? Theme.p : Theme.danger }
                    Txt {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? "mpvpaper instalado" : "Falta mpvpaper: sin él los vídeos se quedan quietos"
                        size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                    Button { visible: !root.hasPlayer; kind: "primary"; text: "Instalar mpvpaper"; onClicked: root.installPlayer() }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: howCol.implicitHeight + 20
                    radius: Theme.r(6)
                    color: Theme.fill2
                    ColumnLayout {
                        id: howCol
                        x: 10; y: 10
                        width: parent.width - 20
                        spacing: 4
                    Txt { text: "Cómo poner un fondo en movimiento"; weight: Font.DemiBold; size: 12 }
                    Txt {
                        Layout.fillWidth: true; size: 11.5; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; textFormat: Text.StyledText
                        text: "1. Instala <b>mpvpaper</b> (botón de arriba) si aún no lo tienes.<br>"
                            + "2. Pulsa <b>Añadir fondo animado…</b> y elige un vídeo o GIF: se copia a tu carpeta de fondos y se pone al momento.<br>"
                            + "3. Para cambiarlo, filtra por <b>Fondos animados</b> y haz clic en otro.<br>"
                            + "Consejo: vídeos en bucle de 10–30 s a la resolución de tu pantalla gastan menos. Con batería o un juego en pantalla completa se pausa solo (abajo)."
                    }
                    }
                }
                LabeledRow {
                    label: "Límite FPS"; labelWidth: 80
                    Pills { model: [15, 30, 60]; current: Settings.get("wallpaperFps", 30); onPicked: v => Settings.set("wallpaperFps", v) }
                }
                Txt { text: "Pausar cuando… (ahorra batería y GPU)"; muted: true }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [["fullscreen", "Pantalla completa"], ["bateria", "Con batería"], ["maximizada", "Ventana maximizada"], ["juego", "Modo juego"], ["foco", "Sin distracciones"]]
                        Chip {
                            required property var modelData
                            readonly property var list: Settings.get("wallpaperPauseOn", ["fullscreen", "bateria", "juego"])
                            text: modelData[1]
                            on: list.includes(modelData[0])
                            onClicked: Settings.set("wallpaperPauseOn", on ? list.filter(x => x !== modelData[0]) : list.concat([modelData[0]]))
                        }
                    }
                }
            }
        }
    }
    // Wallhaven: buscar, añadir a mis fondos y usarlo como origen del cambio automático (ui/WallhavenCard, hf-wallhaven)
    WallhavenCard { Layout.fillWidth: true }
}
