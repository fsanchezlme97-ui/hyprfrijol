pragma Singleton
// ¿Se está viendo tu pantalla? (grabadoras, videollamadas, escritorio remoto). Lo usa el indicador de la barra.
//   ScreenShare.active
// Dos fuentes:
//   · Hyprland avisa de cada captura (evento «screencastv2» = estado,tipo,nombre). Solo cuentan las de pantalla o zona
//     que duran más de un segundo y medio: una captura suelta (Impr Pant) no enciende nada. Las de tipo «window» se
//     ignoran porque las miniaturas de la vista general las producen continuamente.
//   · El portal (navegador, OBS, escritorio remoto, también una sola ventana) crea un flujo «xdph-streaming-…» en
//     PipeWire mientras comparte.
// shortcut: si el shell se reinicia con una grabadora ya en marcha (sin portal), no se entera hasta la siguiente.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Singleton {
    id: root
    property var captures: ({})            // "tipo,nombre" → cuántas hay abiertas
    readonly property bool capturing: Object.keys(captures).length > 0
    property bool lasting: false
    readonly property bool portal: Pipewire.nodes.values.some(n => String(n.name).startsWith("xdph-streaming-"))
    readonly property bool active: portal || lasting

    onCapturingChanged: {
        if (capturing) { off.stop(); if (!lasting) on.start(); }
        else { on.stop(); if (lasting) off.start(); }
    }
    Timer { id: on; interval: 1500; onTriggered: root.lasting = true }
    Timer { id: off; interval: 1000; onTriggered: root.lasting = false }

    function event(data: string): void {
        const parts = data.split(","), started = parts[0] === "1", type = parts[1] ?? "";
        if (type === "window" || !type) return;
        const key = parts.slice(1).join(","), next = Object.assign({}, captures);
        const count = (next[key] ?? 0) + (started ? 1 : -1);
        if (count > 0) next[key] = count; else delete next[key];
        captures = next;
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "screencastv2") root.event(ev.data); }
    }
}
