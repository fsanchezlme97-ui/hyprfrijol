// Ventana de la impresora 3D (vista "w-impresora", clic en el chip de la barra): cámara (o un dibujo de la
// pieza si no hay), trabajo, progreso, capas, tiempo, temperaturas y pausar / reanudar / cancelar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

ChipPopup {
    id: pop
    view: "w-impresora"
    panelWidth: 400
    panelHeight: card.implicitHeight

    property bool using: false
    property bool confirmCancel: false
    onShownChanged: {
        confirmCancel = false;
        if (shown && !using) { using = true; Printer.users++; }
        else if (!shown && using) { using = false; Printer.users--; }
    }
    readonly property var slicer: DesktopEntries.heuristicLookup("OrcaSlicer") ?? DesktopEntries.heuristicLookup("orca-slicer")
                                ?? DesktopEntries.heuristicLookup("PrusaSlicer") ?? DesktopEntries.heuristicLookup("Cura")

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { name: "printer"; size: 16; color: Theme.t }
                Txt { text: "Impresora 3D"; size: 14; weight: Font.DemiBold; Layout.fillWidth: true }
                Rectangle {
                    visible: Printer.configured
                    height: 22; width: st.implicitWidth + 18; radius: Theme.ctl(22)
                    color: Printer.busy ? Theme.pc : Theme.fill2
                    Txt { id: st; anchors.centerIn: parent; text: Printer.online ? Printer.stateText : "Sin conexión"; size: 11.5; color: Printer.busy ? Theme.pcText : Theme.t }
                }
            }

            // Sin configurar
            ColumnLayout {
                visible: !Printer.configured
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: "Pon la dirección de tu impresora (Moonraker/Klipper u OctoPrint) en Ajustes › Escritorio."; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                WBtn { text: "Abrir Ajustes"; icon: "settings"; onClicked: Shell.open("ajustesapp", "escritorio#Impresora 3D") }
            }
            Txt {
                visible: Printer.configured && !Printer.online
                Layout.fillWidth: true
                text: Printer.err || "Conectando con " + Printer.url + "…"
                muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }

            // Cámara
            Rectangle {
                visible: Printer.online
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                radius: Theme.r(10)
                color: "#20242B"
                clip: true
                // Dibujo de la pieza si no hay cámara
                Rectangle { visible: cam.status !== Image.Ready; x: parent.width * 0.2; width: parent.width * 0.6; y: parent.height - 26; height: 6; radius: 2; color: "#565D69" }
                Rectangle {
                    visible: cam.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.24; y: parent.height - 26 - height
                    height: Math.max(3, (parent.height - 60) * Printer.progress)
                    radius: 2
                    color: Theme.p; opacity: 0.85
                    Behavior on height { NumberAnimation { duration: Theme.ms(500); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                }
                Image {
                    id: cam
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: pop.shown ? Printer.camUrl : ""
                    cache: false
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    x: 8; y: 8; height: 20; width: ct.implicitWidth + 14; radius: Theme.ctl(20)
                    color: Qt.rgba(0, 0, 0, 0.5)
                    Txt { id: ct; anchors.centerIn: parent; text: cam.status === Image.Ready ? "● cámara" : "sin cámara"; size: 10.5; color: "#FFFFFF" }
                }
            }

            // Trabajo
            ColumnLayout {
                visible: Printer.online
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Txt { Layout.fillWidth: true; text: Printer.file || "Sin trabajo"; weight: Font.DemiBold }
                    Txt { visible: Printer.busy || Printer.progress > 0; text: Math.round(Printer.progress * 100) + " %"; size: 16; weight: Font.Medium; tabular: true }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: Theme.r(3)
                    color: Theme.fill2
                    Progress { anchors.fill: parent; value: Printer.progress; period: 5000; busy: Printer.state === "printing"; track: "transparent"; color: Printer.state === "paused" ? Theme.ter : Theme.p }
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [Printer.layers ? "Capa " + Printer.layer + " de " + Printer.layers : "",
                           Printer.elapsed > 0 ? Printer.dur(Printer.elapsed) + " imprimiendo" : "",
                           Printer.left >= 0 ? "quedan " + Printer.dur(Printer.left) : "",
                           Printer.left > 0 ? "termina a las " + Qt.formatDateTime(new Date(Date.now() + Printer.left * 1000), "HH:mm") : ""].filter(s => s).join(" · ")
                    muted: true; size: 11.5; tabular: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
            }

            // Temperaturas
            RowLayout {
                visible: Printer.online && !isNaN(Printer.nozzle)
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [
                        { l: "Boquilla", v: Printer.nozzle, t: Printer.nozzleTarget },
                        { l: "Cama", v: Printer.bed, t: Printer.bedTarget }
                    ].filter(x => !isNaN(x.v))
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 54
                        radius: Theme.r(8)
                        color: Theme.fill2
                        Column {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                            spacing: 1
                            Row {
                                spacing: 5
                                Icon { name: "thermometer"; size: 12; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                                Txt { text: parent.parent.parent.modelData.l; muted: true; size: 11 }
                            }
                            Txt {
                                text: Math.round(parent.parent.modelData.v) + "°" + (parent.parent.modelData.t > 0 ? "  / " + Math.round(parent.parent.modelData.t) + "°" : "")
                                size: 15; weight: Font.DemiBold; tabular: true
                            }
                        }
                        // calentando: barra hacia el objetivo
                        Rectangle {
                            visible: parent.modelData.t > 0
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                            height: 3; radius: 2; color: Qt.alpha(Theme.t, 0.1)
                            Rectangle { height: parent.height; radius: 2; color: Theme.ter; width: parent.width * Math.min(1, parent.parent.modelData.v / Math.max(1, parent.parent.modelData.t)) }
                        }
                    }
                }
            }

            // Acciones
            RowLayout {
                visible: Printer.online
                Layout.fillWidth: true
                spacing: 6
                WBtn {
                    enabled: Printer.busy
                    icon: Printer.state === "paused" ? "play" : "pause"
                    text: Printer.state === "paused" ? "Reanudar" : "Pausar"
                    onClicked: Printer.state === "paused" ? Printer.resume() : Printer.pause()
                }
                WBtn {
                    enabled: Printer.busy
                    danger: true
                    icon: "x"
                    text: pop.confirmCancel ? "¿Seguro? Cancelar" : "Cancelar"
                    onClicked: { if (pop.confirmCancel) { Printer.cancel(); pop.confirmCancel = false; } else pop.confirmCancel = true; }
                }
            }
            RowLayout {
                visible: Printer.configured
                Layout.fillWidth: true
                spacing: 6
                WBtn { text: "Panel web"; icon: "globe"; onClicked: { Printer.openWeb(); Shell.close(); } }
                WBtn { visible: !!pop.slicer; text: pop.slicer ? "Abrir " + pop.slicer.name : ""; icon: "external"; onClicked: { pop.slicer.execute(); Shell.close(); } }
            }
        }
    }
}
