// Menú de un icono de la bandeja, con el estilo del shell (no el menú nativo de Qt): lee el dbusmenu de la app
// (QsMenuOpener), con submenús (se entra y se vuelve en la misma ventana), casillas, opciones, iconos y
// entradas desactivadas. Abajo: «Ocultar de la barra» / «Mostrar en la barra» (barTrayHidden: ids que van al
// desplegable «›» de la bandeja). Clic fuera o Esc: se cierra.
//   TrayMenu { id: m }   m.open(trayItem, desdeItem)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../components"

PopupWindow {
    id: menu
    property SystemTrayItem item: null
    property Item from: null
    property var stack: []               // submenús abiertos (QsMenuEntry con hijos)
    property bool shown: false
    readonly property string side: Settings.barPos
    readonly property var hidden: Settings.get("barTrayHidden", [])
    readonly property bool isHidden: !!item && hidden.includes(item.id)

    function open(it, fromItem): void {
        if (shown && item === it) { close(); return; }      // otro clic en el mismo icono: se cierra
        if (shown) { shown = false; Qt.callLater(() => open(it, fromItem)); return; }
        item = it; from = fromItem; stack = []; shown = true;
    }
    function close(): void { shown = false; stack = []; }
    function label(t): string { return String(t ?? "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_"); }

    visible: shown && from !== null && item !== null
    anchor.item: from
    anchor.edges: side === "abajo" ? Edges.Top : side === "arriba" ? Edges.Bottom : side === "izquierda" ? Edges.Right : Edges.Left
    anchor.gravity: anchor.edges
    anchor.margins.top: side === "abajo" ? -6 : 0
    anchor.margins.bottom: side === "arriba" ? -6 : 0
    anchor.margins.left: side === "derecha" ? -6 : 0
    anchor.margins.right: side === "izquierda" ? -6 : 0
    color: "transparent"
    implicitWidth: 256
    implicitHeight: body.implicitHeight

    // Un opener por nivel: el del menú padre sigue abierto mientras se ve un submenú (si se cerrara, la
    // entrada del submenú se destruiría). Hasta 3 niveles de submenús.
    QsMenuOpener { id: o0; menu: menu.shown && menu.item?.hasMenu ? menu.item.menu : null }
    QsMenuOpener { id: o1; menu: menu.stack.length > 0 ? menu.stack[0] : null }
    QsMenuOpener { id: o2; menu: menu.stack.length > 1 ? menu.stack[1] : null }
    QsMenuOpener { id: o3; menu: menu.stack.length > 2 ? menu.stack[2] : null }
    readonly property var opener: [o0, o1, o2, o3][Math.min(3, stack.length)]
    // La captura se activa un instante después de que el menú se muestre: activada en el mismo momento, la ventana
    // aún no existía para Hyprland y la captura no hacía nada (el menú no se cerraba al hacer clic fuera)
    property bool grabbing: false
    onVisibleChanged: { grabbing = false; if (visible) grabLater.restart(); }
    Timer { id: grabLater; interval: 60; onTriggered: menu.grabbing = menu.visible }
    HyprlandFocusGrab { active: menu.grabbing; windows: [menu]; onCleared: menu.close() }

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: col.implicitHeight + 10
        radius: Theme.r(10)
        color: Theme.glassPopup
        border.width: 1
        border.color: Theme.border
        focus: true
        Keys.onEscapePressed: menu.stack.length ? menu.stack = menu.stack.slice(0, -1) : menu.close()

        ColumnLayout {
            id: col
            x: 5; y: 5
            width: parent.width - 10
            spacing: 0

            // cabecera: nombre de la app (o «‹ submenú» para volver)
            Item {
                Layout.fillWidth: true
                implicitHeight: 28
                Row {
                    anchors { fill: parent; leftMargin: 8 }
                    spacing: 6
                    Icon { visible: menu.stack.length > 0; name: "chevron_left"; size: 13; color: Theme.tv; anchors.verticalCenter: parent.verticalCenter }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - 40
                        text: menu.stack.length ? menu.label(menu.stack[menu.stack.length - 1].text) : (menu.item?.title || menu.item?.tooltipTitle || menu.item?.id || "")
                        size: 11.5; muted: true; weight: Font.DemiBold
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: menu.stack.length > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: menu.stack = menu.stack.slice(0, -1)
                }
            }

            // sin menú propio: «Abrir»
            Entry {
                visible: !menu.item?.hasMenu && menu.stack.length === 0
                text: "Abrir"
                onActivated: { menu.item.activate(); menu.close(); }
            }

            Repeater {
                model: menu.opener.children
                delegate: Item {
                    id: row
                    required property QsMenuEntry modelData
                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 9 : 30
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16; height: 1
                        color: Theme.ov
                    }
                    Entry {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        text: menu.label(row.modelData.text)
                        iconSource: row.modelData.icon ?? ""
                        enabledEntry: row.modelData.enabled
                        check: row.modelData.buttonType === QsMenuButtonType.CheckBox ? "box" : row.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio" : ""
                        checked: row.modelData.checkState === Qt.Checked
                        sub: row.modelData.hasChildren
                        onActivated: {
                            if (row.modelData.hasChildren) { if (menu.stack.length < 3) menu.stack = menu.stack.concat([row.modelData]); return; }
                            row.modelData.triggered();
                            menu.close();
                        }
                    }
                }
            }

            Rectangle { visible: menu.stack.length === 0; Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: Theme.ov }
            Entry {
                visible: menu.stack.length === 0
                text: menu.isHidden ? "Mostrar en la barra" : "Ocultar de la barra"
                glyph: menu.isHidden ? "chevron_up" : "chevron_down"
                muted: true
                onActivated: {
                    const id = menu.item.id;
                    Settings.set("barTrayHidden", menu.isHidden ? menu.hidden.filter(x => x !== id) : menu.hidden.concat([id]));
                    menu.close();
                }
            }
        }
    }

    // Fila del menú: [casilla / opción / icono] texto [›]
    component Entry: Rectangle {
        id: e
        property string text: ""
        property string iconSource: ""
        property string glyph: ""
        property string check: ""          // "" · "box" · "radio"
        property bool checked: false
        property bool sub: false
        property bool enabledEntry: true
        property bool muted: false
        signal activated()
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.r(6)
        color: em.containsMouse && enabledEntry ? Theme.fill2 : "transparent"
        opacity: enabledEntry ? 1 : 0.45
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 8
            Item {
                implicitWidth: 16; implicitHeight: 16
                Rectangle {
                    visible: e.check !== ""
                    anchors.centerIn: parent
                    width: 14; height: 14
                    radius: e.check === "radio" ? 7 : Theme.r(4)
                    color: e.checked ? Theme.p : "transparent"
                    border.width: e.checked ? 0 : 1.5
                    border.color: Theme.o
                    Icon { visible: e.checked && e.check === "box"; anchors.centerIn: parent; name: "check"; size: 11; color: Theme.pText }
                    Rectangle { visible: e.checked && e.check === "radio"; anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.pText }
                }
                IconImage { visible: e.check === "" && e.iconSource !== ""; anchors.centerIn: parent; implicitSize: 16; source: e.iconSource; asynchronous: true }
                Icon { visible: e.check === "" && e.iconSource === "" && e.glyph !== ""; anchors.centerIn: parent; name: e.glyph; size: 13; color: Theme.tv }
            }
            Txt { Layout.fillWidth: true; text: e.text; muted: e.muted }
            Icon { visible: e.sub; name: "chevron_right"; size: 13; color: Theme.tv }
        }
        MouseArea {
            id: em
            anchors.fill: parent
            hoverEnabled: true
            enabled: e.enabledEntry
            cursorShape: Qt.PointingHandCursor
            onClicked: e.activated()
        }
    }
}
