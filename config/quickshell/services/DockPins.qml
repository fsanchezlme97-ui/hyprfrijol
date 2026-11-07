pragma Singleton
// Apps fijadas en el dock (ajuste "dockApps", ids .desktop). Las usan el dock (modules/desktop) y el Spotlight
// («Todas las apps» › clic derecho › Fijar en el dock).
//   DockPins.pinned · DockPins.isPinned(id) · DockPins.toggle(id)
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    // GNOME primero (siguen el tema); KDE y otras como alternativa si no están
    readonly property var defaultDock: ["org.gnome.Nautilus", "org.kde.dolphin", "thunar", "firefox", "chromium", "google-chrome",
        "kitty", "org.gnome.TextEditor", "org.gnome.Calculator", "org.kde.kcalc", "org.kde.kate", "code"]
    readonly property var pinned: {
        DesktopEntries.applications.values.length;   // se recalcula cuando se cargan las apps
        // Solo cuenta lo que el usuario fijó (los valores por defecto traen [] y dejarían el dock vacío)
        const ids = Settings.user?.dockApps ?? defaultDock.filter(id => DesktopEntries.byId(id)).slice(0, 6);
        return ids.filter(id => DesktopEntries.byId(id));
    }
    function isPinned(id: string): bool { return pinned.includes(id); }
    function toggle(id: string): void {
        const cur = pinned.slice();
        const i = cur.indexOf(id);
        if (i >= 0) cur.splice(i, 1); else if (DesktopEntries.byId(id)) cur.push(id);
        Settings.set("dockApps", cur);
    }
}
