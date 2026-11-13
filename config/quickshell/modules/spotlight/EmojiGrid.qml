// Emojis dentro de Spotlight (prefijo «;», Super + . abre Spotlight ya en este modo).
// - Busca en español o inglés (sin tildes: «corazon» encuentra «corazón»).
// - Recientes arriba (~/.local/state/hyprfrijol/emoji-recent.json) y luego los grupos de Unicode.
// - ←↑↓→ elegir · Intro: copiar y escribirlo en la ventana (si clipboardAutoPaste) · Mayús+Intro: lo contrario
//   · Tab / Mayús+Tab: grupo siguiente / anterior. Clic = elegir.
// Datos: config/emoji/emojis.json (lo genera dev/gen-emoji.py a partir de los nombres CLDR en español e inglés).
// Requiere wl-clipboard; wtype para escribirlo directamente.
//   EmojiGrid { query: "corazón"; active: true }   ·   key(e) (desde el campo de Spotlight) → true si la usó
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"

Item {
    id: root
    property string query: ""
    property bool active: false
    readonly property bool autoPaste: Settings.get("clipboardAutoPaste", true) !== false
    readonly property string emojiFont: "Noto Color Emoji"
    readonly property real cell: 44

    property var all: []          // [[emoji, es, en, grupo, claves]]
    property var hay: []          // texto de búsqueda normalizado, mismo índice que all
    property var groups: []       // [[id, título]]
    property var recent: []       // emojis (cadenas)
    property int sel: 0           // posición en `flat`
    property string activeGroup: ""
    readonly property var cur: all[flat[sel]] ?? null

    function norm(s: string): string {
        return (s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    }
    readonly property var byEmoji: {
        const m = {};
        all.forEach((e, i) => m[e[0]] = i);
        return m;
    }
    // Secciones visibles: [{ id, title, items: [índices en all] }]
    readonly property var sections: {
        if (!active) return [];
        const q = norm(query.trim());
        if (q) {
            const words = q.split(/\s+/);
            const starts = [], rest = [];
            for (let i = 0; i < hay.length; i++) {
                const h = hay[i];
                if (!words.every(w => h.includes(w))) continue;
                (h.startsWith(words[0]) || h.includes(" " + words[0]) ? starts : rest).push(i);
            }
            const found = starts.concat(rest).slice(0, 360);
            return found.length ? [{ id: "resultados", title: "Resultados · " + found.length, items: found }] : [];
        }
        const out = [];
        const rec = recent.map(e => byEmoji[e]).filter(i => i !== undefined);
        if (rec.length) out.push({ id: "recientes", title: "Recientes", items: rec });
        for (const g of groups) {
            const items = [];
            for (let i = 0; i < all.length; i++) if (all[i][3] === g[0]) items.push(i);
            out.push({ id: g[0], title: g[1], items: items });
        }
        return out;
    }
    // Lista lineal para el teclado: índices en all, en orden de pantalla
    readonly property var flat: {
        const f = [];
        for (const s of sections) for (const i of s.items) f.push(i);
        return f;
    }
    readonly property int cols: Math.max(6, Math.floor((list.width - 2) / cell))
    // Filas del ListView: cabeceras y filas de celdas (cada celda = posición en flat)
    readonly property var rows: {
        const r = [];
        let pos = 0;
        for (const s of sections) {
            r.push({ type: "head", text: s.title, group: s.id });
            for (let k = 0; k < s.items.length; k += cols) {
                const cells = [];
                for (let j = k; j < Math.min(k + cols, s.items.length); j++) cells.push(pos + j);
                r.push({ type: "cells", cells: cells, group: s.id });
            }
            pos += s.items.length;
        }
        return r;
    }
    function rowOf(p: int): int {
        for (let i = 0; i < rows.length; i++) if (rows[i].type === "cells" && rows[i].cells.includes(p)) return i;
        return -1;
    }
    function select(p: int): void {
        if (!flat.length) return;
        sel = Math.max(0, Math.min(flat.length - 1, p));
        const r = rowOf(sel);
        if (r >= 0) list.positionViewAtIndex(r === 1 ? 0 : r, ListView.Contain);
    }
    function vertical(d: int): void {
        const r = rowOf(sel);
        if (r < 0) return;
        const col = rows[r].cells.indexOf(sel);
        let t = r + d;
        while (t >= 0 && t < rows.length && rows[t].type !== "cells") t += d;
        if (t < 0 || t >= rows.length) return;
        const cells = rows[t].cells;
        select(cells[Math.min(col, cells.length - 1)]);
    }
    function jumpGroup(d: int): void {
        const heads = rows.map((r, i) => r.type === "head" ? i : -1).filter(i => i >= 0);
        if (!heads.length) return;
        const cur = rowOf(sel);
        let k = heads.length - 1;
        while (k > 0 && heads[k] > cur) k--;
        k = Math.max(0, Math.min(heads.length - 1, k + d));
        goToHead(heads[k]);
    }
    function goToHead(h: int): void {
        if (h + 1 < rows.length && rows[h + 1].type === "cells") sel = rows[h + 1].cells[0];
        list.positionViewAtIndex(h, ListView.Beginning);
    }
    function goToGroup(id: string): void {
        const h = rows.findIndex(r => r.type === "head" && r.group === id);
        if (h >= 0) goToHead(h);
    }
    function pick(p: int, paste: bool): void {
        const e = all[flat[p]];
        if (!e) return;
        recent = [e[0], ...recent.filter(x => x !== e[0])].slice(0, 24);
        recentStore.setText(JSON.stringify(recent));
        Quickshell.execDetached(["wl-copy", "--", e[0]]);
        Shell.close();
        if (paste) Quickshell.execDetached(["sh", "-c", 'sleep 0.25; command -v wtype >/dev/null && wtype -- "$1"', "sh", e[0]]);
    }
    // Teclas del campo de Spotlight en este modo
    function key(e): bool {
        const k = e.key;
        if (k === Qt.Key_Right) select(sel + 1);
        else if (k === Qt.Key_Left) select(sel - 1);
        else if (k === Qt.Key_Down) vertical(1);
        else if (k === Qt.Key_Up) vertical(-1);
        else if (k === Qt.Key_PageDown) { for (let i = 0; i < 4; i++) vertical(1); }
        else if (k === Qt.Key_PageUp) { for (let i = 0; i < 4; i++) vertical(-1); }
        else if (k === Qt.Key_Tab) jumpGroup(1);
        else if (k === Qt.Key_Backtab) jumpGroup(-1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) pick(sel, (e.modifiers & Qt.ShiftModifier) ? !autoPaste : autoPaste);
        else return false;
        return true;
    }

    onActiveChanged: if (active) { sel = 0; recentStore.reload(); if (!all.length) emojiData.reload(); Qt.callLater(() => list.positionViewAtBeginning()); }
    onQueryChanged: { sel = 0; list.positionViewAtBeginning(); }

    FileView {
        id: emojiData
        path: Paths.root + "/config/emoji/emojis.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.groups = d.groups;
                root.hay = d.emojis.map(e => root.norm(e[1] + " " + e[2] + " " + e[4]));
                root.all = d.emojis;
            } catch (e) { console.warn("emojis.json:", e); }
        }
    }
    FileView {
        id: recentStore
        path: Paths.state + "/emoji-recent.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { root.recent = JSON.parse(text()) || []; } catch (e) { root.recent = []; } }
        onLoadFailed: root.recent = []
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Grupos: atajo a cada sección (se oculta al buscar)
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: root.query.trim() === ""
            spacing: 2
            Repeater {
                model: [["recientes", "", "clock"], ["caras", "😀"], ["personas", "👋"], ["naturaleza", "🌿"], ["comida", "🍕"],
                        ["viajes", "✈️"], ["actividades", "⚽"], ["objetos", "💡"], ["simbolos", "❤️"], ["banderas", "🏁"]]
                Rectangle {
                    required property var modelData
                    readonly property bool here: root.activeGroup === modelData[0]
                    visible: modelData[0] !== "recientes" || root.recent.length > 0
                    width: 38; height: 30; radius: Theme.r(7)
                    color: here ? Theme.fill2 : tabMa.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                    Rectangle {
                        visible: parent.here
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: 14; height: 2; radius: 1; color: Theme.p
                    }
                    Icon { visible: parent.modelData[2] !== undefined; anchors.centerIn: parent; name: parent.modelData[2] ?? ""; color: Theme.tv }
                    Text {
                        visible: parent.modelData[2] === undefined
                        anchors.centerIn: parent
                        text: parent.modelData[1]
                        font.family: root.emojiFont
                        font.pixelSize: 17
                        opacity: parent.here ? 1 : 0.75
                    }
                    MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goToGroup(parent.modelData[0]) }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400
                model: root.rows
                onContentYChanged: {
                    const i = indexAt(10, contentY + 4);
                    if (i >= 0) root.activeGroup = root.rows[i]?.group ?? "";
                }
                onModelChanged: if (root.rows.length) root.activeGroup = root.rows[0].group
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.type === "head" ? 26 : root.cell
                    Txt {
                        visible: rowItem.modelData.type === "head"
                        anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 4 }
                        text: rowItem.modelData.text ?? ""
                        size: 11; weight: Font.DemiBold; muted: true
                    }
                    Row {
                        visible: rowItem.modelData.type === "cells"
                        Repeater {
                            model: rowItem.modelData.cells ?? []
                            Rectangle {
                                id: cellRect
                                required property int modelData
                                readonly property bool on: root.sel === modelData
                                width: root.cell; height: root.cell; radius: Theme.r(8)
                                color: on ? Theme.selBg : cellMa.containsMouse ? Theme.fill2 : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: root.all[root.flat[cellRect.modelData]]?.[0] ?? ""
                                    font.family: root.emojiFont
                                    font.pixelSize: 24
                                    scale: cellMa.containsMouse ? 1.15 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                }
                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.sel = cellRect.modelData
                                    onClicked: root.pick(cellRect.modelData, root.autoPaste)
                                }
                            }
                        }
                    }
                }
            }
            Txt {
                anchors.centerIn: parent
                visible: root.flat.length === 0
                text: root.all.length ? "Ningún emoji coincide con «" + root.query.trim() + "»" : "Cargando emojis…"
                muted: true
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.ov }

        // Vista previa del elegido
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 12
            Text {
                text: root.cur?.[0] ?? ""
                font.family: root.emojiFont
                font.pixelSize: 28
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt { Layout.fillWidth: true; text: root.cur ? root.cur[1].charAt(0).toUpperCase() + root.cur[1].slice(1) : ""; weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: root.cur?.[2] ?? ""; size: 11; muted: true }
            }
            Btn {
                visible: root.cur !== null
                kind: "primary"; h: 30; padX: 14
                text: root.autoPaste ? "Escribir  ↵" : "Copiar  ↵"
                onClicked: root.pick(root.sel, root.autoPaste)
            }
        }
    }
}
