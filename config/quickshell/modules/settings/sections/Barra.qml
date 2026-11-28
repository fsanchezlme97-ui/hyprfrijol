// Ajustes › Barra — posición, forma (fija / flotante) y disposición (completa / archipiélago / isla), tamaño (32 / 34 /
// 36 px), módulos visibles y comportamiento ("barBehavior": siempre / auto / retraer; migra el antiguo barAutoHide al elegir).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"
import "../../../bar"

ColumnLayout {
    id: root
    spacing: 12
    readonly property string pos: Settings.get("barPos", "abajo")
    readonly property string mode: Settings.barMode               // fija · flotante
    readonly property string layout: Settings.barLayout           // completa · archipielago · isla
    readonly property string align: Settings.barAlign
    readonly property bool vertical: root.pos === "izquierda" || root.pos === "derecha"
    readonly property bool archi: Settings.barArchipelago          // archipiélago: una píldora por grupo

    BarTabs { current: "barra" }   // Barra | Widgets (una sola entrada en la lista)

    Section {
        Layout.fillWidth: true
        title: "Posición"
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: [["arriba", "Arriba"], ["abajo", "Abajo"], ["izquierda", "Izquierda"], ["derecha", "Derecha"]]
                ColumnLayout {
                    id: card
                    required property var modelData
                    readonly property bool on: root.pos === modelData[0]
                    readonly property string k: modelData[0]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 8
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
                            visible: !root.archi
                            readonly property bool vert: card.k === "izquierda" || card.k === "derecha"
                            readonly property real inset: (parent.border.width) + parent.m
                            color: card.on ? Theme.p : Theme.o
                            radius: root.mode === "fija" && root.layout === "completa" ? 0 : 3
                            // isla: lo que su contenido (aquí un 40 %); alineada como barAlign
                            readonly property real part: root.layout === "isla" ? 0.4 : 1
                            readonly property real span: (vert ? parent.height : parent.width) - inset * 2
                            readonly property real along: inset + (root.align === "inicio" ? 0 : root.align === "fin" ? 1 : 0.5) * span * (1 - part)
                            width: vert ? 9 : span * part
                            height: vert ? span * part : 9
                            x: card.k === "izquierda" ? inset : card.k === "derecha" ? parent.width - width - inset : along
                            y: card.k === "arriba" ? inset : card.k === "abajo" ? parent.height - height - inset : along
                        }
                        Repeater {   // archipiélago: una píldora por grupo, con hueco entre ellas
                            model: root.archi ? (card.k === "izquierda" || card.k === "derecha" ? [[0, 0.3], [0.62, 0.38]] : [[0, 0.3], [0.38, 0.24], [0.7, 0.3]]) : []
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
        // Forma (fija al borde o flotante) y, dentro de ella, la disposición de los módulos
        LabeledRow {
            label: "Forma"; labelWidth: 90
            Seg {
                model: [["fija", "Fija al borde"], ["flotante", "Flotante"]]
                current: root.mode
                onPicked: k => Confirm.change("Forma de la barra", { barMode: k, barLayout: root.layout })
            }
        }
        LabeledRow {
            label: "Disposición"; labelWidth: 90
            Seg {
                model: [["completa", "Completa"], ["archipielago", "Archipiélago"], ["isla", "Isla"]]
                current: root.layout
                onPicked: k => Confirm.change("Disposición de la barra", { barMode: root.mode, barLayout: k })
            }
        }
        // Isla: dónde se coloca a lo largo del borde
        LabeledRow {
            visible: root.layout === "isla"
            label: "Alineación"; labelWidth: 90
            Seg {
                model: [["inicio", root.vertical ? "Arriba" : "Izquierda"], ["centro", "Centro"], ["fin", root.vertical ? "Abajo" : "Derecha"]]
                current: root.align
                onPicked: k => Settings.set("barAlign", k)
            }
        }
        // Píldoras (isla / archipiélago): esquinas a partir de las de las ventanas, como mucho +4 px (no rompe el estilo)
        LabeledRow {
            visible: root.layout !== "completa"
            label: "Esquinas"; labelWidth: 90
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
        headerRight: Mono { text: "contenido ×" + Settings.barScale.toFixed(2) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Pills {
                Layout.fillWidth: true
                model: [[32, "Compacta · 32 px"], [34, "Normal · 34 px"], [36, "Grande · 36 px"]]
                current: Settings.barSize
                onPicked: v => Confirm.change("Tamaño de la barra", { barHeight: v })
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Iconos, textos y la onda de audio crecen con la barra. Los paneles se abren siempre junto a ella."
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Módulos"
        // Todos los módulos: los fijos, los widgets (y los propios) de barModules, y la bandeja, las memorias USB y las
        // descargas, que tienen su propia clave
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: Object.keys(Settings.barCoreNames).map(k => [k, Settings.barCoreNames[k]])
                    .concat(Settings.barWidgetIds.map(k => [k, Settings.barWidgetNames[k]]))
                    .concat(Settings.barCustomList.map(c => ["propio:" + c.id, c.name || "Widget propio"]))
                Chip {
                    required property var modelData
                    readonly property var list: Settings.barModuleList
                    text: modelData[1]
                    on: list.includes(modelData[0])
                    onClicked: Settings.set("barModules", on ? list.filter(x => x !== modelData[0]) : list.concat([modelData[0]]))
                }
            }
            Repeater {
                model: [["barTray", "Bandeja del sistema"], ["devicesBarIcon", "Memorias USB"], ["downloadsBarIcon", "Descargas"]]
                Chip {
                    required property var modelData
                    text: modelData[1]
                    on: Settings.get(modelData[0], true) !== false
                    onClicked: Settings.set(modelData[0], !on)
                }
            }
        }
        LinkRow { label: "Clima, sistema, pomodoro, asistente y demás widgets"; section: "barwidgets"; sectionLabel: "Widgets de la barra"; target: "Distribución" }
    }
    Section {
        Layout.fillWidth: true
        title: "Comportamiento"
        LabeledRow {
            label: "Mostrar la barra"; labelWidth: 120
            Seg {
                model: [["siempre", "Siempre visible"], ["auto", "Ocultar automáticamente"], ["retraer", "Retraer"]]
                current: Settings.barBehavior
                onPicked: k => Settings.patch({ barBehavior: k }, ["barAutoHide"])
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: Settings.barBehavior === "auto" ? "Se esconde y aparece al llevar el cursor al borde de la pantalla."
                : Settings.barBehavior === "retraer" ? "Se esconde siempre que haya ventanas en el espacio (las flotantes no cuentan), que ocupan entonces su sitio, y vuelve al acercar el cursor al borde donde está."
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
    }
    // Bandeja del sistema (bar/Tray.qml): barTray · barTrayMax · barTrayHidden (ids que van al «›»)
    Section {
        Layout.fillWidth: true
        title: "Bandeja del sistema"
        headerRight: Mono { tech: true; text: "OBS, Steam, Discord… · StatusNotifierItem" }
        SwRow { separator: false; label: "Mostrar la bandeja"; sub: "iconos de las apps en segundo plano · clic derecho: su menú"; key: "barTray"; def: true }
        LabeledRow {
            label: "Iconos a la vista"; labelWidth: 150
            opacity: Settings.get("barTray", true) ? 1 : 0.45
            Pills {
                Layout.fillWidth: true
                model: [[0, "Ninguno"], [3, "3"], [4, "4"], [6, "6"], [8, "8"], [12, "12"]]
                current: Number(Settings.get("barTrayMax", 3))
                onPicked: v => Settings.set("barTrayMax", v)
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Si hay más, todos se ocultan en el desplegable «›», que muestra cuántas apps hay en segundo plano (como en Windows). Los que desmarques aquí abajo van siempre al desplegable."
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
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
        title: "Indicadores de volumen y brillo"
        headerRight: Mono { tech: true; text: "OSD · volumen · brillo · Bloq Mayús · micrófono" }
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
        // Cada estilo dibujado con unos niveles de muestra (bar/Waveform.qml en modo muestra)
        GridLayout {
            id: waveGrid
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8; rowSpacing: 8
            readonly property var sample: Array.from({ length: 48 }, (_, i) => 0.18 + 0.55 * Math.abs(Math.sin(i * 0.37)) * (0.55 + 0.45 * Math.cos(i * 0.11)))
            Repeater {
                model: [["barras", "Barras"], ["onda", "Onda rellena"], ["agujas", "Agujas"]]
                Rectangle {
                    id: wc
                    required property var modelData
                    readonly property bool sel: (["onda", "agujas"].includes(Settings.get("waveStyle", "barras")) ? Settings.get("waveStyle", "barras") : "barras") === modelData[0]
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: Theme.r(7)
                    color: sel ? Theme.selBg : wma.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
                    border.width: sel ? 2 : 1
                    border.color: sel ? Theme.p : Theme.ov
                    Waveform {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        scale: Math.min(1, (wc.width - 16) / implicitWidth)
                        barHeight: 38
                        forceKind: wc.modelData[0]
                        sample: waveGrid.sample
                    }
                    Txt {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
                        horizontalAlignment: Text.AlignHCenter
                        text: wc.modelData[1]; size: 11.5; weight: Font.Medium
                        color: wc.sel ? Theme.selText : Theme.t
                    }
                    MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("waveStyle", wc.modelData[0]) }
                }
            }
        }
        // Estados del asistente (bar/Waveform.qml): se ven en cualquier estilo, antes que la música
        Txt {
            Layout.fillWidth: true
            text: "Además de la música, la onda dice qué hace " + (Settings.get("aiName", "") || "el asistente") + ":"
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Flow {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                model: [[Qt.alpha(Theme.p, 0.45), "En espera"], [Theme.p, "Escuchando"], [Qt.tint(Theme.p, Qt.alpha(Theme.glass, 0.45)), "Procesando"], [Theme.ter, "Hablando"]]
                Row {
                    required property var modelData
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: parent.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: parent.modelData[1]; size: 11.5 }
                }
            }
        }
    }
}
