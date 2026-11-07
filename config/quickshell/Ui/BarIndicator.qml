// Compatibilidad con Omarchy · qs.Ui.BarIndicator: indicador de barra con texto activo/inactivo.
import QtQuick

BarIconButton {
    id: root
    property string moduleName: ""
    property var settings: ({})
    property string activeText: ""
    property string inactiveText: activeText
    property string activeTooltipText: ""
    property string inactiveTooltipText: activeTooltipText
    property string indicatorBlock: "single"
    property var indicatorHost: null
    property var activeOverride: null
    property bool revealWhenInactive: true
    readonly property bool isActive: activeOverride !== null ? !!activeOverride : active
    text: isActive ? activeText : inactiveText
    tooltipText: isActive ? activeTooltipText : inactiveTooltipText
    concealed: !isActive && !revealWhenInactive
}
