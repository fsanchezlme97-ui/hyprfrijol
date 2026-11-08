// Ajustes › Escritorio y gestos — modo de ventanas ("windowMode": mosaico / desplazamiento / flotante, con
// muestras ui/WinModePreview.qml; services/WinMode.qml, config/apply/30-layout.py y 35-windows.py), columnas del
// desplazamiento ("scrollColumnWidth", "scrollFocusFit", "scrollOneFull"), dock ("dockBehavior": fijo / auto / inteligente, "dockInTiling"; modules/desktop),
// espacios ("wsNumerals", "wsShowAll"; bar/Workspaces.qml), iconos del escritorio ("deskIcons", "deskIconSize") y widgets; esquinas calientes (Daemons.qml), gestos del touchpad (hl.gesture),
// apps en ventana flotante ("floatApps", "floatAppsSize"; ui/FloatApps.qml, 35-windows.py),
// diseño de mosaico (general:layout), enfocar al pasar el cursor y acoplar a los bordes; nombres e iconos de los
// espacios ("wsNames", "wsIcons", "wsBarNames" → barra y vista general; ui/WsNames.qml).
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property var actions: [["ninguna", "Nada"], ["vista", "Vista general"], ["ia", "Asistente de IA"], ["spotlight", "Spotlight"],
        ["notificaciones", "Notificaciones"], ["ajustes", "Ajustes rápidos"], ["bloquear", "Bloquear pantalla"], ["escritorio", "Mostrar escritorio"]]
    readonly property var corners: Settings.get("hotCorners", { tl: "vista", tr: "ninguna", bl: "ninguna", br: "escritorio" })
    function setCorner(k, v) { const o = Object.assign({}, corners); o[k] = v; Settings.set("hotCorners", o); }
    readonly property string winMode: WinMode.mode
    // El antiguo layout = "scrolling" es ahora el modo «Desplazamiento»: al elegir otro, el mosaico vuelve a dwindle
    function pickMode(m) {
        if (Settings.get("layout", "dwindle") === "scrolling") Settings.setMany({ windowMode: m, layout: "dwindle" });
        else Settings.set("windowMode", m);
    }
    readonly property string deskIcons: { const v = Settings.get("deskIcons", "todos"); return v === "flotante" ? "ordenado" : v; }

    Section {
        Layout.fillWidth: true
        title: "Modo de ventanas"
        headerRight: Kbd { text: "Super + Mayús + Espacio" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [["mosaico", "Mosaico", "Se reparten la pantalla, sin taparse"],
                        ["desplazamiento", "Desplazamiento", "Columnas en una cinta que se desplaza de lado"],
                        ["flotante", "Flotante", "Ventanas libres que se minimizan y maximizan desde el dock"]]
                WinModePreview {
                    required property var modelData
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    mode: modelData[0]
                    title: modelData[1]; sub: modelData[2]
                    selected: root.winMode === modelData[0]
                    onClicked: root.pickMode(modelData[0])
                }
            }
        }
        Txt {
            Layout.fillWidth: true
            text: (root.winMode === "mosaico"
                ? "Cada ventana nueva se coloca junto a las demás. Super + Alt + Espacio deja flotar solo la ventana activa."
                : root.winMode === "desplazamiento"
                ? "Cada ventana nueva abre una columna a la derecha y la cinta se desplaza para enseñarla. Super + ← / → (o Super + rueda) "
                  + "cambia de columna, Super + Ctrl + Mayús + ← / → mueve la columna, Super + Mayús + ← / → mete la ventana en la "
                  + "columna de al lado, Super + ñ / ´ cambia el ancho y Super + Ctrl + F encaja las columnas a la vista."
                : "Las ventanas nuevas se abren centradas y en cascada. Super + arrastrar las mueve (clic derecho: tamaño) · "
                  + "Super + ↑ maximiza, Super + ↓ restaura, Super + ← / → las acopla a media pantalla y Super + H minimiza "
                  + "(Super + Mayús + H la recupera).")
                + " Super + Mayús + Espacio pasa por los tres modos; en los ajustes rápidos (Ventanas) puedes dar a un espacio otro modo durante la sesión."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
    }

    // Apps que flotan al centro (floatApps, floatAppsSize → config/apply/35-windows.py) · ui/FloatApps.qml
    Section {
        Layout.fillWidth: true
        title: "Apps en ventana flotante"
        headerRight: Mono { text: "hl.window_rule · float + center" }
        FloatApps {
            id: floatApps
            Layout.fillWidth: true
            onApply: l => Settings.set("floatApps", l)
        }
        LabeledRow {
            label: "Tamaño de la ventana"
            labelWidth: 150
            Pills {
                fill: false
                model: [[0.5, "Pequeña · 50 %"], [0.65, "Mediana · 65 %"], [0.8, "Grande · 80 %"]]
                current: Settings.get("floatAppsSize", 0.65)
                onPicked: k => Settings.set("floatAppsSize", k)
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Dock"
        headerRight: Mono { text: root.winMode === "flotante" || Settings.get("dockInTiling", false) ? "a la izquierda" : "solo en espacios flotantes" }
        LabeledRow {
            label: "Mostrar el dock"
            labelWidth: 150
            Seg {
                model: [["fijo", "Siempre visible"], ["auto", "Ocultar automáticamente"], ["inteligente", "Ocultación inteligente"]]
                current: Settings.get("dockBehavior", "inteligente")
                onPicked: k => Settings.set("dockBehavior", k)
            }
        }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: ({ fijo: "Siempre a la vista y las ventanas maximizadas se quedan a su lado.",
                     auto: "Se esconde y aparece al llevar el cursor al borde izquierdo.",
                     inteligente: "Esquiva las ventanas: se aparta cuando una ventana pasa por encima de él y vuelve cuando queda sitio libre (o al llevar el cursor al borde)." })[Settings.get("dockBehavior", "inteligente")] ?? ""
        }
        SwRow { label: "Mostrar el dock también en mosaico y desplazamiento"; sub: "en el modo flotante se ve siempre"; key: "dockInTiling" }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Clic: ir a la app · clic en la app activa: minimizarla · clic en una minimizada: traerla al espacio actual · clic central: nueva ventana · clic derecho: maximizar, minimizar, cerrar y fijar."
        }
    }

    Section {
        Layout.fillWidth: true
        title: "Espacios de trabajo"
        headerRight: Mono { text: "Super + 1 … 9" }
        LabeledRow {
            label: "Numeración"
            labelWidth: 150
            Seg {
                model: WsLabel.styles.map(s => [s[0], s[1] + "  " + [1, 2, 3].map(n => WsLabel.numeral(n, s[0])).join(" ")])
                current: WsLabel.style
                onPicked: k => Settings.set("wsNumerals", k)
            }
        }
        SwRow { label: "Mostrar siempre los 9"; sub: "si no, solo los espacios con ventanas y el activo"; key: "wsShowAll"; def: true }
    }

    // Nombres e iconos de los espacios 1–10 (wsNames, wsIcons, wsBarNames) · ui/WsNames.qml
    WsNames { Layout.fillWidth: true }

    Section {
        Layout.fillWidth: true
        title: "Escritorio, iconos y widgets"
        LabeledRow {
            label: "Iconos del escritorio"
            labelWidth: 150
            Seg {
                model: [["todos", "Iconos clásicos"], ["ordenado", "Escritorio ordenado por grupos"], ["no", "Ocultar"]]
                current: root.deskIcons
                onPicked: k => Settings.set("deskIcons", k)
            }
        }
        LabeledRow {
            label: "Tamaño de los iconos"
            labelWidth: 150
            opacity: root.deskIcons === "todos" ? 1 : 0.45
            Pills {
                model: [["pequeno", "Pequeño"], ["mediano", "Mediano"], ["grande", "Grande"]]
                current: Settings.get("deskIconSize", "mediano")
                onPicked: k => Settings.set("deskIconSize", k)
            }
        }
        Txt {
            Layout.fillWidth: true
            text: "Muestra lo que hay en tu carpeta Escritorio. Doble clic abre · clic derecho lo muestra en la carpeta."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        LabeledRow {
            label: "Ordenar el escritorio"
            labelWidth: 150
            visible: root.deskIcons === "ordenado"
            Seg { model: [["tipo", "Por tipo"], ["fecha", "Por fecha"], ["nombre", "Por nombre"]]; current: Settings.get("deskSort", "tipo"); onPicked: k => Settings.set("deskSort", k) }
        }
        // Los widgets ya no van sobre el escritorio: se abren como ventanas desde sus chips de la barra (Ajustes › Barra)
        LinkRow { label: "Widgets (clima, sistema, impresora)"; section: "barra"; sectionLabel: "Barra"; target: "Clima"; value: "ventanas desde la barra · Super + G" }
        LabeledRow {
            label: "Ciudad del clima"
            labelWidth: 150
            hint: "vacío = por IP"
            Field { Layout.preferredWidth: 260; h: 32; icon: ""; placeholder: "Lima"; text: Settings.get("weatherCity", ""); input.onEditingFinished: Settings.set("weatherCity", text.trim()) }
        }
        LabeledRow {
            label: "Impresora 3D"
            labelWidth: 150
            hint: "Moonraker / OctoPrint"
            Field { Layout.preferredWidth: 260; h: 32; icon: ""; placeholder: "http://impresora.local"; text: Settings.get("printerUrl", ""); input.onEditingFinished: Settings.set("printerUrl", text.trim()) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Esquinas calientes"
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 210
                radius: Theme.r(8)
                color: Theme.bg
                border.width: 1
                border.color: Theme.ov
                Txt { anchors.centerIn: parent; muted: true; size: 11.5; horizontalAlignment: Text.AlignHCenter; text: "Lleva el cursor a una esquina\npara lanzar su acción" }
                Repeater {
                    model: ["tl", "tr", "bl", "br"]
                    Rectangle {
                        id: cc
                        required property string modelData
                        readonly property string act: root.corners[modelData] ?? "ninguna"
                        width: 170; height: 52
                        radius: Theme.r(6)
                        x: modelData[1] === "l" ? 10 : parent.width - width - 10
                        y: modelData[0] === "t" ? 10 : parent.height - height - 10
                        color: act !== "ninguna" ? Theme.selBg : Theme.s4
                        border.width: 1; border.color: Theme.ov
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 0
                            Txt { text: ({ tl: "↖ Arriba izquierda", tr: "↗ Arriba derecha", bl: "↙ Abajo izquierda", br: "↘ Abajo derecha" })[cc.modelData]; size: 10.5; muted: true }
                            Dropdown {
                                Layout.fillWidth: true
                                flat: true; h: 22
                                model: root.actions
                                current: cc.act
                                popupWidth: 200
                                onPicked: k => root.setCorner(cc.modelData, k)
                            }
                        }
                    }
                }
            }
            LabeledRow {
                label: "Tiempo de espera"; labelWidth: 110
                Seg {
                    model: [[1, "Al instante"], [150, "150 ms"], [300, "300 ms"], [500, "500 ms"]]
                    current: Settings.get("hotCornerDelay", 150)
                    onPicked: k => Settings.set("hotCornerDelay", k)
                }
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Gestos del touchpad"
            Repeater {
                model: [
                    { key: "gesture3h", fingers: "3 dedos", dir: "← →", fixed: "Cambiar de espacio" },
                    { key: "gesture3Up", fingers: "3 dedos", dir: "↑", def: "vista" },
                    { key: "gesture3Down", fingers: "3 dedos", dir: "↓", def: "escritorio" },
                    { key: "gesture4Up", fingers: "4 dedos", dir: "↑", def: "spotlight" },
                    { key: "gesture4Down", fingers: "4 dedos", dir: "↓", def: "ninguna" }
                ]
                Item {
                    id: g
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 40
                    Rectangle { visible: g.index > 0; width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        Rectangle { implicitWidth: 64; implicitHeight: 24; radius: 12; color: Theme.s4; Txt { anchors.centerIn: parent; text: g.modelData.fingers; size: 11.5; weight: Font.DemiBold } }
                        Txt { Layout.preferredWidth: 34; text: g.modelData.dir; size: 15; horizontalAlignment: Text.AlignHCenter }
                        Item { Layout.fillWidth: true }
                        Txt { visible: !!g.modelData.fixed; text: g.modelData.fixed ?? ""; weight: Font.Medium }
                        Dropdown {
                            visible: !g.modelData.fixed
                            flat: true
                            Layout.preferredWidth: 190
                            model: root.actions
                            current: Settings.get(g.modelData.key, g.modelData.def)
                            onPicked: k => Settings.set(g.modelData.key, k)
                        }
                    }
                }
            }
            RowLayout {
                Layout.topMargin: 4
                spacing: 4
                Txt { text: "Tocar para clic y velocidad:"; muted: true; size: 11.5 }
                Button { kind: "link"; text: "Ratón y panel táctil"; onClicked: Shell.open("ajustesapp", "raton") }
            }
        }
    }
    Section {
        Layout.fillWidth: true
        title: "Diseño de mosaico"
        headerRight: Mono { text: "general:layout = " + WinMode.layoutFor(root.winMode) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            opacity: root.winMode === "desplazamiento" ? 0.45 : 1
            Repeater {
                model: [["dwindle", "Dwindle", "Cada ventana nueva divide a la anterior"], ["master", "Master", "Una ventana principal y una pila al lado"]]
                Card {
                    required property var modelData
                    title: modelData[1]; sub: modelData[2]
                    selected: WinMode.tiledLayout === modelData[0]
                    onClicked: Settings.set("layout", modelData[0])
                }
            }
        }
        Txt {
            Layout.fillWidth: true
            visible: root.winMode === "desplazamiento"
            text: "Se usa en el modo Mosaico (y en los espacios a los que des ese modo); ahora estás en Desplazamiento."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        SwRow { label: "Enfocar al pasar el cursor"; sub: "input:follow_mouse = " + (Settings.get("focusOnHover", true) ? 1 : 0); mono: true; key: "focusOnHover"; def: true }
        SwRow { label: "Acoplar al arrastrar a los bordes"; sub: "general:snap:enabled · ventanas flotantes"; mono: true; key: "snapEdges"; def: true }
    }
    Section {
        Layout.fillWidth: true
        title: "Desplazamiento"
        headerRight: Mono { text: "scrolling:column_width = " + Settings.get("scrollColumnWidth", 0.5) }
        LabeledRow {
            label: "Ancho de una columna nueva"
            labelWidth: 190
            Pills {
                model: [[0.333, "⅓"], [0.5, "½"], [0.667, "⅔"], [1.0, "Completa"]]
                current: Settings.get("scrollColumnWidth", 0.5)
                onPicked: k => Settings.set("scrollColumnWidth", k)
            }
        }
        LabeledRow {
            label: "Al enfocar una columna"
            labelWidth: 190
            Seg {
                model: [["ajustar", "Traerla justo a la vista"], ["centrar", "Centrarla"]]
                current: Settings.get("scrollFocusFit", "ajustar")
                onPicked: k => Settings.set("scrollFocusFit", k)
            }
        }
        SwRow { label: "Una sola columna ocupa toda la pantalla"; sub: "scrolling:fullscreen_on_one_column"; mono: true; key: "scrollOneFull"; def: true }
        Txt {
            Layout.fillWidth: true
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Super + ñ / ´ pasa la columna activa por ⅓, ½, ⅔ y toda la pantalla · Super + Alt + J saca la ventana a una columna propia · "
                + "Super + Ctrl + rueda cambia de espacio. En la vista general (Super + Tab) se ve la cinta entera."
        }
    }
}
