pragma Singleton
// Rutas compartidas por todo el shell
import QtQuick
import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string state: home + "/.local/state/hyprfrijol"
    readonly property string userDir: home + "/.config/hyprfrijol"
    readonly property string cache: home + "/.cache/hyprfrijol"
    readonly property string root: Quickshell.env("HF_ROOT") || Quickshell.env("HL_ROOT") || Quickshell.shellPath("../..").replace(/\/$/, "")
    readonly property string scripts: root + "/scripts"
    readonly property string assets: root + "/assets"
    readonly property string pictures: home + "/Imágenes"

    function script(name: string): string { return scripts + "/" + name; }
    // Prefijo para procesos que no acaban solos (escuchas, bucles): mueren con el shell aunque este caiga o se
    // reinicie (antes `nmcli monitor` y `hf-devices watch` quedaban huérfanos en cada reinicio)
    readonly property var reaper: ["setpriv", "--pdeathsig", "TERM", "--"]
}
