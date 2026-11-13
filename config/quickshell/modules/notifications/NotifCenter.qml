// Notificaciones del centro de control (QuickSettings.qml; campana de la barra = Shell.open("notificaciones")).
//  Recientes: agrupadas por aplicación (cabecera con icono, cuántas, desplegar/agrupar y descartar el grupo);
//             un grupo de 3 o más se ve apilado («+N») hasta que lo despliegas. «No molestar», borrar todo,
//             respuesta en línea, acciones e imágenes; arrastrar a un lado descarta.
//  Resumen: con 3 avisos o más, una tarjeta arriba resume en una o dos frases lo que pasó (hf-ai digest). Con el
//             modelo local (Ollama de proveedor o de respaldo) se hace sola al abrir el centro si llegó algo nuevo
//             (notifDigestAuto); si no, con «Resumir», porque los avisos irían a la nube.
//  Historial: lo que ha llegado (Notifs.history, también lo ya descartado), con búsqueda y filtro por app.
// Shell.open("notificaciones", "historial") abre el historial; con { app: "whatsapp" } ya filtrado.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    property string recentFilter: ""        // clave del grupo (app) en Recientes ("" = todas)
    // Al abrir el centro: arg = Shell.arg si se pidió esta sección, si no null
    function reset(a): void {
        win.dndMenu = false;
        win.tab = a === "historial" || (a && typeof a === "object") ? "historial" : "recientes";
        win.appFilter = a && typeof a === "object" ? String(a.app ?? "").toLowerCase() : "";
        win.query = "";
        search.text = "";
        win.recentFilter = "";
        if (digestAuto && digestStale && Notifs.count >= 3) digestRun();
    }

    // ---------- resumen de los avisos (hf-ai digest)
    readonly property var digestItems: Notifs.list.values.slice().reverse().slice(0, 30)
        .map(n => ({ app: Notifs.appOf(n), summary: Notifs.plain(n.summary), body: Notifs.plain(n.body) }))
    readonly property string digestKey: digestItems.map(n => n.app + n.summary + n.body).join("\n")
    property string digestFor: ""            // la lista de avisos que se resumió
    property var digest: null                // { text, local, error }
    readonly property bool digestStale: digestKey !== digestFor
    readonly property bool localAi: Settings.get("aiProvider", "") === "ollama" || Settings.get("aiFallbackProvider", "") === "ollama"
    readonly property bool digestAuto: localAi && Settings.get("notifDigestAuto", true) !== false && Settings.get("aiProvider", "") !== "off"
    function digestRun(): void {
        if (digestProc.running) return;
        digestFor = digestKey;
        digestProc.command = [Paths.script("hf-ai"), "digest", JSON.stringify(digestItems)];
        digestProc.running = true;
    }
    Process {
        id: digestProc
        stdout: StdioCollector {
            onStreamFinished: { try { win.digest = JSON.parse(text); } catch (e) { win.digest = { text: "", error: "No se pudo resumir" }; } }
        }
    }
    function isOpen(g): bool { return win.open[g.key] !== undefined ? win.open[g.key] : g.items.length < 3; }
    function toggle(g) { const o = Object.assign({}, open); o[g.key] = !isOpen(g); open = o; }

    readonly property var groups: Notifs.groupsOf(Notifs.list.values.slice().reverse())
    // Recientes filtrados por app (si la app filtrada ya no tiene avisos, se ven todas)
    readonly property var recentApps: groups.map(g => ({ key: g.key, app: g.app, n: g.items.length }))
    readonly property var shownGroups: recentFilter && groups.some(g => g.key === recentFilter) ? groups.filter(g => g.key === recentFilter) : groups

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

            // Resumen: una o dos frases con lo que pasó (y lo que pide atención primero)
            Rectangle {
                visible: Notifs.count >= 3 && Settings.get("aiProvider", "") !== "off"
                Layout.fillWidth: true
                implicitHeight: dcol.implicitHeight + 18
                radius: Theme.r(10)
                color: Qt.alpha(Theme.p, 0.08)
                border.width: 1; border.color: Qt.alpha(Theme.p, 0.22)
                ColumnLayout {
                    id: dcol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9; leftMargin: 11 }
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Icon { name: "sparkle"; size: 13; color: Theme.p
                            SequentialAnimation on opacity { running: digestProc.running && !Theme.still; loops: Animation.Infinite
                                onRunningChanged: if (!running) parent.opacity = 1
                                NumberAnimation { to: 0.3; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                        Txt { text: "Resumen"; weight: Font.DemiBold; size: 12.5 }
                        Txt { text: "· " + Notifs.count + " avisos"; muted: true; size: 11.5; tabular: true }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: !digestProc.running && (win.digest === null || win.digestStale || !!win.digest.error)
                            implicitHeight: 22; implicitWidth: dT.implicitWidth + 16; radius: Theme.r(6)
                            color: dMa.containsMouse ? Theme.fill2 : "transparent"
                            border.width: 1; border.color: Theme.ov
                            Txt { id: dT; anchors.centerIn: parent; size: 11; color: Theme.p
                                text: win.digest === null ? "Resumir" : win.digest.error ? "Reintentar" : "Actualizar" }
                            MouseArea { id: dMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.digestRun() }
                        }
                    }
                    Txt {
                        visible: digestProc.running || !!(win.digest?.text || win.digest?.error)
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        size: 12
                        muted: digestProc.running || !!win.digest?.error
                        text: digestProc.running ? "Leyendo los avisos…" : win.digest?.error ? win.digest.error : (win.digest?.text ?? "")
                    }
                    Txt {
                        visible: win.digest === null && !digestProc.running
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap; size: 11; muted: true
                        text: win.localAi ? "Lo resume el modelo local: nada sale del equipo" : "Los avisos se envían a tu asistente de IA para resumirlos"
                    }
                    Txt {
                        visible: !digestProc.running && !!win.digest?.text
                        size: 10.5; muted: true
                        text: (win.digest?.local ? "Modelo local" : "Asistente de IA") + (win.digestStale ? " · han llegado avisos nuevos" : "")
                    }
                }
            }
            AppChips {
                visible: win.groups.length > 1
                Layout.fillWidth: true
                apps: win.recentApps
                current: win.groups.some(g => g.key === win.recentFilter) ? win.recentFilter : ""
                onPicked: k => win.recentFilter = k
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
                        model: win.shownGroups
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
                    // con un filtro de app, borra solo los de esa app
                    readonly property bool some: win.shownGroups.length < win.groups.length
                    Txt { id: clrT; anchors.centerIn: parent; text: parent.some ? "Borrar estos" : "Borrar todo"; color: Theme.p }
                    MouseArea {
                        id: clr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.some ? Notifs.dismissAll(win.shownGroups.flatMap(g => g.items)) : Notifs.clearAll()
                    }
                }
            }
        }

        // =============================================================== Historial
        ColumnLayout {
            id: histCol
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
            // Filtros por app: una sola fila; si no caben, se desplaza en horizontal (AppChips.qml)
            AppChips {
                visible: win.histApps.length > 1
                Layout.fillWidth: true
                apps: win.histApps
                current: win.appFilter
                onPicked: k => win.appFilter = k
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
                                onClicked: { Shell.exec(["wl-copy", (hr.modelData.summary ?? "") + (hr.modelData.body ? "\n" + hr.modelData.body : "")]); copiedT.restart(); }
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
            // «Copiado» un momento al copiar un aviso; «Deshacer» unos segundos tras vaciar el historial
            Timer { id: copiedT; interval: 1400 }
            property var undoHist: []
            Timer { id: undoT; interval: 8000; onTriggered: histCol.undoHist = [] }
            RowLayout {
                id: histFoot
                visible: Notifs.history.length > 0 || histCol.undoHist.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Txt {
                    Layout.fillWidth: true; size: 11
                    muted: !copiedT.running
                    color: copiedT.running ? Theme.p : Theme.tv
                    text: copiedT.running ? "Copiado"
                        : histCol.undoHist.length && !Notifs.history.length ? "Historial vaciado"
                        : Notifs.history.length + (Notifs.history.length === 1 ? " aviso guardado" : " avisos guardados") + " · clic para copiar"
                }
                Rectangle {
                    readonly property bool undo: histCol.undoHist.length > 0 && !Notifs.history.length
                    implicitHeight: 26; implicitWidth: chT.implicitWidth + 18; radius: Theme.r(6)
                    color: ch.containsMouse ? Theme.fill2 : "transparent"
                    Txt { id: chT; anchors.centerIn: parent; text: parent.undo ? "Deshacer" : "Vaciar historial"; color: Theme.p }
                    MouseArea {
                        id: ch; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const col = histCol;
                            if (parent.undo) { Notifs.restoreHistory(col.undoHist); col.undoHist = []; undoT.stop(); }
                            else { col.undoHist = Notifs.history.slice(); Notifs.clearHistory(); undoT.restart(); }
                        }
                    }
                }
            }
        }
    }
}
