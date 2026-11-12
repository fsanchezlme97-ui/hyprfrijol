// Cuenta un uso de un servicio (SysStats, Weather, Printer, Cava… con su «users») solo mientras hace falta de verdad:
// la pastilla se ve, la barra no está escondida a mano (Super + J) y la sesión no está bloqueada. Antes contaban desde
// que se creaban y los lectores (nvidia-smi, curl a la impresora, cava) seguían con la barra oculta o bloqueado.
//   UseCounter { target: SysStats; active: chip.visible }
import QtQuick
import ".."

QtObject {
    id: root
    property var target: null
    property string prop: "users"
    property bool active: true
    property bool bar: true                 // es de la barra: cuenta también si la barra está escondida
    readonly property bool want: active && !Shell.locked && !(bar && Shell.barHidden) && target !== null
    property bool _on: false
    function _sync(): void {
        if (want === _on || !target) return;
        target[prop] = Math.max(0, (target[prop] ?? 0) + (want ? 1 : -1));
        _on = want;
    }
    onWantChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: if (_on && target) target[prop] = Math.max(0, target[prop] - 1)
}
