// Compatibilidad con Omarchy · qs.Ui.BarIconContent: icono propio (Component) de un botón de barra.
import QtQuick

Item {
    id: root
    property Component sourceComponent: null
    property real sourceSize: 16
    readonly property real paintedWidth: loader.item ? Math.min(width, loader.item.implicitWidth || width) : 0
    readonly property real paintedHeight: loader.item ? Math.min(height, loader.item.implicitHeight || height) : 0
    readonly property rect sourceBounds: Qt.rect(0, 0, paintedWidth, paintedHeight)
    Loader { id: loader; anchors.centerIn: parent; width: root.sourceSize; height: root.sourceSize; sourceComponent: root.sourceComponent }
}
