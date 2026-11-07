pragma Singleton
// Logo de la distribución (LOGO=/ID= de /etc/os-release; HF_OS_LOGO=archlinux|fedora|… para probar) en un solo
// color, para el botón de Aplicaciones de la barra. Lo resuelve scripts/hf-oslogo (variante simbólica, pixmaps,
// temas de iconos → distributor-logo → tux). Si no hay nada, svg queda vacío y la barra muestra ⌘.
//   OsLogo.available · OsLogo.source(color) → data: URL del SVG pintado de ese color
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property string svg: ""
    readonly property bool available: svg !== ""

    function hex(c) {
        const h = n => Math.round(n * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    function source(c): string {
        return available ? "data:image/svg+xml;utf8," + encodeURIComponent(svg.replace(/currentColor/g, typeof c === "string" ? c : hex(c))) : "";
    }

    Process {
        running: true
        command: [Paths.script("hf-oslogo")]
        stdout: StdioCollector { onStreamFinished: root.svg = text.indexOf("<svg") >= 0 ? text : "" }
    }
}
