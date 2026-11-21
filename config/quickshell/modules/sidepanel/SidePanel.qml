// Panel lateral (vista "ia"): el asistente de IA (AiChat.qml), a un lado de la pantalla.
//   Shell.open("ia")                 abre el panel
//   Shell.open("ia", {ask: "…"})     (o el texto '{"ask":"…"}' por IPC) → pregunta directamente a la IA
//   Shell.open("ia", {ask, image})   adjunta una imagen a la pregunta
// Ajustes › Panel lateral: sideWidth ("cuarto" | "tercio" | px), sideSide ("derecha" | "izquierda").
// Fijar (botón de la chincheta · Ajustes › Panel lateral, sidePanelPinned): el panel deja de flotar encima y pasa a
// formar parte del mosaico: una capa invisible (hf-ia-zone) reserva su franja (zona exclusiva de layer-shell, como la
// barra) y las ventanas en mosaico se recolocan a su lado. Se queda abierto en todos los espacios y al abrir otras
// vistas, no se cierra con Esc (Esc devuelve el teclado a la última ventana) y va siempre en la pantalla principal
// (Ajustes › Pantallas). Se esconde (sin dejar la franja visible) con una ventana a pantalla completa, en el modo sin
// distracciones y durante la captura de la IA. Super + A y la × lo esconden en esta sesión (Shell.sideHidden: la
// franja se libera) y Super + A lo vuelve a mostrar fijado; desfijar = la chincheta o el ajuste.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: win
    // ---- fijado (sidePanelPinned): forma parte del mosaico
    readonly property bool pinPref: Settings.get("sidePanelPinned", false) === true
    readonly property bool pinActive: pinPref && !Shell.focusMode && !Shell.sideHidden
    readonly property var pinScreen: Shell.primaryScreen
    readonly property var pinMon: HyprClients.monitorByName(pinScreen?.name ?? "")
    // Ventana a pantalla completa de verdad (fullscreen 2; la maximizada respeta la franja) en la pantalla del panel
    readonly property bool fsHere: {
        if (!pinActive) return false;
        HyprClients.refreshes;
        const id = pinMon?.activeWorkspace?.id ?? 0;
        return HyprClients.clients.some(c => c.workspace?.id === id && (c.fullscreen ?? 0) === 2);
    }
    // Al pasar una ventana a pantalla completa el panel fijado se aparta aunque se hubiera abierto con Super + A
    // (abrirlo después, ya en pantalla completa, sí lo muestra encima)
    // Si su pantalla desaparece (monitor que se apaga, salida nueva) Quickshell esconde la ventana y su `visible` deja de
    // seguir al enlace; el panel fijado no cambia de estado y no volvería: tras cada cambio de pantallas se vuelve a enlazar
    Connections { target: Quickshell; function onScreensChanged() { kickTimer.restart(); } }
    Timer {
        id: kickTimer; interval: 400
        // Se cierra y se vuelve a crear la superficie (con la pantalla nueva puede quedarse sin capa en Hyprland)
        onTriggered: { win.visible = false; zone.visible = false; rebind.restart(); }
    }
    Timer {
        id: rebind; interval: 60
        onTriggered: {
            win.visible = Qt.binding(() => win.shown || slide.running);
            zone.visible = Qt.binding(() => win.pinActive && win.zoneW > 0);
        }
    }
    onFsHereChanged: if (fsHere && Shell.view === "ia") Shell.close()
    // Captura de pantalla de la IA (AiChat.capturing): el panel fijado también se aparta
    property bool chatCapturing: false
    Connections {
        target: chatLoader.item
        ignoreUnknownSignals: true
        function onCapturingChanged() { win.chatCapturing = chatLoader.item?.capturing ?? false; }
    }
    // hf-screen parse (Harper analiza la pantalla para usarla): el panel se aparta un momento y vuelve
    property bool asideForScreen: false
    property bool reopenAfterAside: false
    readonly property bool pinShown: pinActive && !fsHere && !chatCapturing && !asideForScreen
    readonly property bool shown: Shell.view === "ia" || pinShown
    onPinActiveChanged: Shell.sidePinned = pinActive
    function togglePin() {
        const on = !pinPref;
        Settings.set("sidePanelPinned", on);
        if (on) { Shell.sideHidden = false; if (Shell.view !== "ia") Shell.open("ia"); }
    }
    // × o Esc: fijado se esconde (esta sesión) o solo devuelve el teclado; si no, se cierra como siempre
    function hidePanel() {
        if (pinPref) Shell.sideHidden = true;
        if (Shell.view === "ia") Shell.close();
    }
    function releaseFocus() {
        const c = HyprClients.byRecent.find(c => c.monitor === pinMon?.id) ?? HyprClients.byRecent[0];
        if (c) HyprClients.focusWindow(c.address);
        if (Shell.view === "ia") Shell.close();
    }
    // El chat (AiChat.qml) se carga la primera vez que se usa la pestaña IA (carga diferida, lazyModules) y se descarga
    // un rato después de cerrar el panel si no hay conversación ni respuesta en curso (sin aiHistory se perdería).
    property bool chatHeld: false
    onShownChanged: {
        Shell.sideShown = shown;
        if (shown) {
            chatHeld = true;
            // El panel toma el teclado (la entrada de la pregunta): al abrirlo se puede escribir de inmediato. Con el
            // panel fijado no: es parte del mosaico y no debe robarle el teclado a lo que estés haciendo.
            if (!win.pinActive) Qt.callLater(() => win.chat.focusInput?.());
        }
        else modelMenu = false;      // el desplegable de proveedor no se queda abierto al cerrar el panel
    }
    Timer {
        interval: 60000
        repeat: true
        running: Shell.lazyModules && win.chatHeld && !win.shown
        onTriggered: {
            const c = chatLoader.item;
            if (c && (c.busy || c.capturing || c.messages.length || c.pending.length || c.winInfo)) return;
            win.chatHeld = false;
            Qt.callLater(() => gc());
        }
    }
    Connections {
        target: Shell
        function onPreloadRequested(v) { if (v === "ia") win.chatHeld = true; }   // cursor sobre el botón de la IA
    }
    readonly property var chat: chatLoader.item ?? ({ ask: () => {}, attach: () => {}, focusInput: () => {}, clear: () => {}, toggleHistory: () => {}, showHistory: false, toggleLog: () => {}, showLog: false, setWindow: () => {}, handoffTo: null, handoff: () => {}, messages: [] })

    readonly property string aiLabel: String(Settings.get("aiName", "") ?? "").trim() || "IA"
    // Bajo el nombre: quién responde y su respaldo («Gemini · respaldo Ollama»)
    readonly property var provNames: ({ "claude-code": "Claude Code", claude: "Claude", gemini: "Gemini", ollama: "Ollama", opencode: "OpenCode", openai: "OpenAI",
                                        "openai-compatible": "OpenAI compatible", openrouter: "OpenRouter", lmstudio: "LM Studio", mistral: "Mistral", groq: "Groq", deepseek: "DeepSeek",
                                        cli: Settings.get("aiCli", "") || "Terminal" })
    function provName(k): string { k = String(k ?? ""); return provNames[k] ?? (k ? k.charAt(0).toUpperCase() + k.slice(1) : ""); }
    // El modelo que está respondiendo (con OpenCode, el que elige él solo si en Ajustes no hay ninguno): se ve tras la
    // primera respuesta (el pie de cada respuesta también lo enseña).
    readonly property string aiModel: {
        const ms = win.chat.messages ?? [];
        for (let i = ms.length - 1; i >= 0; i--)
            if ((ms[i]?.role ?? "") === "ai" && (ms[i]?.model ?? "") !== "") return String(ms[i].model);
        return "";
    }
    // Lo que dejan los botones de la cabecera (≈ 200 px): el subtítulo se mide y se recorta por lo que cabe
    FontMetrics {
        id: subM
        font.family: Theme.font
        font.pixelSize: Theme.px(Theme.typeStep(10.5))
    }
    readonly property string aiSub: {
        // respaldo solo si es un proveedor conocido, como hf-ai (fallback_for): "off" de versiones viejas = sin respaldo
        const fk = String(Settings.get("aiFallbackProvider", "") ?? "");
        const p = provName(Settings.get("aiProvider", "")), f = fk in provNames ? provName(fk) : "";
        const m = win.aiModel.split("/").pop();       // el nombre del modelo, sin el proveedor delante
        const fb = (f && f !== p) ? "↩ " + f : "";    // «↩ Ollama»: si el principal falla, responde este
        // lo que queda libre entre el icono y los botones: si el modelo no cabe entero, no se enseña (el pie de cada
        // respuesta sí lo dice)
        const room = win.panelW - (win.chat.handoffTo ? 234 : 208);
        const fits = t => subM.advanceWidth(t) <= room;
        const full = p + (m ? " · " + m : "") + (fb ? " · " + fb : "");
        if (fits(full)) return full;
        const withModel = m ? p + " · " + m : "";
        if (withModel && fits(withModel)) return withModel;
        const withFb = fb ? p + " · " + fb : "";
        if (withFb && fits(withFb)) return withFb;
        return p;
    }

    // ---- proveedor y modelo (la cabecera): el desplegable
    readonly property var provList: ["claude-code", "gemini", "opencode", "ollama", "openai-compatible", "cli"]
    property bool modelMenu: false
    // Los modelos del proveedor elegido (hf-ai models <proveedor>); «auto» es el que se usaría sin elegir ninguno.
    property var provModels: []
    property string provAuto: ""
    property bool provLoading: false
    function loadProvModels(p) {
        if (!p || p === "off") { provModels = []; provAuto = ""; provLoading = false; return; }
        provLoading = true;
        provProc.command = [Paths.script("hf-ai"), "models", p];
        provProc.running = false; provProc.running = true;
    }
    Process {
        id: provProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { const j = JSON.parse(text); win.provModels = j.models ?? []; win.provAuto = j.auto ?? ""; }
                catch (e) { win.provModels = []; win.provAuto = ""; }
                win.provLoading = false;
            }
        }
    }
    function toggleModelMenu() {
        modelMenu = !modelMenu;
        if (modelMenu) loadProvModels(Settings.get("aiProvider", "claude-code"));
    }
    // Cambiar de proveedor deja el modelo vacío (el que toque en el nuevo) y el desplegable sigue abierto: así se elige
    // el modelo sin volver a entrar. En el mismo proveedor no se toca nada.
    function pickProvider(p) {
        if (String(p) === String(Settings.get("aiProvider", ""))) return;
        Settings.setMany({ aiProvider: p, aiModel: "" });
        loadProvModels(p);
    }
    function pickModel(m) { Settings.set("aiModel", m ?? ""); modelMenu = false; }

    // ---- márgenes como Overlay (respetan la barra)
    readonly property string barPos: Settings.get("barPos", "abajo")
    // mismos huecos que las ventanas en mosaico (Settings.winGap = gaps_out): fijado, queda alineado con ellas
    readonly property real gap: Settings.winGap
    readonly property real barEdge: Shell.focusMode ? gap : Math.max(gap, Settings.barEdge)
    readonly property real mT: barPos === "arriba" ? barEdge : gap
    readonly property real mB: barPos === "abajo" ? barEdge : gap
    readonly property bool onLeft: Settings.get("sideSide", "derecha") === "izquierda"
    readonly property real mR: (onLeft ? barPos === "izquierda" : barPos === "derecha") ? barEdge : gap     // margen del lado del panel
    // Ancho (sideWidth): "cuarto" (por defecto: una columna de un mosaico de 4), "tercio" o px
    readonly property var sideWidthPref: Settings.get("sideWidth", "cuarto")
    // una columna de un mosaico de 4 (o de 3), con 320 px como mínimo
    function cols(n: int): real { return Math.round(Math.max(320, ((Number(screen?.width) || 1920) - 16) / n)); }
    readonly property real panelW: sideWidthPref === "tercio" ? cols(3)
        : Number(sideWidthPref) > 0 ? Math.max(320, Math.min(720, Number(sideWidthPref))) : cols(4)
    onPanelWChanged: Shell.sideW = panelW
    Component.onCompleted: { Shell.sideW = panelW; Shell.sidePinned = pinActive; Shell.sideShown = shown; }
    // Franja reservada (fijado): lo que ocupa el panel desde el borde menos lo que ya reserva la barra en ese lado
    // (Hyprland suma las zonas exclusivas; las ventanas quedan a gaps_out del panel, como del borde: sin doble hueco)
    readonly property real barSideReserve: {
        if (Settings.barPos !== (onLeft ? "izquierda" : "derecha") || Shell.focusMode) return 0;
        if (Shell.barModeFor(pinScreen) === "oculta") return 0;
        if (Settings.barAutoHide || Shell.barHidden) return 0;
        if (Settings.barSmartHide) {
            WinMode.overrides; WinMode.mode;
            const ws = pinMon?.activeWorkspace?.id ?? -1;
            if (WinMode.isFloat(ws) || WinMode.hasFullscreen(pinScreen?.name ?? "")) return 0;
        }
        return Settings.barThickness + Settings.barOffset;
    }
    // + lo que falta para que entre el panel y la ventana vecina haya el mismo hueco que entre dos ventanas (2 × gaps_in)
    readonly property real innerFix: Math.max(0, 2 * (Number(Settings.get("gapsIn", 1)) || 0) - Settings.gapsOutPx)
    readonly property int zoneW: Math.max(0, Math.round(mR + panelW + innerFix - barSideReserve))
    readonly property real headH: 40

    screen: pinActive ? pinScreen : Shell.screen
    visible: shown || slide.running
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hf-ia"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // La capa ocupa toda la pantalla (es transparente): así el clic fuera del panel lo cierra. Antes la ventana era
    // solo la franja del panel y el clic fuera no llegaba a ninguna parte.
    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: panelW + mR + 48          // margen para la sombra; el ratón lo atraviesa (mask)
    mask: Region { x: 0; y: 0; width: win.width; height: win.height }

    // ======================================================================= apertura
    property var pendingArg: null
    function handleArg(a) {
        if (typeof a === "string" && a.trim().startsWith("{")) { try { a = JSON.parse(a); } catch (e) {} }
        if ((a && typeof a === "object") || (typeof a === "string" && a.startsWith("ask:"))) {
            chatHeld = true;                                                       // crea el chat ya
            // Se carga en segundo plano: hasta que exista, chat es un sustituto que no hace nada y la pregunta se perdía
            if (!chatLoader.item) { pendingArg = a; return; }
        }
        if (a && typeof a === "object" && a.window) chat.setWindow(a.window);    // hf-ai summon (Super+Ctrl+A)
        if (a && typeof a === "object" && a.image) chat.attach(String(a.image));
        if (a && typeof a === "object" && Array.isArray(a.images)) a.images.forEach(p => chat.attach(String(p)));
        if (a && typeof a === "object" && a.ask !== undefined) chat.ask(String(a.ask), "quick");
        else if (typeof a === "string" && a.startsWith("ask:")) chat.ask(a.slice(4), "quick");
        if (a && typeof a === "object" && a.log) { if (!chat.showLog) chat.toggleLog(); return; }   // qs ipc call sidepanel log
        Qt.callLater(() => win.chat.focusInput());
    }
    Connections {
        target: Shell
        function onOpened(v) { if (v === "ia") win.handleArg(Shell.arg); }
    }
    // ======================================================================= dibujo
    // Clic fuera del panel: lo cierra, como la × (los demás paneles del shell hacen lo mismo: Spotlight, Ajustes
    // rápidos, portapapeles…). El clic se queda aquí y no llega a la ventana de debajo: al cerrarse el panel, el
    // siguiente clic sí llega. Con el panel fijado no: es parte del mosaico y se queda siempre a la vista.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: win.shown && !win.pinActive && Shell.view === "ia"
        onPressed: Shell.close()
    }
    Item {
        id: panel
        x: win.onLeft ? win.mR : parent.width - win.mR - width
        y: win.mT
        width: win.panelW
        height: parent.height - win.mT - win.mB
        focus: true
        Keys.onEscapePressed: {
            if (win.modelMenu) { win.modelMenu = false; return; }   // primero se cierra el desplegable
            win.pinPref ? win.releaseFocus() : Shell.close();
        }

        opacity: win.shown ? 1 : 0
        transform: Translate { x: win.shown ? 0 : (win.onLeft ? -24 : 24); Behavior on x { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } } }
        Behavior on opacity { NumberAnimation { id: slide; duration: win.shown ? Theme.durIn : 160; easing.type: Easing.OutCubic } }

        Glass { anchors.fill: parent; kind: "panel" }
        // Los clics dentro del panel no lo cierran (los que no pilla ningún botón)
        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------- cabecera
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: win.headH
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 2
                    RowLayout {
                        Layout.leftMargin: 8
                        spacing: 8
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: Theme.r(8)
                            color: Theme.pc
                            Icon { anchors.centerIn: parent; name: "ai"; size: 14; stroke: 2; color: Theme.pcText }
                            // respondiendo: un punto que late
                            Rectangle {
                                visible: chat.busy ?? false
                                anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
                                width: 9; height: 9; radius: 4.5; color: Theme.p; border.width: 2; border.color: Theme.glassPanel
                                SequentialAnimation on opacity { running: (chat.busy ?? false) && !Theme.still; loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
                            }
                        }
                        ColumnLayout {
                            id: labels
                            spacing: -1
                            // lo que dejan los botones (≈ 200 px): un proveedor largo se corta y no los empuja fuera
                            Layout.maximumWidth: win.panelW - 200
                            Txt { Layout.fillWidth: true; text: win.aiLabel; weight: Font.DemiBold; size: 13 }
                            Txt { id: aiSubTxt; Layout.fillWidth: true; visible: win.aiSub !== ""; text: win.aiSub; size: 10.5; muted: true }
                            // la línea de quién responde es pulsable: abre el proveedor y el modelo (sin ir a Ajustes)
                            MouseArea {
                                parent: aiSubTxt
                                anchors.fill: parent
                                enabled: win.aiSub !== ""
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.toggleModelMenu()
                            }
                        }
                    }
                    IconBtn {
                        icon: "plus"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        tooltip: "Nueva conversación"
                        onClicked: chat.clear()
                    }
                    IconBtn {
                        icon: "clock"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        active: chat.showHistory
                        tooltip: "Conversaciones anteriores"
                        onClicked: chat.toggleHistory()
                    }
                    IconBtn {
                        icon: "terminal"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        active: chat.showLog
                        tooltip: "Registro del asistente"
                        onClicked: chat.toggleLog()
                    }
                    // «Seguir en …» (aiHandoff): lleva la conversación a otra herramienta de IA
                    IconBtn {
                        visible: !!chat.handoffTo
                        icon: "external"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
                        tooltip: "Seguir en " + (chat.handoffTo?.label ?? "")
                        onClicked: chat.handoff()
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn {
                        icon: "pin"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        active: win.pinPref
                        tooltip: win.pinPref ? "Desfijar: volver a flotar encima" : "Fijar: parte del mosaico"
                        onClicked: win.togglePin()
                    }
                    IconBtn {
                        icon: "x"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: win.pinPref ? "Esconder (sigue fijado; vuelve con Super + A)" : "Cerrar"
                        onClicked: win.hidePanel()
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Theme.ov
                }
            }

            // ---------------------------------------------------- contenido
            // (Loader con URL: los tipos hermanos no se resuelven cuando el módulo se carga por URL en desarrollo)
            Loader {
                id: chatLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: win.chatHeld || !Shell.lazyModules
                asynchronous: !win.shown         // precargado (cursor encima): sin bloquear; al abrir, al momento
                source: Qt.resolvedUrl("AiChat.qml")
                onLoaded: {
                    item.active = Qt.binding(() => win.shown);
                    if (win.pendingArg !== null) { const a = win.pendingArg; win.pendingArg = null; win.handleArg(a); }
                }
            }
        }

        // ---------------------------------------------------- proveedor y modelo
        // Desplegable bajo la cabecera: el proveedor (y su modelo) sin ir a Ajustes. El modelo que se marca es el
        // elegido en Ajustes; con OpenCode, «Automático» es el que elige él solo.
        Rectangle {
            id: modelDD
            visible: win.modelMenu
            z: 60
            x: 8
            y: win.headH + 4
            width: Math.min(320, win.panelW - 16)
            height: modelDDCol.implicitHeight + 14
            radius: Theme.r(10)
            color: Theme.s3
            border.width: 1
            border.color: Theme.ov
            ColumnLayout {
                id: modelDDCol
                x: 8; y: 8
                width: parent.width - 16
                spacing: 8
                Txt { text: "Proveedor"; size: 10; muted: true }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: win.provList
                        Rectangle {
                            required property var modelData
                            readonly property bool on: String(Settings.get("aiProvider", "")) === modelData
                            implicitWidth: provTxt.implicitWidth + 16
                            implicitHeight: 22
                            radius: Theme.r(6)
                            color: on ? Theme.pc : "transparent"
                            border.width: on ? 0 : 1
                            border.color: Theme.ov
                            Txt { id: provTxt; anchors.centerIn: parent; text: win.provName(modelData); size: 11.5; color: on ? Theme.pcText : Theme.t }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pickProvider(modelData)      // el desplegable sigue abierto: luego el modelo
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.ov }
                Txt { text: "Modelo"; size: 10; muted: true }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: win.provModels
                        Rectangle {
                            required property var modelData
                            readonly property string mid: String(modelData[0] ?? "")
                            readonly property string caps: String(modelData[2] ?? "")   // lo que puede hacer («ve imágenes»)
                            readonly property bool on: String(Settings.get("aiModel", "")) === mid
                            // El ancho sale del texto (y del rótulo de prestaciones): sin Measure, el texto y la píldora
                            // se estiran el uno al otro (bucle de enlaces) y las fichas se pisan.
                            implicitWidth: Math.min(290, mdlTxt.implicitWidth + (capTxt.visible ? capTxt.implicitWidth + 12 : 0) + 16)
                            implicitHeight: 22
                            radius: Theme.r(6)
                            color: on ? Theme.pc : "transparent"
                            border.width: on ? 0 : 1
                            border.color: Theme.ov
                            Txt {
                                id: mdlTxt
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(24, parent.width - 16 - (capTxt.visible ? capTxt.implicitWidth + 12 : 0))
                                text: String(modelData[1] ?? modelData[0] ?? "") || "Predeterminado"
                                size: 11.5
                                color: on ? Theme.pcText : Theme.t
                                elide: Text.ElideRight
                            }
                            // Las prestaciones, a la derecha del nombre (las declara el catálogo del modelo)
                            Txt {
                                id: capTxt
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.caps !== ""
                                text: parent.caps
                                size: 10
                                muted: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pickModel(mid)
                            }
                        }
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    visible: win.provModels.length === 0
                    text: win.provLoading ? "Cargando modelos…" : "Este proveedor no tiene modelos que elegir"
                    size: 11
                    muted: true
                }
            }
        }
    }

    OpenProbe { name: "ia"; shown: win.shown }

    // Reserva de la franja del panel fijado: capa invisible y sin ratón, encima de la barra en el orden de Hyprland
    // (Overlay), para que la barra del mismo lado no se desplace
    PanelWindow {
        id: zone
        screen: win.pinScreen
        visible: win.pinActive && win.zoneW > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-ia-zone"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: win.onLeft; right: !win.onLeft }
        implicitWidth: 1
        exclusiveZone: win.zoneW
        mask: Region {}
    }
    IpcHandler {
        target: "sidepanel"
        function ask(text: string): void { Shell.open("ia", { ask: text }); }
        // Pregunta con una imagen adjunta (Super + Mayús + A: zona de la pantalla → IA)
        function askImage(text: string, image: string): void { Shell.open("ia", { ask: text, image: image }); }
        // El registro del asistente (cada petición y cada acción aplicada)
        function log(): void { Shell.open("ia", { log: true }); }
        // Apartar el panel mientras hf-screen captura la pantalla (no debe salir, ni tapar lo que hay debajo)
        function aside(on: bool): void {
            if (on) { win.reopenAfterAside = Shell.view === "ia"; win.asideForScreen = true; if (win.reopenAfterAside) Shell.close(); }
            else { win.asideForScreen = false; if (win.reopenAfterAside) Shell.open("ia"); win.reopenAfterAside = false; }
        }
    }
}
