//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
// hyprfrijol · punto de entrada de Quickshell
// Se lanza desde Hyprland con:  qs -p <repo>/config/quickshell
import QtQuick
import Quickshell
import "bar"
import "modules"

ShellRoot {
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
