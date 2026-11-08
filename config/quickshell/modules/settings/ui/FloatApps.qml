// Ajustes › Escritorio y gestos › «Apps en ventana flotante» (la tarjeta y el tamaño están en sections/Escritorio.qml,
// que guarda: así el índice de búsqueda y «Restaurar valores por defecto» ven las claves): apps que se abren flotando
// al centro en vez de en el mosaico. Ajustes "floatApps" (clases de ventana) y "floatAppsSize"; las reglas
// hf-float-apps / hf-float-apps-compact las genera config/apply/35-windows.py y WinMode.qml no las vuelve a mosaico.
// Arriba, grupos de apps por tarea (cada interruptor añade o quita todas las de su grupo); debajo, las de la lista
// que tienes instaladas (con × para quitarlas una a una) y un buscador entre las ventanas abiertas y las apps
// instaladas para añadir cualquier otra por su clase.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root
    spacing: 10
    signal apply(var list)        // nueva lista de clases → Settings.set("floatApps", …) en Escritorio.qml

    // Mismas clases que los valores por defecto de config/defaults/settings.json (floatApps)
    readonly property var groups: [
        { key: "archivos", label: "Archivos", sub: "Nautilus, Thunar, Nemo, PCManFM", classes: ["org.gnome.Nautilus", "thunar", "nemo", "pcmanfm"] },
        { key: "imagenes", label: "Imágenes", sub: "Loupe, Ojo de GNOME, imv, swayimg, Ristretto", classes: ["org.gnome.Loupe", "org.gnome.eog", "eog", "imv", "swayimg", "org.xfce.ristretto"] },
        { key: "audio", label: "Audio", sub: "Decibels, Amberol, Gapless", classes: ["org.gnome.Decibels", "io.bassi.Amberol", "com.github.neithern.g4music"] },
        { key: "video", label: "Vídeo", sub: "mpv, Celluloid, Showtime, Totem, VLC", classes: ["mpv", "io.github.celluloid_player.Celluloid", "org.gnome.Showtime", "org.gnome.Totem", "vlc"] },
        { key: "calc", label: "Calculadora", sub: "Calculadora de GNOME, Qalculate", classes: ["org.gnome.Calculator", "qalculate-gtk"] },
        { key: "comprimidos", label: "Archivos comprimidos", sub: "File Roller, Xarchiver", classes: ["org.gnome.FileRoller", "xarchiver"] }
    ]
    readonly property var preset: groups.reduce((a, g) => a.concat(g.classes), [])

    readonly property var list: { const v = Settings.get("floatApps", []); return Array.isArray(v) ? v : []; }
    readonly property var lower: list.map(c => String(c).toLowerCase())
    function has(cls): bool { return lower.includes(String(cls).toLowerCase()); }
    function groupOn(g): bool { return g.classes.some(c => has(c)); }
    function setGroup(g, on): void {
        const out = list.filter(c => !g.classes.some(x => x.toLowerCase() === String(c).toLowerCase()));
        apply(on ? out.concat(g.classes) : out);
    }
    function add(cls): void { cls = String(cls ?? "").trim(); if (/^[A-Za-z0-9._-]{1,120}$/.test(cls) && !has(cls)) apply(list.concat([cls])); }
    function remove(cls): void { apply(list.filter(c => String(c).toLowerCase() !== String(cls).toLowerCase())); }

    // Entrada .desktop de una clase (null si no está instalada)
    function entry(cls): var {
        DesktopEntries.applications.values.length;
        return DesktopEntries.byId(cls) ?? DesktopEntries.byId(String(cls).toLowerCase())
            ?? DesktopEntries.applications.values.find(e => String(e.startupClass ?? "").toLowerCase() === String(cls).toLowerCase()) ?? null;
    }
    function iconOf(e, cls): string {
        const n = e?.icon ?? String(cls).toLowerCase();
        return n.startsWith("/") ? "file://" + n : (Quickshell.iconPath(n, true) || "");
    }
    // Lo de la lista que se ve: lo instalado y lo añadido a mano (las del grupo sin instalar no se enseñan)
    readonly property var shown: {
        DesktopEntries.applications.values.length;
        return list.map(c => ({ cls: c, e: entry(c) })).filter(x => x.e || !preset.some(p => p.toLowerCase() === String(x.cls).toLowerCase()));
    }
    readonly property int hidden: list.length - shown.length

    // Candidatos para añadir: ventanas abiertas y apps instaladas (clase = StartupWMClass o el id del .desktop)
    property string query: ""
    readonly property var candidates: {
        DesktopEntries.applications.values.length;
        const seen = {}, out = [];
        const push = (cls, name, e, open) => {
            const k = String(cls ?? "").toLowerCase();
            if (!k || seen[k] || has(cls) || !/^[A-Za-z0-9._-]{1,120}$/.test(cls)) return;
            seen[k] = true; out.push({ cls: cls, name: name || cls, e: e, open: open });
        };
        for (const c of HyprClients.clients) {
            if ((c.workspace?.id ?? 0) <= 0 || /^(org\.quickshell|hf-webapp\.qml6)$/.test(c.class ?? "")) continue;
            const e = HyprClients.entryFor(c.class);
            push(c.class, e?.name ?? HyprClients.appName(c.class), e, true);
        }
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            push(e.startupClass || String(e.id ?? "").replace(/\.desktop$/, ""), e.name, e, false);
        }
        const q = query.trim().toLowerCase();
        const r = q ? out.filter(x => x.name.toLowerCase().includes(q) || x.cls.toLowerCase().includes(q)) : out.filter(x => x.open);
        return r.sort((a, b) => (b.open - a.open) || a.name.localeCompare(b.name)).slice(0, 8);
    }

    Txt {
        Layout.fillWidth: true
        text: "Estas apps se abren flotando en el centro de la pantalla en vez de repartirse en el mosaico. "
            + "Las calculadoras y los reproductores de audio pequeños conservan su tamaño. No cambia el modo flotante ni el PiP."
        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 22
        rowSpacing: 0
        Repeater {
            model: root.groups
            SwRow {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                separator: index > 1
                label: modelData.label
                sub: modelData.sub
                checked: root.groupOn(modelData)
                onToggled: v => root.setGroup(modelData, v)
            }
        }
    }
    // ---------- en la lista ----------
    Divider { vertical: false; Layout.fillWidth: true }
    RowLayout {
        Layout.fillWidth: true
        Txt { text: "En la lista"; weight: Font.DemiBold }
        Txt {
            Layout.fillWidth: true
            text: root.shown.length + (root.shown.length === 1 ? " app" : " apps") + (root.hidden > 0 ? " · y " + root.hidden + " del grupo que no tienes instaladas" : "")
            muted: true; size: 11.5; elide: Text.ElideRight
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: root.shown.length > 0
        Repeater {
            model: root.shown
            Rectangle {
                id: chip
                required property var modelData
                implicitHeight: 30
                implicitWidth: chipRow.implicitWidth + 16
                radius: 15
                color: Theme.fill2
                border.width: 1; border.color: Theme.ov
                RowLayout {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 6
                    Image {
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        visible: source != ""
                        source: root.iconOf(chip.modelData.e, chip.modelData.cls)
                        sourceSize: Qt.size(32, 32); asynchronous: true; smooth: true
                    }
                    Txt { text: chip.modelData.e?.name ?? chip.modelData.cls; size: 12 }
                    Mono { visible: !!chip.modelData.e; text: chip.modelData.cls; size: 10.5 }
                    IconBtn {
                        implicitWidth: 18; implicitHeight: 18; radius: 9
                        icon: "x"; iconSize: 10; tooltip: "Quitar de la lista"
                        onClicked: root.remove(chip.modelData.cls)
                    }
                }
            }
        }
    }

    // ---------- añadir ----------
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field {
            id: q
            Layout.fillWidth: true
            Layout.maximumWidth: 380
            h: 32
            placeholder: "Buscar una app instalada o escribir su clase de ventana…"
            onTextChanged: root.query = text
            onAccepted: {
                const c = root.candidates[0];
                if (c) root.add(c.cls); else root.add(text.trim());
                text = "";
            }
        }
        Button {
            h: 32
            text: "Añadir clase"
            enabled: /^[A-Za-z0-9._-]{1,120}$/.test(q.text.trim()) && !root.has(q.text.trim())
            onClicked: { root.add(q.text.trim()); q.text = ""; }
        }
        Item { Layout.fillWidth: true }
    }
    Txt {
        Layout.fillWidth: true
        visible: root.candidates.length > 0
        text: root.query.trim() ? "Resultados" : "Abiertas ahora"
        muted: true; size: 11.5
    }
    Repeater {
        model: root.candidates
        Rectangle {
            id: cand
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.r(6)
            color: cma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 10
                Image {
                    Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    source: root.iconOf(cand.modelData.e, cand.modelData.cls)
                    sourceSize: Qt.size(44, 44); asynchronous: true; smooth: true
                }
                Txt { text: cand.modelData.name; elide: Text.ElideRight; Layout.maximumWidth: 260 }
                Mono { Layout.fillWidth: true; text: cand.modelData.cls + (cand.modelData.open ? " · abierta" : "") }
                Txt { text: "+ Añadir"; color: Theme.p; weight: Font.DemiBold; size: 12 }
            }
            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.add(cand.modelData.cls) }
        }
    }
    Txt {
        Layout.fillWidth: true
        visible: root.candidates.length === 0 && root.query.trim() === ""
        text: "Abre la app que quieras añadir para verla aquí, o búscala por su nombre."
        muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }
}
