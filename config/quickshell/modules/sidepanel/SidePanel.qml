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
    readonly property bool pinShown: pinActive && !fsHere && !chatCapturing
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
        if (shown) chatHeld = true;
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
    readonly property var chat: chatLoader.item ?? ({ ask: () => {}, attach: () => {}, focusInput: () => {}, clear: () => {}, toggleHistory: () => {}, showHistory: false, toggleLog: () => {}, showLog: false, handoffTo: null, handoff: () => {}, setWindow: () => {} })

    readonly property string aiLabel: String(Settings.get("aiName", "") ?? "").trim() || "IA"
    // Bajo el nombre: quién responde y su respaldo («Gemini · respaldo Ollama»)
    readonly property var provNames: ({ "claude-code": "Claude Code", claude: "Claude", gemini: "Gemini", ollama: "Ollama", openai: "OpenAI",
                                        openrouter: "OpenRouter", lmstudio: "LM Studio", mistral: "Mistral", groq: "Groq", deepseek: "DeepSeek" })
    function provName(k): string { k = String(k ?? ""); return provNames[k] ?? (k ? k.charAt(0).toUpperCase() + k.slice(1) : ""); }
    readonly property string aiSub: {
        const p = provName(Settings.get("aiProvider", "")), f = provName(Settings.get("aiFallbackProvider", ""));
        return p + (f && f !== p ? " · respaldo " + f : "");
    }

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
    anchors { top: true; bottom: true; right: !onLeft; left: onLeft }
    implicitWidth: panelW + mR + 48          // margen para la sombra; el ratón lo atraviesa (mask)
    // Por geometría y no por «item»: la Region se calculaba con el panel aún desplazado por la animación de entrada
    // (24 px hacia el borde) y no se actualiza con el Translate; con el panel a la izquierda, la X quedaba fuera
    mask: Region { x: panel.x; y: panel.y; width: panel.width; height: panel.height }

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
        function onAiAskHidden(t) { win.askHidden(t); }
        function onAiCheckIn(reason, image) { win.chatHeld = true; if (!chatLoader.item) win.pendingArg = { checkIn: reason, image: image, hidden: true }; else win.chat.checkIn(reason, image); }
        function onAiPlanAnswer(yes) { if (chatLoader.item) win.chat.answerPlan(yes); }
    }
    // Conversación por voz: el chat trabaja con el panel cerrado (y queda en el historial como siempre)
    function askHidden(text) {
        chatHeld = true;
        if (!chatLoader.item) { pendingArg = { ask: text, hidden: true }; return; }
        chat.ask(String(text), "quick");
    }
    // ======================================================================= dibujo
    Item {
        id: panel
        x: win.onLeft ? win.mR : parent.width - win.mR - width
        y: win.mT
        width: win.panelW
        height: parent.height - win.mT - win.mB
        focus: true
        Keys.onEscapePressed: win.pinPref ? win.releaseFocus() : Shell.close()

        opacity: win.shown ? 1 : 0
        transform: Translate { x: win.shown ? 0 : (win.onLeft ? -24 : 24); Behavior on x { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } } }
        Behavior on opacity { NumberAnimation { id: slide; duration: win.shown ? Theme.durIn : 160; easing.type: Easing.OutCubic } }

        Glass { anchors.fill: parent; kind: "panel" }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------- cabecera
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: win.headH
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 2
                    RowLayout {
                        Layout.leftMargin: 6
                        spacing: 6
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
                            spacing: -1
                            Txt { text: win.aiLabel; weight: Font.DemiBold; size: 13 }
                            Txt { visible: win.aiSub !== ""; text: win.aiSub; size: 10.5; muted: true }
                        }
                    }
                    IconBtn {
                        icon: "plus"; iconSize: 13; fg: Theme.tv
                        implicitWidth: 26; implicitHeight: 26
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
                    Item { Layout.fillWidth: true }
                    IconBtn {
                        visible: !!chat.handoffTo
                        icon: "detach"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: "Seguir en " + (chat.handoffTo?.label ?? "")
                        onClicked: chat.handoff()
                    }
                    IconBtn {
                        icon: "pin"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        active: win.pinPref
                        tooltip: win.pinPref ? "Desfijar: volver a flotar encima" : "Fijar: parte del mosaico"
                        onClicked: win.togglePin()
                    }
                    IconBtn {
                        icon: "x"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                        tooltip: win.pinPref ? "Esconder (sigue fijado; vuelve con Super + A)" : ""
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
                    if (win.pendingArg !== null) { const a = win.pendingArg; win.pendingArg = null; a.checkIn !== undefined ? item.checkIn(a.checkIn, a.image) : a.hidden ? item.ask(String(a.ask), "quick") : win.handleArg(a); }
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
    }
}
