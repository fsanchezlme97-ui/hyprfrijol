// Separador fino (c.ov) — vertical en barras, horizontal en listas
import QtQuick
import ".."

Rectangle {
    property bool vertical: true
    implicitWidth: vertical ? 1 : 100
    implicitHeight: vertical ? 14 : 1
    color: Theme.ov
}
