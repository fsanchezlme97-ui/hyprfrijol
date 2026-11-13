// "Responder…" con botón de enviar (respuesta en línea). compact = estilo de la lista de ajustes rápidos.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    required property var n
    property bool compact: false
    signal sent()
    implicitHeight: compact ? 28 : 30
    radius: compact ? 7 : 6
    color: compact ? Theme.s1 : Theme.fill2
    function send() {
        if (input.text.trim() === "") return;
        Notifs.reply(root.n, input.text.trim());
        input.text = "";
        root.sent();
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 12 : 10
        anchors.rightMargin: 4
        spacing: 8
        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.t
            font.family: Theme.font
            font.pixelSize: Theme.px(12.5)
            selectionColor: Theme.pc
            selectedTextColor: Theme.pcText
            clip: true
            onAccepted: root.send()
            Keys.onEscapePressed: e => { focus = false; e.accepted = false; }
            Txt {
                anchors.fill: parent
                visible: input.text === "" && !input.preeditText
                text: (root.n?.inlineReplyPlaceholder || "Responder") + "…"
                muted: true
            }
        }
        Rectangle {
            implicitWidth: root.compact ? 22 : 24
            implicitHeight: implicitWidth
            radius: root.compact ? 11 : 5
            color: Theme.p
            opacity: input.text.trim() === "" ? 0.75 : 1
            Icon { anchors.centerIn: parent; name: "arrow_right"; color: Theme.pText }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.send() }
        }
    }
}
