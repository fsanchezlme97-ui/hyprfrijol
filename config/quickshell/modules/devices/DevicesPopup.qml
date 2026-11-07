// Menú de unidades extraíbles (vista "w-dispositivos", clic en el icono USB de la barra): cada memoria / tarjeta
// con su espacio, Abrir y Expulsar (o Montar si no lo está), «Expulsar todas» y enlace a Ajustes › Almacenamiento.
// Todo lo hace scripts/hf-devices a través de services/Devices.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../widgets"

ChipPopup {
    id: pop
    view: "w-dispositivos"
    panelWidth: 340
    panelHeight: card.implicitHeight
    onShownChanged: if (shown) { Devices.error = ""; Devices.done = ""; }

    readonly property string usb: '<path d="M10 2h4v4h-4z"/><path d="M8 6h8v9a4 4 0 0 1-8 0z"/><path d="M12 19v3"/>'
    readonly property string sd: '<path d="M7 3h8l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/><path d="M10 7v3M13 7v3M16 8v2"/>'
    readonly property string ejectSvg: '<path d="M12 5l7 8H5z"/><path d="M5 18h14"/>'

    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: col.implicitHeight + 28

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { svg: pop.usb; size: 16; color: Theme.t }
                Txt { text: "Dispositivos"; size: 14; weight: Font.DemiBold; Layout.fillWidth: true }
                Txt { text: Devices.list.length === 1 ? "1 unidad" : Devices.list.length + " unidades"; muted: true; size: 11.5 }
            }

            Txt {
                visible: Devices.list.length === 0
                Layout.fillWidth: true
                text: "No hay memorias USB ni tarjetas conectadas."
                muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }

            Repeater {
                model: Devices.list
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var d: modelData
                    readonly property bool working: Devices.busy === d.dev || Devices.busy === "*"
                    readonly property real used: d.mounted && d.size > 0 && d.avail !== null ? Math.max(0, Math.min(1, 1 - d.avail / d.size)) : 0
                    Layout.fillWidth: true
                    implicitHeight: rc.implicitHeight + 20
                    radius: Theme.r(9)
                    color: Theme.fill2
                    ColumnLayout {
                        id: rc
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 7
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9
                            Rectangle {
                                implicitWidth: 30; implicitHeight: 30; radius: Theme.r(8)
                                color: Theme.pc
                                Icon { anchors.centerIn: parent; svg: row.d.kind === "sd" ? pop.sd : pop.usb; name: row.d.kind === "imagen" ? "file" : ""; size: 15; color: Theme.pcText }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Txt { Layout.fillWidth: true; text: row.d.name; weight: Font.DemiBold }
                                Txt {
                                    Layout.fillWidth: true
                                    text: row.d.mounted
                                        ? Devices.human(row.d.avail) + " libres de " + Devices.human(row.d.size) + " · " + (row.d.fstype ?? "")
                                        : Devices.kindName(row.d.kind) + " · sin montar"
                                    muted: true; size: 11; tabular: true
                                }
                            }
                        }
                        Rectangle {
                            visible: row.d.mounted
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Qt.alpha(Theme.t, 0.12)
                            Rectangle { width: parent.width * row.used; height: parent.height; radius: 2; color: row.used > 0.9 ? Theme.danger : Theme.p }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            DevBtn {
                                icon: "folder"
                                text: row.d.mounted ? "Abrir" : "Montar y abrir"
                                enabled: !row.working
                                onClicked: { Devices.open(row.d.dev); Shell.close(); }
                            }
                            DevBtn {
                                svgIcon: pop.ejectSvg
                                text: row.working ? "Expulsando…" : "Expulsar"
                                enabled: !row.working
                                onClicked: Devices.eject(row.d.dev)
                            }
                        }
                    }
                }
            }

            Txt {
                visible: Devices.error !== "" || Devices.done !== ""
                Layout.fillWidth: true
                text: Devices.error || "✓ " + Devices.done
                color: Devices.error ? Theme.danger : Theme.p
                size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                DevBtn {
                    visible: Devices.list.length > 1
                    svgIcon: pop.ejectSvg
                    text: "Expulsar todas"
                    enabled: Devices.busy === ""
                    onClicked: Devices.ejectAll()
                }
                DevBtn { icon: "settings"; text: "Almacenamiento"; onClicked: Shell.open("ajustesapp", "almacenamiento") }
            }
        }
    }
}
