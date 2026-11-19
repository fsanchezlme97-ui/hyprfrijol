// Botones de voz de la barra (widget «voz»): dictado y orden de voz (modules/dictado/Dictado.qml: Shell.voiceDo).
//   dictado   lo que digas se escribe (clic para empezar y clic para terminar) · Super + Alt + D
//   orden     una orden de voz: «abre Firefox», «lee el archivo notas.md» (clic, la dices y para sola) · Super + Alt + V
// Con Harper leyendo en voz alta, pulsar cualquiera la corta. Micrófono silenciado: tenues; el clic lo vuelve a activar.
import QtQuick
import ".."
import "../components"
import "../services"

Grid {
    id: root
    property bool vertical: false
    readonly property real h: vertical ? 26 : 22
    readonly property bool rec: Shell.dictPhase === "rec"
    readonly property string hush: Shell.aiSpeaking ? " · clic para que " + (Settings.get("aiName", "") || "Harper") + " deje de leer" : ""
    flow: vertical ? Grid.TopToBottom : Grid.LeftToRight
    columns: vertical ? 1 : 2
    spacing: 1

    IconBtn {
        readonly property bool on: root.rec && Shell.dictKind === "dictado"
        implicitHeight: root.h
        icon: on ? "mic_rec" : "mic_dictado"
        active: on
        opacity: Audio.micMuted ? 0.45 : 1
        tooltip: root.vertical ? "" : (Audio.micMuted ? "Micrófono silenciado · clic para activarlo"
                 : on ? "Dictando · clic para terminar" : "Dictado de voz a texto · Super + Alt + D") + root.hush
        onClicked: Shell.voiceDo("dictado")
    }
    IconBtn {
        readonly property bool on: root.rec && Shell.dictKind === "comando"
        implicitHeight: root.h
        icon: on ? "mic_orden_rec" : "mic_orden"
        active: on
        opacity: Audio.micMuted ? 0.45 : 1
        tooltip: root.vertical ? "" : (Audio.micMuted ? "Micrófono silenciado · clic para activarlo"
                 : on ? "Escuchando la orden · clic para terminar" : "Orden de voz · Super + Alt + V") + root.hush
        onClicked: Shell.voiceDo("comando")
    }
}
