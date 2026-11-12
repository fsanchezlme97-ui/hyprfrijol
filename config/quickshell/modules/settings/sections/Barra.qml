// Ajustes › Barra — posición, forma, altura, módulos visibles y comportamiento ("barBehavior": siempre /
// auto / inteligente; migra el antiguo barAutoHide al elegir).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property string pos: Settings.get("barPos", "abajo")
    readonly property string mode: Settings.get("barMode", "fija")

    Section {
        Layout.fillWidth: true
        title: "Posición"
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [["arriba", "Arriba"], ["abajo", "Abajo"], ["izquierda", "Izquierda"], ["derecha", "Derecha"]]
                ColumnLayout {
                    id: card
                    required property var modelData
                    readonly property bool on: root.pos === modelData[0]
                    readonly property string k: modelData[0]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 96
                        radius: Theme.r(6)
                        color: Theme.s4
                        border.width: card.on ? 3 : 1
                        border.color: card.on ? Theme.p : Theme.ov
                        readonly property real m: root.mode === "fija" ? 0 : 6
                        Rectangle {   // ventana de ejemplo
                            x: card.k === "izquierda" ? 26 : 12
                            y: card.k === "arriba" ? 26 : 12
                            width: parent.width - 38; height: parent.height - 38
                            radius: Theme.r(3); color: Theme.s3; opacity: 0.9
                        }
                        Rectangle {   // la barra
                            visible: root.mode !== "archipielago"
                            readonly property bool vert: card.k === "izquierda" || card.k === "derecha"
                            readonly property real inset: (parent.border.width) + parent.m
                            color: card.on ? Theme.p : Theme.o
                            radius: root.mode === "fija" ? 0 : 3
                            width: vert ? 9 : (root.mode === "isla" ? parent.width * 0.5 : parent.width - inset * 2)
                            height: vert ? (root.mode === "isla" ? parent.height * 0.5 : parent.height - inset * 2) : 9
                            x: card.k === "izquierda" ? inset : card.k === "derecha" ? parent.width - width - inset : (parent.width - width) / 2
                            y: card.k === "arriba" ? inset : card.k === "abajo" ? parent.height - height - inset : (parent.height - height) / 2
                        }
                        Repeater {   // archipiélago: una píldora por grupo, con hueco entre ellas
                            model: root.mode === "archipielago" ? (card.k === "izquierda" || card.k === "derecha" ? [[0, 0.3], [0.62, 0.38]] : [[0, 0.3], [0.38, 0.24], [0.7, 0.3]]) : []
                            Rectangle {
                                required property var modelData
                                readonly property bool vert: card.k === "izquierda" || card.k === "derecha"
                                readonly property real inset: parent.border.width + parent.m
                                readonly property real span: (vert ? parent.height : parent.width) - inset * 2
                                color: card.on ? Theme.p : Theme.o
                                radius: 4.5
                                width: vert ? 9 : span * modelData[1]
                                height: vert ? span * modelData[1] : 9
                                x: card.k === "izquierda" ? inset : card.k === "derecha" ? parent.width - width - inset : inset + span * modelData[0]
                                y: card.k === "arriba" ? inset : card.k === "abajo" ? parent.height - height - inset : inset + span * modelData[0]
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Confirm.change("Posición de la barra", { barPos: card.k }) }
                    }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: card.modelData[1]; weight: card.on ? Font.DemiBold : Font.Normal }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 22
            LabeledRow {
                Layout.preferredWidth: 1
                label: "Forma"; labelWidth: 60
                Seg {
                    model: [["fija", "Fija al borde"], ["flotante", "Flotante"], ["isla", "Isla central"], ["archipielago", "Archipiélago"]]
                    current: root.mode
                    onPicked: k => Confirm.change("Forma de la barra", { barMode: k })
                }
            }
        }
        // Píldoras (isla / archipiélago): esquinas a partir de las de las ventanas, como mucho +4 px (no rompe el estilo)
        LabeledRow {
            visible: root.mode === "archipielago" || root.mode === "isla"
            label: "Esquinas"; labelWidth: 60
            Seg {
                readonly property int win: Settings.get("rounding", null) ?? Theme.winRadius
                model: [[0, "Como las ventanas (" + win + " px)"], [2, (win + 2) + " px"], [4, (win + 4) + " px"]]
                current: Settings.get("barRoundExtra", 4)
                onPicked: k => Settings.set("barRoundExtra", k)
            }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Tamaño"
        headerRight: Mono { text: Settings.barSize + " px · contenido ×" + Settings.barScale.toFixed(2) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Pills {
                Layout.fillWidth: true
                model: [[26, "Mini"], [30, "Compacta"], [34, "Normal"], [40, "Grande"], [46, "Muy grande"], [54, "Enorme"]]
                current: Settings.barSize
                onPicked: v => Confirm.change("Tamaño de la barra", { barHeight: v })
            }
            Stepper { label: "Ajuste fino"; unit: " px"; from: 24; to: 56; step: 2; value: Settings.barSize; onStepped: v => Confirm.change("Tamaño de la barra", { barHeight: v }) }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Iconos, textos y la onda de audio crecen con la barra. Los paneles se abren siempre junto a ella."
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Avisos emergentes"
        headerRight: Mono { text: "volumen · brillo · Bloq Mayús · micrófono" }
        LabeledRow {
            label: "Posición"; labelWidth: 80
            Seg {
                model: [["abajo", "Abajo"], ["arriba", "Arriba"], ["centro", "Centro"], ["izquierda", "Izquierda"], ["derecha", "Derecha"], ["inf-der", "Abajo dcha."], ["sup-der", "Arriba dcha."]]
                current: Settings.get("osdPos", "abajo")
                onPicked: k => Settings.set("osdPos", k)
            }
        }
        LabeledRow {
            label: "Distancia"; labelWidth: 80
            Pills {
                model: [[4, "4 px"], [8, "8 px"], [14, "14 px"], [24, "24 px"], [48, "48 px"], [96, "96 px"]]
                current: Settings.get("osdOffset", 14)
                onPicked: v => Settings.set("osdOffset", v)
            }
        }
        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Probar"; onClicked: Quickshell.execDetached(["qs", "-p", Paths.root + "/config/quickshell", "ipc", "call", "osd", "popup", "volumen"]) }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Onda de audio"
        headerRight: Sw { checked: Settings.barHas("musica"); onToggled: v => { const l = Settings.barModuleList.filter(m => m !== "musica"); if (v) l.push("musica"); Settings.set("barModules", l); } }
        LabeledRow {
            label: "Estilo"; labelWidth: 60
            Seg {
                model: [["barras", "Barras"], ["onda", "Onda rellena"], ["linea", "Línea"]]
                current: Settings.get("waveStyle", "barras")
                onPicked: k => Settings.set("waveStyle", k)
            }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Módulos visibles"
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["espacios", "Espacios"], ["titulo", "Título de ventana"], ["musica", "Música"], ["red", "Red"], ["bateria", "Batería"], ["notificaciones", "Notificaciones"], ["reloj", "Reloj"]]
                Chip {
                    required property var modelData
                    readonly property var list: Settings.barModuleList
                    text: modelData[1]
                    on: list.includes(modelData[0])
                    onClicked: Settings.set("barModules", on ? list.filter(x => x !== modelData[0]) : list.concat([modelData[0]]))
                }
            }
        }
        LinkRow { label: "Clima, sistema, pomodoro, asistente y demás widgets"; section: "barwidgets"; sectionLabel: "Widgets de la barra"; target: "Distribución" }
    }
    // Bandeja del sistema (bar/Tray.qml): barTray · barTrayMax · barTrayHidden (ids que van al «›»)
    Section {
        Layout.fillWidth: true
        title: "Bandeja del sistema"
        headerRight: Mono { text: "OBS, Steam, Discord… · StatusNotifierItem" }
        SwRow { separator: false; label: "Mostrar la bandeja"; sub: "iconos de las apps en segundo plano · clic derecho: su menú"; key: "barTray"; def: true }
        LabeledRow {
            label: "Iconos a la vista"; labelWidth: 150
            opacity: Settings.get("barTray", true) ? 1 : 0.45
            Pills {
                Layout.fillWidth: true
                model: [[0, "Ninguno"], [3, "3"], [4, "4"], [6, "6"], [8, "8"], [12, "12"]]
                current: Number(Settings.get("barTrayMax", 6))
                onPicked: v => Settings.set("barTrayMax", v)
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "El resto, y los que marques aquí abajo, quedan en el desplegable «›» de la bandeja."
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                // las apps abiertas ahora y las que ya ocultaste aunque no estén
                model: {
                    const hid = Settings.get("barTrayHidden", []), ids = SystemTray.items.values.map(i => i.id);
                    return ids.concat(hid.filter(h => !ids.includes(h)));
                }
                Chip {
                    required property var modelData
                    readonly property var hid: Settings.get("barTrayHidden", [])
                    h: 26
                    text: modelData
                    on: !hid.includes(modelData)
                    onClicked: Settings.set("barTrayHidden", on ? hid.concat([modelData]) : hid.filter(x => x !== modelData))
                }
            }
            Txt { visible: SystemTray.items.values.length === 0 && Settings.get("barTrayHidden", []).length === 0; text: "No hay ninguna app en la bandeja ahora mismo."; muted: true; size: 11.5 }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Comportamiento"
        LabeledRow {
            label: "Mostrar la barra"; labelWidth: 120
            Seg {
                model: [["siempre", "Siempre visible"], ["auto", "Ocultar automáticamente"], ["inteligente", "Ocultación inteligente"]]
                current: Settings.barBehavior
                onPicked: k => Settings.patch({ barBehavior: k }, ["barAutoHide"])
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: Settings.barBehavior === "auto" ? "Se esconde y aparece al llevar el cursor al borde de la pantalla."
                : Settings.barBehavior === "inteligente" ? "Se aparta cuando una ventana flotante la tapa o hay una maximizada o a pantalla completa, y vuelve al llevar el cursor al borde. En mosaico sigue reservando su sitio."
                : "Siempre a la vista; las ventanas no se colocan debajo."
        }
        // Una fila por pantalla: completa (todo), sencilla (espacios y consumo por programa) u oculta
        Repeater {
            model: Quickshell.screens
            LabeledRow {
                required property var modelData
                label: modelData.name + (modelData === Shell.primaryScreen ? " (principal)" : ""); labelWidth: 120
                Seg {
                    model: [["completa", "Barra completa"], ["sencilla", "Sencilla"], ["oculta", "Sin barra"]]
                    current: Shell.barModeFor(modelData)
                    onPicked: k => {
                        const m = Object.assign({}, Settings.get("barScreens", {}) ?? {});
                        m[modelData.name] = k;
                        Settings.set("barScreens", m);
                    }
                }
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Sencilla: los espacios de esa pantalla y lo que gasta cada programa abierto en ella."
        }
        SwRow { visible: Quickshell.screens.length > 1; label: "Reloj en la barra sencilla"; sub: "la hora también en las otras pantallas"; key: "barSecondaryClock"; def: true }
        SwRow { label: "Barra en las pantallas nuevas"; sub: "sencilla al conectar otra pantalla; si no, sin barra hasta que la elijas"; key: "barAllScreens"; def: true }
        SwRow { label: "Transparente en espacios vacíos"; sub: "la barra se funde con el fondo si no hay ventanas"; key: "barTransparentEmpty" }
    }
}
