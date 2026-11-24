// Icono de Harper: brújula con bolita de estado en la parte superior derecha.
// Estados: idle, listening, thinking, speaking, error.
import QtQuick
import ".."

Item {
    id: root
    property real size: 16
    property string state: {
        if (Shell.aiSpeaking) return "speaking";
        if (Shell.aiBusy || Shell.dictPhase === "trans") return "thinking";
        if (Shell.dictPhase === "rec") return "listening";
        return "idle";
    }
    property color baseColor: Theme.t

    readonly property color dotColor: {
        switch (state) {
        case "listening": return Theme.p;
        case "thinking": return Qt.tint(Theme.p, Qt.alpha(Theme.glass, 0.45));
        case "speaking": return Theme.ter;
        case "error": return Theme.danger;
        default: return Qt.alpha(Theme.tv, 0.2);
        }
    }

    implicitWidth: size
    implicitHeight: size

    Icon {
        anchors.fill: parent
        name: "ai_body"
        color: root.baseColor
    }
    Rectangle {
        x: root.size * (19.5 / 24) - width / 2
        y: root.size * (4.5 / 24) - height / 2
        width: root.size * (5.6 / 24)
        height: width
        radius: width / 2
        color: root.dotColor
    }
}
