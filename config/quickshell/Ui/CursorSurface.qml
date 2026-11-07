// Compatibilidad con Omarchy · qs.Ui.CursorSurface: fondo de una fila con el cursor del teclado/ratón.
import QtQuick
import qs.Commons
import qs.Commons as Commons

BorderSurface {
    id: root
    property bool hasCursor: false
    property bool current: false
    property bool outline: false
    property bool bordered: false
    property color foreground: Commons.Color.foreground
    property color accent: Commons.Color.accent
    property color fill: Style.hoverFillFor(foreground, accent)
    property color currentFill: Style.selectedFillFor(foreground, accent)
    radius: Style.cornerRadius
    color: hasCursor ? fill : current ? currentFill : "transparent"
    borderSpec: hasCursor ? Border.controlSpec("hover-cursor", foreground, accent)
        : current ? Border.controlSpec("selected", foreground, accent)
        : bordered ? Border.controlSpec("normal", foreground, accent) : Border.none()
    Behavior on color { ColorAnimation { duration: Style.duration(60) } }
}
