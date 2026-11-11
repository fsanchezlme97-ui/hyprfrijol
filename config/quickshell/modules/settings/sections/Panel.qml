// Ajustes › Panel lateral y PiP — pestañas del panel (sidePanelApps), ancho, lado y fijado (sidePanelPinned); PiP: esquina, tamaño,
// margen, opacidad (config/apply/pip.py genera la window_rule); también las miniventanas de llamadas
// (pipCalls) y reproductores (pipPlayers), ver modules/pip/pip-apps.json.
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
    AiTabs { current: "panel" }   // Asistente | Privacidad | Dictado | Panel (una sola entrada en la lista)
    readonly property var apps: Settings.get("sidePanelApps", ["ia"])
    readonly property var catalog: [["ia", "", "Asistente de IA", "hf-ai", ""]]
    function toggleTab(k, v) { Settings.set("sidePanelApps", v ? apps.concat([k]) : apps.filter(x => x !== k)); }
    readonly property string corner: Settings.get("pipCorner", "sup-der")
    readonly property var sizes: ({ minimo: [192, 108], pequeno: [256, 144], mediano: [320, 180], grande: [400, 225] })
    readonly property var size: sizes[Settings.get("pipSize", "minimo")] ?? sizes.minimo
    readonly property int margin: Settings.get("pipMargin", 12)

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Panel lateral"
            headerRight: Kbd { text: "Super + A" }
            Repeater {
                model: root.catalog
                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: root.apps.includes(modelData[0])
                    Layout.fillWidth: true
                    implicitHeight: 44
                    Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6)
                            color: row.index === 0 ? Theme.p : rowIcon.status === Image.Ready ? "transparent" : Theme.s4
                            Image { id: rowIcon; anchors.fill: parent; source: row.modelData[4]; sourceSize: Qt.size(52, 52); visible: status === Image.Ready }
                            Icon { visible: row.index === 0; anchors.centerIn: parent; name: "ai"; size: 15; color: Theme.pText }
                            Txt { visible: rowIcon.status !== Image.Ready && row.index > 0; anchors.centerIn: parent; text: row.modelData[1]; size: 12; weight: Font.DemiBold; color: row.index === 0 ? Theme.pText : Theme.t }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Txt { Layout.fillWidth: true; text: row.modelData[2]; weight: Font.DemiBold }
                            Mono { Layout.fillWidth: true; text: row.modelData[3]; size: 10.5 }
                        }
                        Sw { checked: row.on; onToggled: v => root.toggleTab(row.modelData[0], v) }
                    }
                }
            }
            LabeledRow {
                label: "Ancho"; labelWidth: 60
                Seg { model: [["cuarto", "Un cuarto"], ["tercio", "Un tercio"], [400, "400 px"]]; current: Settings.get("sideWidth", "cuarto"); onPicked: k => Settings.set("sideWidth", k) }
            }
            LabeledRow {
                label: "Lado"; labelWidth: 60
                Seg { model: [["derecha", "Derecha"], ["izquierda", "Izquierda"]]; current: Settings.get("sideSide", "derecha"); onPicked: k => Settings.set("sideSide", k) }
            }
            SwRow {
                label: "Fijar el panel"
                sub: "parte del mosaico: ocupa un tercio de la pantalla y las demás ventanas se reparten el resto; sigue abierto en todos los espacios (pantalla principal)"
                key: "sidePanelPinned"
                onToggled: v => { if (v) Shell.sideHidden = false; }
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.2
            Layout.alignment: Qt.AlignTop
            title: "Imagen en imagen (PiP)"
            headerRight: Sw { checked: Settings.get("pip", true); onToggled: v => Settings.set("pip", v) }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                // selector de esquina sobre una pantalla en miniatura
                Rectangle {
                    id: scr
                    implicitWidth: 200; implicitHeight: 125
                    radius: Theme.r(6)
                    color: Theme.bg
                    border.width: 1; border.color: Theme.ov
                    readonly property real k: width / 1920
                    Repeater {
                        model: ["sup-izq", "sup-centro", "sup-der", "inf-izq", "inf-centro", "inf-der"]
                        Rectangle {
                            required property string modelData
                            readonly property bool on: root.corner === modelData
                            width: Math.max(24, root.size[0] * scr.k * 1.6); height: width * 9 / 16
                            radius: Theme.r(3)
                            x: modelData.endsWith("izq") ? 6 : modelData.endsWith("centro") ? (scr.width - width) / 2 : scr.width - width - 6
                            y: modelData.startsWith("sup") ? 6 : scr.height - height - 6
                            Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                            color: on ? Theme.p : "transparent"
                            border.width: on ? 0 : 1; border.color: Theme.o
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("pipCorner", parent.modelData) }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Txt { text: "Tamaño"; muted: true }
                    Pills { Layout.fillWidth: true; model: [["minimo", "Mínimo"], ["pequeno", "Pequeño"], ["mediano", "Mediano"], ["grande", "Grande"]]; current: Settings.get("pipSize", "minimo"); onPicked: k => Settings.set("pipSize", k) }
                    Mono { text: root.size[0] + " × " + root.size[1] }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap; elide: Text.ElideNone
                        muted: true; size: 11.5
                        text: root.corner === "libre" ? "Posición libre: queda donde lo soltaste. Elige una posición en la miniatura para volver a fijarlo."
                                                     : "Arrástralo con el ratón: se imanta a la posición más cercana o se queda donde lo sueltes."
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                LabeledRow { Layout.preferredWidth: 1; label: "Margen"; labelWidth: 56; Pills { model: [[4, "4 px"], [12, "12 px"], [24, "24 px"], [48, "48 px"]]; current: root.margin; onPicked: v => Settings.set("pipMargin", v) } }
                LabeledRow { Layout.preferredWidth: 1; label: "Opacidad"; labelWidth: 60; Pills { model: [[1, "100 %"], [0.85, "85 %"], [0.7, "70 %"]]; current: Settings.get("pipOpacity", 1); onPicked: v => Settings.set("pipOpacity", v) } }
            }
            SwRow { label: "Botón PiP en todos los vídeos"; sub: "en el navegador y las web apps"; key: "pipButton"; def: true }
            SwRow { label: "PiP automático"; sub: "al cambiar de espacio con un vídeo sonando"; key: "pipAuto"; def: true }
            SwRow { label: "Visible en todos los espacios"; sub: "pin = true"; mono: true; key: "pipAllWs"; def: true }
            SwRow { label: "Controles solo al pasar el cursor"; key: "pipHoverControls"; def: true }
            SwRow { label: "Transparente si el cursor se acerca"; sub: "para ver lo que hay debajo"; key: "pipFadeNear"; def: false }
            SwRow { label: "Videollamadas (Meet, Teams…)"; sub: "su ventana flotante: cerrar sin colgar y volver a la llamada"; key: "pipCalls"; def: true }
            SwRow { label: "Reproductores (Spotify…)"; sub: "miniventana con pausa, siguiente y volver a la app"; key: "pipPlayers"; def: true }
            Mono {
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere; elide: Text.ElideNone
                text: 'window_rule { title = Picture-in-Picture, float, pin = ' + Settings.get("pipAllWs", true) + ', size = ' + root.size[0] + ' ' + root.size[1] + ', opacity = ' + Settings.get("pipOpacity", 1) + ' }'
            }
        }
    }
    function settingsSection(s) { Quickshell.execDetached(["qs", "-p", Paths.root + "/config/quickshell", "ipc", "call", "settings", "open", s]); }
}
