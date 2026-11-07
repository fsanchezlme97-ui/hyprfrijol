// Hueco de la barra para los widgets de los plugins de Omarchy (kind «bar-widget»), en el orden de
// `hf-plugin bar <id> on`. Dónde va: Ajustes › Plugins de Omarchy (omarchyBarSlot: "derecha" junto a la bandeja ·
// "izquierda" tras los espacios). Cada widget recibe lo que le da la barra de Omarchy: bar (Ui/PluginBarApi.qml con
// los colores del tema y el globo de ayuda de hyprfrijol), moduleName, settings (los de su manifiesto + los de
// `hf-plugin set`) y fixedEdge. El contenido de la barra se dibuja a 32 px y se escala (Bar.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"
import qs.Ui as OUi

GridLayout {
    id: root
    required property var barWindow
    property bool vertical: false
    property string place: "derecha"         // en qué hueco está este (omarchyBarSlot elige uno)
    readonly property bool here: Settings.get("omarchyBarSlot", "derecha") === place
    readonly property bool any: rep.count > 0
    flow: vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 2
    columnSpacing: 2
    visible: any

    Repeater {
        id: rep
        model: root.here ? OmarchyPlugins.barEntries : []
        Item {
            id: slot
            required property var modelData
            readonly property string pid: modelData.id
            readonly property var comp: Qt.createComponent(modelData.url, Component.PreferSynchronous)
            readonly property Item w: loader.item
            Layout.alignment: Qt.AlignCenter
            implicitWidth: root.vertical ? 32 : Math.max(0, w ? (w.implicitWidth || w.width) : 0)
            implicitHeight: root.vertical ? Math.max(0, w ? (w.implicitHeight || w.height) : 0) : 32
            visible: !!w
            Component.onCompleted: if (comp.status === Component.Error) OmarchyPlugins.setError(pid, comp.errorString().trim())
            Connections {
                target: slot.comp
                function onStatusChanged() { if (slot.comp.status === Component.Error) OmarchyPlugins.setError(slot.pid, slot.comp.errorString().trim()); }
            }
            OUi.PluginBarApi {
                id: api
                pluginId: slot.pid
                moduleName: slot.pid
                shell: OmarchyPlugins.shellApiFor(slot.pid)
                foreground: Theme.t
                barForeground: Theme.t
                background: Theme.glass
                urgent: Theme.p
                fontFamily: Theme.font
                position: OmarchyPlugins.barInfo.position
                vertical: root.vertical
                barSize: root.vertical ? 36 : 32
                _showTooltip: (target, text) => { tip.target = target; tip.text = text; tipDelay.restart(); }
                _hideTooltip: target => { if (tip.target === target) { tipDelay.stop(); tip.shown = false; } }
                _moduleWidgets: id => OmarchyPlugins.widgets[id] ?? []
                _run: cmd => Quickshell.execDetached(["bash", "-lc", cmd])
            }
            Loader {
                id: loader
                anchors.centerIn: parent
                width: slot.w ? (root.vertical ? 32 : (slot.w.implicitWidth || slot.w.width)) : 0
                height: slot.w ? (root.vertical ? (slot.w.implicitHeight || slot.w.height) : 32) : 0
                sourceComponent: slot.comp.status === Component.Ready ? slot.comp : null
                onLoaded: {
                    const o = item;
                    if ("bar" in o) o.bar = api;
                    if ("moduleName" in o) o.moduleName = slot.pid;
                    if ("settings" in o) o.settings = slot.modelData.settings ?? {};
                    if ("fixedEdge" in o) o.fixedEdge = Settings.get("omarchyBarSlot", "derecha") === "izquierda" ? "start" : "end";
                    if ("shell" in o) o.shell = OmarchyPlugins.shellApiFor(slot.pid);
                    if ("manifest" in o) o.manifest = OmarchyPlugins.publicManifest(slot.pid);
                    if ("service" in o) o.service = OmarchyPlugins.services[slot.pid] ?? null;
                    OmarchyPlugins.registerWidget(slot.pid, o);
                    OmarchyPlugins.setError(slot.pid, "");
                }
            }
            Component.onDestruction: if (loader.item) OmarchyPlugins.unregisterWidget(pid, loader.item)
        }
    }

    // Globo de ayuda de los widgets (bar.showTooltip / hideTooltip)
    Timer { id: tipDelay; interval: 450; onTriggered: tip.shown = true }
    PopupWindow {
        id: tip
        property Item target: null
        property string text: ""
        property bool shown: false
        readonly property string side: Settings.barPos
        anchor.item: target ?? root
        anchor.edges: side === "abajo" ? Edges.Top : side === "arriba" ? Edges.Bottom : side === "izquierda" ? Edges.Right : Edges.Left
        anchor.gravity: anchor.edges
        anchor.margins.top: side === "abajo" ? -8 : 0
        anchor.margins.bottom: side === "arriba" ? -8 : 0
        anchor.margins.left: side === "derecha" ? -8 : 0
        anchor.margins.right: side === "izquierda" ? -8 : 0
        visible: shown && text !== "" && !!target && target.visible
        color: "transparent"
        implicitWidth: lbl.implicitWidth + 18
        implicitHeight: 26
        mask: Region {}
        Rectangle {
            anchors.fill: parent
            radius: Theme.r(6)
            color: Theme.glassPopup
            border.width: 1
            border.color: Theme.border
            Txt { id: lbl; anchors.centerIn: parent; text: tip.text; size: 11.5 }
        }
    }
}
