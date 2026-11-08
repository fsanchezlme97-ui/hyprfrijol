pragma Singleton
// Sitio compartido de las píldoras del OSD (modules/osd/Osd.qml) y del dictado (modules/dictado/Dictado.qml):
// misma posición (osdPos: abajo · arriba · centro · izquierda · derecha · inf-der · sup-der), misma distancia al
// borde (osdOffset, o a la barra si está en ese borde) y nunca una encima de otra. El dictado va pegado al borde
// y, mientras se ve, el OSD se aparta «dictation + gap» px hacia dentro (se apilan).
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    readonly property string pos: Settings.get("osdPos", "abajo")
    readonly property real off: Math.max(0, Number(Settings.get("osdOffset", 14)) || 0)
    readonly property bool atB: pos === "abajo" || pos === "inf-der"
    readonly property bool atT: pos === "arriba" || pos === "sup-der"
    readonly property bool atL: pos === "izquierda"
    readonly property bool atR: pos === "derecha" || pos === "inf-der" || pos === "sup-der"
    readonly property string barPos: Settings.barPos
    // margen de la ventana (con 20 px de aire alrededor de la píldora para la sombra y la animación)
    function edge(side) { return (Settings.barReserves && barPos === side ? Settings.barEdge : 4) + off - 20; }

    // alto de la píldora del dictado mientras se ve (0 = oculta)
    property real dictation: 0
    readonly property real gap: 8
    readonly property real push: dictation > 0 ? dictation + gap : 0

    // y de una píldora de alto h dentro de una ventana de alto winH, desplazada «shift» px hacia dentro
    function pillY(winH, h, shift) {
        if (atT) return 20 + shift;
        if (atB) return winH - 20 - h - shift;
        return (winH - h) / 2 + shift;
    }
}
