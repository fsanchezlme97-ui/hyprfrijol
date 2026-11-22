pragma Singleton
// Apps fijadas en el dock (ajuste "dockApps", ids .desktop). Las usan el dock (modules/desktop) y el Spotlight
// («Todas las apps» › clic derecho › Fijar en el dock).
//   DockPins.pinned · DockPins.isPinned(id) · DockPins.toggle(id)
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    // Una app por tarea: la primera instalada de cada grupo. KDE/Qt primero (siguen el tema activo con qt6ct);
    // las de GNOME solo si no hay de KDE.
    readonly property var defaultGroups: [["org.kde.dolphin", "pcmanfm-qt"], ["org.kde.falkon", "firefox", "chromium", "google-chrome"],
        ["kitty"], ["org.kde.kate"], ["org.kde.kcalc"], ["code"]]
    readonly property var defaultDock: { DesktopEntries.applications.values.length; return defaultGroups.map(g => g.find(id => DesktopEntries.byId(id))).filter(Boolean); }
    readonly property var pinned: {
        DesktopEntries.applications.values.length;   // se recalcula cuando se cargan las apps
        // Solo cuenta lo que el usuario fijó (los valores por defecto traen [] y dejarían el dock vacío)
        const ids = Settings.user?.dockApps ?? defaultDock.slice(0, 6);
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
