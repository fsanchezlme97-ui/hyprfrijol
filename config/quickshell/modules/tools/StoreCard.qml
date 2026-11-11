// Tarjeta de una app en el Centro de aplicaciones: icono, nombre, fuente (insignia con color y tooltip), descripción,
// compatibilidad y acciones. Pulsar la tarjeta abre la ficha de la app; la casilla la marca para instalar.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../settings/ui"

Item {
    id: card
    property var tool: ({})
    property var store: null            // el Scope de Tools.qml (sel, toggle, openDetail, iconOf)
    readonly property bool inst: Pkg.isToolInstalled(tool)
    readonly property bool on: !!store?.sel[tool.id] && !inst
    readonly property var upd: inst ? Pkg.updateFor(tool) : null
    readonly property string compat: tool.preview ? "Nativa · no oficial" : tool.alpha ? "Por verificar" : tool.web ? "Navegador" : tool.term ? "Terminal" : tool.xw ? "XWayland" : "Wayland"
    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: 6
        anchors.bottomMargin: 6
        radius: Theme.r(6)
        color: card.on ? Qt.alpha(Theme.p, 0.10) : cardMa.containsMouse ? Qt.tint(Theme.s3, Qt.alpha(Theme.t, 0.04)) : Theme.s3
        border.width: 1
        border.color: card.on ? Theme.p : cardMa.containsMouse ? Theme.o : Theme.ov
        Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        MouseArea { id: cardMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.store.openDetail(card.tool) }
        RowLayout {
            anchors.fill: parent; anchors.margins: 12
            spacing: 12
            StoreIcon { Layout.alignment: Qt.AlignTop; tool: card.tool; store: card.store; size: 40 }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Txt { id: nm; text: card.tool.name; weight: Font.DemiBold; size: 13; Layout.fillWidth: true; Layout.maximumWidth: tm.advanceWidth + 2; elide: Text.ElideRight
                        TextMetrics { id: tm; font: nm.font; text: nm.text } }
                    Txt { visible: card.tool.star; text: "★"; size: 11; color: Theme.ter }
                    Item { Layout.fillWidth: true }
                    StoreBadge { tool: card.tool }
                    StoreCheck { visible: !card.inst; on: card.on; onClicked: card.store.toggle(card.tool.id) }
                }
                Txt { Layout.fillWidth: true; Layout.fillHeight: true; text: card.tool.desc; muted: true; size: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; verticalAlignment: Text.AlignTop; lineHeight: 1.05 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: [card.inst ? ["INSTALADA", Theme.sc, Theme.scText] : null, card.upd ? ["ACTUALIZACIÓN", Theme.p, Theme.pText] : null, !card.inst && card.tool.isNew ? ["NUEVO", Theme.pc, Theme.pcText] : null, card.tool.alpha ? ["ALFA", Theme.ter, Theme.bg] : null, card.tool.preview ? ["PREVIEW", Theme.ter, Theme.bg] : null].filter(Boolean)
                        Rectangle {
                            required property var modelData
                            implicitWidth: bt.implicitWidth + 10; implicitHeight: 16; radius: Theme.r(3)
                            color: modelData[1]
                            Txt { id: bt; anchors.centerIn: parent; text: parent.modelData[0]; size: 9.5; weight: Font.Bold; color: parent.modelData[2] }
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        size: 11
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        color: Theme.tv
                        text: "<b><font color='" + (card.tool.xw || card.tool.preview ? Theme.ter : card.tool.alpha ? Theme.tv : Theme.p) + "'>" + card.compat + "</font></b>"
                            + (!card.tool.alt || card.tool.alt === "—" ? "" : "  ·  alt. a " + card.tool.alt)
                    }
                    StoreBtn { visible: !!card.upd; primary: true; text: "Actualizar"; onClicked: Pkg.update(card.tool) }
                    StoreBtn { visible: card.inst && (!!Pkg.entryOf(card.tool) || !!card.tool.bin); text: "Abrir"; onClicked: Pkg.launch(card.tool) }
                    StoreBtn { visible: card.inst && Pkg.uninstallCmd(card.tool) !== ""; danger: true; text: "Desinstalar"; onClicked: Pkg.uninstall(card.tool) }
                }
            }
        }
    }
}
