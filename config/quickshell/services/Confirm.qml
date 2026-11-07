pragma Singleton
// «¿Se ve bien?» para ajustes arriesgados (resolución, escala, estilo, barra…): aplica el cambio y, si no se
// pulsa «Mantener» en 15 s, vuelve a los valores de antes (como al cambiar la resolución en GNOME).
// La barra la pinta Ajustes (modules/settings/ui/ConfirmBar.qml); el plazo corre aunque se cierre la ventana.
//   Confirm.change("Escala de la interfaz", { uiScale: 1.5 })
//   Confirm.change("Resolución", { monitors: m }, { undo: [["hyprctl", "eval", lua]] })   (órdenes al deshacer)
//   Confirm.change("Valores por defecto de Barra", {}, { remove: ["barPos", "barHeight"] })   (borrar claves)
// Varios cambios seguidos se suman: «Deshacer» vuelve al estado anterior al primero.
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    property string label: ""
    property int left: 0
    property int total: 15
    property var prev: ({})          // clave → { had, v }: lo que había en settings.json antes del primer cambio
    property var undoCmds: []        // órdenes a ejecutar al deshacer (en orden inverso)
    readonly property bool active: left > 0

    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }

    function change(what: string, obj, opts): void {
        const o = opts ?? {}, set = obj ?? {}, rm = (o.remove ?? []).filter(k => k in Settings.user);
        // sin cambios reales → nada que confirmar
        if (!rm.length && Object.keys(set).every(k => same(Settings.get(k, null), set[k]))) return;
        const p = active ? Object.assign({}, prev) : {};
        for (const k of Object.keys(set).concat(rm))
            if (!(k in p)) p[k] = k in Settings.user ? { had: true, v: JSON.parse(JSON.stringify(Settings.user[k])) } : { had: false };
        prev = p;
        undoCmds = (active ? undoCmds : []).concat(o.undo ?? []);
        label = active && !label.split(" · ").includes(what) ? label + " · " + what : what;
        total = o.secs ?? 15;
        left = total;
        Settings.patch(set, rm);
    }
    function keep(): void { left = 0; prev = {}; undoCmds = []; }
    function revert(): void {
        const keys = Object.keys(prev);
        if (!keys.length) { keep(); return; }
        const set = {}, rm = [];
        for (const k of keys) { if (prev[k].had) set[k] = prev[k].v; else rm.push(k); }
        const cmds = undoCmds.slice().reverse();
        keep();
        Settings.patch(set, rm);
        cmds.forEach(c => Quickshell.execDetached(c));
    }
    Timer {
        interval: 1000; repeat: true; running: root.active
        onTriggered: { if (root.left <= 1) root.revert(); else root.left--; }
    }
}
