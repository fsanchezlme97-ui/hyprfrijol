//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
// hyprfrijol · punto de entrada de Quickshell
// Se lanza desde Hyprland con:  qs -p <repo>/config/quickshell
import QtQuick
import Quickshell
import "bar"
import "modules"

ShellRoot {
    // Recarga en caliente al cambiar un .qml solo en las sesiones anidadas (dev/try.sh): en la tuya cada recarga
    // dejaba memoria atrás y tras muchas el shell iba lento; al actualizar, hf-apply lo reinicia (hf-shell refresh)
    settings.watchFiles: Quickshell.env("HF_NESTED") === "1"
    // Fondo y barra en cada monitor
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Wallpaper { id: wall; screen: perScreen.modelData }
            Bar { screen: perScreen.modelData }
            // Pantalla de carga al iniciar sesión (logo + barrita) hasta que el fondo se ve
            Splash { screen: perScreen.modelData; ready: wall.ready }
        }
    }

    NotificationPopups {}

    // Módulos (cada uno es una vista del diseño; se abren con Shell.toggle("<vista>"))
    Modules {}
}
