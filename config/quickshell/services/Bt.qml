pragma Singleton
// Bluetooth (BlueZ vía Quickshell.Bluetooth)
//   adapter, available, enabled, devices, connected, paired, discovered (sin emparejar, con nombre)
//   setEnabled(on), iconFor(dev) → nombre de icono de components/Icons, kindText(dev) → "Auriculares"…
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: Bluetooth.devices.values
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
    readonly property var discovered: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")
    function setEnabled(on: bool): void { if (adapter) adapter.enabled = on; }

    // icono BlueZ (freedesktop) → icono del diseño
    function iconFor(d): string {
        const i = d?.icon ?? "";
        return /audio|headset|headphone|speaker/.test(i) ? "volume"
             : /keyboard/.test(i) ? "keyboard"
             : /phone/.test(i) ? "phone"
             : /gaming|joystick/.test(i) ? "gamepad"
             : /computer|laptop/.test(i) ? "monitor"
             : /camera|video/.test(i) ? "camera"
             : /printer/.test(i) ? "printer"
             : "bluetooth";
    }
    function kindText(d): string {
        const i = d?.icon ?? "";
        return /headset/.test(i) ? "Auriculares con micrófono" : /headphone/.test(i) ? "Auriculares"
             : /speaker|audio/.test(i) ? "Altavoz" : /keyboard/.test(i) ? "Teclado" : /mouse/.test(i) ? "Ratón"
             : /tablet/.test(i) ? "Tableta" : /phone/.test(i) ? "Teléfono" : /gaming|joystick/.test(i) ? "Mando"
             : /computer|laptop/.test(i) ? "Ordenador" : /printer/.test(i) ? "Impresora" : "Dispositivo";
    }
}
