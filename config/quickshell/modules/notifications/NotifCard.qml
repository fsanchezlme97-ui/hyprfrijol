// Tarjeta de notificación.
//  toast: aviso emergente (Glass, baldosa 28, ×, respuesta y botones de acción) — design «Notificaciones»
//  list:  elemento del centro / ajustes rápidos (fondo fill2, baldosa 26, hora a la derecha)
// stack > 0: hay más avisos de la misma app debajo → se pintan 1–2 capas detrás y la pastilla «+N»
//            (clic → stackToggled(), para desplegar el grupo).
// Arrastrar a un lado descarta el aviso (swipe). Urgente: borde y etiqueta «Urgente»; no se cierra solo.
// Imagen de contenido (capturas, fotos…): se ve en grande bajo el texto (Notifs.previewOf).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../.."
import "../../components"

Item {
    id: root
    required property var n
    property string mode: "toast"
    property int stack: 0                 // avisos de la misma app que quedan debajo
    property bool showApp: true           // «App · resumen» (en un grupo con cabecera basta el resumen)
    signal stackToggled()
    readonly property bool toast: mode === "toast"
    readonly property bool critical: Notifs.isCritical(n)
    readonly property var extraActions: (n?.actions ?? []).filter(a => a.identifier !== "default" && a.identifier !== "inline-reply")
    readonly property bool hovered: hover.hovered || drag.active
    readonly property string preview: Notifs.previewOf(n)
    readonly property real ghost: stack <= 0 ? 0 : stack === 1 ? 6 : 11
    implicitHeight: col.implicitHeight + 20 + ghost

    HoverHandler { id: hover }

    // ---- capas de la pila (asoman por debajo de la tarjeta)
    Repeater {
        model: Math.min(2, root.stack)
        Item {
            required property int index
            readonly property real inset: (index + 1) * 9
            y: face.height; width: root.width; height: root.ghost
            clip: true
            z: -1 - index
            opacity: (index === 0 ? 0.8 : 0.5) * face.opacity
            Item {
                x: parent.inset; width: root.width - parent.inset * 2
                y: (parent.index + 1) * 5.5 - 40; height: 40
                Glass { anchors.fill: parent; visible: root.toast; kind: "panel"; shadow: false }
                Rectangle { anchors.fill: parent; visible: !root.toast; radius: Theme.r(6); color: Theme.fill2; border.width: 1; border.color: Theme.ov }
            }
        }
    }

    // ---- la tarjeta (se arrastra)
    Item {
        id: face
        width: root.width
        height: root.height - root.ghost
        opacity: 1 - Math.min(0.85, Math.abs(x) / width)
        Behavior on x { enabled: !drag.active; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

        DragHandler {
            id: drag
            target: face
            yAxis.enabled: false
            xAxis.minimum: -root.width; xAxis.maximum: root.width
            onActiveChanged: if (!active) {
                if (Math.abs(face.x) > root.width * 0.32) { face.x = face.x > 0 ? root.width : -root.width; gone.start(); }
                else face.x = 0;
            }
        }
        Timer { id: gone; interval: Theme.dur; onTriggered: Notifs.dismiss(root.n) }

        Glass {
            anchors.fill: parent
            visible: root.toast
            kind: "panel"
        }
        Rectangle {
            anchors.fill: parent
            visible: !root.toast
            radius: Theme.r(6)
            color: Theme.fill2
        }
        Rectangle {   // urgente: borde de aviso
            anchors.fill: parent
            visible: root.critical
            radius: root.toast ? Theme.panelRadius : Theme.r(6)
            color: "transparent"
            border.width: 1
            border.color: Theme.danger
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.activate(root.n)
        }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: root.toast ? 12 : 10
            anchors.rightMargin: 10
            anchors.topMargin: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                NotifTile {
                    Layout.alignment: Qt.AlignTop
                    n: root.n
                    size: root.toast ? 28 : 26
                    radius: root.toast ? 7 : 8
                    avatar: root.preview === ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Txt {
                            Layout.fillWidth: true
                            text: {
                                const a = root.n?.appName ?? "", s = root.n?.summary ?? "";
                                if (!root.showApp) return s || a || "Notificación";
                                return a && s && a !== s ? a + " · " + s : (s || a || "Notificación");
                            }
                            weight: Font.DemiBold
                        }
                        Rectangle {   // «Urgente»
                            visible: root.critical
                            implicitHeight: 16; implicitWidth: urgT.implicitWidth + 10; radius: Theme.r(4)
                            color: Qt.alpha(Theme.danger, 0.16)
                            Txt { id: urgT; anchors.centerIn: parent; text: "Urgente"; size: 10; weight: Font.DemiBold; color: Theme.danger }
                        }
                        Rectangle {   // «+N» de la pila (en el centro lo dice la cabecera del grupo)
                            visible: root.stack > 0 && root.toast
                            implicitHeight: 18; implicitWidth: stT.implicitWidth + 12; radius: 9
                            color: stMa.containsMouse ? Theme.pc : Theme.s1
                            border.width: 1; border.color: Theme.ov
                            Txt { id: stT; anchors.centerIn: parent; text: "+" + root.stack; size: 10.5; weight: Font.DemiBold; tabular: true
                                  color: stMa.containsMouse ? Theme.pcText : Theme.t }
                            MouseArea { id: stMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stackToggled() }
                        }
                        Txt {   // el mismo aviso repetido (Notifs.repeats)
                            readonly property int times: Notifs.repeats[root.n?.id] ?? 1
                            visible: times > 1
                            text: "×" + times; size: 11; weight: Font.DemiBold; muted: true; tabular: true
                        }
                        Txt { text: Notifs.ago(root.n); size: 11; muted: true; tabular: true }
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.n?.body ?? ""
                        textFormat: Text.StyledText
                        muted: true
                        wrapMode: Text.Wrap
                        maximumLineCount: root.toast ? 4 : 3
                        lineHeight: 1.15
                        onLinkActivated: l => Qt.openUrlExternally(l)
                    }
                }
                IconBtn {
                    Layout.alignment: Qt.AlignTop
                    opacity: root.toast || hover.hovered ? 1 : 0
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Theme.r(5)
                    icon: "x"
                    iconSize: 12
                    fg: Theme.tv
                    tooltip: "Descartar"
                    onClicked: Notifs.dismiss(root.n)
                }
            }
            // Imagen de contenido
            Rectangle {
                visible: root.preview !== "" && pv.status === Image.Ready
                Layout.fillWidth: true
                Layout.leftMargin: root.toast ? 38 : 36
                Layout.preferredHeight: visible ? Math.min(120, Math.max(60, width * pv.implicitHeight / Math.max(1, pv.implicitWidth))) : 0
                radius: Theme.r(7)
                color: Theme.s1
                clip: true
                Image {
                    id: pv
                    anchors.fill: parent
                    source: root.preview
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 640
                    layer.enabled: true
                    layer.smooth: true
                }
                Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: Theme.ov }
            }
            ReplyField {
                Layout.fillWidth: true
                visible: root.n?.hasInlineReply ?? false
                n: root.n
                compact: !root.toast
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.extraActions.length > 0
                spacing: 6
                Repeater {
                    model: root.extraActions.slice(0, 3)
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: root.toast ? 28 : 26
                        radius: Theme.r(6)
                        color: index === 0 ? Theme.p : root.toast ? Theme.fill2 : Qt.alpha(Theme.t, 0.08)
                        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.light ? "#000" : "#FFF"; opacity: actMa.containsMouse ? 0.08 : 0 }
                        Txt {
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 12)
                            text: parent.modelData.text
                            color: parent.index === 0 ? Theme.pText : Theme.t
                            weight: Font.Medium
                        }
                        MouseArea {
                            id: actMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // invoke() puede cerrar el aviso y destruir esta tarjeta: se guardan antes las referencias
                            onClicked: { const n = root.n, act = parent.modelData; act.invoke(); Notifs.hidePopup(n); }
                        }
                    }
                }
            }
        }
    }
}
