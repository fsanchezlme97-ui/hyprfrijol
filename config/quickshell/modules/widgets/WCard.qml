// Tarjeta de widget (vidrio, padding 14, contorno discontinuo al editar).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Glass {
    id: card
    property bool editing: false
    property real pad: 14
    default property alias body: inner.data
    property alias spacing: inner.spacing
    property bool clickable: false
    signal clicked()
    kind: "panel"
    implicitHeight: inner.implicitHeight + pad * 2
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    MouseArea {
        anchors.fill: parent
        visible: card.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }
    ColumnLayout {
        id: inner
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.pad }
        spacing: 12
    }
    Canvas {
        anchors.fill: parent
        anchors.margins: -3
        visible: card.editing
        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.strokeStyle = Qt.alpha(Theme.p, 0.8); g.lineWidth = 1.5; g.setLineDash([5, 3]);
            g.beginPath(); g.roundedRect(1, 1, width - 2, height - 2, Theme.panelRadius + 3, Theme.panelRadius + 3); g.stroke();
        }
    }
}
