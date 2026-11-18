// Micrófono de la barra (módulo «dictado»). Cuatro modos (Shell.micMode; clic derecho o Super + Shift + Alt + M para
// cambiar): dictado (lo que digas se escribe) · walkie (clic, hablas y clic: se lo pasa al asistente; con
// Super + Alt + M, mientras lo mantienes) · fluido (conversación de ida y vuelta) · desactivado (no escucha).
// Clic o Super + Alt + M: lo del modo (modules/dictado/Dictado.qml); con Harper hablando, primero lo corta.
// Silenciado: tachado, en rojo, sin cambiar de modo; el clic solo lo vuelve a activar.
// Va entre el portapapeles y el asistente (herramientas para escribir y hablar, juntas).
import QtQuick
import ".."
import "../components"
import "../services"

IconBtn {
    readonly property string mode: Shell.micMode
    readonly property bool rec: Shell.dictPhase === "rec"
    // dictado: micrófono con líneas de texto (relleno mientras escucha) · walkie: walkie-talkie (con ondas mientras
    // escucha) · fluido: bocadillo con la onda de la voz · desactivado: bocadillo tachado
    icon: Audio.micMuted ? "mic-off" : mode === "walkie" ? (rec ? "walkie_rec" : "walkie") : mode === "fluido" ? "fluido"
          : mode === "desactivado" ? "voz_off" : rec ? "mic_rec" : "mic_dictado"
    active: rec || Shell.aiConversation
    fg: Audio.micMuted || mode === "desactivado" ? Theme.danger : Theme.t
    // Silenciado no se cambia de modo (modules/dictado/Dictado.qml): el clic solo lo vuelve a activar
    tooltip: Audio.micMuted ? "Micrófono silenciado · clic para activarlo · Super + Alt + M"
             : Shell.aiSpeaking && mode !== "desactivado" ? "Clic para que " + (Settings.get("aiName", "") || "Harper") + " deje de hablar"
             : (rec ? (mode === "dictado" ? "Dictando · clic para terminar" : mode === "walkie" ? "Escuchando · clic para preguntar" : "Escuchando")
                : Shell.aiConversation ? "Conversación · clic para terminar"
                : ({ dictado: "Dictado", walkie: "Walkie-talkie: clic, habla y clic", fluido: "Conversación fluida", desactivado: "Voz desactivada" })[mode])
               + " · Super + Alt + M · clic derecho: cambiar de modo"
    onClicked: Shell.dictToggle()
    onRightClicked: Shell.micCycle()
}
