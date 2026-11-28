// Isla dinámica suelta (ajuste island, apagada de fábrica): una pastilla arriba al centro, bajo la barra, con lo que está
// pasando. Plegada enseña lo más importante en una línea (reunión en menos de 10 min > Pomodoro > procesos en curso >
// música sonando); pulsarla abre la vista completa de eso (Pomodoro, procesos, música o agenda). Qué se muestra:
// islandShow (musica · pomodoro · descargas · reunion). Sin nada en marcha se esconde, o enseña la hora con islandAlways.
// Estado e IPC en services/Isla.qml. Con la barra en forma «Muesca» la isla va dentro de la barra (bar/Bar.qml) y esta
// ventana no se crea.
// El dictado no entra: su píldora (modules/dictado) sigue donde estaba y se aparta de la isla (OsdStack.island).
// Se pone en el sitio superior del OSD (services/OsdStack.qml: respeta la barra, su reserva y osdOffset) y en la capa
// «Top», así que una ventana a pantalla completa la tapa. Apagada no crea ninguna ventana.
// Ajustes › Barra › Isla dinámica.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

Scope {
    id: root
    readonly property bool shown: Isla.shown && !Isla.inBar
    Binding { target: OsdStack; property: "island"; value: root.shown ? 32 : 0 }

    PanelWindow {
        id: win
        screen: Shell.screen
        visible: Isla.on && !Isla.inBar && (root.shown || pill.opacity > 0.01)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hf-isla"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true }
        margins { top: OsdStack.edge("arriba") }
        implicitWidth: 440
        implicitHeight: 20 + 32 + 20
        mask: Region { item: pill }

        Glass {
            id: pill
            kind: "panel"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            opacity: root.shown ? 1 : 0
            width: Math.max(120, Math.min(300, line.implicitWidth + 28))
            height: 32
            radius: height / 2
            Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Isla.open() }

            IslaLine {
                id: line
                anchors.centerIn: parent
            }
            Rectangle {
                visible: Isla.keys.length > 0 && Isla.top.progress >= 0
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 4 }
                width: (parent.width - 32) * Isla.top.progress; height: 2; radius: 1; color: Theme.p
            }
        }
    }
}
