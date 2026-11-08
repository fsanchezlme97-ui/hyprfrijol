// Notificaciones del centro de control (QuickSettings.qml; campana de la barra = Shell.open("notificaciones")).
//  Recientes: agrupadas por aplicación (cabecera con icono, cuántas, desplegar/agrupar y descartar el grupo);
//             un grupo de 3 o más se ve apilado («+N») hasta que lo despliegas. «No molestar», borrar todo,
//             respuesta en línea, acciones e imágenes; arrastrar a un lado descarta.
//  Historial: lo que ha llegado (Notifs.history, también lo ya descartado), con búsqueda y filtro por app.
// Shell.open("notificaciones", "historial") abre el historial; con { app: "whatsapp" } ya filtrado.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"

Glass {
    id: win
    kind: "panel"
    // alto natural (el panel lo usa para su tamaño; si sobra sitio, la lista crece)
    implicitHeight: Math.max(150, body.implicitHeight + 20)
    property bool dndMenu: false            // atajos de «no molestar» desplegados (DndPresets.qml)
    property string tab: "recientes"        // recientes | historial
    property var open: ({})                 // grupo (clave) → desplegado / agrupado a mano
    property string query: ""
    property string appFilter: ""           // clave de app del historial ("" = todas)
    // Al abrir el centro: arg = Shell.arg si se pidió esta sección, si no null
    function reset(a): void {
        win.dndMenu = false;
        win.tab = a === "historial" || (a && typeof a === "object") ? "historial" : "recientes";
        win.appFilter = a && typeof a === "object" ? String(a.app ?? "").toLowerCase() : "";
        win.query = "";
        search.text = "";
    }
    function isOpen(g): bool { return win.open[g.key] !== undefined ? win.open[g.key] : g.items.length < 3; }
    function toggle(g) { const o = Object.assign({}, open); o[g.key] = !isOpen(g); open = o; }

    readonly property var groups: Notifs.groupsOf(Notifs.list.values.slice().reverse())

    // Historial filtrado + apps que aparecen en él (para los filtros)
    readonly property var histApps: {
        const seen = {}, out = [];
        for (const h of Notifs.history) { const k = (h.app || "").toLowerCase(); if (!seen[k]) { seen[k] = 1; out.push({ key: k, app: h.app || "Sistema" }); } }
        return out.slice(0, 30);   // la fila de filtros se desplaza si no caben
    }
    readonly property var histRows: {
        const q = win.query.trim().toLowerCase();
        const out = [];
        let day = "";
        for (const h of Notifs.history) {
            if (win.appFilter && (h.app || "").toLowerCase() !== win.appFilter) continue;
            if (q && !((h.app + " " + h.summary + " " + h.body).toLowerCase().includes(q))) continue;
            const d = Notifs.dayOf(h.t);
            if (d !== day) { out.push({ header: d }); day = d; }
            out.push(h);
            if (out.length > 150) break;
        }
        return out;
    }

    ColumnLayout {
        id: body
        anchors { fill: parent; margins: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 6
            Segmented {
                h: 28
                model: [{ key: "recientes", label: "Recientes" + (Notifs.count ? " · " + Notifs.count : "") }, { key: "historial", label: "Historial" }]
                current: win.tab
                onPicked: k => win.tab = k
            }
            Item { Layout.fillWidth: true }
            IconBtn {
                implicitWidth: 28; implicitHeight: 26; radius: Theme.r(6)
                icon: "dnd"; iconSize: 14
                active: Notifs.dnd
                tooltip: "No molestar"
                onClicked: Notifs.setDnd(!Notifs.dnd)
                onRightClicked: win.dndMenu = !win.dndMenu
            }
            IconBtn {
                implicitWidth: 20; implicitHeight: 26; radius: Theme.r(6)
                icon: win.dndMenu ? "chevron_up" : "chevron_down"; iconSize: 12; fg: Theme.tv
                tooltip: "No molestar durante…"
                onClicked: win.dndMenu = !win.dndMenu
            }
            IconBtn {
                implicitWidth: 26; implicitHeight: 26; radius: Theme.r(6)
                icon: "settings"; iconSize: 13; fg: Theme.tv
                tooltip: "Ajustes de notificaciones"
                onClicked: Shell.open("ajustesapp", "notificaciones")
            }
        }
        Txt {
            visible: Notifs.dnd && !win.dndMenu
            Layout.fillWidth: true; Layout.leftMargin: 4
            size: 11.5; muted: true
            text: "No molestar · " + Notifs.dndLeft + " · solo se muestran los avisos urgentes"
            wrapMode: Text.WordWrap; maximumLineCount: 2
        }
        DndPresets {
            visible: win.dndMenu
            Layout.fillWidth: true
            onPicked: win.dndMenu = false
        }

        // =============================================================== Recientes
        ColumnLayout {
            visible: win.tab === "recientes"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Item {   // vacío (centrado en el sitio que sobre)
                visible: Notifs.count === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: empty.implicitHeight + 28
                ColumnLayout {
                    id: empty
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { Layout.alignment: Qt.AlignHCenter; name: "bell"; size: 26; color: Theme.tv; opacity: 0.6 }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "Sin notificaciones nuevas"; muted: true }
                    Txt {
                        visible: Notifs.history.length > 0
                        Layout.alignment: Qt.AlignHCenter
                        text: "Ver el historial"; size: 11.5; color: hl.containsMouse ? Theme.t : Theme.p
                        MouseArea { id: hl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.tab = "historial" }
                    }
                }
            }

            Flickable {
                id: flick
                visible: Notifs.count > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: list.implicitHeight          // el panel pone el tope (QuickSettings: notifRoom)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollHint { flick: flick; inset: 0 }
                ColumnLayout {
                    id: list
                    width: flick.width
                    spacing: 12
                    Repeater {
                        model: win.groups
                        ColumnLayout {
                            id: grp
                            required property var modelData
                            readonly property bool many: modelData.items.length > 1
                            readonly property bool expanded: win.isOpen(modelData)
                            Layout.fillWidth: true
                            spacing: 5
                            // cabecera: icono · APP · n · hora · desplegar · descartar
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 2
                                spacing: 7
                                Txt { size: 11; muted: true; weight: Font.DemiBold; text: grp.modelData.app.toUpperCase() }
                                Txt { visible: grp.many; size: 11; muted: true; tabular: true; text: "· " + grp.modelData.items.length }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    visible: grp.many
                                    implicitHeight: 20; implicitWidth: exT.implicitWidth + 16; radius: Theme.r(5)
                                    color: exMa.containsMouse ? Theme.fill2 : "transparent"
                                    Row {
                                        id: exT
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Txt { text: grp.expanded ? "Agrupar" : "Ver " + grp.modelData.items.length; size: 11; color: Theme.p }
                                        Icon { anchors.verticalCenter: parent.verticalCenter; name: grp.expanded ? "chevron_up" : "chevron_down"; size: 10; color: Theme.p }
                                    }
                                    MouseArea { id: exMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.toggle(grp.modelData) }
                                }
                                IconBtn {
                                    implicitWidth: 20; implicitHeight: 20; radius: Theme.r(5)
                                    icon: "x"; iconSize: 10; fg: Theme.tv
                                    tooltip: grp.many ? "Descartar las " + grp.modelData.items.length : "Descartar"
                                    onClicked: Notifs.dismissAll(grp.modelData.items)
                                }
                            }
                            Repeater {
                                model: grp.expanded ? grp.modelData.items : grp.modelData.items.slice(0, 1)
                                NotifCard {
                                    required property var modelData
                                    n: modelData
                                    mode: "list"
                                    showApp: false
                                    stack: grp.expanded ? 0 : grp.modelData.items.length - 1
                                    onStackToggled: win.toggle(grp.modelData)
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                visible: Notifs.count > 0
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Txt { Layout.fillWidth: true; size: 11; muted: true; text: "Arrastra un aviso a un lado para descartarlo" }
                Rectangle {
                    implicitHeight: 26; implicitWidth: clrT.implicitWidth + 18; radius: Theme.r(6)
                    color: clr.containsMouse ? Theme.fill2 : "transparent"
                    Txt { id: clrT; anchors.centerIn: parent; text: "Borrar todo"; color: Theme.p }
                    MouseArea { id: clr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
                }
            }
        }

        // =============================================================== Historial
        ColumnLayout {
            visible: win.tab === "historial"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Field {
                id: search
                Layout.fillWidth: true
                h: 30
                placeholder: "Buscar en el historial…"
                onTextChanged: win.query = text
            }
            // Filtros por app: una sola fila; si no caben, se desplaza en horizontal (rueda o arrastrar)
            Flickable {
                id: chipsFlick
                visible: win.histApps.length > 1
                Layout.fillWidth: true
                implicitHeight: chipsRow.implicitHeight + (contentWidth > width ? 8 : 0)
                contentWidth: chipsRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                clip: true
                // la rueda vertical también desplaza la fila
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    enabled: chipsFlick.interactive
                    onWheel: e => {
                        const d = e.angleDelta.x !== 0 ? -e.angleDelta.x : -e.angleDelta.y;
                        chipsFlick.contentX = Math.max(0, Math.min(chipsFlick.contentWidth - chipsFlick.width, chipsFlick.contentX + d * 0.6));
                    }
                }
                ScrollHint { flick: chipsFlick; horizontal: true; inset: 0 }
                Row {
                    id: chipsRow
                    spacing: 5
                    Repeater {
                        model: [{ key: "", app: "Todas" }].concat(win.histApps)
                        Rectangle {
                            required property var modelData
                            readonly property bool on: win.appFilter === modelData.key
                            implicitHeight: 22; implicitWidth: fT.implicitWidth + 16; radius: Theme.ctl(22)
                            color: on ? Theme.pc : fMa.containsMouse ? Theme.fill2 : "transparent"
                            border.width: on ? 0 : 1; border.color: Theme.ov
                            Txt { id: fT; anchors.centerIn: parent; text: parent.modelData.app; size: 11; weight: Font.Medium; color: parent.on ? Theme.pcText : Theme.t }
                            MouseArea { id: fMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.appFilter = parent.on ? "" : parent.modelData.key }
                        }
                    }
                }
            }
            Item {   // vacío
                visible: win.histRows.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: hempty.implicitHeight + 24
                ColumnLayout {
                    id: hempty
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { Layout.alignment: Qt.AlignHCenter; name: Notifs.keepHistory ? "clock" : "info"; size: 24; color: Theme.tv; opacity: 0.6 }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter; muted: true
                        text: !Notifs.keepHistory ? "El historial está desactivado" : win.query || win.appFilter ? "Nada coincide" : "El historial está vacío"
                    }
                }
            }
            Flickable {
                id: hflick
                visible: win.histRows.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: hlist.implicitHeight
                contentHeight: hlist.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollHint { flick: hflick; inset: 0 }
                ColumnLayout {
                    id: hlist
                    width: hflick.width
                    spacing: 4
                    Repeater {
                        model: win.histRows
                        Item {
                            id: hr
                            required property var modelData
                            readonly property bool header: modelData.header !== undefined
                            Layout.fillWidth: true
                            implicitHeight: header ? 24 : hcol.implicitHeight + 14
                            HoverHandler { id: hh }
                            Txt {
                                visible: hr.header
                                anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 3 }
                                text: hr.modelData.header ?? ""; size: 11; muted: true; weight: Font.DemiBold
                            }
                            Rectangle {
                                visible: !hr.header
                                anchors.fill: parent
                                radius: Theme.r(6)
                                color: hh.hovered ? Theme.fill2 : "transparent"
                                border.width: hr.modelData.urgency === 2 ? 1 : 0
                                border.color: Theme.danger
                            }
                            MouseArea {
                                id: hMa
                                visible: !hr.header
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                // copia el texto del aviso
                                onClicked: Shell.exec(["wl-copy", (hr.modelData.summary ?? "") + (hr.modelData.body ? "\n" + hr.modelData.body : "")])
                            }
                            RowLayout {
                                id: hcol
                                visible: !hr.header
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7; leftMargin: 8 }
                                spacing: 9
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: 22; implicitHeight: 22; radius: Theme.r(6); color: Theme.s4
                                    readonly property string ic: {
                                        const i = String(hr.modelData.icon ?? "");
                                        if (i === "") return "";
                                        if (i.startsWith("/")) return "file://" + i;
                                        if (i.startsWith("file:") || i.startsWith("image:")) return i;
                                        return Quickshell.iconPath(i, true) || "";
                                    }
                                    Txt { anchors.centerIn: parent; visible: hic.status !== Image.Ready; text: String(hr.modelData.app || "?").charAt(0).toUpperCase(); size: 10.5; weight: Font.DemiBold }
                                    Image { id: hic; anchors.centerIn: parent; width: 15; height: 15; sourceSize: Qt.size(30, 30); source: parent.ic; asynchronous: true; visible: status === Image.Ready }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Txt { Layout.fillWidth: true; text: (hr.modelData.app ?? "") + (hr.modelData.summary ? " · " + hr.modelData.summary : ""); weight: Font.Medium; size: 12 }
                                        Txt { text: hr.header ? "" : Notifs.agoT(hr.modelData.t); size: 10.5; muted: true; tabular: true }
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: hr.modelData.body ?? ""
                                        muted: true; size: 11.5
                                        wrapMode: Text.Wrap; maximumLineCount: 2
                                    }
                                }
                                IconBtn {
                                    Layout.alignment: Qt.AlignTop
                                    opacity: hh.hovered ? 1 : 0
                                    implicitWidth: 20; implicitHeight: 20; radius: Theme.r(5)
                                    icon: "x"; iconSize: 10; fg: Theme.tv
                                    tooltip: "Quitar del historial"
                                    onClicked: Notifs.forget(hr.modelData.uid)
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                visible: Notifs.history.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Txt { Layout.fillWidth: true; size: 11; muted: true; text: Notifs.history.length + (Notifs.history.length === 1 ? " aviso guardado" : " avisos guardados") + " · clic para copiar" }
                Rectangle {
                    implicitHeight: 26; implicitWidth: chT.implicitWidth + 18; radius: Theme.r(6)
                    color: ch.containsMouse ? Theme.fill2 : "transparent"
                    Txt { id: chT; anchors.centerIn: parent; text: "Vaciar historial"; color: Theme.p }
                    MouseArea { id: ch; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearHistory() }
                }
            }
        }
    }
}
