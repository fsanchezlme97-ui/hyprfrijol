// Iconos del escritorio clásicos (ajuste "deskIcons" = "todos"): los archivos de xdg-user-dir DESKTOP sobre el
// fondo, en la capa inferior (debajo de las ventanas), en columnas desde arriba a la izquierda.
// Iconos reales del tema (mime / .desktop), miniaturas para imágenes, nombre con sombra suave.
// Clic: seleccionar · doble clic: abrir (xdg-open) · clic derecho: mostrar en la carpeta.
// Tamaño: ajuste "deskIconSize" (pequeno / mediano / grande).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"

PanelWindow {
    id: win
    required property var desk          // el Scope de Desktop.qml (files, openFile, reveal, iconFor…)
    property bool shown: false
    // Hueco a la izquierda para el dock cuando no reserva su franja (Dock.qml en modo auto / inteligente)
    property int leftReserve: 0
    property int bottomReserve: 0       // lo mismo con el dock abajo
    // Hueco a la derecha para los widgets del escritorio (Widgets.qml: 312 + 24)
    readonly property int rightReserve: 0      // (los widgets ya no ocupan la derecha del escritorio)

    readonly property string sizeKey: Settings.get("deskIconSize", "mediano")
    readonly property int iconSize: sizeKey === "pequeno" ? 40 : sizeKey === "grande" ? 64 : 50
    readonly property int cellW: iconSize + (sizeKey === "pequeno" ? 44 : 52)
    readonly property int cellH: iconSize + 50
    readonly property int pad: 14

    readonly property int rows: Math.max(1, Math.floor((height - pad * 2) / cellH))
    readonly property int maxCols: Math.max(1, Math.floor(((screen?.width ?? 1440) - rightReserve - pad * 2) * 0.6 / cellW))
    readonly property int capacity: rows * maxCols
    readonly property var items: {
        const f = desk.sortedFiles;
        if (f.length <= capacity) return f;
        return f.slice(0, capacity - 1).concat([{ more: true, count: f.length - capacity + 1 }]);
    }
    readonly property int cols: Math.max(1, Math.ceil(items.length / rows))

    property string selected: ""

    visible: shown && desk.files.length > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "hf-deskicons"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true }
    margins.left: leftReserve
    margins.bottom: bottomReserve
    implicitWidth: cols * cellW + pad * 2
    mask: Region { item: grid }
    onShownChanged: if (!shown) selected = ""

    Item {
        id: grid
        x: win.pad; y: win.pad
        width: win.cols * win.cellW
        height: Math.min(win.items.length, win.rows) * win.cellH
        // Clic en un hueco: quita la selección
        MouseArea { anchors.fill: parent; onClicked: win.selected = "" }

        Repeater {
            model: win.items
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool more: !!modelData.more
                readonly property bool sel: !more && win.selected === modelData.path
                readonly property bool hot: ma.containsMouse
                readonly property bool thumb: !more && cell.modelData.thumb === true
                x: Math.floor(index / win.rows) * win.cellW
                y: (index % win.rows) * win.cellH
                width: win.cellW
                height: win.cellH
                z: hot || sel ? 2 : 1

                // Fondo de hover / selección (crece con la etiqueta si se despliega)
                Rectangle {
                    x: 3; y: 2
                    width: parent.width - 6
                    height: Math.max(parent.height - 4, label.y + label.height + 6 - y)
                    radius: Theme.r(8)
                    color: cell.sel ? Qt.alpha(Theme.p, 0.32) : Qt.alpha("#ffffff", 0.14)
                    border.width: cell.sel ? 1 : 0
                    border.color: Qt.alpha(Theme.p, 0.85)
                    opacity: cell.sel || cell.hot ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                }

                Item {
                    id: art
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: win.iconSize; height: win.iconSize
                    scale: ma.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(90); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.45)
                        shadowBlur: 0.5
                        shadowVerticalOffset: 2
                    }

                    // Miniatura de imagen (con marco blanco, como una foto)
                    Rectangle {
                        visible: cell.thumb && thumbImg.status === Image.Ready
                        anchors.centerIn: parent
                        width: thumbImg.paintedWidth + 4; height: thumbImg.paintedHeight + 4
                        radius: Theme.r(3)
                        color: "#ffffff"
                    }
                    Image {
                        id: thumbImg
                        visible: cell.thumb && status === Image.Ready
                        anchors.fill: parent
                        anchors.margins: 3
                        source: cell.thumb ? win.desk.fileUrl(cell.modelData.path) : ""
                        sourceSize: Qt.size(win.iconSize * 2, win.iconSize * 2)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true; mipmap: true
                    }
                    // Icono del tema
                    Image {
                        id: themeIcon
                        visible: !cell.more && (!cell.thumb || thumbImg.status === Image.Error) && status === Image.Ready
                        anchors.fill: parent
                        source: cell.more ? "" : win.desk.iconFor(cell.modelData)
                        sourceSize: Qt.size(win.iconSize * 2, win.iconSize * 2)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true; mipmap: true
                    }
                    // Sin icono en el tema: icono del diseño
                    Rectangle {
                        visible: cell.more || (!themeIcon.visible && !thumbImg.visible)
                        anchors.centerIn: parent
                        width: win.iconSize * 0.84; height: win.iconSize * 0.84
                        radius: width * 0.22
                        color: cell.more ? Qt.alpha(Theme.s3, 0.85) : Theme.s4
                        Icon {
                            anchors.centerIn: parent
                            visible: !cell.more
                            name: cell.modelData.dir ? "folder" : "file"
                            size: win.iconSize * 0.46
                            color: Theme.t
                        }
                        Txt {
                            anchors.centerIn: parent
                            visible: cell.more
                            text: "+" + (cell.modelData.count ?? 0)
                            size: win.iconSize * 0.3; weight: Font.DemiBold
                        }
                    }
                }

                // Nombre: 2 líneas; completo al pasar el ratón o seleccionado
                Text {
                    id: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: art.y + art.height + 6
                    width: parent.width - 10
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.more ? "Más en la carpeta" : cell.modelData.label
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: cell.hot || cell.sel ? 5 : 2
                    elide: Text.ElideRight
                    color: "#ffffff"   // sobre el fondo de pantalla, como en cualquier escritorio
                    font.family: Theme.font
                    font.pixelSize: Theme.px(win.sizeKey === "grande" ? 12.5 : 11.5)
                    font.weight: Font.DemiBold
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                    lineHeight: 0.95
                    renderType: Text.NativeRendering
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 1)
                        shadowBlur: 0.45
                        shadowScale: 1.04
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 1
                        blurMax: 10
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (cell.more) { win.desk.openFile({ path: win.desk.deskDir }); return; }
                        if (e.button === Qt.RightButton) win.desk.reveal(cell.modelData);
                        else win.selected = cell.modelData.path;
                    }
                    onDoubleClicked: e => { if (!cell.more && e.button === Qt.LeftButton) win.desk.openFile(cell.modelData); }
                }
            }
        }
    }
}
