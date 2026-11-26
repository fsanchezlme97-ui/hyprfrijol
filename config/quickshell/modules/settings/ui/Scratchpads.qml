// Ajustes › Escritorio y gestos › «Espacios ocultos con nombre» (ajuste "scratchpads" → config/apply/55-scratchpads.py;
// la sección, que guarda, está en sections/Escritorio.qml). Hasta cuatro, en orden: Super + F1 … F4.
import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 8
    property var pads: []
    signal apply(var list)
    // cada espacio con su hueco fijo (Super + Fn): el guardado si está libre y los demás por orden, como 55-scratchpads.py
    readonly property var slotted: {
        const list = pads.filter(p => p && typeof p === "object"), slot = [], free = [];
        list.forEach((p, i) => { if ([1, 2, 3, 4].includes(p.slot) && !slot.includes(p.slot)) slot[i] = p.slot; });
        for (let n = 1; n <= 4; n++) if (!slot.includes(n)) free.push(n);
        return list.map((p, i) => Object.assign({}, p, { slot: slot[i] ?? free.shift() })).filter(p => p.slot)
            .sort((a, b) => a.slot - b.slot);
    }
    function change(slot: int, patch: var): void { apply(slotted.map(p => p.slot === slot ? Object.assign({}, p, patch) : p)); }
    function add(): void {
        const used = slotted.map(p => p.slot), slot = [1, 2, 3, 4].find(n => !used.includes(n));
        if (slot) apply(slotted.concat([{ slot: slot, name: ["Música", "Chat", "Notas", "Extra"][slot - 1], apps: [] }]));
    }
    // al quitarlo, sus ventanas vuelven al espacio que estás viendo (si no, quedarían sin atajo que las enseñe)
    function remove(slot: int): void {
        const here = HyprClients.focusedMonitor?.activeWorkspace?.id ?? 1;
        for (const c of HyprClients.clients)
            if (c.workspace?.name === "special:hfpad-" + slot)
                Shell.dispatch('hl.dsp.window.move({ workspace = ' + here + ', follow = false, ' + WinMode.win(c.address) + ' })');
        apply(slotted.filter(p => p.slot !== slot));
        HyprClients.refresh();
    }

    Txt {
        Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "Un espacio que aparece encima y se esconde con su atajo: la música, el chat, las notas… Las apps que le pongas "
            + "abren dentro sin molestar. Super + Mayús + F1…F4 envía allí la ventana activa. (Aparte del de Super + S.)"
    }
    Repeater {
        // por número: así escribir en un nombre no rehace las filas
        model: root.slotted.length
        Expander {
            id: pad
            required property int index
            readonly property var info: root.slotted[index] ?? ({})
            readonly property int slot: info.slot ?? 0
            title: (info.name || "Espacio " + slot) + " · Super + F" + slot
            subtitle: (info.apps ?? []).length ? (info.apps ?? []).join(", ") : "sin apps asignadas"
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field {
                    Layout.fillWidth: true; h: 30; icon: ""
                    text: pad.info.name ?? ""
                    placeholder: "Nombre (Intro para guardar)"
                    onAccepted: root.change(pad.slot, { name: text.trim() })
                }
                Button { text: "Quitar"; onClicked: root.remove(pad.slot) }
            }
            FloatApps {
                Layout.fillWidth: true
                list: pad.info.apps ?? []
                groups: []
                intro: "Apps que abren en este espacio."
                onApply: l => root.change(pad.slot, { apps: l })
            }
        }
    }
    Button {
        visible: root.slotted.length < 4
        text: "Añadir un espacio"
        onClicked: root.add()
    }
}
