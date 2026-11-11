// Base de los chips de widgets de la barra (clima, sistema, impresora): fondo al pasar el cursor, resaltado
// mientras su ventana está abierta y clic → abre su ventana flotante pegada al chip (modules/widgets/ChipPopup).
//   BarChip { popup: "w-clima"; vertical: false; … contenido … }
import QtQuick
import QtQuick.Window
import ".."

Rectangle {
    id: chip
    property string popup: ""
    property bool vertical: false
    property bool want: true             // la barra lo enseña (el Loader mira esto: visible daría un bucle)
    readonly property bool open: popup !== "" && Shell.view === popup
    readonly property bool hovered: ma.containsMouse
    signal rightClicked()
    radius: Theme.r(7)
    color: open ? Theme.fill2 : ma.containsMouse ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    // Centro del chip a lo largo de la barra, en px de la pantalla (la ventana de la barra empieza a barOffset del borde)
    function anchorArg(): var {
        const p = chip.mapToItem(null, chip.width / 2, chip.height / 2);
        return { chip: true, c: Settings.barOffset + (Settings.barVertical ? p.y : p.x), screen: chip.Window.window?.screen?.name ?? "" };
    }
    function toggle(): void {
        if (open) Shell.close();
        else Shell.open(popup, anchorArg());
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: if (chip.popup) Shell.preload(chip.popup)     // carga diferida: crear su ventana mientras llega el clic
        onClicked: e => e.button === Qt.RightButton ? chip.rightClicked() : chip.toggle()
    }
}
