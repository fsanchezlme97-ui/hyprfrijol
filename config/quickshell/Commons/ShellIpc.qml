// Compatibilidad con Omarchy · Commons.ShellIpc: un IpcHandler que solo se activa en la primera copia de su
// destino (ver IpcRegistry). En hyprfrijol se llega igual con `qs -p <repo>/config/quickshell ipc call <destino> <función>`.
import QtQuick
import Quickshell.Io

IpcHandler {
    id: handler
    enabled: target !== "" && IpcRegistry.leads(handler, IpcRegistry.revision)
    onTargetChanged: IpcRegistry.touch()
    Component.onCompleted: IpcRegistry.register(handler)
    Component.onDestruction: IpcRegistry.unregister(handler)
}
