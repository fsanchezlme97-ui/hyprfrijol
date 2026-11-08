// Vista previa a pantalla completa del selector de fondos: dos Image apiladas con fundido cruzado.
// Al cambiar de fondo entra al momento la miniatura (ya está en la caché de imágenes, la usa la tira) y, cuando la
// selección se queda quieta `settle` ms, el original decodificado al tamaño de la pantalla (libjpeg lo reduce al leer).
// Solo se anima la opacidad de la capa que entra; la de debajo no se toca hasta que la tapa del todo.
import QtQuick
import QtQuick.Effects
import "../.."

Item {
    id: bd
    property string thumb: ""        // url de la miniatura
    property string full: ""         // url del original ("" = solo miniatura, p. ej. vídeos)
    property bool mono: false        // modo de color monocromo con «fondo en blanco y negro»
    property int settle: 140
    signal requested()               // se pidió otra miniatura (para la sonda)
    signal shownReady(bool hi)       // la capa pedida ya se ve (para la sonda)

    property Image front: a
    property Image pending: null
    readonly property Image back: front === a ? b : a

    function load(url: string, hi: bool): void {
        if (!hi && url !== "") requested();
        if (url === "" || (front.source.toString() === url && front.status === Image.Ready)) { if (url !== "") shownReady(hi); return; }
        if (fade.running) fade.complete();
        const t = back;
        t.source = "";          // primero vaciar: cambiar sourceSize con la fuente vieja la volvería a decodificar
        t.hi = hi;
        t.source = url;
        pending = t;
        if (t.status === Image.Ready) swap();
    }
    function swap(): void {
        const t = pending;
        pending = null;
        if (!t) return;
        t.z = front.z + 1;
        front = t;
        shownReady(t.hi);
        if (Theme.dur <= 0 || !bd.visible) { t.opacity = 1; return; }
        t.opacity = 0;
        fade.target = t;
        fade.restart();
    }
    onThumbChanged: { load(thumb, false); hiRes.restart(); }
    Timer { id: hiRes; interval: bd.settle; onTriggered: if (bd.full !== "" && bd.full !== bd.thumb) bd.load(bd.full, true) }
    NumberAnimation { id: fade; property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Easing.OutCubic }

    component Layer: Image {
        property bool hi: false
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Miniatura: tamaño natural (la misma entrada de caché que la tira). Original: al tamaño de la pantalla.
        sourceSize: hi ? Qt.size(bd.width, bd.height) : undefined
        cache: !hi
        smooth: true
        onStatusChanged: if (status === Image.Ready && bd.pending === this) bd.swap()
    }
    Item {
        anchors.fill: parent
        layer.enabled: bd.mono
        layer.effect: MultiEffect { saturation: -1 }
        Layer { id: a }
        Layer { id: b }
    }
}
