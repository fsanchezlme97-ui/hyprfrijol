// Icono de archivo, carpeta o lenguaje de Catppuccin Icons (catppuccin/vscode-icons, MIT · assets/catppuccin/LICENSE).
// Mocha con tema oscuro, Latte con tema claro. Las tablas salen de dev/gen-catppuccin.py (components/catppuccin.js).
//   CatIcon { path: "/home/ana/notas.md" }        archivo (por nombre exacto o extensión)
//   CatIcon { path: "src"; dir: true }            carpeta (con las especiales: src, .config, Descargas…)
//   CatIcon { lang: "sql" }                       lenguaje de un bloque de código; `valid` es false si no tiene icono propio
import QtQuick
import ".."
import "catppuccin.js" as Ctp

Item {
    id: root
    property string path: ""
    property bool dir: false
    property bool open: false
    property string lang: ""
    property real size: 16
    readonly property string iconName: lang !== "" ? Ctp.forLang(lang) : (path !== "" || dir) ? Ctp.forPath(path, dir, open) : ""
    readonly property bool valid: iconName !== ""
    readonly property alias status: img.status
    implicitWidth: size
    implicitHeight: size
    Image {
        id: img
        anchors.fill: parent
        source: root.valid ? Qt.resolvedUrl("../assets/catppuccin/" + Ctp.rel(root.iconName, Theme.light)) : ""
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
