// Tarjeta con muestra de un modo de ventanas (Ajustes › Escritorio › Modo de ventanas): una pantalla en
// miniatura con las ventanas como las coloca ese modo, el nombre y una línea de ayuda; anillo c.p si está elegido.
//   WinModePreview { mode: "mosaico" | "desplazamiento" | "flotante"; title; sub; selected; onClicked }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property string mode: "mosaico"
    property string title: ""
    property string sub: ""
    property bool selected: false
    signal clicked()
    Layout.fillWidth: true
    implicitWidth: 160
    implicitHeight: col.implicitHeight + 20
    radius: Theme.r(8)
    color: selected ? Theme.selBg : ma.containsMouse ? Qt.alpha(Theme.t, 0.04) : "transparent"
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.p : Theme.ov
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    // Ventana de muestra: barra de título con tres puntos y dos líneas de texto
    component Win: Rectangle {
        property bool active: false
        radius: Theme.r(4)
        color: active ? Theme.s1 : Theme.s3
        border.width: 1
        border.color: active ? Qt.alpha(Theme.p, 0.75) : Qt.alpha(Theme.ov, 0.5)
        clip: true
        Rectangle { x: 5; y: 5; width: Math.min(parent.width * 0.5, 28); height: 3; radius: 1.5; color: Theme.tv; opacity: 0.5 }
        Rectangle { x: 5; y: 11; width: parent.width * 0.62; height: 3; radius: 1.5; color: Theme.tv; opacity: 0.3; visible: parent.height > 24 }
        Rectangle { x: 5; y: 17; width: parent.width * 0.42; height: 3; radius: 1.5; color: Theme.tv; opacity: 0.3; visible: parent.height > 30 }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 8
        // Pantalla en miniatura (16:10)
        Rectangle {
            id: scr
            Layout.fillWidth: true
            implicitHeight: Math.round(width * 0.56)
            radius: Theme.r(6)
            color: Theme.bg
            border.width: 1
            border.color: Qt.alpha(Theme.ov, 0.45)
            clip: true
            readonly property real g: 4                  // separación
            readonly property real bh: 6                 // barra superior
            readonly property real y0: bh + g + 2
            readonly property real ih: height - y0 - g
            Rectangle { x: 0; y: 0; width: parent.width; height: scr.bh; color: Theme.s4; opacity: 0.9 }

            // Mosaico: una grande a la izquierda y dos a la derecha (dwindle)
            Item {
                anchors.fill: parent
                visible: root.mode === "mosaico"
                Win { active: true; x: scr.g; y: scr.y0; width: (scr.width - 3 * scr.g) / 2; height: scr.ih }
                Win { x: scr.width / 2 + scr.g / 2; y: scr.y0; width: (scr.width - 3 * scr.g) / 2; height: (scr.ih - scr.g) / 2 }
                Win { x: scr.width / 2 + scr.g / 2; y: scr.y0 + (scr.ih + scr.g) / 2; width: (scr.width - 3 * scr.g) / 2; height: (scr.ih - scr.g) / 2 }
            }
            // Desplazamiento: columnas que siguen fuera de la pantalla por los dos lados
            Item {
                anchors.fill: parent
                visible: root.mode === "desplazamiento"
                readonly property real cw: (scr.width - 3 * scr.g) / 2
                Win { x: -parent.cw * 0.62; y: scr.y0; width: parent.cw; height: scr.ih; opacity: 0.55 }
                Win { active: true; x: scr.width / 2 - parent.cw / 2 - scr.g * 2.5; y: scr.y0; width: parent.cw * 0.86; height: scr.ih }
                Win { x: scr.width / 2 + parent.cw * 0.43 - scr.g * 1.5; y: scr.y0; width: parent.cw * 0.7; height: (scr.ih - scr.g) / 2 }
                Win { x: scr.width / 2 + parent.cw * 0.43 - scr.g * 1.5; y: scr.y0 + (scr.ih + scr.g) / 2; width: parent.cw * 0.7; height: (scr.ih - scr.g) / 2 }
                // flechas de la cinta
                Icon { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 1 } name: "chevron_left"; size: 13; color: Theme.p }
                Icon { anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 1 } name: "chevron_right"; size: 13; color: Theme.p }
            }
            // Flotante: ventanas libres que se solapan y el dock a la izquierda
            Item {
                anchors.fill: parent
                visible: root.mode === "flotante"
                Win { x: scr.width * 0.20; y: scr.y0 + 2; width: scr.width * 0.46; height: scr.ih * 0.62 }
                Win { active: true; x: scr.width * 0.40; y: scr.y0 + scr.ih * 0.30; width: scr.width * 0.50; height: scr.ih * 0.66 }
                Rectangle {
                    x: 3; y: scr.y0 + scr.ih * 0.18; width: 9; height: scr.ih * 0.64
                    radius: 4; color: Theme.s4; border.width: 1; border.color: Qt.alpha(Theme.ov, 0.5)
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Repeater { model: 4; Rectangle { width: 5; height: 5; radius: 1.5; color: index === 1 ? Theme.p : Theme.tv; opacity: index === 1 ? 1 : 0.5 } }
                    }
                }
            }
        }
        Txt { Layout.fillWidth: true; text: root.title; weight: Font.DemiBold; color: root.selected ? Theme.selText : Theme.t }
        Txt { Layout.fillWidth: true; Layout.topMargin: -6; text: root.sub; size: 11.5; muted: true; visible: text !== ""; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
