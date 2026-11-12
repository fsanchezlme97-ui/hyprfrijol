// Ajustes › Dictado — voz a texto local y comandos de voz (scripts/hf-dictate + scripts/hf-voice + modules/dictado):
// motor (whisper.cpp, Vosk, híbrido o faster-whisper), modelos descargables a ~/.local/share/hyprfrijol/whisper con
// progreso (o en la terminal con «Gestionar modelos»), idioma, modo del atajo (mantener / pulsar / continuo), cómo se
// entrega el texto, puntuación, órdenes por voz (atajo propio o palabra de activación «Distro»), órdenes propias
// (voiceCommands: frase → comando, app, web u otra orden), sinónimos (voiceAliases) y zonas de prueba.
// El dictado NUNCA usa IA; solo una orden que hf-voice no entienda va al asistente (voiceAiFallback).
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
    AiTabs { current: "dictado" }   // Asistente | Privacidad | Dictado | Panel (una sola entrada en la lista)
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
    readonly property string voice: Paths.script("hf-voice")
    readonly property string wake: String(Settings.get("dictationWakeWord", "Distro")).trim() || "Distro"
    readonly property var cmds: Settings.get("voiceCommands", []) ?? []
    readonly property var aliasMap: Settings.get("voiceAliases", ({})) ?? ({})
    readonly property var aliasList: Object.keys(aliasMap).map(k => [k, aliasMap[k]])
    // Vosk (tiempo real palabra a palabra): ¿falta el módulo o el modelo?
    readonly property string voskName: Settings.get("dictationVoskModel", "vosk-model-small-es-0.42")
    readonly property bool voskModelOk: (root.st.voskModels ?? []).some(m => m.name === root.voskName && m.installed)
    readonly property bool voskMissing: root.st.ready !== false && root.eng !== "whisper.cpp" && root.eng !== "faster-whisper"
                                         && root.eng !== "parakeet" && root.st.engine !== "parakeet"
                                         && (root.st.vosk === false || !root.voskModelOk) && (root.st.voskModels ?? []).length > 0
    function installVosk() {
        const dl = root.cmd + " download --tty " + root.voskName;
        const mod = root.st.vosk ? "" : root.arch ? "sudo pacman -S --needed python-vosk vosk-api && " : root.cmd + " install-vosk && ";
        Pkg.runInTerminal(mod + dl, "Dictado en tiempo real (Vosk)");
        later.restart();
    }
    // Parakeet v3 (el motor más rápido y preciso en CPU): entorno de Python propio + modelo (~670 MB), en la terminal
    function installParakeet() {
        Pkg.runInTerminal(root.cmd + " install-parakeet --tty", "Dictado: Parakeet v3");
        later.restart();
    }
    // palabra de activación: una o dos palabras, solo letras, 2–24 caracteres
    function wakeError(w) {
        const v = w.trim();
        if (v === "") return "Escribe una palabra (por ejemplo «Distro»).";
        if (v.length < 2 || v.length > 24) return "Entre 2 y 24 letras.";
        if (!/^[A-Za-zÀ-ÿñÑ]+( [A-Za-zÀ-ÿñÑ]+)?$/.test(v)) return "Solo letras, una o dos palabras, sin signos.";
        return "";
    }
    property string wakeErr: ""
    function saveWake(w) {
        wakeErr = wakeError(w);
        if (wakeErr === "" && w.trim() !== Settings.get("dictationWakeWord", "Distro")) Settings.set("dictationWakeWord", w.trim());
    }
    // órdenes propias
    property string cmdErr: ""
    function addCmd(phrase, kind, value) {
        const ph = phrase.trim(), v = value.trim();
        if (ph.length < 2) { cmdErr = "Escribe la frase que dirás."; return false; }
        if (v === "") { cmdErr = kind === "run" ? "Escribe el comando." : kind === "app" ? "Escribe la aplicación." : kind === "url" ? "Escribe la dirección." : "Escribe la orden a la que equivale."; return false; }
        if (kind === "url" && !/^(https?:\/\/|[\w-]+\.[\w.-]+)/.test(v)) { cmdErr = "La dirección debe empezar por https:// (o ser un dominio)."; return false; }
        if (root.cmds.some(c => String(c.phrase).trim().toLowerCase() === ph.toLowerCase())) { cmdErr = "Ya tienes una orden con esa frase."; return false; }
        cmdErr = "";
        Settings.set("voiceCommands", root.cmds.concat([{ "phrase": ph, "do": kind, "value": v }]));
        return true;
    }
    function removeCmd(i) { const l = root.cmds.slice(); l.splice(i, 1); Settings.set("voiceCommands", l); }
    function addAlias(word, canon) {
        const w = word.trim().toLowerCase(), c = canon.trim().toLowerCase();
        if (!w || !c || w === c) return false;
        const m = Object.assign({}, root.aliasMap); m[w] = c; Settings.set("voiceAliases", m);
        return true;
    }
    function removeAlias(w) { const m = Object.assign({}, root.aliasMap); delete m[w]; Settings.set("voiceAliases", m); }
    readonly property var kindLabels: ({ run: "Ejecuta", app: "Abre la app", url: "Abre la web", orden: "Equivale a" })
    // probar una orden escrita (no la ejecuta: solo dice qué haría)
    property var parsed: null
    Process {
        id: parseProc
        property string q: ""
        command: [root.voice, "parse", q]
        stdout: StdioCollector { onStreamFinished: { try { root.parsed = JSON.parse(text); } catch (e) { root.parsed = null; } } }
    }
    function tryText(q) { if (!q.trim()) return; parseProc.running = false; parseProc.q = q.trim(); parseProc.running = true; }

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

    // ---------- Vosk: tiempo real de un clic ----------
    Section {
        visible: root.voskMissing
        Layout.fillWidth: true
        title: "Dictado en tiempo real"
        InfoRow {
            label: root.st.vosk === false ? "Falta Vosk" : "Falta el modelo de Vosk"
            icon: "mic"
            lit: false
            sub: (root.st.vosk === false ? (root.arch ? "python-vosk y vosk-api" : "módulo vosk de Python") + (root.voskModelOk ? "" : " + modelo") : "modelo " + root.voskName)
                 + " · palabra a palabra mientras hablas. Mientras, se dicta con whisper"
            Button { kind: "primary"; text: "Instalar"; onClicked: root.installVosk() }
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
                model: root.st.engine === "vosk" ? [] : (root.st.models ?? [])
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
                            Progress {
                                visible: !!mrow.prog
                                Layout.fillWidth: true
                                value: (mrow.prog?.pct ?? 0) / 100
                                period: 700            // hf-dictate avisa a cada 1 %
                                track: Theme.fill2
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
                model: root.st.engine === "vosk" || root.eng === "vosk" || root.eng === "hibrido" ? (root.st.voskModels ?? []) : []
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
                visible: root.st.parakeet === false && (root.eng === "auto" || root.eng === "parakeet")
                text: "Instalar Parakeet v3 (recomendado: ~0,3 s por frase, español e inglés)"
                onClicked: root.installParakeet()
            }
            Button {
                visible: (root.eng === "vosk" || root.eng === "hibrido") && root.st.vosk === false
                text: root.arch ? "Instalar Vosk (python-vosk y vosk-api)" : "Instalar Vosk con pip (en la terminal)"
                onClicked: root.installVosk()
            }
            Txt {
                visible: root.dlError !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 11.5; color: Theme.danger
                text: root.dlError
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: (root.eng === "vosk" || root.eng === "hibrido") && !root.st.vosk
                    ? "Vosk necesita su módulo de Python: paquetes python-vosk y vosk-api (Arch) o «hf-dictate install-vosk»."
                    : root.st.engine === "parakeet" ? "Dictas con Parakeet v3 (NVIDIA, ~670 MB en …/whisper/parakeet): español, inglés y 23 idiomas más sin tener que elegir, con puntuación y ~0,3 s por frase en CPU. Los modelos de whisper de arriba quedan como alternativa (Motor › whisper)."
                    : root.st.engine === "vosk" ? "Modelos de Vosk (alphacephei.com). El pequeño (39 MB, ~300 MB de RAM) escribe palabra a palabra al instante; el grande (1,4 GB, varios GB de RAM) acierta más."
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
                label: "Micrófono"
                labelWidth: 110
                Seg {
                    model: [["dictado", "Dictado"], ["ia", "Asistente"], ["silencio", "Silenciar"]]
                    current: Settings.get("micMode", "dictado")
                    onPicked: k => Settings.set("micMode", k)
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: "Lo que hacen el botón del micrófono de la barra y Super + Alt + M. Clic derecho en el botón o Super + Shift + Alt + M: el siguiente."
            }
            LabeledRow {
                label: "Motor"
                labelWidth: 110
                Seg {
                    model: [["auto", "Automático"], ["parakeet", "Parakeet"], ["whisper.cpp", "whisper"], ["vosk", "Vosk"], ["hibrido", "Híbrido"]]
                    current: root.eng
                    onPicked: k => { Settings.set("dictationEngine", k); later.restart(); }
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: root.eng === "parakeet" ? "Parakeet v3: el más rápido y preciso sin GPU (~0,3 s por frase), español e inglés a la vez y con puntuación."
                    : root.eng === "vosk" ? "Vosk: tiempo real, cada palabra aparece mientras la dices y cada frase se escribe al hacer una pausa."
                    : root.eng === "whisper.cpp" ? "whisper: más preciso y con puntuación, por frases (cada frase se escribe ~1 s después de la pausa; al momento con GPU)."
                    : root.eng === "hibrido" ? "Híbrido: Vosk enseña lo provisional y whisper escribe cada frase (más preciso, algo más lento)."
                    : "Automático: Parakeet si está instalado (el más rápido); si no, whisper si tienes su modelo; si no, Vosk."
            }
            LabeledRow {
                label: "Idioma"
                labelWidth: 110
                Dropdown {
                    model: [["es+en", "Español + inglés"], ["es", "Español"], ["auto", "Detectar automáticamente"], ["en", "Inglés"], ["ca", "Catalán"], ["gl", "Gallego"], ["eu", "Euskera"],
                            ["pt", "Portugués"], ["fr", "Francés"], ["it", "Italiano"], ["de", "Alemán"]]
                    current: Settings.get("dictationLang", "es+en")
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
                    placeholder: "Separados por comas: midudev, Foo Fighters, Hyprland…"
                    text: Settings.get("dictationPrompt", "")
                    onAccepted: Settings.set("dictationPrompt", text.trim())
                    input.onActiveFocusChanged: if (!input.activeFocus && text.trim() !== Settings.get("dictationPrompt", "")) Settings.set("dictationPrompt", text.trim())
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: "Lo que suene como una de estas palabras se escribe así al acabar cada frase, con cualquier motor y sin conexión. whisper además las usa al reconocer."
            }
            LabeledRow {
                label: "Corregir con la IA"
                labelWidth: 110
                hint: "dictationAiFix"
                Seg {
                    model: [["nunca", "Nunca"], ["asistente", "Al hablar con el asistente"], ["siempre", "Siempre"]]
                    current: Settings.get("dictationAiFix", "asistente")
                    onPicked: k => Settings.set("dictationAiFix", k)
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11; wrapMode: Text.WordWrap
                text: (Settings.get("dictationAiFix", "asistente") === "siempre"
                       ? "Cada frase pasa por el modelo rápido de tu asistente antes de escribirse (~1–2 s más): arregla nombres de grupos, creadores, marcas, programas y términos de internet que el reconocedor oye mal. Lo que dictas sale de tu equipo salvo con «Solo en este equipo»."
                       : "Con «Siempre», cada frase dictada pasa por el modelo rápido de tu asistente (~1–2 s más) y arregla nombres de grupos, creadores, marcas, programas y términos de internet que el reconocedor oye mal. Al hablar con el asistente, lo que dices ya va a la IA.")
                    + " Si no responde en " + (Settings.get("dictationAiFixSec", 3)) + " s, se escribe lo que se oyó."
            }
            SwRow { label: "Puntuación y mayúsculas automáticas"; sub: "comas, puntos y mayúscula al empezar frase; di «nueva línea» o «punto y aparte»"; key: "dictationPunct"; def: true }
            SwRow { label: "Ver el texto mientras hablas"; sub: "lo provisional aparece en la píldora antes de escribirse"; key: "dictationLive"; def: true }
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
            text: "Con su atajo, lo que digas es una orden: «Reproduce Walk de los Foo Fighters desde YouTube», «sube el volumen al 40 %», «nueva pestaña». Las entiende tu equipo, sin IA; la píldora enseña ⌘ en lugar del micrófono, la orden que entendió y si salió bien."
        }
        SwRow {
            label: "Palabra de activación al dictar"
            sub: "empieza una frase con «" + root.wake + ", …» u «oye " + root.wake + "» y será una orden en vez de texto"
            key: "dictationWake"; def: true
        }
        LabeledRow {
            label: "Palabra"
            labelWidth: 110
            hint: "dictationWakeWord"
            Field {
                id: wakeField
                icon: ""
                placeholder: "Distro"
                text: Settings.get("dictationWakeWord", "Distro")
                onAccepted: root.saveWake(text)
                input.onTextChanged: root.wakeErr = root.wakeError(text)
                input.onActiveFocusChanged: if (!input.activeFocus) root.saveWake(text)
            }
            Button { visible: root.wake !== "Distro"; text: "Distro"; h: 28; onClicked: { wakeField.text = "Distro"; root.saveWake("Distro"); } }
        }
        Txt {
            Layout.fillWidth: true; size: 11; wrapMode: Text.WordWrap
            color: root.wakeErr ? Theme.danger : Theme.tv
            text: root.wakeErr || "«Distro», en homenaje a las distribuciones de Linux. Mejor una palabra que no uses al dictar; se aceptan «oye/hey " + root.wake + "» y pequeños errores al oírla."
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
        // probar una orden escrita: dice qué haría, sin hacerlo
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field {
                id: tryCmd
                Layout.fillWidth: true
                icon: "command"
                placeholder: "Escribe una orden para ver qué haría: «toca Walk en YouTube»"
                onAccepted: root.tryText(text)
            }
            Button { text: "Comprobar"; onClicked: root.tryText(tryCmd.text) }
            Button { kind: "primary"; text: "Probar una orden"; onClicked: Quickshell.execDetached(root.qs.concat(["command"])) }
        }
        Txt {
            visible: root.parsed !== null
            Layout.fillWidth: true; size: 11.5; wrapMode: Text.WordWrap
            color: root.parsed?.intent === "unknown" ? Theme.tv : Theme.t
            text: !root.parsed ? "" : root.parsed.intent === "unknown"
                ? (Settings.get("voiceAiFallback", true) ? "No es una orden conocida: iría al asistente de IA («" + root.parsed.text + "»)." : "No es una orden conocida (y el asistente está desactivado).")
                : "Entendido: " + root.parsed.label + (root.parsed.custom ? " · orden tuya" : "")
        }
        Repeater {
            model: root.intents
            InfoRow {
                required property var modelData
                label: modelData[0]; sub: modelData[1]; icon: "command"; lit: true
            }
        }
        LinkRow { label: "Cambiar el atajo"; value: "Comando de voz"; section: "teclado"; sectionLabel: "Teclado y atajos"; target: "Comando de voz"; Layout.fillWidth: true }
    }

    // ---------- órdenes propias ----------
    Section {
        Layout.fillWidth: true
        title: "Tus órdenes"
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Frases tuyas que se miran antes que las de serie. Un * recoge lo que digas en su sitio y se usa como {x}: «busca * en mi wiki» → https://wiki.example.org/?q={x}."
        }
        Repeater {
            model: root.cmds
            InfoRow {
                required property var modelData
                required property int index
                label: "«" + modelData.phrase + "»"
                sub: (root.kindLabels[modelData["do"]] ?? modelData["do"]) + " " + (modelData["do"] === "orden" ? "«" + modelData.value + "»" : modelData.value)
                icon: modelData["do"] === "run" ? "terminal" : modelData["do"] === "url" ? "globe" : modelData["do"] === "app" ? "grid" : "command"
                lit: true
                IconBtn { icon: "trash"; onClicked: root.removeCmd(index) }
            }
        }
        Txt { visible: root.cmds.length === 0; muted: true; size: 11.5; text: "Aún no tienes órdenes propias." }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: newPhrase; Layout.fillWidth: true; Layout.preferredWidth: 3; icon: "mic"; placeholder: "Cuando diga… «modo cine»" }
            Seg {
                id: newKind
                fill: false
                property string k: "run"
                model: [["run", "Comando"], ["app", "App"], ["url", "Web"], ["orden", "Otra orden"]]
                current: k
                onPicked: key => k = key
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field {
                id: newValue
                Layout.fillWidth: true
                icon: ""
                placeholder: newKind.k === "run" ? "…ejecuta: hyprctl keyword decoration:blur:enabled false"
                    : newKind.k === "app" ? "…abre la app: firefox, thunderbird…"
                    : newKind.k === "url" ? "…abre: https://… ({x} = lo dicho en el *)"
                    : "…equivale a: pon lo-fi en YouTube"
                onAccepted: add.clicked()
            }
            Button {
                id: add
                kind: "primary"; text: "Añadir"
                onClicked: if (root.addCmd(newPhrase.text, newKind.k, newValue.text)) { newPhrase.text = ""; newValue.text = ""; }
            }
        }
        Txt { visible: root.cmdErr !== ""; Layout.fillWidth: true; size: 11; color: Theme.danger; text: root.cmdErr }

        // sinónimos de las órdenes de serie
        Txt { Layout.topMargin: 6; text: "Otras palabras para las órdenes de serie"; weight: Font.DemiBold }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Por ejemplo «toca» → «reproduce»: «toca Walk en YouTube» se entiende como «reproduce Walk en YouTube»."
        }
        Repeater {
            model: root.aliasList
            InfoRow {
                required property var modelData
                label: "«" + modelData[0] + "»"
                sub: "se entiende como «" + modelData[1] + "»"
                icon: "command"; lit: true
                IconBtn { icon: "trash"; onClicked: root.removeAlias(modelData[0]) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field { id: newAlias; Layout.fillWidth: true; icon: ""; placeholder: "Si digo… «toca»" }
            Field { id: newCanon; Layout.fillWidth: true; icon: ""; placeholder: "…es como decir «reproduce»"; onAccepted: addAl.clicked() }
            Button {
                id: addAl
                text: "Añadir"
                onClicked: if (root.addAlias(newAlias.text, newCanon.text)) { newAlias.text = ""; newCanon.text = ""; }
            }
        }
    }
}
