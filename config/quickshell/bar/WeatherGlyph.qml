// Icono del clima que se mueve según el tiempo (Barra viva, barLive): el sol gira despacio, con cielo parcial asoma
// tras una nube que va y viene, con cielo cubierto dos nubes se cruzan, cae lluvia o nieve, el rayo destella y la
// luna tiene una estrella que titila. Lo mueve un Timer a ~12 fotogramas por segundo
// (no animaciones a 60 fps: la barra entera se repinta en cada fotograma); quieto si live es false (pantalla
// completa, modo juego, barra oculta) o sin animaciones (Theme.still).
//   WeatherGlyph { code: Weather.code; day: Weather.isDay; live: chip.visible }
import QtQuick
import ".."
import "../components"

Item {
    id: g
    property int code: -1
    property bool day: true
    property bool live: true
    property color color: Theme.t
    property real size: 14
    implicitWidth: size
    implicitHeight: size

    // Códigos WMO de Open-Meteo (services/Weather.qml: describe)
    readonly property string kind: code < 0 ? "nube"
        : code === 0 ? (day ? "sol" : "luna")
        : code <= 2 ? "parcial"
        : code === 3 ? "nube"
        : code <= 48 ? "niebla"
        : code <= 67 || (code >= 80 && code <= 82) ? "lluvia"
        : code <= 77 || (code >= 85 && code <= 86) ? "nieve"
        : "tormenta"
    readonly property bool falling: kind === "lluvia" || kind === "nieve" || kind === "tormenta"
    readonly property bool animating: live && !Theme.still && visible
    property int t: 0
    Timer { interval: 83; repeat: true; running: g.animating; onTriggered: g.t = (g.t + 1) % 100000 }

    // sol: los rayos dan una vuelta cada 30 s
    Icon {
        visible: g.kind === "sol" || (g.kind === "parcial" && g.day)
        name: "sun"; color: g.color
        size: g.kind === "parcial" ? g.size * 0.72 : g.size
        x: g.kind === "parcial" ? -g.size * 0.06 : 0
        y: g.kind === "parcial" ? -g.size * 0.08 : 0
        rotation: (g.t * 1) % 360
    }
    // luna (sola o tras la nube) y una estrella que titila
    Icon {
        visible: g.kind === "luna" || (g.kind === "parcial" && !g.day)
        name: "moon"; color: g.color
        size: g.kind === "parcial" ? g.size * 0.68 : g.size
        x: g.kind === "parcial" ? -g.size * 0.04 : 0
        y: g.kind === "parcial" ? -g.size * 0.06 : 0
    }
    Rectangle {
        visible: g.kind === "luna"
        x: g.size * 0.78; y: g.size * 0.08
        width: Math.max(1.5, g.size * 0.13); height: width; radius: width / 2
        color: g.color
        opacity: 0.25 + 0.75 * Math.abs(Math.sin(g.t / 9))
    }
    // cubierto: una nube pequeña detrás que va al revés que la de delante
    Icon {
        visible: g.kind === "nube"
        name: "cloud"; color: g.color; opacity: 0.55
        size: g.size * 0.62
        x: g.size * 0.42 - 1.8 * Math.sin(g.t / 13)
        y: -g.size * 0.12
    }
    // nube: delante del sol o la luna (parcial), la de delante (cubierto) o arriba con lo que cae debajo
    Icon {
        visible: g.kind !== "sol" && g.kind !== "luna"
        name: "cloud"; color: g.color
        size: g.kind === "parcial" ? g.size * 0.78 : g.kind === "nube" ? g.size * 0.86 : g.size * 0.86
        x: g.kind === "parcial" ? g.size * 0.26 + 1.6 * Math.sin(g.t / 12)
            : g.kind === "nube" ? g.size * 0.02 + 1.8 * Math.sin(g.t / 13)
            : (g.size - size) / 2
        y: g.kind === "parcial" || g.kind === "nube" ? g.size * 0.2 : -g.size * 0.14
    }
    // niebla: dos rayas que se desplazan
    Repeater {
        model: g.kind === "niebla" ? 2 : 0
        Rectangle {
            required property int index
            x: g.size * (index ? 0.18 : 0.30) + 1.2 * Math.sin((g.t + index * 14) / 10)
            y: g.size * (0.70 + index * 0.16)
            width: g.size * 0.52; height: Math.max(1.2, g.size * 0.1); radius: height / 2
            color: g.color; opacity: 0.8
        }
    }
    // lluvia, nieve o tormenta: tres gotas (o copos) que caen y se desvanecen al llegar abajo
    Repeater {
        model: g.falling ? 3 : 0
        Rectangle {
            required property int index
            readonly property bool snow: g.kind === "nieve"
            readonly property real span: g.size * 0.36
            readonly property real p: ((g.t * (snow ? 0.045 : 0.11) + index * 0.37) % 1)
            x: g.size * (0.28 + index * 0.22) - width / 2 - (snow ? 0 : p * 1.2)
            y: g.size * 0.6 + p * span
            width: snow ? Math.max(1.8, g.size * 0.14) : Math.max(1.3, g.size * 0.1)
            height: snow ? width : Math.max(2.6, g.size * 0.22)
            radius: width / 2
            color: g.color
            opacity: 1 - p * 0.8
        }
    }
    // tormenta: un rayo que destella cada ~4 s
    Icon {
        visible: g.kind === "tormenta" && (g.t % 48 === 0 || g.t % 48 === 2 || !g.animating)
        anchors.horizontalCenter: parent.horizontalCenter
        y: g.size * 0.42
        svg: '<path d="M13 2L6 13h5l-1 9 7-11h-5z" fill="currentColor"/>'
        size: g.size * 0.62; color: Theme.ter
    }
}
