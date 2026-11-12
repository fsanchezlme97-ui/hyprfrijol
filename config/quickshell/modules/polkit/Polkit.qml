// Agente de polkit (diseño «Diálogo de autenticación»): sustituye a polkit-kde-agent / polkit-gnome.
// Aparece cuando una aplicación pide permisos de administrador (pkexec, Btrfs Assistant, discos…).
// Solo puede haber un agente por sesión: si otro ya está registrado, este se queda inactivo (avisa en el registro).
// Pruebas (HF_TRY=1): HF_TRY_POLKIT=1 muestra el diálogo con datos de ejemplo · HF_TRY_POLKIT=error con el error.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../.."
import "../../components"

Scope {
    id: root
    readonly property string tryMode: Quickshell.env("HF_TRY") === "1" ? (Quickshell.env("HF_TRY_POLKIT") ?? "") : ""
    // (la vista previa espera un poco: dev/try.sh cambia de monitor al arrancar)
    property bool preview: false
    Timer { running: root.tryMode !== ""; interval: 3000; onTriggered: root.startPreview() }
    readonly property var flow: agent.flow
    readonly property bool shown: agent.isActive || preview
    property bool busy: false
    property string error: ""
    property bool details: false
    property string realName: ""
    property bool isAdmin: false
    property bool hasFprint: false
    signal shake()

    readonly property string message: {
        const m = preview ? "Btrfs Assistant quiere restaurar el punto #212. Esta acción cambia archivos del sistema."
                          : (flow?.message ?? "");
        return m;
    }
    readonly property string actionId: preview ? "org.btrfs-assistant.pkexec.run" : (flow?.actionId ?? "")
    readonly property string identityName: {
        const id = flow?.selectedIdentity;
        return (id && (id.displayName || id.name)) || realName || (Quickshell.env("USER") ?? "");
    }
    readonly property string prompt: {
        const p = (flow?.inputPrompt ?? "").trim().replace(/:$/, "");
        if (!p || /^password$/i.test(p) || /contraseña/i.test(p)) return "Contraseña";
        return p;
    }
    readonly property string hint: {
        if (error) return error;
        const s = flow?.supplementaryMessage ?? "";
        return s;
    }

    function submit(): void {
        if (busy) return;
        if (preview) {
            if (field.text === "") { error = "Escribe tu contraseña"; shake(); return; }
            busy = true; previewTimer.restart(); return;
        }
        if (!flow || !flow.isResponseRequired) return;
        busy = true;
        error = "";
        flow.submit(field.text);
    }
    function cancel(): void {
        if (preview) { console.info("[polkit] (HF_TRY) cancelar"); return; }
        if (flow) flow.cancelAuthenticationRequest();
    }
    function reset(): void { busy = false; error = ""; details = false; field.text = ""; showPw.on = false; }   // la contraseña vuelve a ir oculta en cada petición

    Timer { id: previewTimer; interval: 900; onTriggered: { root.busy = false; root.error = "Contraseña incorrecta. Inténtalo de nuevo"; field.text = ""; root.shake(); } }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: { root.reset(); Qt.callLater(() => field.forceActiveFocus()); }
        onIsRegisteredChanged: if (isRegistered) console.info("[polkit] agente de HyprFrijol registrado")
    }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { root.busy = false; root.error = "Contraseña incorrecta. Inténtalo de nuevo"; field.text = ""; root.shake(); field.forceActiveFocus(); }
        function onAuthenticationSucceeded() { root.busy = false; }
        function onAuthenticationRequestCancelled() { root.busy = false; }
        function onIsResponseRequiredChanged() { if (root.flow.isResponseRequired) { root.busy = false; field.forceActiveFocus(); } }
    }

    Process {
        running: true
        command: ["sh", "-c", 'echo "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"; id -nG | tr " " "\\n" | grep -qxE "wheel|sudo|admin" && echo admin || echo user; command -v fprintd-verify >/dev/null && fprintd-list "$USER" 2>/dev/null | grep -q "#" && echo fp || echo nofp']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.realName = (l[0] || "").trim();
                root.isAdmin = l[1] === "admin";
                root.hasFprint = l[2] === "fp";
            }
        }
    }
    function startPreview(): void {
        preview = true;
        Qt.callLater(() => field.forceActiveFocus());
        if (tryMode === "error") Qt.callLater(() => { field.text = "x"; error = "Contraseña incorrecta. Inténtalo de nuevo"; field.text = ""; details = true; });
    }

    PanelWindow {
        id: win
        screen: Shell.screen
        visible: root.shown || card.opacity > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hf-polkit"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.shown ? 0.42 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
        }
        MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

        Glass {
            id: card
            kind: "panel"
            big: true
            width: 420
            height: col.implicitHeight + 44
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - height) / 2 - 20
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: Theme.durIn; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
            }
            Connections { target: root; function onShake() { if (!Theme.still) shakeAnim.restart(); } }
            MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 14

                // Cabecera
                RowLayout {
                    spacing: 14
                    Layout.fillWidth: true
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 40; implicitHeight: 40; radius: Theme.r(10)
                        color: Theme.pc
                        Icon { anchors.centerIn: parent; name: "shield"; size: 17; color: Theme.pcText }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Txt { text: "Se requiere autenticación"; size: 15; weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: root.message
                            muted: true
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            lineHeight: 1.15
                            textFormat: Text.PlainText
                        }
                    }
                }

                // Identidad
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.r(7)
                    color: Theme.fill2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10
                        Rectangle {
                            implicitWidth: 28; implicitHeight: 28; radius: 14
                            color: Theme.pc
                            Txt { anchors.centerIn: parent; text: root.identityName.charAt(0).toUpperCase(); color: Theme.pcText; weight: Font.DemiBold; size: 12 }
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: root.identityName + (root.isAdmin ? " · administrador" : "")
                            weight: Font.Medium
                        }
                        Txt { visible: root.hasFprint; text: "Huella disponible"; size: 11.5; muted: true }
                    }
                }

                // Contraseña
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.r(7)
                    color: Theme.fill2
                    border.width: 1
                    border.color: root.error ? Qt.alpha(Theme.ter, 0.8) : field.activeFocus ? Qt.alpha(Theme.p, 0.6) : Theme.ov
                    Behavior on border.color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    Txt {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: root.busy ? "Comprobando…" : root.prompt
                        size: 14
                        muted: true
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 40
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: (root.flow?.responseVisible ?? false) || showPw.on ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.t
                        font.family: Theme.font
                        font.pixelSize: 14
                        selectionColor: Theme.p
                        selectedTextColor: Theme.pText
                        clip: true
                        enabled: !root.busy
                        onTextChanged: if (text !== "" && root.error) root.error = ""
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                    Item {
                        id: showPw
                        property bool on: false
                        anchors.right: parent.right; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        visible: field.text !== ""
                        Icon { anchors.centerIn: parent; name: "eye"; size: 15; color: showPw.on ? Theme.t : Theme.tv }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showPw.on = !showPw.on }
                    }
                }
                Txt {
                    visible: root.hint !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: -6
                    text: root.hint
                    size: 12
                    color: root.error || (root.flow?.supplementaryIsError ?? false) ? Theme.ter : Theme.tv
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                // Detalles
                Item {
                    implicitWidth: detRow.implicitWidth
                    implicitHeight: detRow.implicitHeight
                    RowLayout {
                        id: detRow
                        spacing: 4
                        Txt { text: "Detalles"; size: 12; muted: true }
                        Icon { name: root.details ? "chevron_up" : "chevron_down"; size: 11; color: Theme.tv }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.details = !root.details }
                }
                Rectangle {
                    visible: root.details
                    Layout.fillWidth: true
                    implicitHeight: detCol.implicitHeight + 16
                    radius: Theme.r(7)
                    color: Theme.fill2
                    ColumnLayout {
                        id: detCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 10 }
                        spacing: 3
                        Repeater {
                            model: [["Acción", root.actionId], ["Identidad", root.identityName], ["Agente", "HyprFrijol (Quickshell)"]]
                            RowLayout {
                                required property var modelData
                                spacing: 10
                                Layout.fillWidth: true
                                Text { text: modelData[0]; color: Theme.tv; font.family: Theme.mono; font.pixelSize: 11; Layout.preferredWidth: 70 }
                                Text { text: modelData[1]; color: Theme.t; font.family: Theme.mono; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideMiddle }
                            }
                        }
                    }
                }

                // Botones
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: -4
                    spacing: 8
                    Rectangle {
                        implicitWidth: cancelTxt.implicitWidth + 32; implicitHeight: 34; radius: Theme.r(7)
                        color: cancelMa.containsMouse ? Theme.fill2 : "transparent"
                        border.width: 1; border.color: Theme.ov
                        Txt { id: cancelTxt; anchors.centerIn: parent; text: "Cancelar" }
                        MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                    }
                    Rectangle {
                        implicitWidth: authTxt.implicitWidth + 36; implicitHeight: 34; radius: Theme.r(7)
                        color: authMa.containsMouse ? Qt.lighter(Theme.p, 1.08) : Theme.p
                        opacity: root.busy ? 0.7 : 1
                        Txt { id: authTxt; anchors.centerIn: parent; text: root.busy ? "Comprobando…" : "Autenticar"; color: Theme.pText; weight: Font.DemiBold }
                        MouseArea { id: authMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                    }
                }
            }
        }
    }
}
