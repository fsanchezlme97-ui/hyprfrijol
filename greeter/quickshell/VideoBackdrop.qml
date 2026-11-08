// Fondo en movimiento del login: el vídeo que copia hf-greeter-sync (live/wallpaper.mp4), en bucle y sin sonido.
// Va en un archivo aparte porque necesita QtMultimedia (qt6-multimedia + qt6-multimedia-ffmpeg): si no está
// instalado, el Loader de shell.qml no lo carga y el login se queda con la imagen fija.
import QtQuick
import QtMultimedia

Item {
    id: vb
    property string source: ""
    // Hasta que no hay un fotograma de verdad se ve la imagen fija de debajo
    readonly property bool ready: player.playing && player.position > 0
    MediaPlayer {
        id: player
        source: vb.source ? "file://" + vb.source : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        onSourceChanged: if (source.toString() !== "") play()
        onErrorOccurred: (error, msg) => console.warn("fondo en vídeo:", msg)
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
