// Micrófono de la barra (módulo «dictado»): un botón de dictado. Clic o Super + Alt + M (o + D): dictar
// (modules/dictado/Dictado.qml); con Harper leyendo en voz alta, primero la corta.
// Silenciado: tachado, en rojo; el clic solo lo vuelve a activar.
// Va entre el portapapeles y el asistente (herramientas para escribir, juntas).
import QtQuick
import ".."
import "../components"
import "../services"

IconBtn {
    readonly property bool rec: Shell.dictPhase === "rec"
    icon: Audio.micMuted ? "mic-off" : rec ? (Shell.dictKind === "comando" ? "mic_orden_rec" : "mic_rec") : "mic_dictado"
    active: rec
    fg: Audio.micMuted ? Theme.danger : Theme.t
    tooltip: Audio.micMuted ? "Micrófono silenciado · clic para activarlo · Super + Alt + M"
             : Shell.aiSpeaking ? "Clic para que " + (Settings.get("aiName", "") || "Harper") + " deje de leer"
             : (rec ? (Shell.dictKind === "comando" ? "Escuchando la orden · clic para terminar" : "Dictando · clic para terminar") : "Dictado")
               + " · Super + Alt + M"
    onClicked: Shell.voiceDo(rec && Shell.dictKind === "comando" ? "comando" : "dictado")
}
