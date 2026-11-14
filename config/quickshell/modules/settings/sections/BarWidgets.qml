// Ajustes › Widgets de la barra — qué widgets hay, en qué isla y en qué orden (arrastrando o con el teclado), sus
// opciones, clic derecho y rueda propios y los widgets propios. barModules (encendidos) · barOrder (islas y orden;
// Settings.barZone) · barActions · barCustom · barWeatherText · barStatsStyle · barStatsShow. Lo pinta bar/BarWidget.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12

    BarTabs { current: "barwidgets" }   // Barra | Widgets

    // id → [nombre, icono, qué hace]
    readonly property var info: ({
        clima: ["Clima", "cloud", "temperatura · clic: próximas horas y 3 días"],
        recursos: ["Sistema", "cpu", "CPU, GPU, RAM, disco, red y temperatura · clic: núcleos, procesos, discos y red"],
        impresora: ["Impresora 3D", "printer", Printer.configured ? "estado y progreso · clic: cámara, temperaturas y pausa" : "configura la dirección en Ajustes › Escritorio"],
        bongo: ["Gato bongo", "smile", "toca el tambor mientras escribes"],
        pomodoro: ["Pomodoro", "clock", "tiempo de foco y descansos · también en el centro de control"],
        cafeina: ["Cafeína", "coffee", "no apagar la pantalla · clic derecho: 1 hora"],
        portapapeles: ["Portapapeles", "clipboard", "abre el historial en Spotlight"],
        dictado: ["Micrófono", "mic", "un botón: dictar, hablar con el asistente o silenciar (clic derecho cambia de modo)"],
        voz: ["Botones de voz", "audio_lines", "dictado, conversación, silenciar las respuestas habladas y el micrófono"],
        ia: ["Asistente de IA", "ai", "abre el panel del asistente"],
        ajustes: ["Ajustes", "gear", "la tuerca: abre esta ventana"]
    })
    function name(id: string): string {
        if (id.startsWith("sep:")) return "Separador";
        if (id.startsWith("propio:")) return Settings.barCustomList.find(c => "propio:" + c.id === id)?.name || "Widget propio";
        return info[id]?.[0] ?? id;
    }
    function icon(id: string): string {
        if (id.startsWith("sep:")) return "minus";
        if (id.startsWith("propio:")) return Settings.barCustomList.find(c => "propio:" + c.id === id)?.icon || "code";
        return info[id]?.[1] ?? "puzzle";
    }
    // Separadores: se añaden al final de la isla del elegido (o de la derecha) y se quitan sin más
    function addSep(): void {
        const id = "sep:" + Date.now().toString(36);
        moveTo(id, sel ? zoneOf(sel) : "derecha", "");
        sel = id;
    }
    function removeSep(id: string): void {
        const o = Settings.barOrder;
        Settings.set("barOrder", { izquierda: o.izquierda.filter(x => x !== id), derecha: o.derecha.filter(x => x !== id) });
        if (sel === id) sel = "";
    }
    readonly property bool movable: sel !== "" && (sel.startsWith("sep:") || Settings.barHas(sel))
    function setOn(id: string, v: bool): void {
        Settings.set("barModules", Settings.barModuleList.filter(m => m !== id).concat(v ? [id] : []));
    }

    // ---------- Orden ----------
    // Mueve «id» a la isla «zone», delante de «before» (vacío: al final)
    function moveTo(id: string, zone: string, before: string): void {
        const o = Settings.barOrder;
        const izq = o.izquierda.filter(x => x !== id), der = o.derecha.filter(x => x !== id);
        const l = zone === "izquierda" ? izq : der;
        const i = before ? l.indexOf(before) : -1;
        l.splice(i < 0 ? l.length : i, 0, id);
        Settings.set("barOrder", { izquierda: izq, derecha: der });
    }
    function zoneOf(id: string): string { return Settings.barOrder.izquierda.includes(id) ? "izquierda" : "derecha"; }
    // Uno a la izquierda (-1) o a la derecha (+1) entre los que se ven
    function nudge(id: string, d: int): void {
        const z = zoneOf(id), v = Settings.barZone(z), i = v.indexOf(id);
        if (d < 0 && i > 0) moveTo(id, z, v[i - 1]);
        else if (d > 0 && i >= 0 && i < v.length - 1) moveTo(id, z, v[i + 2] ?? "");
    }
    // A la otra isla, por el lado que da a la isla de la que viene
    function swapSide(id: string): void {
        if (zoneOf(id) === "izquierda") moveTo(id, "derecha", Settings.barZone("derecha")[0] ?? "");
        else moveTo(id, "izquierda", "");
    }
    property string sel: ""             // elegido (clic o foco): lo mueven los botones de abajo
    property string dragId: ""
    property point dragPos

    Section {
        Layout.fillWidth: true
        title: "Distribución"
        headerRight: Button { text: "Ver todos · Super + G"; kind: "outline"; h: 26; onClicked: Shell.open("widgets") }
        Txt {
            Layout.fillWidth: true
            text: "Arrastra un widget para cambiarlo de orden o de isla. Con el teclado: Tab hasta él, ← → para moverlo y ↑ ↓ para "
                + "pasarlo a la otra isla. Los separadores se añaden abajo y se quitan con Supr."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Item {
            id: board
            Layout.fillWidth: true
            implicitHeight: zonesCol.implicitHeight

            ColumnLayout {
                id: zonesCol
                width: parent.width
                spacing: 8
                Repeater {
                    id: zoneRep
                    model: [["izquierda", "Isla izquierda", "tras los espacios y el título"], ["derecha", "Isla derecha", "antes de la bandeja y la hora"]]
                    ColumnLayout {
                        id: zoneBox
                        required property var modelData
                        readonly property string zone: modelData[0]
                        readonly property var ids: Settings.barZone(zone)
                        readonly property alias tiles: tileRep
                        readonly property alias area: zoneRect
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            spacing: 8
                            Txt { text: zoneBox.modelData[1]; size: 12; weight: Font.Medium }
                            Txt { text: zoneBox.modelData[2]; muted: true; size: 11 }
                        }
                        Rectangle {
                            id: zoneRect
                            Layout.fillWidth: true
                            implicitHeight: flow.implicitHeight + 16
                            radius: Theme.r(10)
                            color: Theme.fill2
                            border.width: root.dragId !== "" ? 1 : 0
                            border.color: Theme.ov
                            Flow {
                                id: flow
                                x: 8; y: 8
                                width: parent.width - 16
                                spacing: 8
                                // lo fijo de la isla (no se mueve)
                                Rectangle {
                                    visible: zoneBox.zone === "izquierda"
                                    width: fixL.implicitWidth + 16; height: 30; radius: Theme.r(7)
                                    color: "transparent"; border.width: 1; border.color: Theme.ov
                                    Txt { id: fixL; anchors.centerIn: parent; text: "Aplicaciones · Espacios · Título"; muted: true; size: 11.5 }
                                }
                                Repeater {
                                    id: tileRep
                                    model: zoneBox.ids
                                    Rectangle {
                                        id: tile
                                        required property string modelData
                                        readonly property string wid: modelData
                                        readonly property bool picked: root.sel === wid
                                        width: tileRow.implicitWidth + 20; height: 30
                                        radius: Theme.r(7)
                                        opacity: root.dragId === wid ? 0.35 : 1
                                        color: picked ? Theme.pc : Theme.glass
                                        border.width: activeFocus ? 2 : 1
                                        border.color: activeFocus || tma.containsMouse ? Theme.p : Theme.ov
                                        activeFocusOnTab: true
                                        onActiveFocusChanged: if (activeFocus) root.sel = wid
                                        Keys.onPressed: e => {
                                            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) root.nudge(wid, e.key === Qt.Key_Left ? -1 : 1);
                                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) root.swapSide(wid);
                                            else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && wid.startsWith("sep:")) root.removeSep(wid);
                                            else return;
                                            e.accepted = true;
                                        }
                                        Accessible.role: Accessible.Button
                                        Accessible.name: root.name(wid)
                                        RowLayout {
                                            id: tileRow
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Icon { name: root.icon(tile.wid); size: 13; color: tile.picked ? Theme.pcText : Theme.t }
                                            Txt { text: root.name(tile.wid); size: 12; color: tile.picked ? Theme.pcText : Theme.t }
                                        }
                                        MouseArea {
                                            id: tma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: root.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            property point start
                                            onPressed: e => { start = Qt.point(e.x, e.y); root.sel = tile.wid; }
                                            onPositionChanged: e => {
                                                if (!pressed) return;
                                                if (root.dragId === "" && Math.hypot(e.x - start.x, e.y - start.y) > 6) root.dragId = tile.wid;
                                                if (root.dragId !== "") root.dragPos = mapToItem(board, e.x, e.y);
                                            }
                                            preventStealing: true       // que el desplazamiento de Ajustes no se quede el arrastre
                                            onReleased: if (root.dragId !== "") { const id = root.dragId; root.dragId = ""; board.drop(root.dragPos, id); }
                                            onCanceled: root.dragId = ""
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: zoneBox.zone === "derecha"
                                    width: fixR.implicitWidth + 16; height: 30; radius: Theme.r(7)
                                    color: "transparent"; border.width: 1; border.color: Theme.ov
                                    Txt { id: fixR; anchors.centerIn: parent; text: "Bandeja · Estado y hora"; muted: true; size: 11.5 }
                                }
                                Txt {
                                    visible: zoneBox.ids.length === 0 && zoneBox.zone === "izquierda"
                                    height: 30; verticalAlignment: Text.AlignVCenter
                                    text: "suelta aquí"; muted: true; size: 11.5
                                }
                            }
                        }
                    }
                }
            }
            // Lo que se arrastra
            Rectangle {
                visible: root.dragId !== ""
                z: 10
                x: root.dragPos.x - width / 2; y: root.dragPos.y - height / 2
                width: ghostRow.implicitWidth + 20; height: 30
                radius: Theme.r(7)
                color: Theme.pc
                RowLayout {
                    id: ghostRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: root.icon(root.dragId); size: 13; color: Theme.pcText }
                    Txt { text: root.name(root.dragId); size: 12; color: Theme.pcText }
                }
            }
            // Suelta en «p» (coordenadas de board): delante del primer widget que quede después del punto al leer
            function drop(p: point, id: string): void {
                for (let z = 0; z < zoneRep.count; z++) {
                    const box = zoneRep.itemAt(z), a = box.area, q = a.mapFromItem(board, p.x, p.y);
                    if (q.x < -12 || q.y < -12 || q.x > a.width + 12 || q.y > a.height + 12) continue;
                    let before = "";
                    for (let i = 0; i < box.tiles.count; i++) {
                        const t = box.tiles.itemAt(i);
                        if (!t || t.wid === id) continue;
                        const c = t.mapToItem(a, t.width / 2, t.height / 2);
                        if (c.y - t.height / 2 > q.y || (Math.abs(c.y - q.y) <= t.height / 2 && q.x < c.x)) { before = t.wid; break; }
                    }
                    root.moveTo(id, box.zone, before);
                    return;
                }
            }
        }
        RowLayout {
            spacing: 8
            Txt { text: root.sel ? root.name(root.sel) + ":" : "Elige un widget para moverlo con los botones"; muted: !root.sel; size: 11.5 }
            Button { text: "‹ Antes"; h: 26; enabled: root.movable; onClicked: root.nudge(root.sel, -1) }
            Button { text: "Después ›"; h: 26; enabled: root.movable; onClicked: root.nudge(root.sel, 1) }
            Button { text: "A la otra isla"; h: 26; enabled: root.movable; onClicked: root.swapSide(root.sel) }
            Button { visible: root.sel.startsWith("sep:"); text: "Quitar"; h: 26; onClicked: root.removeSep(root.sel) }
            Item { Layout.fillWidth: true }
            Button { text: "Añadir separador"; h: 26; onClicked: root.addSep() }
            Button { text: "Orden de fábrica"; kind: "link"; h: 26; onClicked: { Settings.set("barOrder", null); root.sel = ""; } }
        }
    }

    // ---------- Catálogo ----------
    Section {
        Layout.fillWidth: true
        title: "Widgets"
        Repeater {
            model: Settings.barWidgetIds
            ColumnLayout {
                id: card
                required property string modelData
                required property int index
                readonly property bool on: Settings.barHas(modelData)
                Layout.fillWidth: true
                spacing: 0
                SwRow {
                    separator: card.index > 0
                    label: root.info[card.modelData][0]
                    sub: root.info[card.modelData][2]
                    checked: card.on
                    onToggled: v => root.setOn(card.modelData, v)
                }
                // Opciones de cada uno
                SwRow {
                    visible: card.modelData === "clima"
                    separator: false
                    label: "Mostrar el estado del cielo"; sub: "«18° nublado» siempre, no solo al pasar el cursor"; key: "barWeatherText"
                    enabled: card.on
                    Layout.leftMargin: 16
                }
                LabeledRow {
                    visible: card.modelData === "recursos"
                    label: "Estilo"; labelWidth: 140
                    Layout.leftMargin: 16
                    opacity: card.on ? 1 : 0.45
                    Seg {
                        model: [["barras", "Barritas"], ["grafica", "Gráfica"], ["texto", "Solo números"]]
                        current: Settings.get("barStatsStyle", "barras")
                        onPicked: k => Settings.set("barStatsStyle", k)
                    }
                }
                // Medidas del chip «Sistema» (barStatsShow); la ventana enseña siempre todas
                LabeledRow {
                    visible: card.modelData === "recursos"
                    label: "Medidas"; labelWidth: 140
                    Layout.leftMargin: 16
                    opacity: card.on ? 1 : 0.45
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [["cpu", "CPU"], ["gpu", "GPU"], ["ram", "RAM"], ["disco", "Disco"], ["red", "Red ↓↑"], ["temp", "Temperatura"]]
                            Chip {
                                required property var modelData
                                readonly property var list: { const v = Settings.get("barStatsShow", null); return Array.isArray(v) ? v : ["cpu", "ram", "gpu", "temp"]; }
                                h: 26
                                text: modelData[1]
                                on: list.includes(modelData[0])
                                // en el orden de la lista de arriba
                                onClicked: Settings.set("barStatsShow", on ? list.filter(x => x !== modelData[0])
                                                                           : ["cpu", "gpu", "ram", "disco", "red", "temp"].filter(x => x === modelData[0] || list.includes(x)))
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Clic derecho y rueda propios (barActions[id] = { rclick, up, down }) ----------
    Section {
        Layout.fillWidth: true
        title: "Clic derecho y rueda"
        Txt {
            Layout.fillWidth: true
            text: "Una orden propia para el clic derecho o la rueda de un widget (p. ej. «playerctl next» o «brightnessctl set 5%+»). "
                + "En blanco, el widget hace lo de siempre."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        LabeledRow {
            label: "Widget"; labelWidth: 140
            Dropdown {
                id: actW
                Layout.preferredWidth: 240
                model: Settings.barWidgetIds.concat(Settings.barCustomList.map(c => "propio:" + c.id)).map(id => [id, root.name(id)])
                current: "clima"
                onPicked: k => current = k
            }
        }
        Repeater {
            model: [["rclick", "Clic derecho"], ["up", "Rueda arriba"], ["down", "Rueda abajo"]]
            LabeledRow {
                id: actRow
                required property var modelData
                label: modelData[1]; labelWidth: 140
                Field {
                    Layout.fillWidth: true; h: 30; icon: ""
                    placeholder: "lo de siempre · Intro para guardar"
                    text: ((Settings.get("barActions", {}) ?? {})[actW.current] ?? {})[actRow.modelData[0]] ?? ""
                    onAccepted: {
                        const all = Object.assign({}, Settings.get("barActions", {}) ?? {});
                        const a = Object.assign({}, all[actW.current] ?? {});
                        if (text.trim()) a[actRow.modelData[0]] = text.trim(); else delete a[actRow.modelData[0]];
                        if (Object.keys(a).length) all[actW.current] = a; else delete all[actW.current];
                        Settings.set("barActions", all);
                    }
                }
            }
        }
    }

    // ---------- Widgets propios (barCustom; bar/CustomChip) ----------
    Section {
        id: own
        Layout.fillWidth: true
        title: "Widgets propios"
        property string editing: ""        // id del que se edita ("" = uno nuevo)
        function clear(): void { editing = ""; fName.text = ""; fCmd.text = ""; fEvery.text = ""; fIcon.text = ""; fClick.text = ""; fRclick.text = ""; }
        function save(): void {
            const c = { id: editing || Date.now().toString(36), name: fName.text.trim() || "Widget propio", cmd: fCmd.text.trim(),
                        interval: Math.max(2, parseInt(fEvery.text) || 10), icon: fIcon.text.trim(), click: fClick.text.trim(), rclick: fRclick.text.trim() };
            const l = Settings.barCustomList.slice();
            const i = l.findIndex(x => x.id === c.id);
            if (i >= 0) l[i] = c; else l.push(c);
            Settings.set("barCustom", l);
            if (i < 0) root.setOn("propio:" + c.id, true);
            clear();
        }
        Txt {
            Layout.fillWidth: true
            text: "Corre una orden cada pocos segundos y enseña lo que escribe: texto, o JSON {\"text\": …, \"icon\": …, \"tooltip\": …}. "
                + "Sin salida no ocupa sitio. Se colocan arriba, en Distribución, como los demás."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Repeater {
            model: Settings.barCustomList
            RowLayout {
                id: crow
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Icon { name: crow.modelData.icon || "code"; size: 14; color: Theme.t }
                Txt { text: crow.modelData.name; weight: Font.Medium; size: 12.5 }
                Txt { Layout.fillWidth: true; text: crow.modelData.cmd + " · cada " + crow.modelData.interval + " s"; muted: true; size: 11.5; font.family: Theme.mono }
                Sw { checked: Settings.barHas("propio:" + crow.modelData.id); onToggled: v => root.setOn("propio:" + crow.modelData.id, v) }
                Button {
                    text: "Editar"; h: 26
                    onClicked: {
                        const c = crow.modelData;
                        own.editing = c.id; fName.text = c.name ?? ""; fCmd.text = c.cmd ?? ""; fEvery.text = String(c.interval ?? 10);
                        fIcon.text = c.icon ?? ""; fClick.text = c.click ?? ""; fRclick.text = c.rclick ?? "";
                    }
                }
                Button {
                    text: "Quitar"; h: 26
                    onClicked: {
                        const id = crow.modelData.id;
                        Settings.set("barCustom", Settings.barCustomList.filter(x => x.id !== id));
                        root.setOn("propio:" + id, false);
                        if (own.editing === id) own.clear();
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8; rowSpacing: 8
            Field { id: fName; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Nombre (sale al pasar el cursor)" }
            Field { id: fEvery; Layout.preferredWidth: 160; h: 30; icon: ""; placeholder: "Cada (s) · 10" }
            Field { id: fCmd; Layout.fillWidth: true; Layout.columnSpan: 2; h: 30; icon: ""; placeholder: "Orden: p. ej. curl -s 'wttr.in/?format=%t'"; input.font.family: Theme.mono }
            Field { id: fIcon; Layout.fillWidth: true; Layout.columnSpan: 2; h: 30; icon: ""; placeholder: "Icono (opcional): globe, cpu, music, cloud, code…" }
            Field { id: fClick; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Al hacer clic (opcional)" }
            Field { id: fRclick; Layout.preferredWidth: 160; Layout.fillWidth: true; h: 30; icon: ""; placeholder: "Clic derecho (opcional)" }
        }
        RowLayout {
            Item { Layout.fillWidth: true }
            Button { visible: own.editing !== ""; text: "Cancelar"; h: 28; onClicked: own.clear() }
            Button { kind: "primary"; h: 28; text: own.editing ? "Guardar" : "Añadir"; enabled: fCmd.text.trim() !== "" || fIcon.text.trim() !== ""; onClicked: own.save() }
        }
    }
}
