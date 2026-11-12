// Un fondo en vídeo dentro del shell: en bucle, sin sonido (sin audioOutput) y con un fundido cuando ya hay
// fotograma (hasta entonces se ve la imagen fija que haya debajo). Lo usan el selector de fondos (vista previa) y la
// pantalla de bloqueo. Siempre a través de un Loader: necesita QtMultimedia (qt6-multimedia + qt6-multimedia-ffmpeg)
// y, si no está, no se carga y queda la imagen fija.
import QtQuick
import QtMultimedia
import ".."

Item {
    id: vp
    property string source: ""
    property bool paused: false          // quieto en el fotograma de ahora (la pantalla de bloqueo, tras 2 min sin tocarla)
    onPausedChanged: paused ? player.pause() : player.play()
    readonly property bool ready: player.playing && player.position > 0
    opacity: ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
    MediaPlayer {
        id: player
        source: vp.source ? "file://" + vp.source : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        onSourceChanged: if (source.toString() !== "" && !vp.paused) play()
        onErrorOccurred: (error, msg) => console.warn("vista previa del fondo en vídeo:", msg)
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
