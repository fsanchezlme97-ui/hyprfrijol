// Baldosa del aviso: imagen (avatar), icono de la app, o inicial sobre color del tono (como el diseño).
// avatar: false → la imagen del aviso se muestra aparte (NotifCard) y aquí va solo el icono de la app.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../components"

Item {
    id: root
    required property var n
    property real size: 28
    property real radius: Theme.r(7)
    property bool avatar: true
    implicitWidth: size
    implicitHeight: size
    readonly property string tone: Notifs.tone(n)
    readonly property color bgc: tone === "pc" ? Theme.pc : tone === "sc" ? Theme.sc : Theme.s4
    readonly property color fgc: tone === "pc" ? Theme.pcText : tone === "sc" ? Theme.scText : Theme.t
    readonly property string iconSrc: {
        const i = n?.appIcon ?? "";
        if (i === "") return "";
        if (i.startsWith("/") || i.startsWith("file:")) return i.startsWith("/") ? "file://" + i : i;
        return Quickshell.iconPath(i, true);
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.bgc
        Txt {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready && icon.status !== Image.Ready
            text: Notifs.glyph(root.n)
            color: root.fgc
            size: root.size > 27 ? 12 : 11
            weight: Font.DemiBold
        }
        IconImage {
            id: icon
            anchors.centerIn: parent
            implicitSize: root.size * 0.62
            visible: img.status !== Image.Ready && status === Image.Ready
            source: root.iconSrc
            asynchronous: true
        }
        Image {
            id: img
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.avatar ? (root.n?.image ?? "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(root.size * 2, root.size * 2)
        }
    }
}
