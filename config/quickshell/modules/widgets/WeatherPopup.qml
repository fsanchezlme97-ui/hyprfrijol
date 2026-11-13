// Ventana del clima (vista "w-clima", clic en el clima de la barra): ahora, próximas 24 h y 3 días.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

ChipPopup {
    id: pop
    view: "w-clima"
    panelWidth: 392
    panelHeight: card.implicitHeight

    // Mide mientras está abierta (y un poco antes de verse, para no abrir vacía)
    property bool using: false
    onShownChanged: if (shown && !using) { using = true; Weather.users++; } else if (!shown && using) { using = false; Weather.users--; }

    readonly property var range: {
        const all = (Weather.days ?? []).concat(Weather.today ? [Weather.today] : []);
        if (!all.length) return { lo: 0, hi: 1 };
        return { lo: Math.min(...all.map(d => d.min)), hi: Math.max(...all.map(d => d.max)) };
    }
    function popTxt(p): string { return p >= 0 ? p + " %" : "—"; }

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 32

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 16

            // ---- ahora
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    radius: Theme.r(14)
                    color: Theme.pc
                    Icon { anchors.centerIn: parent; name: Weather.ready ? Weather.icon : "cloud"; size: 30; stroke: 1.6; color: Theme.pcText }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        spacing: 8
                        Txt { text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"; size: 34; weight: Font.Medium; tabular: true }
                        Txt {
                            visible: !isNaN(Weather.feels)
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 8
                            text: "sensación " + Math.round(Weather.feels) + "°"
                            muted: true; size: 11.5; tabular: true
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: Weather.ready ? Weather.desc.charAt(0).toUpperCase() + Weather.desc.slice(1) : (Weather.err || "Buscando el tiempo…")
                        weight: Font.DemiBold
                        wrapMode: Weather.ready ? Text.NoWrap : Text.WordWrap
                    }
                }
                ColumnLayout {
                    visible: !!Weather.today
                    spacing: 2
                    Txt { Layout.alignment: Qt.AlignRight; text: "↑ " + (Weather.today?.max ?? "") + "°"; tabular: true }
                    Txt { Layout.alignment: Qt.AlignRight; text: "↓ " + (Weather.today?.min ?? "") + "°"; muted: true; tabular: true }
                }
            }

            // ---- datos
            Flow {
                visible: Weather.ready
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [
                        { i: "drop", t: isNaN(Weather.humidity) ? "" : "Humedad " + Math.round(Weather.humidity) + " %" },
                        { i: "", s: '<path d="M3 8h10a3 3 0 1 0-3-3"/><path d="M3 12h15a3 3 0 1 1-3 3"/><path d="M3 16h7"/>', t: isNaN(Weather.wind) ? "" : "Viento " + Math.round(Weather.wind) + " km/h" },
                        { i: "cloud", t: (Weather.today?.pop ?? -1) >= 0 ? "Lluvia " + Weather.today.pop + " %" : "" },
                        { i: "sun", t: Weather.today?.sunrise ? Weather.today.sunrise + " – " + Weather.today.sunset : "" }
                    ].filter(x => x.t !== "")
                    Rectangle {
                        required property var modelData
                        height: 24; width: pr.implicitWidth + 16
                        radius: Theme.ctl(24)
                        color: Theme.fill2
                        Row {
                            id: pr
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { name: parent.parent.modelData.i; svg: parent.parent.modelData.s ?? ""; size: 12; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: parent.parent.modelData.t; size: 11.5; tabular: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // ---- próximas horas
            ColumnLayout {
                visible: Weather.hours.length > 0
                Layout.fillWidth: true
                spacing: 8
                SectionLabel { text: "Próximas horas" }
                Flickable {
                    id: hf
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    contentWidth: hrow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    // Rueda vertical → desplazamiento horizontal
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: e => hf.contentX = Math.max(0, Math.min(hf.contentWidth - hf.width, hf.contentX - (e.angleDelta.y || e.angleDelta.x) / 2))
                    }
                    readonly property real lo: Math.min(...Weather.hours.map(h => h.temp))
                    readonly property real hi: Math.max(...Weather.hours.map(h => h.temp))
                    Row {
                        id: hrow
                        spacing: 2
                        Repeater {
                            model: Weather.hours
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: 44; height: 92
                                radius: Theme.r(10)
                                color: index === 0 ? Theme.fill2 : "transparent"
                                Column {
                                    anchors.fill: parent
                                    anchors.topMargin: 8
                                    spacing: 4
                                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.index === 0 ? "Ahora" : parent.parent.modelData.h + " h"; size: 10.5; muted: parent.parent.index !== 0; tabular: true }
                                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.iconFor(parent.parent.modelData.code, parent.parent.modelData.day); size: 18; color: Theme.t }
                                    // la temperatura sube y baja con la curva del día
                                    Item {
                                        width: parent.width; height: 26
                                        Txt {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: hf.hi > hf.lo ? (1 - (parent.parent.parent.modelData.temp - hf.lo) / (hf.hi - hf.lo)) * 10 : 5
                                            text: parent.parent.parent.modelData.temp + "°"
                                            weight: Font.DemiBold; tabular: true
                                        }
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: parent.parent.modelData.pop > 0 ? parent.parent.modelData.pop + "%" : " "
                                        size: 10; color: Theme.p; tabular: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- próximos días
            ColumnLayout {
                visible: Weather.days.length > 0
                Layout.fillWidth: true
                spacing: 4
                SectionLabel { text: "Próximos días" }
                Repeater {
                    model: Weather.days
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 12
                        Txt { text: parent.modelData.d.charAt(0).toUpperCase() + parent.modelData.d.slice(1); Layout.preferredWidth: 36; weight: Font.Medium }
                        Icon { name: Weather.iconFor(parent.modelData.code, true); size: 16; color: Theme.t }
                        Txt { text: Weather.describe(parent.modelData.code); muted: true; size: 11.5; Layout.preferredWidth: 96 }
                        Txt { text: parent.modelData.min + "°"; muted: true; tabular: true; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }
                        // franja mín–máx sobre el rango de los días
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            radius: Theme.r(3)
                            color: Theme.fill2
                            readonly property real span: Math.max(1, pop.range.hi - pop.range.lo)
                            Rectangle {
                                x: parent.width * (parent.parent.modelData.min - pop.range.lo) / parent.span
                                width: Math.max(6, parent.width * (parent.parent.modelData.max - parent.parent.modelData.min) / parent.span)
                                height: parent.height
                                radius: parent.radius
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.ter }
                                    GradientStop { position: 1; color: Theme.p }
                                }
                            }
                        }
                        Txt { text: parent.modelData.max + "°"; tabular: true; Layout.preferredWidth: 28 }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.ov }
            // ---- lugar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { name: "pin"; size: 13; color: Theme.tv }
                Txt {
                    Layout.fillWidth: true
                    text: (Weather.city || (Settings.get("weatherCity", "") || "Ubicación por IP")) + (Weather.updatedText ? " · " + Weather.updatedText : "")
                    muted: true; size: 11.5
                }
                WBtn { Layout.fillWidth: false; icon: "refresh"; onClicked: Weather.refresh() }
                WBtn { Layout.fillWidth: false; text: "Cambiar ciudad"; onClicked: Shell.open("ajustesapp", "escritorio#Ciudad del clima") }
            }
        }
    }
}
