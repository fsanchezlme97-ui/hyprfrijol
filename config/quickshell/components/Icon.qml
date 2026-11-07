// Icono de trazo como en el diseño (clase .s = 14 px, .i = 17 px; trazo 1.8, extremos redondeados).
//   Icon { name: "wifi" }                      — de Icons.qml
//   Icon { svg: '<path d="M5 12h14"/>' }       — pegado de un diseño
import QtQuick
import ".."

Item {
    id: root
    property string name: ""
    property string svg: ""
    property color color: Theme.t
    property real size: 14
    property real stroke: 1.8
    implicitWidth: size
    implicitHeight: size

    readonly property string markup: svg !== "" ? svg : (Icons.paths[name] ?? "")
    function hex(c) {
        const h = n => Math.round(n * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    Image {
        anchors.fill: parent
        visible: root.markup !== ""
        opacity: root.color.a
        smooth: true
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        source: root.markup === "" ? "" : "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + root.hex(root.color)
            + '" stroke-width="' + root.stroke + '" stroke-linecap="round" stroke-linejoin="round" color="' + root.hex(root.color) + '">'
            + root.markup.replace(/currentColor/g, root.hex(root.color)) + '</svg>')
    }
}
