// Micrófono de la barra (módulo «dictado»). Tres modos («micMode»; clic derecho o Super + Shift + Alt + M para
// cambiar): dictado (lo que digas se escribe) · ia (se lo dices al asistente) · silencio (silenciar o activar el
// micrófono). Clic o Super + Alt + M: lo del modo (modules/dictado/Dictado.qml). Silenciado: tachado, en rojo,
// sin cambiar de modo; el clic solo lo vuelve a activar.
// Va entre el portapapeles y el asistente (herramientas para escribir y hablar, juntas).
import QtQuick
import ".."
import "../components"
import "../services"

IconBtn {
    readonly property string mode: Settings.get("micMode", "dictado")
    readonly property bool rec: Shell.dictPhase === "rec"
    // dictado: micrófono con líneas de texto (relleno mientras escucha) · ia: con chispas · silencio: el micrófono solo
    icon: Audio.micMuted ? "mic-off" : mode === "ia" ? "mic_ai" : mode === "silencio" ? "mic" : rec ? "mic_rec" : "mic_dictado"
    active: rec
    fg: Audio.micMuted ? Theme.danger : Theme.t
    // Silenciado no se cambia de modo (modules/dictado/Dictado.qml): el clic solo lo vuelve a activar
    tooltip: Audio.micMuted ? "Micrófono silenciado · clic para activarlo · Super + Alt + M"
             : (rec ? (mode === "ia" ? "Escuchando · clic para preguntar" : "Dictando · clic para terminar")
                : ({ dictado: "Dictado", ia: "Hablar con el asistente", silencio: "Silenciar el micrófono" })[mode])
               + " · Super + Alt + M · clic derecho: cambiar de modo"
    onClicked: Shell.dictToggle()
    onRightClicked: Shell.micCycle()
}
