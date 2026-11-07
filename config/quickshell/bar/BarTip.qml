// Globo de ayuda de un botón de la barra: una ventana emergente pegada al botón, hacia dentro de la pantalla.
//   MouseArea { id: ma; hoverEnabled: true }   BarTip { target: ma; text: "Aplicaciones" }
import QtQuick
import Quickshell
import ".."
import "../components"

PopupWindow {
    id: tip
    required property Item target
    property string text: ""
    readonly property string side: Settings.barPos
    readonly property bool want: (target?.containsMouse ?? false) && !(target?.pressed ?? false)
    onWantChanged: want ? delay.restart() : (delay.stop(), shown = false)
    property bool shown: false
    Timer { id: delay; interval: 450; onTriggered: tip.shown = true }

    anchor.item: target
    anchor.edges: side === "abajo" ? Edges.Top : side === "arriba" ? Edges.Bottom : side === "izquierda" ? Edges.Right : Edges.Left
    anchor.gravity: anchor.edges
    // márgenes negativos = el globo se separa 8 px del botón
    anchor.margins.top: side === "abajo" ? -8 : 0
    anchor.margins.bottom: side === "arriba" ? -8 : 0
    anchor.margins.left: side === "derecha" ? -8 : 0
    anchor.margins.right: side === "izquierda" ? -8 : 0
    visible: shown && text !== ""
    color: "transparent"
    implicitWidth: lbl.implicitWidth + 18
    implicitHeight: 26
    mask: Region {}
    Rectangle {
        anchors.fill: parent
        radius: Theme.r(6)
        color: Theme.glassPopup
        border.width: 1
        border.color: Theme.border
        Txt { id: lbl; anchors.centerIn: parent; text: tip.text; size: 11.5 }
    }
}
