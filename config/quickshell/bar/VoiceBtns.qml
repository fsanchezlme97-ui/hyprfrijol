// Botones de voz de la barra (widget «voz»): un botón por modo de voz (Shell.micMode), resaltado el que está puesto.
// Pulsar uno lo pone y hace lo suyo (modules/dictado/Dictado.qml: Shell.voiceDo):
//   dictado       dictado de voz a texto (clic para empezar y clic para terminar)
//   walkie        mantenlo pulsado mientras le hablas al asistente y suelta (un toque corto: clic, habla y clic)
//   fluido        conversación de ida y vuelta (clic para empezar y para terminar)
//   desactivado   no escucha nada (termina lo que estuviera escuchando)
// Con Harper hablando, pulsar cualquiera lo corta. Micrófono silenciado: tenues; el clic lo vuelve a activar.
// Desactivada la voz, los otros tres se atenúan y el suyo sale en rojo.
import QtQuick
import ".."
import "../components"
import "../services"

Grid {
    id: root
    property bool vertical: false
    readonly property real h: vertical ? 26 : 22
    readonly property bool conv: Shell.aiConversation
    readonly property bool rec: Shell.dictPhase === "rec" && !conv
    readonly property string mode: Shell.micMode
    readonly property string name: Settings.get("aiName", "") || "Harper"
    readonly property string hush: Shell.aiSpeaking ? " · clic para que " + name + " deje de hablar" : ""
    flow: vertical ? Grid.TopToBottom : Grid.LeftToRight
    columns: vertical ? 1 : 4
    spacing: 1

    IconBtn {
        implicitHeight: root.h
        icon: root.rec && root.mode === "dictado" ? "mic_rec" : "mic_dictado"
        active: root.mode === "dictado"
        opacity: Audio.micMuted || root.mode === "desactivado" ? 0.45 : 1
        tooltip: root.vertical ? "" : (root.rec && root.mode === "dictado" ? "Dictando · clic para terminar" : "Dictado de voz a texto") + root.hush
        onClicked: Shell.voiceDo("dictado")
    }
    IconBtn {
        implicitHeight: root.h
        icon: root.rec && root.mode === "walkie" ? "walkie_rec" : "walkie"
        active: root.mode === "walkie"
        opacity: Audio.micMuted || root.mode === "desactivado" ? 0.45 : 1
        tooltip: root.vertical ? "" : (root.rec && root.mode === "walkie" ? "Escuchando · suelta para preguntar"
                 : "Walkie-talkie: mantén pulsado mientras le hablas a " + root.name) + root.hush
        onDown: Shell.voiceDo("walkie")
        onUp: Shell.voiceDo("walkie-up")
    }
    IconBtn {
        implicitHeight: root.h
        icon: root.conv ? "audio_lines" : "fluido"
        active: root.mode === "fluido"
        opacity: (Audio.micMuted || root.mode === "desactivado") && !root.conv ? 0.45 : 1
        tooltip: root.vertical ? "" : (root.conv ? "Conversación en marcha · clic para terminar" : "Conversación fluida con " + root.name) + root.hush
        onClicked: Shell.voiceDo("fluido")
    }
    IconBtn {
        implicitHeight: root.h
        icon: "voz_off"
        active: root.mode === "desactivado"
        // puesta, que se note: tachado en rojo sobre rojo tenue (como el micrófono silenciado)
        activeBg: Qt.alpha(Theme.danger, 0.2); activeFg: Theme.danger
        tooltip: root.vertical ? "" : root.mode === "desactivado" ? "Voz desactivada: no escucha nada" : "Desactivar la voz"
        onClicked: Shell.voiceDo("desactivado")
    }
}
