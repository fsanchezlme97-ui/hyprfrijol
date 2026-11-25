// Icono del clima, fijo: un dibujo por cada estado del cielo (códigos WMO de Open-Meteo, services/Weather.qml).
//   WeatherGlyph { code: Weather.code; day: Weather.isDay }
import QtQuick
import ".."
import "../components"

Icon {
    id: g
    property int code: -1
    property bool day: true
    size: 15
    color: Theme.t

    readonly property string kind: code < 0 ? "nublado"
        : code === 0 ? (day ? "sol" : "luna")
        : code <= 2 ? (day ? "parcialDia" : "parcialNoche")
        : code === 3 ? "nublado"
        : code <= 48 ? "niebla"
        : code <= 57 ? "llovizna"
        : code <= 67 ? "lluvia"
        : code <= 77 ? "nieve"
        : code <= 82 ? "chubascos"
        : code <= 86 ? "nieve"
        : "tormenta"

    // nube arriba, dejando sitio a lo que cae
    readonly property string cloudUp: '<path d="M7 15h10a4 4 0 0 0 .6-7.96A5.5 5.5 0 0 0 7.1 8.2 3.5 3.5 0 0 0 7 15z"/>'
    // nube pequeña abajo a la derecha (cielo parcial)
    readonly property string cloudLow: '<path d="M10 20h8a3.2 3.2 0 0 0 .4-6.38 4.4 4.4 0 0 0-8.3.9A2.8 2.8 0 0 0 10 20z"/>'
    svg: ({
        sol: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
        luna: '<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z"/>',
        parcialDia: '<path d="M8 2v1.6M2 8h1.6M3.8 3.8l1.1 1.1M12.2 3.8l-1.1 1.1M5.6 10.8A3.4 3.4 0 1 1 11 6.8"/>' + cloudLow,
        parcialNoche: '<path d="M10.6 9.6A5 5 0 0 1 5 3a5 5 0 1 0 2.4 9.3"/>' + cloudLow,
        nublado: '<path d="M5.5 18h10a4 4 0 0 0 .6-7.96A5.5 5.5 0 0 0 5.6 11.2 3.5 3.5 0 0 0 5.5 18z"/><path d="M9 6.2A4.6 4.6 0 0 1 17.4 7a3.6 3.6 0 0 1 3.8 5.6"/>',
        niebla: '<path d="M7 12h10a4 4 0 0 0 .6-7.96A5.5 5.5 0 0 0 7.1 5.2 3.5 3.5 0 0 0 7 12z"/><path d="M4 16h14M7 20h13"/>',
        llovizna: cloudUp + '<path d="M8 18.5v.5M12 20.5v.5M16 18.5v.5"/>',
        lluvia: cloudUp + '<path d="M8 18l-1 3.5M12.5 18l-1 3.5M17 18l-1 3.5"/>',
        chubascos: cloudUp + '<path d="M7 18l-.6 2M10.5 20l-.6 2M14 18l-.6 2M17.5 20l-.6 2"/>',
        nieve: cloudUp + '<path d="M8 18.5h.01M12 18.5h.01M16 18.5h.01M10 21.5h.01M14 21.5h.01" stroke-width="2.6"/>',
        tormenta: cloudUp + '<path d="M12.5 14l-3 4.5h4l-2.5 4"/>'
    })[kind]
}
