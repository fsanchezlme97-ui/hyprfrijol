// Texto monoespaciado (JetBrains Mono 11.5, c.tv) para líneas de configuración.
// tech: true → detalle técnico (comando, clave de configuración, servicio): solo con Ajustes › Acerca › «Detalles
// técnicos» (settingsTech); lo que sirve a cualquiera (atajos, recuentos, nombres de dispositivos) no lo lleva.
import QtQuick
import "../../.."
import "../../../components"

Txt {
    property bool tech: false
    visible: !tech || Settings.get("settingsTech", false) === true
    size: 11.5; muted: true; font.family: Theme.mono; elide: Text.ElideRight
}
