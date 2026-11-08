// Ajustes › Dictado — voz a texto local y comandos de voz (scripts/hf-dictate + scripts/hf-voice + modules/dictado):
// motor (whisper.cpp, Vosk, híbrido o faster-whisper), modelos descargables a ~/.local/share/hyprfrijol/whisper con
// progreso (o en la terminal con «Gestionar modelos»), idioma, modo del atajo (mantener / pulsar / continuo), cómo se
// entrega el texto, puntuación, órdenes por voz (atajo propio o palabra de activación) y una zona de prueba.
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
    property var st: ({ models: [], voskModels: [], ready: false, gpu: [] })
    property var dl: ({})            // modelo → { pct, mb, total } mientras se descarga
    property string dlError: ""
    property string last: ""
    property var intents: []
    readonly property string model: Settings.get("dictationModel", "base")
    readonly property string eng: Settings.get("dictationEngine", "auto")
    readonly property bool arch: Pkg.family === "arch"
    readonly property var qs: ["qs", "-p", Paths.root + "/config/quickshell", "ipc", "call", "dictado"]

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
    Process {
        running: true
        command: [Paths.script("hf-voice"), "intents"]
        stdout: StdioCollector { onStreamFinished: { try { root.intents = JSON.parse(text); } catch (e) {} } }
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
    function manage() { Pkg.runInTerminal(root.cmd + " manage", "Modelos de dictado"); later.restart(); }
    function sizeOf(mb) { return mb >= 1000 ? (mb / 1000).toFixed(1).replace(".", ",") + " GB" : mb + " MB"; }

    // ---------- estado ----------
    Section {
        Layout.fillWidth: true
        title: "Dictado por voz"
        headerRight: Kbd { text: "Super + Alt + D" }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Habla y ve el texto mientras lo dices: cada frase se escribe donde esté el cursor en cuanto haces una pausa. Todo se procesa en tu equipo; no se envía audio a ningún sitio."
        }
        InfoRow {
            label: "Motor de reconocimiento"
            icon: "sparkle"
            lit: root.st.engine !== "" && root.st.engine !== undefined
            sub: root.st.engine === "whisper.cpp" ? "whisper.cpp · " + (root.st.server ? "servidor residente" : "whisper-cli") + " · "
                    + ((root.st.gpu ?? []).length ? "GPU (" + root.st.gpu.join(", ") + ")" : "CPU")
                    + (root.st.loaded ? " · modelo cargado" : "")
                : root.st.engine === "hibrido" ? "Híbrido · Vosk para lo provisional y whisper.cpp para cada frase"
                : root.st.engine === "vosk" ? "Vosk · " + root.st.voskModel
                : root.st.engine === "faster-whisper" ? "faster-whisper (Python)"
                : root.arch ? "Falta whisper.cpp (paquete whisper-cpp de los repos oficiales)"
                : "Instala whisper.cpp (whisper-cli) o Vosk"
            Button {
                visible: !root.st.engine && root.arch
                kind: "primary"; text: "Instalar"
                onClicked: { Pkg.install([{ key: "repo", pkg: "whisper-cpp", name: "whisper.cpp" }], "Instalar whisper.cpp"); later.restart(); }
            }
            Button {
                visible: root.st.engine === "whisper.cpp" && (root.st.gpu ?? []).length === 0 && root.arch
                text: "Usar la GPU"
                onClicked: { Pkg.install([{ key: "repo", pkg: "ggml-vulkan", name: "ggml-vulkan" }], "Instalar ggml-vulkan (whisper.cpp en la GPU)"); later.restart(); }
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
                : root.st.typer ? root.st.typer + " · escribe con ydotool" : "Falta wtype: el texto solo se copiará al portapapeles"
            Button {
                visible: root.st.typer !== "wtype"
                text: "Instalar wtype"
                onClicked: { Pkg.install([{ key: "repo", pkg: "wtype", name: "wtype" }], "Instalar wtype"); later.restart(); }
            }
        }
        // zona de prueba: el dictado escribe aquí
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field {
                id: tryField
                Layout.fillWidth: true
                icon: "mic"
                placeholder: "Pulsa «Probar» y habla: el texto aparecerá aquí"
            }
            Button {
                kind: "primary"; text: "Probar"
                onClicked: { tryField.text = ""; tryField.input.forceActiveFocus(); Quickshell.execDetached(root.qs.concat(["toggle"])); }
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
            headerRight: Button { text: "Gestionar modelos"; h: 26; onClicked: root.manage() }
            Repeater {
                model: root.eng === "vosk" ? [] : (root.st.models ?? [])
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
                            Txt { text: mrow.modelData.name.charAt(0).toUpperCase() + mrow.modelData.name.slice(1) + "  ·  " + root.sizeOf(mrow.modelData.mb); weight: Font.DemiBold }
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
            // modelos de Vosk (motor Vosk o híbrido)
            Repeater {
                model: root.eng === "vosk" || root.eng === "hibrido" ? (root.st.voskModels ?? []) : []
                Item {
                    id: vrow
                    required property var modelData
                    readonly property bool cur: Settings.get("dictationVoskModel", "vosk-model-small-es-0.42") === modelData.name
                    readonly property var prog: root.dl[modelData.name] ?? null
                    Layout.fillWidth: true
                    implicitHeight: 52
                    Rectangle { width: parent.width; height: 1; color: Theme.ov }
                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        spacing: 10
                        Rectangle {
                            implicitWidth: 16; implicitHeight: 16; radius: 8; color: "transparent"
                            border.width: vrow.cur ? 5 : 1.5; border.color: vrow.cur ? Theme.p : Theme.o
                            opacity: vrow.modelData.installed ? 1 : 0.45
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt { text: vrow.modelData.name + "  ·  " + root.sizeOf(vrow.modelData.mb); weight: Font.DemiBold; Layout.fillWidth: true }
                            Txt { visible: !vrow.prog; Layout.fillWidth: true; text: vrow.modelData.desc + (vrow.modelData.installed ? " · descargado" : ""); muted: true; size: 11.5 }
                            Txt { visible: !!vrow.prog; text: "Descargando… " + (vrow.prog?.pct ?? 0) + " %"; muted: true; size: 11; tabular: true }
                        }
                        Button {
                            visible: !vrow.modelData.installed && !vrow.prog
                            text: "Descargar"
                            onClicked: { root.download(vrow.modelData.name); Settings.set("dictationVoskModel", vrow.modelData.name); }
                        }
                        Button {
                            visible: vrow.modelData.installed && !vrow.cur
                            text: "Usar"
                            onClicked: Settings.set("dictationVoskModel", vrow.modelData.name)
                        }
                    }
                }
            }
            Timer { id: delTimer; interval: 400; onTriggered: root.refresh() }
            Button {
                visible: (root.eng === "vosk" || root.eng === "hibrido") && root.st.vosk === false
                text: root.arch ? "Instalar Vosk (python-vosk)" : "Instalar Vosk con pip (en la terminal)"
                onClicked: {
                    if (root.arch) Pkg.install([{ key: "repo", pkg: "python-vosk", name: "Vosk" }], "Instalar Vosk");
                    else Pkg.runInTerminal(root.cmd + " install-vosk", "Instalar Vosk");
                    later.restart();
                }
            }
            Txt {
                visible: root.dlError !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.danger
                text: root.dlError
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: (root.eng === "vosk" || root.eng === "hibrido") && !root.st.vosk
                    ? "Vosk necesita su módulo de Python: paquete python-vosk (Arch) o «hf-deps install vosk»."
                    : root.st.engine === "faster-whisper" ? "Con faster-whisper el modelo elegido se descarga solo la primera vez que dictas."
                    : "Modelos de whisper.cpp (Hugging Face). Sin GPU, «base» escribe cada frase en ~1,5 s y «small» en ~3 s pero acierta mucho más; con GPU (ggml-vulkan) hasta «turbo» va fluido. El modelo se queda cargado mientras dictas y se descarga tras " + Math.round(Settings.get("dictationKeepLoaded", 600) / 60) + " min sin usarlo."
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
                    model: [["ptt", "Mantener"], ["toggle", "Pulsar y pulsar"], ["continuo", "Continuo"]]
                    current: Settings.get("dictationMode", "ptt")
                    onPicked: k => Settings.set("dictationMode", k)
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: Settings.get("dictationMode", "ptt") === "ptt"
                    ? "Habla mientras mantienes el atajo. Un toque corto deja el micrófono abierto hasta que vuelvas a pulsarlo."
                    : Settings.get("dictationMode", "ptt") === "continuo"
                    ? "Una pulsación empieza a escuchar y para sola tras " + Settings.get("dictationSilenceSec", 5) + " s en silencio (u otra pulsación)."
                    : "Una pulsación empieza a escuchar y otra termina."
            }
            LabeledRow {
                label: "Motor"
                labelWidth: 110
                Seg {
                    model: [["auto", "Automático"], ["whisper.cpp", "whisper"], ["vosk", "Vosk"], ["hibrido", "Híbrido"]]
                    current: root.eng
                    onPicked: k => { Settings.set("dictationEngine", k); later.restart(); }
                }
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
            SwRow { label: "Puntuación y mayúsculas automáticas"; sub: "comas, puntos y mayúscula al empezar frase; di «nueva línea» o «punto y aparte»"; key: "dictationPunct"; def: true }
            SwRow { label: "Ver el texto mientras hablas"; sub: "lo provisional aparece en la píldora antes de escribirse"; key: "dictationLive"; def: true }
            SwRow {
                label: "Mejorar el texto con IA"
                sub: "puntuación y muletillas · escribe al terminar, no frase a frase · usa " + Settings.get("aiProvider", "claude-code")
                key: "dictationAI"
            }
            LinkRow { label: "Cambiar el atajo"; value: "Dictado"; section: "teclado"; sectionLabel: "Teclado y atajos"; target: "Dictado" }
        }
    }

    // ---------- comandos de voz ----------
    Section {
        Layout.fillWidth: true
        title: "Comandos de voz"
        headerRight: Kbd { text: "Super + Alt + V" }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Con su atajo, lo que digas es una orden: «Reproduce Walk de los Foo Fighters desde YouTube», «sube el volumen al 40 %», «nueva pestaña». La píldora enseña ⌘ en lugar del micrófono, la orden que entendió y si salió bien."
        }
        SwRow {
            label: "Palabra de activación al dictar"
            sub: "empieza una frase con «" + Settings.get("dictationWakeWord", "Frijol") + ", …» u «oye " + Settings.get("dictationWakeWord", "Frijol") + "» y será una orden en vez de texto"
            key: "dictationWake"; def: true
        }
        LabeledRow {
            label: "Palabra"
            labelWidth: 110
            hint: "dictationWakeWord"
            Field {
                icon: ""
                placeholder: "Frijol"
                text: Settings.get("dictationWakeWord", "Frijol")
                onAccepted: Settings.set("dictationWakeWord", text.trim() || "Frijol")
                input.onActiveFocusChanged: if (!input.activeFocus && text.trim() !== Settings.get("dictationWakeWord", "Frijol")) Settings.set("dictationWakeWord", text.trim() || "Frijol")
            }
        }
        LabeledRow {
            label: "Música en"
            labelWidth: 110
            Seg {
                model: [["youtube", "YouTube"], ["music", "YouTube Music"], ["spotify", "Spotify"]]
                current: Settings.get("voiceMusicService", "youtube")
                onPicked: k => Settings.set("voiceMusicService", k)
            }
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
            text: "Para «pon <canción>» sin decir dónde. YouTube abre el primer resultado y empieza solo" + (root.st.ytdlp ? " (lo busca yt-dlp)." : "; con yt-dlp instalado la búsqueda es más fiable.")
        }
        SwRow {
            label: "Lo que no entienda, al asistente"
            sub: "la orden va al panel de IA; lo que cambie algo pide tu aprobación allí"
            key: "voiceAiFallback"; def: true
        }
        Repeater {
            model: root.intents
            InfoRow {
                required property var modelData
                label: modelData[0]; sub: modelData[1]; icon: "command"; lit: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            LinkRow { label: "Cambiar el atajo"; value: "Comando de voz"; section: "teclado"; sectionLabel: "Teclado y atajos"; target: "Comando de voz"; Layout.fillWidth: true }
            Button { kind: "primary"; text: "Probar una orden"; onClicked: Quickshell.execDetached(root.qs.concat(["command"])) }
        }
    }
}
