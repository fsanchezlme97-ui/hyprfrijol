// Campo de búsqueda/texto con icono (como los <label> con lupa del diseño, 30–34 px, fondo fill2).
//   Field { icon: "search"; placeholder: "Buscar…"; onAccepted: … ; text }
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: "search"
    property real h: 32
    property real textSize: 12.5
    signal accepted()
    signal keyPressed(var event)
    implicitHeight: h
    radius: Theme.ctl(h)
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.p
    color: Theme.fill2
    function focusInput() { input.forceActiveFocus(); }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8
        Icon { visible: root.icon !== ""; name: root.icon; color: Theme.tv }
        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.t
            selectionColor: Theme.pc
            selectedTextColor: Theme.pcText
            font.family: Theme.font
            font.pixelSize: Theme.px(root.textSize)
            clip: true
            onAccepted: root.accepted()
            Keys.onPressed: e => root.keyPressed(e)
            Txt {
                anchors.fill: parent
                visible: input.text === "" && !input.preeditText
                text: root.placeholder
                muted: true
                size: root.textSize
            }
        }
    }
}
