// Ajustes › Asistente de IA — proveedor/modelo/servidor (los usa scripts/hf-ai: aiProvider, aiModel, aiEndpoint,
// aiKeyEnv), personalidad (aiName, aiPersona) y permisos del asistente (aiContextWindow, aiContextClipboard…).
// Gemini: la clave se guarda con `hf-ai key set gemini` (llavero con secret-tool o ~/.config/hyprfrijol/secrets,
// nunca en settings.json); la lista de modelos sale de `hf-ai models gemini` y «Probar conexión» de `hf-ai test`.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"
import "../ui"

ColumnLayout {
    id: root
    spacing: 12
    readonly property string prov: Settings.get("aiProvider", "claude-code")
    property var ollamaModels: []
    property var geminiModels: []
    property string geminiModelsErr: ""
    property string status: ""
    property var key: ({ stored: false, where: "", hint: "" })
    readonly property bool needKey: prov === "gemini" || Settings.get("aiVoice", false)   // la voz usa Gemini TTS
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
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.status = j.available ? "Disponible" : (j.hint || j.error || "No disponible"); } catch (e) { root.status = ""; } } }
    }
    Timer { id: statTimer; interval: 900; onTriggered: { stat.running = false; stat.running = true; } }

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
        : prov === "ollama" ? (ollamaModels.length ? ollamaModels.map(m => [m, m]) : [["llama3.2", "llama3.2"]])
        : prov === "gemini" ? (geminiModels.length ? geminiModels : [["gemini-flash-latest", "Gemini Flash (recomendado)"]])
        : [["gpt-4o-mini", "gpt-4o-mini"], ["claude-sonnet-5-5", "claude-sonnet-5-5"]]
    readonly property string curModel: {
        const m = Settings.get("aiModel", "");
        return prov === "gemini" && !/^(gemini|gemma|learnlm)/.test(m) ? "gemini-flash-latest" : m;
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
                model: [["claude-code", "Claude"], ["gemini", "Gemini"], ["ollama", "Ollama"], ["openai-compatible", "API OpenAI"], ["off", "Apagado"]]
                current: root.prov
                // el modelo de un proveedor no sirve en otro: vuelve al predeterminado
                onPicked: k => { if (k !== root.prov) Settings.setMany({ aiProvider: k, aiModel: "" }); root.testMsg = ""; root.keyMsg = ""; statTimer.restart(); }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: root.prov === "claude-code" ? "Usa la CLI de Claude Code (`claude -p`) con tu cuenta. Nada se envía si no escribes al asistente."
                    : root.prov === "gemini" ? "Google Gemini con una clave gratuita de Google AI Studio. Ve las imágenes que adjuntes. En el plan gratuito Google puede usar lo que envías para mejorar sus modelos."
                    : root.prov === "ollama" ? "Todo se queda en tu equipo. Necesita Ollama en marcha y un modelo descargado (ollama pull llama3.2)."
                    : root.prov === "openai-compatible" ? "Cualquier servidor con la API /v1/chat/completions (LM Studio, vLLM, OpenRouter…). La clave se lee de una variable de entorno."
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
                spacing: 14
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
                spacing: 10
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
            Item { implicitHeight: 2 }
            Kv { k: "Atajo para abrir"; v: "Super + A" }
            Kv { k: "Preguntar desde Spotlight"; v: "Empieza con ?" }
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
            SwRow { label: "Consultar el escritorio"; sub: "ventanas abiertas, avisos, archivos y estado, solo cuando lo necesite"; key: "aiReadDesktop"; def: true }
            SwRow { label: "Confirmar antes de aplicar cambios"; sub: "y siempre se pueden deshacer"; key: "aiConfirm"; def: true }
            SwRow { label: "Responder desde Spotlight"; sub: "escribe ? y tu pregunta"; key: "aiSpotlight"; def: true }
            SwRow { label: "Guardar historial de conversaciones"; sub: "~/.local/share/hyprfrijol/ai"; key: "aiHistory"; def: true }
        }
    }

    // Personalidad (aiName, aiPersona): scripts/hf-ai persona_doc las AÑADE al prompt base, que no se puede
    // sustituir (sus reglas de acciones y permisos mandan siempre). La IA no puede tocarlas (DENY_KEYS ^ai[A-Z]).
    Section {
        Layout.fillWidth: true
        title: "Personalidad"
        headerRight: Button {
            visible: Settings.get("aiName", "") !== "" || Settings.get("aiPersona", "") !== ""
            text: "Restablecer"; h: 26
            onClicked: { Settings.set("aiName", ""); Settings.set("aiPersona", ""); persona.text = ""; nameField.text = ""; }
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
            border.width: persona.activeFocus && Theme.estilo === "flat" ? 2 : 0
            border.color: Theme.p
            TextEdit {
                id: persona
                anchors { fill: parent; margins: 9 }
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
        // Voz (aiVoice, aiVoiceName): hf-ai speak lee cada respuesta con Gemini TTS, con la clave de Gemini de arriba
        SwRow { label: "Hablar con voz"; sub: "lee las respuestas en voz alta con Gemini (clave gratuita de Google; Google recibe el texto)"; key: "aiVoice"; def: false }
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
                spacing: 10
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
