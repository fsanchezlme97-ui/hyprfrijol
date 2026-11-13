// Icono del clima que se mueve según el tiempo (Barra viva): el sol gira despacio, las nubes van y vienen, cae lluvia
// o nieve, el rayo destella y la luna tiene una estrella que titila. Lo mueve un Timer a ~12 fotogramas por segundo
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
        : code <= 1 ? (day ? "sol" : "luna")
        : code <= 3 ? "nube"
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
        anchors.centerIn: parent
        visible: g.kind === "sol"
        name: "sun"; size: g.size; color: g.color
        rotation: (g.t * 1) % 360
    }
    // luna y una estrella que titila
    Icon { anchors.centerIn: parent; visible: g.kind === "luna"; name: "moon"; size: g.size; color: g.color }
    Rectangle {
        visible: g.kind === "luna"
        x: g.size * 0.78; y: g.size * 0.08
        width: Math.max(1.5, g.size * 0.13); height: width; radius: width / 2
        color: g.color
        opacity: 0.25 + 0.75 * Math.abs(Math.sin(g.t / 9))
    }
    // nube: sola (va y viene un poco) o arriba, con lo que cae debajo
    Icon {
        visible: g.kind !== "sol" && g.kind !== "luna"
        name: "cloud"; color: g.color
        size: g.falling || g.kind === "niebla" ? g.size * 0.86 : g.size
        x: (g.size - size) / 2 + (g.falling ? 0 : 1.1 * Math.sin(g.t / 11))
        y: g.falling || g.kind === "niebla" ? -g.size * 0.14 : 0
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
