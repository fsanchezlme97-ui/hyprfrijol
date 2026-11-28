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
import "../../../bar"

ColumnLayout {
    id: root
    spacing: 12
    readonly property string pos: Settings.get("barPos", "abajo")
    readonly property string mode: Settings.barMode
    readonly property string align: Settings.barAlign
    readonly property bool vertical: root.pos === "izquierda" || root.pos === "derecha"
    readonly property bool archi: Settings.barArchipelago          // archipiélago o isla integrada: una píldora por grupo

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
                            radius: root.mode === "fija" ? 0 : 3
                            // isla: lo que su contenido (aquí un 40 %); alineada como barAlign
                            readonly property real part: root.mode === "isla" ? 0.4 : 1
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
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            LabeledRow {
                Layout.preferredWidth: 1
                label: "Forma"; labelWidth: 60
                Seg {
                    model: [["fija", "Fija al borde"], ["flotante", "Flotante"], ["isla", "Isla"], ["archipielago", "Archipiélago"], ["integrada", "Isla integrada"]]
                    current: root.mode
                    onPicked: k => Confirm.change("Forma de la barra", { barMode: k })
                }
            }
        }
        Txt {
            visible: root.mode === "integrada"
            Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5
            text: Settings.barIntegrated ? "La isla dinámica ocupa el centro de la barra y se despliega hacia el escritorio; la onda de audio no se muestra. Qué enseña se elige en «Isla dinámica»."
                : "La isla solo cabe dentro de la barra si está arriba o abajo y siempre visible; con esta configuración flota junto a ella."
        }
        // Isla: dónde se coloca a lo largo del borde
        LabeledRow {
            visible: root.mode === "isla"
            label: "Alineación"; labelWidth: 60
            Seg {
                model: [["inicio", root.vertical ? "Arriba" : "Izquierda"], ["centro", "Centro"], ["fin", root.vertical ? "Abajo" : "Derecha"]]
                current: root.align
                onPicked: k => Settings.set("barAlign", k)
            }
        }
        // Píldoras (isla / archipiélago): esquinas a partir de las de las ventanas, como mucho +4 px (no rompe el estilo)
        LabeledRow {
            visible: root.archi || root.mode === "isla"
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
        title: "Módulos visibles"
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["espacios", "Espacios"], ["titulo", "Título"], ["musica", "Música"], ["red", "Red"], ["bateria", "Batería"], ["notificaciones", "Notificaciones"], ["reloj", "Reloj"]]
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
        title: "Isla dinámica"
        headerRight: Mono { tech: true; text: "island · islandShow · islandAlways" }
        SwRow {
            separator: false
            label: "Isla dinámica"
            sub: root.mode === "integrada" ? "siempre activa con la forma «Isla integrada» de la barra" : "una pastilla arriba al centro con lo que está pasando; se despliega al pasar el puntero o al pulsarla"
            enabled: root.mode !== "integrada"
            key: "island"; def: false
            onToggled: v => Settings.set("island", v)
        }
        SwRow {
            label: "Siempre visible"
            sub: "con nada en marcha enseña la hora; si no, se esconde"
            key: "islandAlways"; def: false
            onToggled: v => Settings.set("islandAlways", v)
        }
        LabeledRow {
            label: "Mostrar"; labelWidth: 80
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [["reunion", "Reuniones"], ["pomodoro", "Pomodoro"], ["descargas", "Procesos"], ["musica", "Música"]]
                    Chip {
                        required property var modelData
                        readonly property var list: Settings.get("islandShow", ["musica", "pomodoro", "descargas", "reunion"]) ?? []
                        text: modelData[1]
                        on: list.includes(modelData[0])
                        onClicked: Settings.set("islandShow", on ? list.filter(x => x !== modelData[0]) : list.concat([modelData[0]]))
                    }
                }
            }
        }
        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; size: 11.5; text: "Va en el sitio de arriba de los indicadores de volumen: ellos y la píldora del dictado se apartan de ella. Una ventana a pantalla completa la tapa. El dictado no entra en la isla." }
    }
    Section {
        Layout.fillWidth: true
        title: "Onda de audio"
        headerRight: Sw { checked: Settings.barHas("musica"); onToggled: v => { const l = Settings.barModuleList.filter(m => m !== "musica"); if (v) l.push("musica"); Settings.set("barModules", l); } }
        // Cada estilo dibujado con unos niveles de muestra (bar/Waveform.qml en modo muestra)
        GridLayout {
            id: waveGrid
            Layout.fillWidth: true
            columns: width > 640 ? 4 : 3
            columnSpacing: 8; rowSpacing: 8
            readonly property var sample: Array.from({ length: 48 }, (_, i) => 0.18 + 0.55 * Math.abs(Math.sin(i * 0.37)) * (0.55 + 0.45 * Math.cos(i * 0.11)))
            Repeater {
                model: [["barras", "Barras"], ["onda", "Onda rellena"], ["linea", "Línea"], ["zigzag", "Zigzag"],
                        ["cinta", "Cinta"], ["escalones", "Escalones"], ["capas", "Capas suaves"], ["burbujas", "Burbujas"],
                        ["agujas", "Agujas"], ["montana", "Montaña"], ["reflejo", "Reflejo"], ["pixeles", "Píxeles"],
                        ["eco", "Eco"], ["cuerdas", "Cuerdas"], ["pulso", "Pulso"]]
                Rectangle {
                    id: wc
                    required property var modelData
                    readonly property bool sel: Settings.get("waveStyle", "barras") === modelData[0]
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
