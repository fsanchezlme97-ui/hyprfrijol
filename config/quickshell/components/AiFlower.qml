// La flor de Emma (icono "ai") con vida: piensa → gira despacio de pétalo en pétalo (72°, la flor es simétrica);
// habla → late; escucha → se abre (más grande); error → se cierra un poco (Shell.aiError, unos segundos).
// En reposo nada se mueve, y con «Reducir movimiento» (Theme.still) solo cambia de tamaño sin animar.
// Lo usan el botón de la barra (BarWidget), la cabecera del panel lateral y su pantalla vacía (AiChat).
import QtQuick
import ".."

Item {
    id: root
    property real size: 15
    property real stroke: 2
    property color color: Theme.t
    property bool listenOpens: true          // en la barra, escuchando sale el micrófono en su lugar
    readonly property bool thinking: Shell.aiBusy && !Theme.still
    readonly property bool speaking: Shell.aiSpeaking && !Theme.still
    readonly property bool listening: listenOpens && Shell.dictPhase === "rec"
    implicitWidth: size
    implicitHeight: size

    Item {
        id: beat
        anchors.fill: parent
        Icon {
            id: ic
            anchors.centerIn: parent
            name: "ai"
            size: root.size
            stroke: root.stroke
            color: root.color
            scale: Shell.aiError ? 0.8 : root.listening ? 1.14 : 1
            opacity: Shell.aiError ? 0.6 : 1
            Behavior on scale { enabled: !Theme.still; NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }
            Behavior on opacity { enabled: !Theme.still; NumberAnimation { duration: Theme.dur } }
        }
    }
    NumberAnimation {
        target: ic; property: "rotation"; running: root.thinking
        from: 0; to: 72; duration: 1400; loops: Animation.Infinite; easing.type: Easing.InOutSine
    }
    NumberAnimation { id: settle; target: ic; property: "rotation"; duration: Theme.durShort; easing.type: Easing.OutCubic }
    onThinkingChanged: if (!thinking) { settle.to = ic.rotation > 36 ? 72 : 0; settle.start(); }
    SequentialAnimation {
        running: root.speaking; loops: Animation.Infinite
        NumberAnimation { target: beat; property: "scale"; to: 1.12; duration: 420; easing.type: Easing.OutSine }
        NumberAnimation { target: beat; property: "scale"; to: 1; duration: 420; easing.type: Easing.InSine }
    }
    onSpeakingChanged: if (!speaking) beat.scale = 1
}
