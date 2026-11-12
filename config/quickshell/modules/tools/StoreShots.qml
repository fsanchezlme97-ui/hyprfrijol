// Carrusel de capturas de la ficha de una app (Centro de aplicaciones): flechas, puntos, rueda y arrastre.
// Las imágenes se cargan en segundo plano desde Flathub (o el metainfo local) con su marcador y error en español.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Rectangle {
    id: sh
    property var model: []
    property bool loading: false
    property string emptyText: "Esta app no tiene capturas publicadas"
    radius: Theme.r(8)
    color: Theme.s3
    border.width: 1
    border.color: Theme.ov
    clip: true

    ListView {
        id: lv
        anchors.fill: parent
        anchors.margins: 1
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Theme.still ? 0 : 320
        boundsBehavior: Flickable.StopAtBounds
        model: sh.model
        clip: true
        delegate: Item {
            id: d
            required property var modelData
            required property int index
            width: lv.width
            height: lv.height
            Image {
                id: im
                anchors.fill: parent
                anchors.margins: 14
                anchors.bottomMargin: d.modelData.caption ? 34 : 14
                source: d.modelData.src
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
                // no decodificar a tamaño completo capturas de 4K
                sourceSize.width: Math.min(1600, Math.max(400, width * 1.5))
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: im.status !== Image.Ready
                spacing: 8
                BusyIndicator { Layout.alignment: Qt.AlignHCenter; visible: im.status === Image.Loading; running: visible; implicitWidth: 28; implicitHeight: 28 }
                Txt { Layout.alignment: Qt.AlignHCenter; muted: true; size: 12
                    text: im.status === Image.Error ? "No se pudo cargar la captura" : im.status === Image.Loading ? "Cargando captura… " + Math.round(im.progress * 100) + " %" : "" }
            }
            Txt {
                visible: !!d.modelData.caption
                anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 120
                horizontalAlignment: Text.AlignHCenter
                text: d.modelData.caption ?? ""
                muted: true; size: 11.5
            }
        }
    }
    // Sin capturas / cargando
    ColumnLayout {
        anchors.centerIn: parent
        visible: lv.count === 0
        spacing: 8
        BusyIndicator { Layout.alignment: Qt.AlignHCenter; visible: sh.loading; running: visible; implicitWidth: 28; implicitHeight: 28 }
        Txt { Layout.alignment: Qt.AlignHCenter; muted: true; text: sh.loading ? "Buscando capturas…" : sh.emptyText }
    }
    // Flechas
    Repeater {
        model: [-1, 1]
        Rectangle {
            required property int modelData
            visible: lv.count > 1 && (modelData < 0 ? lv.currentIndex > 0 : lv.currentIndex < lv.count - 1)
            anchors.verticalCenter: parent.verticalCenter
            x: modelData < 0 ? 12 : parent.width - width - 12
            width: 36; height: 36; radius: Theme.ctl(36)
            color: am.containsMouse ? Theme.s1 : Qt.alpha(Theme.s1, 0.85)
            border.width: 1; border.color: Theme.ov
            Txt { anchors.centerIn: parent; text: parent.modelData < 0 ? "‹" : "›"; size: 20; weight: Font.DemiBold }
            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: lv.currentIndex = Math.max(0, Math.min(lv.count - 1, lv.currentIndex + parent.modelData)) }
        }
    }
    // Puntos
    Row {
        visible: lv.count > 1
        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 14
        spacing: 5
        Repeater {
            model: lv.count
            Rectangle {
                required property int index
                width: index === lv.currentIndex ? 16 : 6; height: 6; radius: 3
                color: index === lv.currentIndex ? Theme.p : Theme.o
                Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: lv.currentIndex = parent.index }
            }
        }
    }
    function step(n: int): void { lv.currentIndex = Math.max(0, Math.min(lv.count - 1, lv.currentIndex + n)); }
}
