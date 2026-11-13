// Ajustes › Ratón y panel táctil — ratón (velocidad input:sensitivity, aceleración, botón principal, desplazamiento
// natural y velocidad, pegar con el botón central), panel táctil (velocidad y modo de desplazamiento por dispositivo,
// tocar para hacer clic, tocar y arrastrar, natural, desactivar al escribir, clic por zonas o por dedos) y tableta
// gráfica (pantalla asignada, zurdos; OpenTabletDriver). Todo → config/apply/20-input.py. Los gestos siguen en
// Escritorio y gestos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var mice: []
    property var touchpads: []
    property var tablets: []
    property var outputs: []
    property bool otd: false

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null; echo; echo '@@'; hyprctl monitors -j 2>/dev/null; echo; echo '@@'; (command -v otd || command -v otd-daemon || systemctl --user cat opentabletdriver.service) >/dev/null 2>&1 && echo otd"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@");
                try {
                    const d = JSON.parse(parts[0]);
                    const isTp = n => /touchpad|trackpad|synaptics/i.test(n);
                    const virt = n => /virtual|ydotool|keyboard|power-button|video-bus/i.test(n);
                    root.touchpads = (d.mice ?? []).map(m => m.name).filter(isTp);
                    root.mice = (d.mice ?? []).map(m => m.name).filter(n => !isTp(n) && !virt(n));
                    root.tablets = (d.tablets ?? []).map(t => t.name ?? t.address ?? "tableta");
                    // guarda los touchpads para que 20-input.py los configure aunque Hyprland aún no los liste al cargar
                    const saved = Settings.get("touchpadNames", []);
                    if (root.touchpads.length && JSON.stringify(saved) !== JSON.stringify(root.touchpads)) Settings.set("touchpadNames", root.touchpads);
                } catch (e) {}
                try { root.outputs = JSON.parse(parts[1]).map(m => m.name); } catch (e) {}
                root.otd = (parts[2] ?? "").includes("otd");
            }
        }
    }

    // los deslizadores guardan al soltar (cada cambio relanza hf-apply)
    property real mouseSpeed: Number(Settings.get("mouseSpeed", 0))
    property real tpSpeed: Number(Settings.get("touchpadSpeed", 0))
    Timer { id: saveMouse; interval: 450; onTriggered: Settings.set("mouseSpeed", Math.round(root.mouseSpeed * 100) / 100) }
    Timer { id: saveTp; interval: 450; onTriggered: Settings.set("touchpadSpeed", Math.round(root.tpSpeed * 100) / 100) }

    component Speed: ColumnLayout {
        id: sp
        property real value: 0
        signal moved(real v)
        Layout.fillWidth: true
        spacing: 4
        SliderBar { Layout.fillWidth: true; from: -1; to: 1; value: sp.value; icon: "arrow_right"; onMoved: v => sp.moved(Math.abs(v) < 0.04 ? 0 : v) }
        RowLayout {
            Layout.fillWidth: true
            Txt { text: "Lenta"; muted: true; size: 11 }
            Item { Layout.fillWidth: true }
            Txt { text: sp.value === 0 ? "Normal" : (sp.value > 0 ? "+" : "") + Math.round(sp.value * 100) + " %"; muted: true; size: 11; tabular: true }
            Item { Layout.fillWidth: true }
            Txt { text: "Rápida"; muted: true; size: 11 }
        }
    }

    // ---------- ratón ----------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Ratón"
            headerRight: Mono { text: root.mice.length ? root.mice[0] + (root.mice.length > 1 ? " +" + (root.mice.length - 1) : "") : "ningún ratón detectado" }
            LabeledRow {
                label: "Velocidad del puntero"; labelWidth: 150
                hint: "input:sensitivity"
                Speed { value: root.mouseSpeed; onMoved: v => { root.mouseSpeed = v; saveMouse.restart(); } }
            }
            LabeledRow {
                label: "Aceleración"; labelWidth: 150
                hint: "accel_profile"
                Seg {
                    model: [["adaptive", "Adaptativa"], ["flat", "Plana · para juegos"]]
                    current: Settings.get("mouseAccel", "adaptive")
                    onPicked: k => Settings.set("mouseAccel", k)
                }
            }
            LabeledRow {
                label: "Botón principal"; labelWidth: 150
                hint: "left_handed"
                Seg {
                    model: [[false, "Izquierdo"], [true, "Derecho (zurdos)"]]
                    current: Settings.get("leftHanded", false) === true
                    onPicked: k => Settings.set("leftHanded", k)
                }
            }
            LabeledRow {
                label: "Velocidad de la rueda"; labelWidth: 150
                hint: "scroll_factor"
                Pills { model: [[0.5, "0,5×"], [1, "1×"], [1.5, "1,5×"], [2, "2×"], [3, "3×"]]; current: Number(Settings.get("mouseScroll", 1)); onPicked: v => Settings.set("mouseScroll", v) }
            }
            SwRow { label: "Desplazamiento natural"; sub: "el contenido sigue a la rueda, como en el móvil"; key: "mouseNatural"; def: false }
            SwRow { label: "Pegar con el botón central"; sub: "misc:middle_click_paste · pega lo último que seleccionaste"; key: "middlePaste"; def: true }
        }
        Section {
            Layout.fillWidth: true
            title: "Tableta gráfica"
            headerRight: Mono { text: root.tablets.length ? root.tablets.length + " detectada" + (root.tablets.length > 1 ? "s" : "") : "ninguna conectada" }
            Repeater {
                model: root.tablets
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Icon { name: "edit"; size: 15; color: Theme.tv }
                    Txt { Layout.fillWidth: true; text: parent.modelData; weight: Font.Medium }
                }
            }
            LabeledRow {
                label: "Usar en la pantalla"; labelWidth: 150
                hint: "input:tablet:output"
                Dropdown {
                    model: [["", "Todas las pantallas"]].concat(root.outputs.map(o => [o, o]))
                    current: Settings.get("tabletOutput", "")
                    onPicked: k => Settings.set("tabletOutput", k)
                }
            }
            SwRow { label: "Modo zurdo"; sub: "gira la tableta 180°"; key: "tabletLeftHanded"; def: false }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: root.otd ? "OpenTabletDriver está instalado: ajusta la zona activa y los botones en su propia app."
                    : "Las Wacom funcionan sin instalar nada. Para Huion, XP-Pen, Gaomon y zona activa o presión a medida, instala OpenTabletDriver."
            }
            RowLayout {
                spacing: 8
                Button {
                    visible: !root.otd
                    text: "Instalar OpenTabletDriver"
                    onClicked: Pkg.runInTerminal((Pkg.aur ? Pkg.aur + " -S --needed opentabletdriver" : "echo 'Instala paru o yay y luego: paru -S opentabletdriver'") + " && systemctl --user enable --now opentabletdriver.service", "Tableta gráfica")
                }
                Button { visible: root.otd; text: "Abrir OpenTabletDriver"; onClicked: Quickshell.execDetached(["sh", "-c", "otd-gui || OpenTabletDriver.UX.Gtk"]) }
            }
        }
    }

    // ---------- panel táctil ----------
    Section {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        title: "Panel táctil"
        headerRight: Mono { text: root.touchpads.length ? root.touchpads[0] : "no detectado" }
        Txt {
            visible: root.touchpads.length === 0
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "No hay ningún panel táctil conectado. Estos ajustes se aplicarán cuando lo haya."
        }
        LabeledRow {
            label: "Velocidad"; labelWidth: 130
            hint: "por dispositivo"
            Speed { value: root.tpSpeed; onMoved: v => { root.tpSpeed = v; saveTp.restart(); } }
        }
        LabeledRow {
            label: "Desplazamiento"; labelWidth: 130
            hint: "scroll_method"
            Seg {
                model: [["2fg", "Con dos dedos"], ["edge", "Por el borde"]]
                current: Settings.get("touchpadScroll", "2fg")
                onPicked: k => Settings.set("touchpadScroll", k)
            }
        }
        LabeledRow {
            label: "Clic secundario"; labelWidth: 130
            hint: "clickfinger"
            Seg {
                model: [["areas", "Esquina inferior derecha"], ["clickfinger", "Dos dedos"]]
                current: Settings.get("clickMethod", "areas")
                onPicked: k => Settings.set("clickMethod", k)
            }
        }
        LabeledRow {
            label: "Velocidad de desplazamiento"; labelWidth: 130
            Pills { model: [[0.5, "0,5×"], [0.8, "0,8×"], [1, "1×"], [1.5, "1,5×"], [2, "2×"]]; current: Number(Settings.get("touchpadScrollFactor", 1)); onPicked: v => Settings.set("touchpadScrollFactor", v) }
        }
        SwRow { label: "Tocar para hacer clic"; sub: "input:touchpad:tap_to_click"; mono: true; key: "tapToClick"; def: true }
        SwRow { label: "Tocar y arrastrar"; sub: "doble toque y desliza para arrastrar"; key: "tapAndDrag"; def: true; enabled: Settings.get("tapToClick", true) }
        SwRow { label: "Desplazamiento natural"; sub: "input:touchpad:natural_scroll"; mono: true; key: "naturalScroll"; def: true }
        SwRow { label: "Desactivar mientras escribes"; sub: "input:touchpad:disable_while_typing"; mono: true; key: "disableWhileTyping"; def: true }
        RowLayout {
            Layout.topMargin: 4
            spacing: 4
            Txt { text: "Gestos con 3 y 4 dedos:"; muted: true; size: 11.5 }
            Button { kind: "link"; text: "Escritorio y gestos"; onClicked: Shell.open("ajustesapp", "escritorio") }
        }
    }
}
