// Tarjeta de un plugin de Hyprland en Ajustes › Plugins.
//   PluginCard { p: <entrada de config/tools/plugins.json>; st: "" | "on" | "off" | "fail"; onInstall/onToggle/onConfigure/onWeb }
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"

Rectangle {
    id: root
    property var p: ({})
    property string st: ""              // "" no instalado · on activado · off instalado · fail no compiló
    property bool busy: false
    property bool selected: false
    property bool canRun: true           // hay hyprpm
    signal install()
    signal toggle()
    signal configure()
    signal web()
    readonly property bool manual: p.install === "manual"
    readonly property bool hasOptions: (p.options ?? []).length > 0
    readonly property string compatText: ({ ok: "Compatible con 0.57 (Lua)", probable: "Probablemente compatible con 0.57", manual: "Instalación manual" })[p.compat] ?? "Sin verificar"
    readonly property color compatColor: p.compat === "ok" ? Theme.p : p.compat === "probable" || p.compat === "manual" ? Theme.tv : Theme.danger
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.fillHeight: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.r(6)
    color: Theme.card
    border.width: selected || st === "on" ? (selected ? 2 : 1) : (Theme.glassy ? 1 : 0)
    border.color: selected || st === "on" ? Theme.p : Theme.border
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: Theme.r(6)
                color: root.st === "on" ? Theme.p : Theme.s4
                Txt { anchors.centerIn: parent; text: (root.p.name ?? "?")[0].toUpperCase(); weight: Font.DemiBold; size: 14; color: root.st === "on" ? Theme.pText : Theme.t }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Txt { Layout.fillWidth: true; text: root.p.name ?? ""; weight: Font.DemiBold }
                Mono { Layout.fillWidth: true; text: (root.p.by ?? "") + (root.p.official ? " · oficial" : ""); size: 10.5 }
            }
            Rectangle {
                implicitHeight: 20; implicitWidth: stTxt.implicitWidth + 14
                radius: Theme.ctl(20)
                color: root.st === "on" ? Theme.selBg : root.st === "fail" ? Qt.alpha(Theme.danger, 0.16) : "transparent"
                border.width: root.st === "on" || root.st === "fail" ? 0 : 1
                border.color: Theme.ov
                Txt {
                    id: stTxt
                    anchors.centerIn: parent
                    size: 10.5; weight: Font.Medium
                    color: root.st === "on" ? Theme.selText : root.st === "fail" ? Theme.danger : Theme.tv
                    text: root.st === "on" ? "Activado" : root.st === "off" ? "Instalado" : root.st === "fail" ? "No compiló" : root.manual ? "Manual" : "No instalado"
                }
            }
        }
        Txt { Layout.fillWidth: true; text: root.p.desc ?? ""; muted: true; size: 11.5; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 3.5; color: root.compatColor }
            Txt { Layout.fillWidth: true; text: root.compatText; size: 11; color: root.p.compat === "ok" || root.p.compat === "probable" || root.p.compat === "manual" ? Theme.tv : Theme.danger; weight: Font.Medium }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6
            Button {
                visible: !root.manual
                h: 26
                kind: root.st === "" || root.st === "off" || root.st === "fail" ? "primary" : "outline"
                text: root.busy ? "…" : root.st === "" ? "Instalar" : root.st === "on" ? "Desactivar" : root.st === "fail" ? "Recompilar" : "Activar"
                enabled: root.canRun && !root.busy
                onClicked: root.st === "" || root.st === "fail" ? root.install() : root.toggle()
            }
            Button {
                visible: root.hasOptions || root.manual
                h: 26
                text: root.manual ? "Cómo instalarlo" : "Opciones"
                kind: root.selected ? "primary" : "outline"
                onClicked: root.configure()
            }
            Item { Layout.fillWidth: true }
            Button { visible: !!(root.p.url || root.p.repo); h: 26; kind: "link"; text: "GitHub ↗"; onClicked: root.web() }
        }
    }
}
