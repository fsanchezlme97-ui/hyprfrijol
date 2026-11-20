// Ajustes › Asistente de IA › Proveedor y permisos («iaproveedor»; la entrada «ia» es Inicio) — proveedor/modelo/servidor (los usa scripts/hf-ai: aiProvider, aiModel, aiEndpoint,
// aiKeyEnv), personalidad (aiName, aiPersona) y permisos del asistente (aiContextWindow, aiContextClipboard…).
// Gemini: la clave se guarda con `hf-ai key set gemini` (llavero con secret-tool o ~/.config/hyprfrijol/secrets,
// nunca en settings.json); la lista de modelos sale de `hf-ai models gemini` y «Probar conexión» de `hf-ai test`.
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
    AiTabs { current: "iaproveedor" }   // Inicio | Proveedor y permisos | Privacidad | Recetas | Dictado | Panel
    readonly property string prov: Settings.get("aiProvider", "claude-code")
    property var ollamaModels: []
    property var geminiModels: []
    property var ocModels: []           // hf-ai models opencode: [[proveedor/modelo, nombre]…], los gratuitos primero
    property string ocModelsErr: ""
    property string geminiModelsErr: ""
    property string status: ""
    property var key: ({ stored: false, where: "", hint: "" })
    property var voiceLocal: undefined     // hf-ai status: voz local (Piper) instalada; sin ella la voz usa Gemini TTS
    readonly property bool announces: Settings.get("aiAnnounceGreet", false) || Settings.get("aiAnnounceUrgent", false)
    readonly property bool needKey: prov === "gemini" || root.announces || (Settings.get("aiVoice", false) && root.voiceLocal === false)
    property string keyMsg: ""
    property bool keyErr: false
    property string testMsg: ""
    property bool testOk: false
    property bool testing: false

    Process {
        running: true
        command: ["sh", "-c", "command -v ollama >/dev/null && ollama list 2>/dev/null | awk 'NR>1{print $1}'"]
        stdout: StdioCollector { onStreamFinished: root.ollamaModels = text.split("\n").filter(Boolean) }
    }
    Process {
        id: stat
        running: true
        command: [Paths.script("hf-ai"), "status"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.voiceLocal = !!j.voiceLocal; root.status = j.available ? "Disponible" : (j.hint || j.error || "No disponible"); } catch (e) { root.status = ""; } } }
    }
    Timer { id: statTimer; interval: 900; onTriggered: { stat.running = false; stat.running = true; } }
    // IA de terminal instaladas (hf-ai clis): claude → Claude Code, ollama → Ollama, el resto → proveedor "cli" (aiCli)
    property var clis: []
    readonly property var termClis: clis.filter(c => c.provider === "cli")
    readonly property string cliId: Settings.get("aiCli", "")
    readonly property string cliLabel: (clis.find(c => c.id === cliId)?.name) ?? "Terminal"
    readonly property bool hasOpencode: clis.some(c => c.provider === "opencode")
    Process {
        running: true
        command: [Paths.script("hf-ai"), "clis"]
        stdout: StdioCollector { onStreamFinished: { try { root.clis = JSON.parse(text).clis ?? []; } catch (e) {} } }
    }
    function isPrimary(c): bool { return root.prov === c.provider && (c.provider !== "cli" || root.cliId === c.id); }
    function isFallback(c): bool { const f = Settings.get("aiFallbackProvider", ""); return f === c.provider && (c.provider !== "cli" || root.cliId === c.id); }
    function usePrimary(c): void {
        const ch = { aiProvider: c.provider, aiModel: "" };
        if (c.provider === "cli") ch.aiCli = c.id;
        if (Settings.get("aiFallbackProvider", "") === c.provider) ch.aiFallbackProvider = "";   // no puede ser su propio respaldo
        Settings.setMany(ch); root.testMsg = ""; statTimer.restart();
    }
    function useFallback(c): void {
        const ch = { aiFallbackProvider: c.provider, aiFallbackModel: "" };
        if (c.provider === "cli") ch.aiCli = c.id;
        Settings.setMany(ch);
    }

    // ---- Gemini: clave, modelos y prueba ----
    function refreshGemini(): void {
        keyStat.running = false; keyStat.running = true;
        gmodels.running = false; gmodels.running = true;
    }
    Process {
        id: keyStat
        running: root.needKey
        command: [Paths.script("hf-ai"), "key", "status", "gemini"]
        stdout: StdioCollector { onStreamFinished: { try { root.key = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: gmodels
        running: root.prov === "gemini"
        command: [Paths.script("hf-ai"), "models", "gemini"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.geminiModels = j.models ?? []; root.geminiModelsErr = j.error ?? ""; } catch (e) {} } }
    }
    Process {
        running: root.prov === "opencode"
        command: [Paths.script("hf-ai"), "models", "opencode"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.ocModels = j.models ?? []; root.ocModelsErr = j.error ?? ""; } catch (e) {} } }
    }
    Process {
        id: keySet
        property string value: ""
        command: [Paths.script("hf-ai"), "key", "set", "gemini"]
        environment: ({ HF_AI_KEY_IN: keySet.value })
        stdout: StdioCollector {
            onStreamFinished: {
                keySet.value = "";
                try {
                    const j = JSON.parse(text);
                    root.keyErr = !j.ok;
                    root.keyMsg = j.ok ? (j.where === "llavero" ? "Guardada en el llavero" : "Guardada en un archivo privado") : j.error;
                    if (j.ok) { keyField.text = ""; root.testMsg = ""; }
                } catch (e) { root.keyErr = true; root.keyMsg = "No se pudo guardar la clave"; }
                root.refreshGemini(); statTimer.restart();
            }
        }
    }
    Process {
        id: keyClear
        command: [Paths.script("hf-ai"), "key", "clear", "gemini"]
        onExited: { root.keyErr = false; root.keyMsg = "Clave borrada"; root.testMsg = ""; root.refreshGemini(); statTimer.restart(); }
    }
    Process {
        id: tester
        command: [Paths.script("hf-ai"), "test"]
        onRunningChanged: root.testing = running
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.testOk = !!j.ok; root.testMsg = j.text; } catch (e) { root.testOk = false; root.testMsg = "No se pudo probar"; } } }
    }
    function saveKey(): void {
        const k = keyField.text.trim();
        if (!k) return;
        keySet.value = k;
        keySet.running = true;
    }

    readonly property var models: prov === "claude-code" ? [["", "Predeterminado de Claude Code"], ["haiku", "Haiku (rápido)"], ["sonnet", "Sonnet (equilibrado)"], ["opus", "Opus (el más capaz)"]]
        : prov === "ollama" ? (ollamaModels.length ? ollamaModels.map(m => [m, m]) : [["gemma4:e4b", "gemma4:e4b"]])
        : prov === "gemini" ? (geminiModels.length ? geminiModels : [["gemini-flash-latest", "Gemini Flash (recomendado)"]])
        : prov === "opencode" ? (ocModels.length ? ocModels : [["", "DeepSeek V4.1 Flash Free · gratis"]])
        : prov === "cli" ? [["", "Predeterminado de " + cliLabel]]
        : [["gpt-4o-mini", "gpt-4o-mini"], ["claude-sonnet-5-5", "claude-sonnet-5-5"]]
    readonly property string curModel: {
        const m = Settings.get("aiModel", "");
        return prov === "gemini" && !/^(gemini|gemma|learnlm)/.test(m) ? "gemini-flash-latest"
            : prov === "opencode" && m === "" && ocModels.length ? "opencode/deepseek-v4.1-flash-free" : m;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Proveedor"
            headerRight: Txt { text: root.status; size: 11.5; color: root.status === "Disponible" ? Theme.p : Theme.tv }
            Seg {
                Layout.fillWidth: true
                textSize: 11.5
                model: [["claude-code", "Claude"], ["gemini", "Gemini"]].concat(root.hasOpencode || root.prov === "opencode" ? [["opencode", "OpenCode"]] : [])
                    .concat([["ollama", "Ollama"], ["openai-compatible", "API OpenAI"]])
                    .concat(root.termClis.length || root.prov === "cli" ? [["cli", root.cliLabel]] : []).concat([["off", "Apagado"]])
                current: root.prov
                // el modelo de un proveedor no sirve en otro: vuelve al predeterminado
                onPicked: k => {
                    if (k !== root.prov) Settings.setMany(Object.assign({ aiProvider: k, aiModel: "" },
                        k === "cli" && !root.termClis.some(c => c.id === root.cliId) && root.termClis.length ? { aiCli: root.termClis[0].id } : {}));
                    root.testMsg = ""; root.keyMsg = ""; statTimer.restart();
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: root.prov === "claude-code" ? "Usa la CLI de Claude Code (`claude -p`) con tu cuenta. Nada se envía si no escribes al asistente."
                    : root.prov === "gemini" ? "Google Gemini con una clave gratuita de Google AI Studio. Ve las imágenes que adjuntes. En el plan gratuito Google puede usar lo que envías para mejorar sus modelos."
                    : root.prov === "opencode" ? "Los modelos de OpenCode, por su servicio local y sin herramientas: no puede ejecutar, leer ni editar nada. Los gratuitos comparten una cuota por cuenta (también lo que programas con OpenCode); al agotarse responde el respaldo. No ve imágenes (van por OCR)."
                    : root.prov === "ollama" ? "Todo se queda en tu equipo. Necesita Ollama en marcha y un modelo descargado (ollama pull gemma4:e4b)."
                    : root.prov === "openai-compatible" ? "Cualquier servidor con la API /v1/chat/completions (LM Studio, vLLM, OpenRouter…). La clave se lee de una variable de entorno."
                    : root.prov === "cli" ? root.cliLabel + " ya instalado en tu equipo: responde por la terminal, sin herramientas y en una carpeta vacía. No ve imágenes (van por OCR)."
                    : "El asistente queda apagado: el panel lateral y «?» en Spotlight no responden."
            }

            // ---- clave de Gemini ----
            LabeledRow {
                visible: root.needKey
                label: "Clave de la API"; labelWidth: 120
                hint: root.key.stored ? root.key.hint : ""
                RowLayout {
                    spacing: 8
                    Field {
                        id: keyField
                        Layout.fillWidth: true
                        icon: ""
                        input.echoMode: TextInput.Password
                        placeholder: root.key.stored ? (root.key.where.startsWith("env:") ? "Se usa $" + root.key.where.slice(4) : "Guardada · pega otra") : "Pega aquí tu clave (AIza… o AQ.…)"
                        onAccepted: root.saveKey()
                    }
                    Button { kind: "primary"; text: "Guardar"; enabled: keyField.text.trim() !== "" && !keySet.running; onClicked: root.saveKey() }
                    Button { visible: root.key.stored && !root.key.where.startsWith("env:"); text: "Borrar"; onClicked: keyClear.running = true }
                }
            }
            RowLayout {
                visible: root.needKey
                Layout.fillWidth: true
                Layout.leftMargin: 130
                spacing: 16
                Button { kind: "link"; text: "Obtener una clave gratis ↗"; onClicked: Qt.openUrlExternally("https://aistudio.google.com/apikey") }
                Txt {
                    Layout.fillWidth: true
                    size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    color: root.keyErr ? Theme.ter : Theme.tv
                    text: root.keyMsg !== "" ? root.keyMsg : root.key.stored ? (root.key.where === "llavero" ? "En el llavero del sistema" : root.key.where === "archivo" ? "En un archivo privado" : "De la variable de entorno") : "Sin clave"
                }
            }

            LabeledRow {
                visible: root.prov !== "off"
                label: "Modelo"; labelWidth: 120
                Dropdown { model: root.models; current: root.curModel; onPicked: k => Settings.set("aiModel", k) }
            }
            Txt {
                visible: root.prov === "opencode" && root.ocModelsErr !== ""
                Layout.fillWidth: true; Layout.leftMargin: 130
                size: 11; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "No pude leer la lista de modelos: " + root.ocModelsErr
            }
            Txt {
                visible: root.prov === "gemini" && root.geminiModelsErr !== "" && root.key.stored
                Layout.fillWidth: true; Layout.leftMargin: 130
                size: 11; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: "No pude leer la lista de modelos: " + root.geminiModelsErr
            }
            LabeledRow {
                visible: root.prov !== "off"
                label: "Modelo (texto)"; labelWidth: 120
                Field { icon: ""; text: root.prov === "gemini" && root.curModel !== Settings.get("aiModel", "") ? "" : Settings.get("aiModel", ""); placeholder: "o escribe el nombre exacto…"; onAccepted: Settings.set("aiModel", text.trim()) }
            }
            LabeledRow {
                visible: root.prov === "ollama" || root.prov === "openai-compatible"
                label: "Dirección del servidor"; labelWidth: 120
                Field {
                    icon: ""
                    text: Settings.get("aiEndpoint", "")
                    placeholder: root.prov === "ollama" ? "http://localhost:11434" : "https://api.openai.com/v1"
                    onAccepted: { Settings.set("aiEndpoint", text.trim()); statTimer.restart(); }
                }
            }
            LabeledRow {
                visible: root.prov === "openai-compatible"
                label: "Variable de la clave"; labelWidth: 120
                Field { icon: ""; text: Settings.get("aiKeyEnv", "HF_AI_KEY"); placeholder: "HF_AI_KEY"; onAccepted: Settings.set("aiKeyEnv", text.trim()) }
            }
            RowLayout {
                visible: root.prov !== "off"
                Layout.fillWidth: true
                spacing: 12
                Button {
                    text: root.testing ? "Probando…" : "Probar conexión"
                    enabled: !root.testing && (root.prov !== "gemini" || root.key.stored)
                    onClicked: { root.testMsg = ""; tester.running = true; }
                }
                Txt {
                    Layout.fillWidth: true
                    size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 3
                    color: root.testOk ? Theme.p : Theme.ter
                    text: root.testMsg
                }
            }
        }
        Section {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Permisos"
            SwRow { separator: false; label: "Leer la ventana activa"; sub: "título y clase, para entender de qué hablas"; key: "aiContextWindow"; def: true }
            SwRow { label: "Leer el portapapeles"; sub: "solo cuando le escribes"; key: "aiContextClipboard"; def: true }
            SwRow { label: "Ver capturas que adjuntes"; sub: root.prov === "gemini" ? "Gemini recibe la imagen tal cual" : "captura + OCR local (tesseract)"; key: "aiContextCapture"; def: true }
            SwRow { label: "Proponer comandos de terminal"; sub: "nunca los ejecuta sin que pulses"; key: "aiTerminal"; def: true }
            SwRow { label: "Controlar el escritorio"; sub: "ajustes, ventanas, apps, música, volumen, temporizadores… (con Deshacer)"; key: "aiControlShell"; def: true }
            // scripts/hf-screen: analiza la pantalla (OCR + elementos numerados), señala con un cursor fantasma y hace
            // clic o escribe con un puntero virtual; cada paso se confirma (hf-ai meta)
            SwRow { label: "Usar la pantalla"; sub: "señala con un cursor fantasma dónde hará clic o escribirá, y lo hace cuando lo apruebas"; key: "aiScreenControl"; def: true }
            SwRow { label: "Consultar el escritorio"; sub: "ventanas abiertas, avisos, archivos y estado, solo cuando lo necesite"; key: "aiReadDesktop"; def: true }
            SwRow { label: "Confirmar antes de aplicar cambios"; sub: "y siempre se pueden deshacer"; key: "aiConfirm"; def: true }
            SwRow { label: "Responder desde Spotlight"; sub: "escribe ? y tu pregunta"; key: "aiSpotlight"; def: true }
            LinkRow { label: "Privacidad, historial y registro de acciones"; section: "iaprivacidad"; sectionLabel: "Privacidad"; target: "Ocultar datos sensibles" }
        }
    }

    // IA que ya tienes instalada (hf-ai clis): elegirla de principal o de respaldo con un clic
    Section {
        Layout.fillWidth: true
        title: "IA ya instalada en este equipo"
        headerRight: Txt { text: root.clis.length ? root.clis.length + (root.clis.length === 1 ? " encontrada" : " encontradas") : ""; size: 11.5; color: Theme.tv }
        Txt {
            visible: !root.clis.length
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "No encuentro ninguna: Claude Code (claude), OpenCode, Ollama o llm. Si instalas una, sale aquí. Otras (Codex, Gemini CLI…) no se ofrecen: leen tus archivos o salen a la web por su cuenta."
        }
        Repeater {
            model: root.clis
            InfoRow {
                required property var modelData
                required property int index
                separator: index > 0
                label: modelData.name
                sub: modelData.path
                glyph: modelData.name.split(/[\s-]+/).map(w => w[0]).join("").slice(0, 2).toUpperCase()
                lit: root.isPrimary(modelData) || root.isFallback(modelData)
                badge: root.isPrimary(modelData) ? "Principal" : root.isFallback(modelData) ? "Respaldo" : ""
                badgeStrong: root.isPrimary(modelData)
                Button { visible: !root.isPrimary(modelData); text: "Usar"; h: 28; onClicked: root.usePrimary(modelData) }
                Button { visible: !root.isPrimary(modelData) && !root.isFallback(modelData); text: "De respaldo"; h: 28; onClicked: root.useFallback(modelData) }
            }
        }
    }

    // Modelos (hf-ai provider_for / fallback_for): modelo por tarea, respaldo si el proveedor falla y modo local
    Section {
        Layout.fillWidth: true
        visible: root.prov !== "off"
        title: "Modelos"
        SwRow {
            separator: false
            label: "Solo en este equipo"
            sub: "usa Ollama y apaga lo que sale a la nube (voces de Gemini incluidas); el modelo, el del respaldo si es Ollama"
            key: "aiLocalOnly"; def: false
        }
        LabeledRow {
            label: "Respuestas rápidas"; labelWidth: 140
            hint: "Spotlight y voz"
            Field { icon: ""; text: Settings.get("aiModelQuick", ""); placeholder: "El mismo que el general (p. ej. haiku)"; onAccepted: Settings.set("aiModelQuick", text.trim()) }
        }
        LabeledRow {
            label: "Con imágenes"; labelWidth: 140
            hint: "capturas"
            Field { icon: ""; text: Settings.get("aiModelVision", ""); placeholder: "El mismo que el general"; onAccepted: Settings.set("aiModelVision", text.trim()) }
        }
        LabeledRow {
            label: "Si no responde"; labelWidth: 140
            Seg {
                model: [["", "Nada"], ["ollama", "Ollama"], ["claude-code", "Claude"], ["gemini", "Gemini"]].concat(root.hasOpencode ? [["opencode", "OpenCode"]] : [])
                    .concat(root.termClis.length ? [["cli", root.cliLabel]] : []).filter(x => x[0] !== root.prov)
                current: Settings.get("aiFallbackProvider", "")
                onPicked: k => Settings.setMany(Object.assign({ aiFallbackProvider: k, aiFallbackModel: "" },
                    k === "cli" && !root.termClis.some(c => c.id === root.cliId) ? { aiCli: root.termClis[0].id } : {}))
            }
        }
        LabeledRow {
            visible: Settings.get("aiFallbackProvider", "") !== ""
            label: "Modelo del respaldo"; labelWidth: 140
            Field {
                icon: ""
                text: Settings.get("aiFallbackModel", "")
                placeholder: ({ ollama: "gemma4:e4b", "claude-code": "haiku", gemini: "gemini-flash-latest", opencode: "opencode/deepseek-v4.1-flash-free" })[Settings.get("aiFallbackProvider", "")] ?? ""
                onAccepted: Settings.set("aiFallbackModel", text.trim())
            }
        }
        // hf-ai WAIT: lo que se espera al principal antes de preguntar al respaldo (voz; al escribir, el triple)
        LabeledRow {
            visible: Settings.get("aiFallbackProvider", "") !== ""
            label: "Saltar al respaldo"; labelWidth: 140
            hint: "si no contesta en"
            Seg {
                model: [[5, "5 s"], [8, "8 s"], [12, "12 s"], [20, "20 s"]]
                current: Number(Settings.get("aiFallbackWait", 8))
                onPicked: k => Settings.set("aiFallbackWait", k)
            }
        }
        Txt {
            visible: Settings.get("aiFallbackProvider", "") !== ""
            Layout.fillWidth: true; Layout.leftMargin: 150
            size: 11; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: "Se espera el triple: el respaldo contesta si el principal no lo ha hecho a los " + 3 * Number(Settings.get("aiFallbackWait", 8)) + " s."
        }
    }

    // Leer en voz alta (aiVoice): la voz de Harper (local, Piper) solo lee, no conversa. hf-ai announce y greet;
    // Notifs.qml lee los urgentes. Nunca en «no molestar».
    Section {
        Layout.fillWidth: true
        title: "Leer en voz alta"
        SwRow {
            label: "Leer en voz alta"; key: "aiVoice"; def: false
            sub: root.voiceLocal === false ? "falta la voz de Harper: instálala abajo"
                                           : (Settings.get("aiName", "") || "Harper") + " lee los avisos que elijas con su voz local (rápida y sin internet). No conversa: el asistente se usa por escrito"
        }
        Button {
            visible: root.voiceLocal === false
            text: "Instalar la voz de Harper (Piper, ~250 MB, sin internet)"
            onClicked: { Pkg.runInTerminal(Paths.script("hf-ai") + " voice-install --tty", "Voz del asistente"); voiceLater.n = 0; voiceLater.restart(); }
        }
        SwRow {
            visible: Settings.get("aiVoice", false) === true
            label: "Avisos urgentes"; key: "aiAnnounceUrgent"; def: false
            sub: "recordatorios y temporizadores del asistente al vencer, batería baja y otras notificaciones urgentes; calla en «no molestar»"
        }
        SwRow {
            visible: Settings.get("aiVoice", false) === true
            label: "Saludo al entrar"; key: "aiAnnounceGreet"; def: false
            sub: "al iniciar sesión dice la hora y el tiempo"
        }
        Timer { id: voiceLater; interval: 5000; repeat: true; property int n: 0; onTriggered: { stat.running = false; stat.running = true; if (++n > 24 || root.voiceLocal) stop(); } }
    }

    // Personalidad (aiName, aiPersona): scripts/hf-ai persona_doc las AÑADE al prompt base, que no se puede
    // sustituir (sus reglas de acciones y permisos mandan siempre). La IA no puede tocarlas (DENY_KEYS ^ai[A-Z]).
    Section {
        Layout.fillWidth: true
        title: "Personalidad"
        headerRight: Button {
            visible: Settings.user.aiName !== undefined || Settings.user.aiPersona !== undefined     // solo si los cambiaste
            text: "Restablecer"; h: 26
            // vuelven el nombre y la personalidad de fábrica (no se quedan vacíos)
            onClicked: { Settings.reset(["aiName", "aiPersona"]); persona.text = Settings.get("aiPersona", ""); nameField.text = Settings.get("aiName", ""); }
        }
        LabeledRow {
            label: "Nombre"
            labelWidth: 120
            hint: "aiName"
            Field {
                id: nameField
                icon: ""
                placeholder: "Sin nombre (Tu asistente del escritorio)"
                text: Settings.get("aiName", "")
                input.maximumLength: 40
                onAccepted: Settings.set("aiName", text.trim())
                input.onActiveFocusChanged: if (!input.activeFocus && text.trim() !== Settings.get("aiName", "")) Settings.set("aiName", text.trim())
            }
        }
        Txt {
            Layout.fillWidth: true
            text: "Cómo quieres que sea: tono, trato, idioma, si responde corto o largo, en qué te conoce… Se suma a sus instrucciones de siempre; lo que pidas aquí no le quita los permisos ni la confirmación de cambios."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(84, Math.min(220, persona.contentHeight + 18))
            radius: Theme.r(8)
            color: Theme.fill2
            border.width: persona.activeFocus ? 2 : 0
            border.color: Theme.p
            TextEdit {
                id: persona
                anchors { fill: parent; margins: 8 }
                wrapMode: TextEdit.Wrap
                color: Theme.t
                selectionColor: Theme.pc
                selectedTextColor: Theme.pcText
                font.family: Theme.font
                font.pixelSize: Theme.px(12.5)
                clip: true
                text: Settings.get("aiPersona", "")
                function save(): void {
                    const t = text.trim().slice(0, 2000);
                    if (t !== Settings.get("aiPersona", "")) Settings.set("aiPersona", t);
                }
                onTextChanged: if (activeFocus) personaSave.restart()
                onActiveFocusChanged: if (!activeFocus) save()
                Txt {
                    visible: persona.text === ""
                    width: parent.width
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "Ejemplo: Háblame de tú y con humor, como un amigo. Respuestas cortas. Me llamo Fer y programo en Python."
                    muted: true; size: 12
                }
            }
            Timer { id: personaSave; interval: 800; onTriggered: persona.save() }
        }
        Txt {
            Layout.alignment: Qt.AlignRight
            visible: persona.text.length > 1500
            text: persona.text.length + " / 2000"
            size: 11; color: persona.text.length > 2000 ? Theme.ter : Theme.tv
        }
    }

    // «Aprobar siempre esta acción» (tarjeta del plan en el panel): aiAlwaysApprove, con su nombre de `hf-ai approvals`
    readonly property var always: Settings.get("aiAlwaysApprove", [])
    property var alwaysLabels: ({})
    onAlwaysChanged: { appr.running = false; appr.running = true; }
    Process {
        id: appr
        running: true
        command: [Paths.script("hf-ai"), "approvals"]
        stdout: StdioCollector { onStreamFinished: { try { const m = {}; JSON.parse(text).forEach(x => m[x.kind] = x.label); root.alwaysLabels = m; } catch (e) {} } }
    }
    Section {
        Layout.fillWidth: true
        title: "Aprobadas siempre"
        headerRight: Button { visible: root.always.length > 0; text: "Quitar todas"; h: 26; onClicked: Settings.set("aiAlwaysApprove", []) }
        Txt {
            Layout.fillWidth: true
            text: root.always.length
                ? "Estas acciones se aplican sin preguntar (siguen pudiéndose deshacer). Lo que no tiene vuelta atrás —cerrar ventanas, expulsar, cancelar descargas, comandos— pregunta siempre."
                : "Ninguna. En el panel de la IA, bajo cada paso propuesto, «Aprobar siempre esta acción» hace que esa acción no vuelva a preguntar."
            muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Repeater {
            model: root.always
            RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: 12
                Txt { Layout.fillWidth: true; text: root.alwaysLabels[parent.modelData] ?? parent.modelData; weight: Font.DemiBold }
                Txt { text: parent.modelData; muted: true; size: 11; font.family: Theme.mono }
                Button { text: "Revocar"; h: 26; onClicked: Settings.set("aiAlwaysApprove", root.always.filter(k => k !== parent.modelData)) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Txt { Layout.fillWidth: true; text: "Presentación del asistente (qué puede hacer y ejemplos)"; muted: true; size: 11.5 }
            Button { text: "Volver a verla"; kind: "link"; enabled: Settings.get("aiOnboarded", false) === true; onClicked: Settings.set("aiOnboarded", false) }
        }
    }
}
