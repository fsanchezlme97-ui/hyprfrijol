// Ajustes › Dictado — voz a texto local (scripts/hf-dictate + modules/dictado): motor (whisper.cpp o
// faster-whisper), modelos descargables a ~/.local/share/hyprfrijol/whisper con progreso, idioma, modo del atajo
// (mantener / pulsar), cómo se entrega el texto (wtype, pegar o portapapeles) y limpieza opcional con la IA.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property string cmd: Paths.script("hf-dictate")
    property var st: ({ models: [], ready: false })
    property var dl: ({})            // modelo → { pct, mb, total } mientras se descarga
    property string dlError: ""
    property string last: ""
    readonly property string model: Settings.get("dictationModel", "base")
    readonly property bool arch: Pkg.family === "arch"

    function refresh() { probe.running = false; probe.running = true; lastProc.running = true; }
    Process {
        id: probe
        running: true
        command: [root.cmd, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: lastProc
        running: true
        command: [root.cmd, "last"]
        stdout: StdioCollector { onStreamFinished: root.last = text.trim() }
    }
    // tras instalar en la terminal, volver a mirar un rato
    Timer { id: later; interval: 5000; repeat: true; property int n: 0; onTriggered: { root.refresh(); if (++n > 12) { n = 0; stop(); } } }

    Component {
        id: dlComp
        Process {
            id: p
            property string name
            command: [root.cmd, "download", name]
            running: true
            stdout: SplitParser {
                onRead: l => {
                    let j; try { j = JSON.parse(l); } catch (e) { return; }
                    const d = Object.assign({}, root.dl);
                    if (j.ev === "progress") d[p.name] = j;
                    else { delete d[p.name]; if (j.ev === "error") root.dlError = j.msg; }
                    root.dl = d;
                }
            }
            onExited: { const d = Object.assign({}, root.dl); delete d[p.name]; root.dl = d; root.refresh(); p.destroy(); }
        }
    }
    function download(name) {
        if (dl[name]) return;
        dlError = "";
        const d = Object.assign({}, dl); d[name] = { pct: 0, mb: 0, total: 0 }; dl = d;
        dlComp.createObject(root, { name: name });
    }

    // ---------- estado ----------
    Section {
        Layout.fillWidth: true
        title: "Dictado por voz"
        headerRight: Kbd { text: "Super + Alt + D" }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Mantén pulsado el atajo mientras hablas y suéltalo: el texto aparece donde esté el cursor. Todo se procesa en tu equipo con Whisper; no se envía audio a ningún sitio."
        }
        InfoRow {
            label: "Motor de reconocimiento"
            icon: "sparkle"
            lit: root.st.engine !== "" && root.st.engine !== undefined
            sub: root.st.engine === "whisper.cpp" ? "whisper.cpp · " + root.st.bin
                : root.st.engine === "faster-whisper" ? "faster-whisper (Python)"
                : root.arch ? "Falta whisper.cpp (paquete whisper-cpp de los repos oficiales)"
                : "Instala whisper.cpp (whisper-cli) o faster-whisper"
            Button {
                visible: !root.st.engine && root.arch
                kind: "primary"; text: "Instalar"
                onClicked: { Pkg.install([{ key: "repo", pkg: "whisper-cpp", name: "whisper.cpp" }], "Instalar whisper.cpp"); later.restart(); }
            }
            Button {
                visible: !root.st.engine && !root.arch
                text: "Cómo instalarlo"
                onClicked: Qt.openUrlExternally("https://github.com/ggml-org/whisper.cpp#quick-start")
            }
        }
        InfoRow {
            label: "Micrófono"
            icon: "mic"
            lit: !!root.st.recorder
            sub: root.st.recorder ? root.st.recorder + " · " + (Audio.source?.description || Audio.source?.nickname || "entrada predeterminada") : "Falta pw-record (PipeWire) o arecord"
        }
        InfoRow {
            label: "Escribir en la ventana"
            icon: "keyboard"
            lit: root.st.typer === "wtype"
            sub: root.st.typer === "wtype" ? "wtype · escribe como un teclado virtual"
                : root.st.typer ? root.st.typer + " · se pegará con Ctrl + V" : "Falta wtype: el texto solo se copiará al portapapeles"
            Button {
                visible: root.st.typer !== "wtype"
                text: "Instalar wtype"
                onClicked: { Pkg.install([{ key: "repo", pkg: "wtype", name: "wtype" }], "Instalar wtype"); later.restart(); }
            }
        }
        Txt {
            visible: root.last !== ""
            Layout.fillWidth: true; size: 11.5; muted: true; wrapMode: Text.WordWrap; maximumLineCount: 2
            text: "Último dictado: «" + root.last + "»"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        // ---------- modelos ----------
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Modelo"
            headerRight: Mono { text: "~/.local/share/hyprfrijol/whisper" }
            Repeater {
                model: root.st.models ?? []
                Item {
                    id: mrow
                    required property var modelData
                    required property int index
                    readonly property bool cur: root.model === modelData.name
                    readonly property var prog: root.dl[modelData.name] ?? null
                    Layout.fillWidth: true
                    implicitHeight: 52
                    Rectangle { visible: mrow.index > 0; width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        spacing: 10
                        // radio
                        Rectangle {
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: "transparent"
                            border.width: mrow.cur ? 5 : 1.5
                            border.color: mrow.cur ? Theme.p : Theme.o
                            opacity: mrow.modelData.installed || root.st.engine === "faster-whisper" ? 1 : 0.45
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt { text: mrow.modelData.name.charAt(0).toUpperCase() + mrow.modelData.name.slice(1) + "  ·  " + (mrow.modelData.mb >= 1000 ? (mrow.modelData.mb / 1000).toFixed(1).replace(".", ",") + " GB" : mrow.modelData.mb + " MB"); weight: Font.DemiBold }
                            Txt { visible: !mrow.prog; Layout.fillWidth: true; text: mrow.modelData.desc + (mrow.modelData.installed ? " · descargado" : ""); muted: true; size: 11.5 }
                            Rectangle {
                                visible: !!mrow.prog
                                Layout.fillWidth: true
                                implicitHeight: 4; radius: 2; color: Theme.fill2
                                Rectangle { width: parent.width * (mrow.prog?.pct ?? 0) / 100; height: 4; radius: 2; color: Theme.p
                                    Behavior on width { NumberAnimation { duration: 200 } } }
                            }
                            Txt { visible: !!mrow.prog; text: "Descargando… " + (mrow.prog?.pct ?? 0) + " % · " + (mrow.prog?.mb ?? 0) + " de " + (mrow.prog?.total || mrow.modelData.mb) + " MB"; muted: true; size: 11; tabular: true }
                        }
                        Button {
                            visible: !mrow.modelData.installed && !mrow.prog
                            kind: mrow.cur ? "primary" : "outline"
                            text: "Descargar"
                            onClicked: { root.download(mrow.modelData.name); if (!mrow.cur) Settings.set("dictationModel", mrow.modelData.name); }
                        }
                        Button {
                            visible: mrow.modelData.installed && !mrow.cur
                            text: "Usar"
                            onClicked: Settings.set("dictationModel", mrow.modelData.name)
                        }
                        IconBtn {
                            visible: mrow.modelData.installed
                            icon: "trash"
                            onClicked: { Quickshell.execDetached([root.cmd, "delete", mrow.modelData.name]); delTimer.restart(); }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; z: -1
                        enabled: mrow.modelData.installed
                        onClicked: Settings.set("dictationModel", mrow.modelData.name)
                    }
                }
            }
            Timer { id: delTimer; interval: 400; onTriggered: root.refresh() }
            Txt {
                visible: root.dlError !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.danger
                text: root.dlError
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: root.st.engine === "faster-whisper" ? "Con faster-whisper el modelo elegido se descarga solo la primera vez que dictas."
                    : "Modelos ggml de whisper.cpp (Hugging Face). Más grande = más preciso y más lento; con GPU (whisper.cpp-vulkan/-cuda del AUR) hasta «medium» va fluido."
            }
        }

        // ---------- preferencias ----------
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Preferencias"
            LabeledRow {
                label: "Atajo"
                labelWidth: 110
                Seg {
                    model: [["ptt", "Mantener pulsado"], ["toggle", "Pulsar y pulsar"]]
                    current: Settings.get("dictationMode", "ptt")
                    onPicked: k => Settings.set("dictationMode", k)
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: Settings.get("dictationMode", "ptt") === "ptt"
                    ? "Habla mientras mantienes el atajo. Un toque corto deja el micrófono abierto hasta que vuelvas a pulsarlo."
                    : "Una pulsación empieza a escuchar y otra termina."
            }
            LabeledRow {
                label: "Idioma"
                labelWidth: 110
                Dropdown {
                    model: [["es", "Español"], ["auto", "Detectar automáticamente"], ["en", "Inglés"], ["ca", "Catalán"], ["gl", "Gallego"], ["eu", "Euskera"],
                            ["pt", "Portugués"], ["fr", "Francés"], ["it", "Italiano"], ["de", "Alemán"]]
                    current: Settings.get("dictationLang", "es")
                    onPicked: k => Settings.set("dictationLang", k)
                }
            }
            LabeledRow {
                label: "El texto se…"
                labelWidth: 110
                Seg {
                    model: [["escribir", "Escribe"], ["pegar", "Pega"], ["portapapeles", "Copia"]]
                    current: Settings.get("dictationOutput", "escribir")
                    onPicked: k => Settings.set("dictationOutput", k)
                }
            }
            LabeledRow {
                label: "Motor"
                labelWidth: 110
                Seg {
                    model: [["auto", "Automático"], ["whisper.cpp", "whisper.cpp"], ["faster-whisper", "faster-whisper"]]
                    current: Settings.get("dictationEngine", "auto")
                    onPicked: k => { Settings.set("dictationEngine", k); later.restart(); }
                }
            }
            LabeledRow {
                label: "Vocabulario"
                labelWidth: 110
                hint: "dictationPrompt"
                Field {
                    icon: ""
                    placeholder: "Nombres o términos: Hyprland, Quickshell…"
                    text: Settings.get("dictationPrompt", "")
                    onAccepted: Settings.set("dictationPrompt", text.trim())
                    input.onActiveFocusChanged: if (!input.activeFocus && text.trim() !== Settings.get("dictationPrompt", "")) Settings.set("dictationPrompt", text.trim())
                }
            }
            SwRow {
                label: "Mejorar el texto con IA"
                sub: "puntuación y muletillas · usa el proveedor de Asistente de IA (" + Settings.get("aiProvider", "claude-code") + ")"
                key: "dictationAI"
            }
            LinkRow { label: "Cambiar el atajo"; value: "Dictado"; section: "teclado"; sectionLabel: "Teclado y atajos"; target: "Dictado" }
        }
    }
}
