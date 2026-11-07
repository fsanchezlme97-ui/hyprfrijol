// Compatibilidad con Omarchy · qs.Ui.PanelHero: cabecera de panel con icono, título, meta y detalle.
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property Component iconComponent: null
    property string title: ""
    property string meta: ""
    property string detail: ""
    property color foreground: Commons.Color.foreground
    property string fontFamily: Style.font.family
    property real iconSize: Style.font.display
    property real iconOpacity: 1.0
    property alias metaOpacity: metaText.opacity
    property Component trailingControl: null
    readonly property color dim: Qt.darker(foreground, 1.4)
    readonly property real trailingInset: trailingLoader.item && trailingLoader.item.visible ? trailingLoader.width + Style.space(12) : 0
    implicitWidth: 260
    implicitHeight: Math.max(iconBox.height, texts.implicitHeight)
    Loader { id: iconBox; width: root.iconComponent ? root.iconSize : 0; height: root.iconSize; anchors.verticalCenter: parent.verticalCenter; sourceComponent: root.iconComponent; opacity: root.iconOpacity }
    Column {
        id: texts
        anchors.left: iconBox.right
        anchors.leftMargin: root.iconComponent ? Style.space(12) : 0
        anchors.right: parent.right
        anchors.rightMargin: root.trailingInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text { width: parent.width; text: root.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true }
        Text { id: metaText; width: parent.width; visible: root.meta !== ""; text: root.meta; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Text { width: parent.width; visible: root.detail !== ""; text: root.detail; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    }
    Loader { id: trailingLoader; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; sourceComponent: root.trailingControl }
}
