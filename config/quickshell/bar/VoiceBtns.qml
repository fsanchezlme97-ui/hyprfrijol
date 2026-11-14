// Botones de voz de la barra (widget «voz»): cuatro controles fijos, cada uno con una sola función
// (modules/dictado/Dictado.qml: Shell.voiceDo):
//   dictar      dictado de voz a texto (Super + Alt + D)
//   conversar   conversación por voz con el asistente (Super + Alt + H)
//   silenciar   respuestas habladas (aiMuted: hf-ai speak calla); la conversación sigue y contesta por escrito
//   micrófono   silenciar o activar el micrófono
// Iconos fijos (los de la acción); lo silenciado se pinta en rojo y lo que está en marcha, resaltado.
import QtQuick
import ".."
import "../components"
import "../services"

Grid {
    id: root
    property bool vertical: false
    readonly property real h: vertical ? 26 : 22
    readonly property bool conv: Shell.aiConversation
    readonly property bool dictating: Shell.dictPhase === "rec" && !conv
    readonly property bool repliesMuted: Settings.get("aiMuted", false)
    readonly property string name: Settings.get("aiName", "") || "el asistente"
    flow: vertical ? Grid.TopToBottom : Grid.LeftToRight
    columns: vertical ? 1 : 4
    spacing: 1

    IconBtn {
        implicitHeight: root.h
        icon: root.dictating ? "mic_rec" : "mic_dictado"
        active: root.dictating
        opacity: Audio.micMuted || root.conv ? 0.45 : 1
        tooltip: root.vertical ? "" : root.dictating ? "Dictando · clic para terminar · Super + Alt + D"
                 : root.conv ? "Dictado: termina antes la conversación" : "Dictado de voz a texto · Super + Alt + D"
        onClicked: Shell.voiceDo("dictar")
    }
    IconBtn {
        implicitHeight: root.h
        icon: "audio_lines"
        active: root.conv
        opacity: Audio.micMuted && !root.conv ? 0.45 : 1
        tooltip: root.vertical ? "" : root.conv ? "Conversación en marcha · clic para terminar · Super + Alt + H"
                 : "Conversar con " + root.name + " · Super + Alt + H"
        onClicked: Shell.voiceDo("conversar")
    }
    IconBtn {
        implicitHeight: root.h
        icon: "volume_mute"
        fg: root.repliesMuted ? Theme.danger : Theme.t
        active: root.repliesMuted
        activeBg: Qt.alpha(Theme.danger, 0.18); activeFg: Theme.danger
        tooltip: root.vertical ? "" : root.repliesMuted ? "Respuestas silenciadas: contesta por escrito · clic para volver a oírlas"
                 : "Silenciar las respuestas habladas · en la conversación, di «silencio»"
        onClicked: Shell.voiceDo("silenciar")
    }
    IconBtn {
        implicitHeight: root.h
        icon: "mic-off"
        fg: Audio.micMuted ? Theme.danger : Theme.t
        tooltip: root.vertical ? "" : Audio.micMuted ? "Micrófono deshabilitado · clic para activarlo" : "Deshabilitar el micrófono"
        onClicked: Shell.voiceDo("microfono")
    }
}
