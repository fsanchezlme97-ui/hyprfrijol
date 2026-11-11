// Micrófono de la barra (módulo «dictado»). Tres modos («micMode»; clic derecho o Super + Shift + Alt + M para
// cambiar): dictado (lo que digas se escribe) · ia (se lo dices al asistente) · silencio (silenciar o activar el
// micrófono). Clic o Super + Alt + M: lo del modo (modules/dictado/Dictado.qml). Silenciado: tachado, en rojo.
import QtQuick
import ".."
import "../components"
import "../services"

IconBtn {
    readonly property string mode: Settings.get("micMode", "dictado")
    readonly property bool rec: Shell.dictPhase === "rec"
    icon: Audio.micMuted ? "mic-off" : mode === "ia" ? "ai" : "mic"
    active: rec
    fg: Audio.micMuted ? Theme.danger : Theme.t
    tooltip: (rec ? (mode === "ia" ? "Escuchando · clic para preguntar" : "Dictando · clic para terminar")
              : (Audio.micMuted ? "Micrófono silenciado · " : "")
                + ({ dictado: "Dictado", ia: "Hablar con el asistente", silencio: Audio.micMuted ? "clic para activarlo" : "Silenciar el micrófono" })[mode])
             + " · Super + Alt + M · clic derecho: cambiar de modo"
    onClicked: Shell.dictToggle()
    onRightClicked: Shell.micCycle()
}
