// Perfiles de actividad (vista "perfiles"): Trabajo · Diseño 3D · Juego · Personal.
// Un clic ejecuta scripts/hf-profile <perfil> (fondo, energía, avisos, apps, barra, pomodoro).
// Los valores de cada tarjeta salen del ajuste "profiles" (los mismos que usa hf-profile).
// «Cambiar solo»: reglas (ajuste "profileRules") que cambian de perfil al conectar un monitor, en un horario
// o al abrir ciertas apps. Funcionan aunque el panel esté cerrado (ProfilesAuto.qml).
// Teclas: ← → elegir · Intro aplicar · 1–4 directo · Esc cerrar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"

Overlay {
    id: win
    view: "perfiles"
    place: "center"
    dim: true
    panelWidth: 980
    panelHeight: card.implicitHeight

    property string current: ""
    property int sel: 0
    property var wallFiles: []        // nombres en <fondos>/perfiles/

    readonly property var order: ["trabajo", "diseno", "juego", "personal"]
    readonly property var scenes: ({
        lago:     { sky: "#8FA9B2", glow: "#F1E7D0", far: "#789199", near: "#45606A", label: "Lago" },
        bosque:   { sky: "#1C3631", glow: "#86C9A6", far: "#2E5A4B", near: "#173A30", label: "Bosque" },
        noche:    { sky: "#0F1626", glow: "#5B6FA8", far: "#1F2B45", near: "#121B2E", label: "Noche" },
        amanecer: { sky: "#2A3042", glow: "#E7B49B", far: "#5A627A", near: "#30364A", label: "Atardecer" }
    })
    // Igual que DEFAULTS en scripts/hf-profile
    readonly property var defaults: ({
        trabajo:  { name: "Trabajo", glyph: "T", scene: "lago", apps: [], avisos: "favoritos", energia: "balanced", barra: "fija", pomodoro: true },
        diseno:   { name: "Diseño 3D", glyph: "3D", scene: "bosque", apps: ["blender", "org.freecad.FreeCAD", "OrcaSlicer"], avisos: "normales", energia: "performance", barra: "fija", widgets: ["impresora"] },
        juego:    { name: "Juego", glyph: "J", scene: "noche", apps: ["steam", "com.heroicgameslauncher.hgl", "discord"], avisos: "silencio", energia: "performance", gamemode: true, barra: "oculta" },
        personal: { name: "Personal", glyph: "P", scene: "amanecer", apps: [], avisos: "normales", energia: "power-saver", barra: "fija" }
    })
    readonly property var userProfiles: Settings.get("profiles", ({}))
    function prof(k: string): var { return Object.assign({}, defaults[k] ?? {}, userProfiles?.[k] ?? {}); }

    function appNames(ids): string {
        const names = (ids ?? []).map(id => (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id))?.name).filter(n => n);
        return names.length ? names.join(", ") : "Ninguna";
    }
    function rows(k: string): var {
        const p = prof(k), r = [];
        const wf = wallFiles.find(f => f.toLowerCase().startsWith(k + "."));
        r.push({ k: "Fondo", v: p.wallpaper ? String(p.wallpaper).split("/").pop() : wf ? wf : (scenes[p.scene]?.label ?? "—") });
        r.push({ k: "Apps", v: appNames(p.apps) });
        r.push({ k: "Avisos", v: ({ favoritos: "Solo favoritos", silencio: "Silenciados", normales: "Normales" })[p.avisos] ?? "Normales" });
        r.push({ k: "Energía", v: p.gamemode ? "gamemode · máximo" : (({ balanced: "Equilibrado", performance: "Rendimiento", "power-saver": "Ahorro" })[p.energia] ?? "Equilibrado") });
        if (p.widgets?.length) r.push({ k: "Widgets", v: p.widgets.map(w => ({ impresora: "Impresora 3D", clima: "Clima", sistema: "Sistema" })[w] ?? w).join(", ") });
        else r.push({ k: "Barra", v: (({ fija: "Fija", flotante: "Flotante", oculta: "Oculta" })[p.barra] ?? "Fija") + (p.pomodoro ? " · pomodoro" : "") });
        return r;
    }

    function apply(k: string): void {
        current = k;
        Quickshell.execDetached([Paths.script("hf-profile"), k]);
    }

    // ---------- estado ----------
    FileView {
        path: Paths.state + "/profile"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: win.current = text().trim() || "trabajo"
        onLoadFailed: win.current = "trabajo"
    }
    Process {
        id: walls
        command: ["sh", "-c", 'P="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"; for d in "$HF_WALL_DIR" "$P/Fondos" "$P/Wallpapers"; do [ -n "$d" ] && ls "$d/perfiles" 2>/dev/null; done']
        stdout: StdioCollector { onStreamFinished: win.wallFiles = text.split("\n").filter(s => s) }
    }
    onShownChanged: if (shown) {
        sel = Math.max(0, order.indexOf(current));
        walls.running = true;
        Qt.callLater(() => keys.forceActiveFocus());
    }

    // ---------- Cambiar solo ----------
    // Reglas de «Cambiar solo»: las vigila ProfilesAuto.qml (siempre cargado; esta vista es diferida)
    property var auto: null
    readonly property var rules: auto?.rules ?? []
    function setRule(id: string, on: bool): void {
        Settings.set("profileRules", rules.map(r => r.id === id ? Object.assign({}, r, { on: on }) : r));
    }
    // ---------- interfaz ----------
    Glass {
        id: card
        anchors.fill: parent
        kind: "popup"
        implicitHeight: body.implicitHeight + 36

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) win.sel = (win.sel + 1) % 4;
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) win.sel = (win.sel + 3) % 4;
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { win.sel = e.key - Qt.Key_1; win.apply(win.order[win.sel]); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.apply(win.order[win.sel]);
                else if (e.key === Qt.Key_Escape) Shell.close();
                else return;
                e.accepted = true;
            }
        }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Txt { text: "Perfiles de actividad"; size: 16; weight: Font.DemiBold }
                    Txt { text: "Un clic cambia fondo, barra, apps abiertas, avisos y energía · Super + Alt + P siguiente perfil"; size: 11.5; muted: true }
                }
                Item { Layout.fillWidth: true }
                IconBtn { icon: "x"; Layout.preferredWidth: 28; Layout.preferredHeight: 28; Layout.alignment: Qt.AlignTop | Qt.AlignRight; onClicked: Shell.close() }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: win.order
                    delegate: Rectangle {
                        id: pc
                        required property string modelData
                        required property int index
                        readonly property var p: win.prof(modelData)
                        readonly property var sc: win.scenes[p.scene] ?? win.scenes.lago
                        readonly property bool active: win.current === modelData
                        readonly property bool focused: win.sel === index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.preferredHeight: 92 + info.implicitHeight + 22
                        radius: Theme.r(10)
                        color: pma.containsMouse ? Qt.alpha(Theme.t, 0.13) : Theme.fill2
                        clip: true
                        Behavior on color { ColorAnimation { duration: 140 } }

                        // Escena
                        Canvas {
                            id: scene
                            width: parent.width
                            height: 92
                            readonly property var s: pc.sc
                            onSChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const g = getContext("2d"), w = width, h = height;
                                g.reset();
                                // esquinas superiores redondeadas como la tarjeta
                                g.beginPath(); g.roundedRect(0, 0, w, h + 20, 10, 10); g.clip();
                                g.fillStyle = s.sky; g.fillRect(0, 0, w, h);
                                const rg = g.createRadialGradient(w * 0.5, h * 0.38, 0, w * 0.5, h * 0.38, w * 0.42);
                                rg.addColorStop(0, Qt.alpha(s.glow, 0.85)); rg.addColorStop(0.45, Qt.alpha(s.glow, 0.35)); rg.addColorStop(1, Qt.alpha(s.glow, 0));
                                g.fillStyle = rg; g.fillRect(0, 0, w, h);
                                // montañas lejanas (45 % del alto)
                                const top = h * 0.55, mh = h * 0.45;
                                const pts = [[0, .40], [.18, .10], [.35, .45], [.55, .05], [.75, .40], [1, .15], [1, 1], [0, 1]];
                                g.fillStyle = s.far; g.beginPath();
                                pts.forEach((q, i) => { const x = q[0] * w, y = top + q[1] * mh; i ? g.lineTo(x, y) : g.moveTo(x, y); });
                                g.closePath(); g.fill();
                                // banda cercana (22 %)
                                g.fillStyle = s.near; g.fillRect(0, h * 0.78, w, h * 0.22);
                            }
                        }
                        // Anillo: activo (p) o seleccionado con el teclado
                        Rectangle { anchors.fill: parent; radius: Theme.r(10); color: "transparent"; border.width: pc.active ? 2 : (pc.focused ? 1.5 : 0); border.color: pc.active ? Theme.p : Qt.alpha(Theme.p, 0.6); z: 3 }

                        Rectangle {
                            x: 10; y: 10
                            width: 30; height: 30; radius: Theme.r(7)
                            color: Qt.rgba(0, 0, 0, 0.35)
                            Txt { anchors.centerIn: parent; text: pc.p.glyph ?? pc.p.name.charAt(0); color: "#FFFFFF"; weight: Font.DemiBold; size: 12.5 }
                        }
                        Rectangle {
                            visible: pc.active
                            anchors { top: parent.top; right: parent.right; margins: 10 }
                            width: actTxt.implicitWidth + 16; height: 20; radius: Theme.r(6)
                            color: Theme.p
                            Txt { id: actTxt; anchors.centerIn: parent; text: "Activo"; size: 11; weight: Font.DemiBold; color: Theme.pText }
                        }

                        ColumnLayout {
                            id: info
                            anchors { left: parent.left; right: parent.right; top: scene.bottom; leftMargin: 12; rightMargin: 12; topMargin: 10 }
                            spacing: 5
                            Txt { text: pc.p.name; size: 14; weight: Font.DemiBold; Layout.bottomMargin: 2 }
                            Repeater {
                                model: win.rows(pc.modelData)
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Txt { text: parent.modelData.k; size: 11.5; muted: true; Layout.preferredWidth: 54; Layout.alignment: Qt.AlignTop }
                                    Txt {
                                        text: parent.modelData.v
                                        size: 11.5
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideNone
                                        maximumLineCount: 2
                                        verticalAlignment: Text.AlignTop
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: pma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = pc.index
                            onClicked: win.apply(pc.modelData)
                        }
                    }
                }
            }

            // Cambiar solo
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rulesCol.implicitHeight + 24
                radius: Theme.r(8)
                color: "transparent"
                border.width: 1
                border.color: Theme.ov
                ColumnLayout {
                    id: rulesCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 12
                    Txt { text: "Cambiar solo"; weight: Font.DemiBold }
                    Repeater {
                        model: win.rules
                        delegate: RowLayout {
                            id: ruleRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10
                            Toggle { checked: ruleRow.modelData.on; onToggled: v => win.setRule(ruleRow.modelData.id, v) }
                            Txt { text: ruleRow.modelData.label ?? ""; Layout.fillWidth: true; color: ruleRow.modelData.on ? Theme.t : Theme.tv }
                            Txt { text: "→ " + (win.prof(ruleRow.modelData.profile).name ?? ruleRow.modelData.profile); size: 11.5; muted: true }
                        }
                    }
                }
            }
        }
    }
}
