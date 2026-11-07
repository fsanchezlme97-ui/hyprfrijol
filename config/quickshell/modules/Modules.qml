// Registro de módulos. Cada módulo es autónomo (normalmente un Overlay que se muestra con su vista).
// Para añadir uno: créalo en modules/<nombre>/ y ponlo aquí.
// Portapapeles y emojis no son módulos propios: son modos de Spotlight («:» y «;», ver Shell.redirects).
// Desarrollo: HF_DEV_MODULES="modules/x/X.qml,…" carga módulos extra sin tocar este archivo (lo usa dev/try.sh).
import QtQuick
import Quickshell
import "spotlight"
import "power"
import "lock"
import "focus"
import "polkit"
import "quicksettings"
import "notifications"
import "osd"
import "sidepanel"
import "pip"
import "wallpapers"
import "capture"
import "colorpicker"
import "updates"
import "overview"
import "alttab"
import "snap"
import "desktop"
import "widgets"
import "profiles"
import "settings"
import "welcome"
import "tools"
import "cheatsheet"
import "media"
import "dictado"
import "firmar"

Scope {
    Spotlight {}
    Energia {}
    Lock {}
    Focus {}
    Polkit {}
    QuickSettings {}      // centro de control: ajustes rápidos + notificaciones + agenda
    Osd {}
    SidePanel {}
    Pip {}
    WallpaperSelector {}
    Capture {}
    ColorPicker {}
    Updates {}
    Overview {}
    AltTab {}
    Snap {}
    Desktop {}
    Widgets {}
    Profiles {}
    SettingsApp {}
    Welcome {}
    Tools {}
    Cheatsheet {}
    MediaControls {}
    Dictado {}
    Firmar {}

    Variants {
        model: (Quickshell.env("HF_DEV_MODULES") ?? "").split(",").filter(s => s.trim() !== "")
        LazyLoader {
            required property string modelData
            active: true
            source: Qt.resolvedUrl("../" + modelData.trim())
        }
    }
}
