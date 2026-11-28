// Isla plegada: lo más importante en una línea (o un punto sin nada en marcha, o la hora con islandAlways).
// La usan la isla suelta (Island.qml) y la muesca de la barra (bar/BarH.qml).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

RowLayout {
    spacing: 8
    Rectangle { visible: Isla.dot; implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.tv }
    Icon { visible: Isla.keys.length > 0; name: Isla.top.icon ?? "clock"; size: 14; color: Theme.p }
    Txt { visible: !Isla.dot; Layout.maximumWidth: 170; text: Isla.keys.length ? Isla.top.title : Time.hhmm; elide: Text.ElideRight; weight: Font.Medium; size: 12.5; tabular: !Isla.keys.length }
    Txt { visible: Isla.keys.length > 0 && !!Isla.top.sub && Isla.keys[0] !== "musica"; text: Isla.top.sub; muted: true; size: 12; tabular: true }
}
