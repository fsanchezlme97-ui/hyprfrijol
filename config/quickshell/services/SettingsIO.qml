pragma Singleton
// Exportar / importar los ajustes (~/.config/hyprfrijol/settings.json) — Ajustes › Sistema › Tus ajustes.
//   SettingsIO.exportFile()          elige dónde con zenity (si no hay, ~/Documentos/hyprfrijol-ajustes-<fecha>.json)
//   SettingsIO.importFile()          elige el archivo (si no hay diálogo, la copia más reciente de Documentos)
//   SettingsIO.exportFile(ruta) / importFile(ruta)   sin diálogo (IPC de pruebas: settings exportTo / importFrom)
// Importar valida el JSON (un objeto; claves válidas y del mismo tipo que su valor por defecto), lo mezcla con
// los ajustes actuales y lo aplica con Confirm (barra «¿Se ve bien?», se puede deshacer 15 s).
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property string msg: ""
    property bool bad: false
    readonly property bool busy: exportProc.running || importProc.running

    readonly property string docs: "d=$(xdg-user-dir DOCUMENTS 2>/dev/null); [ -n \"$d\" ] && [ \"$d\" != \"$HOME\" ] || d=\"$HOME/Documentos\"; "

    function done(t: string, isBad: bool): void { msg = t.split(Paths.home).join("~"); bad = isBad; }

    function exportFile(path): void {
        if (busy) return;
        msg = "";
        exportProc.command = ["sh", "-c", docs
            + "def=\"$d/hyprfrijol-ajustes-$(date +%F).json\"; f=$2; "
            + "if [ -n \"$f\" ]; then :; "
            + "elif command -v zenity >/dev/null; then f=$(zenity --file-selection --save --confirm-overwrite --title='Exportar ajustes' --filename=\"$def\" --file-filter='JSON | *.json' 2>/dev/null) || { echo CANCEL; exit; }; "
            + "else mkdir -p \"$d\"; f=$def; fi; "
            + "case $f in *.json) ;; *) f=$f.json;; esac; "
            + "{ [ -f \"$1\" ] && cp \"$1\" \"$f\" || echo '{}' > \"$f\"; } && echo \"OK $f\" || echo \"ERR $f\"",
            "sh", Paths.userDir + "/settings.json", path ?? ""];
        exportProc.running = true;
    }
    function importFile(path): void {
        if (busy) return;
        msg = "";
        importProc.command = ["sh", "-c", docs
            + "f=$1; if [ -n \"$f\" ]; then :; "
            + "elif command -v zenity >/dev/null; then f=$(zenity --file-selection --title='Importar ajustes' --filename=\"$d/\" --file-filter='JSON | *.json' 2>/dev/null) || { echo CANCEL; exit; }; "
            + "else f=$(ls -t \"$d\"/hyprfrijol-ajustes-*.json \"$d\"/hypr-liquid-ajustes-*.json 2>/dev/null | head -n1); [ -n \"$f\" ] || { echo NOFILE; exit; }; fi; "
            + "[ -r \"$f\" ] || { echo \"NOREAD $f\"; exit; }; echo \"FILE $f\"; head -c 2000000 \"$f\"",
            "sh", path ?? ""];
        importProc.running = true;
    }

    // Texto de la orden de importar: «FILE ruta» y el JSON
    function importText(t: string): void {
        const nl = t.indexOf("\n"), head = nl < 0 ? t.trim() : t.slice(0, nl);
        if (head === "CANCEL" || head === "") return;
        if (head === "NOFILE") return done("No hay ninguna copia en Documentos (hyprfrijol-ajustes-*.json)", true);
        if (!head.startsWith("FILE ")) return done("No se pudo leer «" + head.replace(/^NOREAD /, "") + "»", true);
        const file = head.slice(5);
        let o;
        try { o = JSON.parse(t.slice(nl + 1)); } catch (e) { return done("«" + file + "» no es un JSON válido", true); }
        if (!o || typeof o !== "object" || Array.isArray(o)) return done("«" + file + "» no es un archivo de ajustes", true);
        const ok = {}, skip = [];
        for (const k in o) {
            const d = Settings.defaults[k], v = o[k];
            const typeOk = d === undefined || d === null || v === null || (typeof d === typeof v && Array.isArray(d) === Array.isArray(v));
            if (/^[A-Za-z][A-Za-z0-9_]*$/.test(k) && typeOk) ok[k] = v; else skip.push(k);
        }
        const n = Object.keys(ok).length;
        if (!n) return done("«" + file + "» no tiene ajustes válidos", true);
        const changed = Object.keys(ok).filter(k => JSON.stringify(Settings.get(k, null)) !== JSON.stringify(ok[k])).length;
        const ign = skip.length ? " · " + skip.length + " ignorados (" + skip.slice(0, 3).join(", ") + (skip.length > 3 ? "…" : "") + ")" : "";
        if (!changed) return done("Ya tenías estos " + n + " ajustes" + ign, false);
        Confirm.change("Ajustes importados", ok);
        done("Importados de «" + file + "»: " + changed + (changed === 1 ? " ajuste cambia" : " ajustes cambian") + ign, false);
    }

    Process {
        id: exportProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === "CANCEL" || t === "") return;
                root.done(t.startsWith("OK ") ? "Exportados a " + t.slice(3) : "No se pudo guardar en " + t.slice(4), !t.startsWith("OK "));
            }
        }
    }
    Process {
        id: importProc
        stdout: StdioCollector { onStreamFinished: root.importText(text) }
    }
}
