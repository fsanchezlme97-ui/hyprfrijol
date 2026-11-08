pragma Singleton
// Reproductores (MPRIS), ya limpios:
//   players   sin duplicados ni vacíos: fuera playerctld (repite al activo), los que no tienen nada cargado
//             (sin título y sin sonar: pestañas paradas, instancias vacías del navegador) y las copias de la misma
//             pista (plasma-browser-integration repite la del navegador; dos instancias del mismo vídeo). De cada
//             copia se queda la mejor: la que suena, la que no es un puente, la que tiene carátula y duración.
//             Orden: los que suenan primero.
//   all       todos, tal cual los anuncia MPRIS
//   active    el que suena; si no, el último que sonó; si no, el primero
//   appOf(p)  { name, icon } con el nombre real de la app y su icono (entrada .desktop; las web apps integradas,
//             cuyo reproductor se llama como la web app, con el icono del catálogo)
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var all: Mpris.players.values
    property string lastPlaying: ""

    function isBridge(p): bool { return /plasma-browser-integration|kdeconnect|MediaPlayer2\.Valent|playerctld|mpris-proxy/i.test(p?.dbusName ?? ""); }
    function hasContent(p): bool { return String(p?.trackTitle ?? "").trim() !== "" || String(p?.trackArtUrl ?? "") !== ""; }
    function score(p): int {
        return (p.isPlaying ? 100 : 0) + (isBridge(p) ? 0 : 20) + (p.dbusName === lastPlaying ? 8 : 0)
             + (p.trackArtUrl ? 4 : 0) + (p.lengthSupported && p.length > 0 ? 2 : 0) + (p.canSeek ? 1 : 0);
    }
    function norm(s): string { return String(s ?? "").toLowerCase().replace(/\s+/g, " ").replace(/^\(\d+\)\s*/, "").trim(); }
    readonly property var players: {
        const groups = new Map();
        for (const p of all) {
            if (!p || /playerctld/i.test(p.dbusName ?? "")) continue;
            if (!p.isPlaying && !hasContent(p)) continue;
            if (p.playbackState === MprisPlaybackState.Stopped && !hasContent(p)) continue;
            const k = hasContent(p) ? norm(p.trackTitle) + "|" + norm(p.trackArtist) : "#" + p.dbusName;
            const cur = groups.get(k);
            if (!cur || score(p) > score(cur)) groups.set(k, p);
        }
        const out = Array.from(groups.values());
        // los que suenan primero; el resto en el orden de MPRIS
        return out.filter(p => p.isPlaying).concat(out.filter(p => !p.isPlaying));
    }
    readonly property var active: players.find(p => p.isPlaying) ?? players.find(p => p.dbusName === lastPlaying) ?? players[0] ?? null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string art: active?.trackArtUrl ?? ""
    function toggle(): void { if (active?.canTogglePlaying) active.togglePlaying(); }
    function next(): void { if (active?.canGoNext) active.next(); }
    function previous(): void { if (active?.canGoPrevious) active.previous(); }

    // Recuerda el último que sonó (para no saltar a otro al pausar)
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) root.lastPlaying = modelData.dbusName; }
        }
    }

    // ---- nombre e icono de la app
    function entryOf(p) {
        const de = String(p?.desktopEntry ?? "");
        if (de) {
            const e = DesktopEntries.byId(de) ?? DesktopEntries.heuristicLookup(de);
            if (e) return e;
        }
        const id = String(p?.identity ?? "");
        return id ? DesktopEntries.heuristicLookup(id) : null;
    }
    function appOf(p): var {
        if (!p) return { name: "", icon: "" };
        const ident = String(p.identity ?? "");
        // Web apps integradas (scripts/hf-webapp): el reproductor lleva el nombre de la web app
        const web = /chromium\.instance/i.test(p.dbusName ?? "") ? WebApps.byName(ident) : null;
        if (web) return { name: web.name, icon: WebApps.iconOf(web), web: true };
        if (/^qml runtime$/i.test(ident)) return { name: "Web app", icon: Quickshell.iconPath("web-browser", true), web: true };
        const e = entryOf(p);
        const raw = String(p.dbusName ?? "").replace("org.mpris.MediaPlayer2.", "").replace(/\.instance[_\d]+$/, "");
        const name = e?.name || ident || raw.charAt(0).toUpperCase() + raw.slice(1);
        const icon = (e?.icon ? Quickshell.iconPath(e.icon, true) : "")
            || Quickshell.iconPath(String(p.desktopEntry || raw).toLowerCase(), true)
            || Quickshell.iconPath("audio-x-generic", true);
        return { name: name, icon: icon, web: false };
    }
}
