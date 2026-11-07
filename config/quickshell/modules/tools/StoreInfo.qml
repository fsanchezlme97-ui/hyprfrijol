// Datos de la ficha de una app del Centro de aplicaciones, en segundo plano y sin claves de API:
//   · Flathub (appstream ?locale=es + summary): descripción, capturas, web, licencia, desarrollador, versión, tamaños
//   · AUR (RPC v5 info): versión, descripción, web, votos, popularidad, mantenedor, última actualización
//   · pacman -Si (sin red): versión, tamaños, licencia, web, repositorio
//   · metainfo de AppStream local (/usr/share/metainfo) si la app está instalada: descripción y capturas
// Lo descargado se guarda en ~/.cache/hyprfrijol/store/ (un día; sin red se usa la copia vieja).
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../services"

Item {
    id: si
    visible: false
    property var tool: null
    readonly property var p: tool?.pkgs ?? {}
    readonly property string flatpakId: p.flatpak ?? (tool?.key === "flatpak" ? tool.pkg : "")
    readonly property string aurPkg: Pkg.family === "arch" ? Pkg.names(p.aur ?? (tool?.key === "aur" ? tool.pkg : ""))[0] ?? "" : ""
    readonly property string repoPkg: Pkg.family === "arch" ? Pkg.names(p.pacman ?? (tool?.key === "repo" ? tool.pkg : "") ?? "")[0] ?? "" : ""
    // Nombres con los que buscar el metainfo local: id de Flatpak, iconos con forma de id (org.gnome.X) y la entrada .desktop
    readonly property var appIds: [...new Set([flatpakId].concat(tool?.icon ?? []).concat([tool?.desktop ?? ""]).filter(n => /^[\w-]+(\.[\w-]+){2,}$/.test(n)))]

    property var fh: null               // appstream de Flathub (null = no está o aún no llegó)
    property var fhSum: null            // tamaños de Flathub
    property var aurInfo: null
    property var pac: null              // campos de pacman -Si
    property var local: null            // metainfo local { summary, description, shots, homepage, license, developer, version }
    property string fhState: ""         // "" | loading | ok | none | err
    property string aurState: ""
    property bool localDone: false
    readonly property bool loading: fhState === "loading" || aurState === "loading" || !localDone
    readonly property string cacheDir: Paths.cache + "/store"

    onToolChanged: Qt.callLater(load)      // después de que se actualicen flatpakId/aurPkg/repoPkg
    function load(): void {
        fh = null; fhSum = null; aurInfo = null; pac = null; local = null; localDone = false;
        fhState = flatpakId ? "loading" : ""; aurState = aurPkg ? "loading" : "";
        net.running = false; loc.running = false;
        if (!tool) return;
        const args = [];
        if (flatpakId) args.push("flathub-" + flatpakId + ".json", "https://flathub.org/api/v2/appstream/" + flatpakId + "?locale=es",
                                 "flathub-sum-" + flatpakId + ".json", "https://flathub.org/api/v2/summary/" + flatpakId);
        if (aurPkg) args.push("aur-" + aurPkg + ".json", "https://aur.archlinux.org/rpc/v5/info?arg[]=" + encodeURIComponent(aurPkg));
        if (args.length) { net.command = ["bash", "-c", netScript, "hf-store", cacheDir].concat(args); net.running = true; }
        loc.command = ["bash", "-c", locScript, "hf-store", repoPkg].concat(appIds);
        loc.running = true;
    }

    // Descarga con caché: «@@hl:nombre» + ok|err + cuerpo. Un 404 se recuerda como null (no existe).
    readonly property string netScript: "d=$1; shift; mkdir -p \"$d\" 2>/dev/null\n"
        + "while [ $# -ge 2 ]; do n=$1; u=$2; shift 2; f=\"$d/$n\"; echo \"@@hl:$n\"\n"
        + "  if [ -s \"$f\" ] && [ $(( $(date +%s) - $(stat -c %Y \"$f\") )) -lt 86400 ]; then echo ok; cat \"$f\"; echo; continue; fi\n"
        + "  c=$(curl -sSL --max-time 20 -A hyprfrijol -o \"$f.part\" -w '%{http_code}' \"$u\" 2>/dev/null)\n"
        + "  if [ \"$c\" = 200 ]; then mv -f \"$f.part\" \"$f\"; echo ok; cat \"$f\"; echo\n"
        + "  elif [ \"$c\" = 404 ]; then rm -f \"$f.part\"; echo null > \"$f\"; echo ok; echo null\n"
        + "  else rm -f \"$f.part\"; if [ -s \"$f\" ]; then echo ok; cat \"$f\"; echo; else echo err; fi; fi\n"
        + "done"
    // Sin red: pacman -Si del paquete de los repos y el metainfo instalado (si lo hay)
    readonly property string locScript: "export LC_ALL=C; r=$1; shift\n"
        + "echo @@hl:pacman; [ -n \"$r\" ] && command -v pacman >/dev/null && pacman -Si -- \"$r\" 2>/dev/null | awk 'NR>1 && /^Repository/{exit} {print}'\n"
        + "echo @@hl:meta\n"
        + "for c; do for f in /usr/share/metainfo/$c.metainfo.xml /usr/share/metainfo/$c.appdata.xml /usr/share/appdata/$c.appdata.xml; do\n"
        + "  [ -f \"$f\" ] && { head -c 200000 \"$f\"; exit 0; }; done; done; exit 0"

    function sections(text: string): var {
        const out = {};
        text.split("\n@@hl:").forEach((chunk, i) => {
            if (i === 0) chunk = chunk.replace(/^@@hl:/, "");
            const nl = chunk.indexOf("\n");
            if (nl < 0) { out[chunk.trim()] = ""; return; }
            out[chunk.slice(0, nl).trim()] = chunk.slice(nl + 1);
        });
        return out;
    }
    function parseNet(body): var {         // → { ok, data }
        const nl = body.indexOf("\n");
        const st = (nl < 0 ? body : body.slice(0, nl)).trim();
        if (st !== "ok") return { ok: false, data: null };
        try { return { ok: true, data: JSON.parse(body.slice(nl + 1)) }; } catch (e) { return { ok: false, data: null }; }
    }
    Process {
        id: net
        stdout: StdioCollector {
            onStreamFinished: {
                const s = si.sections(text);
                if (si.flatpakId) {
                    const a = si.parseNet(s["flathub-" + si.flatpakId + ".json"] ?? "");
                    si.fh = a.data && a.data.id ? a.data : null;
                    si.fhState = !a.ok ? "err" : si.fh ? "ok" : "none";
                    const b = si.parseNet(s["flathub-sum-" + si.flatpakId + ".json"] ?? "");
                    si.fhSum = b.data && b.data.arches ? b.data : null;
                }
                if (si.aurPkg) {
                    const c = si.parseNet(s["aur-" + si.aurPkg + ".json"] ?? "");
                    si.aurInfo = c.data?.results?.[0] ?? null;
                    si.aurState = !c.ok ? "err" : si.aurInfo ? "ok" : "none";
                }
            }
        }
        onExited: (code) => {
            if (si.fhState === "loading") si.fhState = "err";
            if (si.aurState === "loading") si.aurState = "err";
        }
    }
    Process {
        id: loc
        stdout: StdioCollector {
            onStreamFinished: {
                const s = si.sections(text);
                si.pac = si.parsePacman(s.pacman ?? "");
                si.local = si.parseMeta(s.meta ?? "");
                si.localDone = true;
            }
        }
        onExited: si.localDone = true
    }
    function parsePacman(t: string): var {
        const o = {};
        let last = "";
        for (const line of t.split("\n")) {
            const m = line.match(/^(\S[^:]*?)\s*:\s(.*)$/);
            if (m) { last = m[1]; o[last] = m[2].trim(); }
            else if (last && /^\s+\S/.test(line)) o[last] += " " + line.trim();
        }
        return o.Name ? o : null;
    }
    function parseMeta(x: string): var {
        if (!x.trim()) return null;
        x = x.replace(/<!--[\s\S]*?-->/g, "");
        const one = re => (x.match(re) ?? [])[1]?.trim() ?? "";
        let desc = one(/<description>([\s\S]*?)<\/description>/);
        desc = desc.replace(/<(\w+)[^>]*xml:lang="[^"]*"[^>]*>[\s\S]*?<\/\1>/g, "").replace(/\s+/g, " ").trim();
        const shots = [];
        const re = /<image(?![^>]*type="thumbnail")[^>]*>\s*([^<\s]+)\s*<\/image>/g;
        let m;
        while ((m = re.exec(x)) !== null && shots.length < 8) shots.push({ src: m[1], caption: "" });
        return {
            summary: one(/<summary xml:lang="es">([^<]*)<\/summary>/) || one(/<summary>([^<]*)<\/summary>/),
            description: desc, shots: shots,
            homepage: one(/<url type="homepage">([^<]+)<\/url>/),
            license: one(/<project_license>([^<]+)<\/project_license>/),
            developer: one(/<developer_name>([^<]+)<\/developer_name>/) || one(/<developer[^>]*>\s*<name>([^<]+)<\/name>/),
            version: one(/<release[^>]*version="([^"]+)"/)
        };
    }

    // ---------- lo que muestra la ficha ----------
    function fmtBytes(n): string {
        n = Number(n);
        if (!n) return "";
        const u = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (n >= 1000 && i < u.length - 1) { n /= 1000; i++; }
        return n.toLocaleString(Qt.locale("es_ES"), "f", n < 10 && i > 0 ? 1 : 0) + " " + u[i];
    }
    function fmtDate(sec): string { return sec ? new Date(Number(sec) * 1000).toLocaleDateString(Qt.locale("es_ES"), "d MMM yyyy") : ""; }
    // «12.34 MiB» de pacman → «12,9 MB» como el resto de la ficha
    function pacSize(s): string {
        const m = String(s ?? "").match(/^([\d.]+)\s*(B|KiB|MiB|GiB)$/);
        return m ? fmtBytes(Number(m[1]) * ({ B: 1, KiB: 1024, MiB: 1048576, GiB: 1073741824 })[m[2]]) : String(s ?? "");
    }

    readonly property string summary: fh?.summary || local?.summary || ""
    readonly property string description: fh?.description || local?.description
        || ((aurInfo?.Description || pac?.Description) ? "<p>" + (pac?.Description || aurInfo?.Description) + "</p>" : "")
    readonly property string developer: fh?.developer_name || local?.developer || ""
    readonly property string homepage: fh?.urls?.homepage || local?.homepage || pac?.URL || aurInfo?.URL || ""
    readonly property string license: fh?.project_license || local?.license || (pac?.Licenses ?? "") || (aurInfo?.License ?? []).join(", ")
    readonly property string iconUrl: fh?.icon ?? ""
    readonly property var release: (fh?.releases ?? [])[0] ?? null
    readonly property var shots: {
        const s = (fh?.screenshots ?? []).map(x => {
            // la más cercana a ~1250 px de ancho (las capturas de Flathub vienen en varios tamaños)
            const sz = (x.sizes ?? []).slice().sort((a, b) => Math.abs(Number(a.width) - 1250) - Math.abs(Number(b.width) - 1250))[0];
            return sz ? { src: sz.src, caption: x.caption ?? "" } : null;
        }).filter(Boolean);
        return s.length ? s : (local?.shots ?? []);
    }
    // Versión según la fuente
    function versionFor(key: string): string {
        if (key === "repo") return pac?.Version ?? "";
        if (key === "aur") return aurInfo?.Version ?? "";
        if (key === "flatpak") return release?.version ?? "";
        return "";
    }
    // Filas de información según la fuente elegida: [[etiqueta, valor]]
    function rows(key: string): var {
        const r = [];
        const v = versionFor(key) || pac?.Version || aurInfo?.Version || release?.version || local?.version || "";
        if (v) r.push(["Versión", v + (key === "flatpak" && release?.timestamp ? " · " + fmtDate(release.timestamp) : "")]);
        if (key === "repo" && pac) {
            if (pac.Repository) r.push(["Repositorio", pac.Repository]);
            if (pac["Download Size"]) r.push(["Descarga", pacSize(pac["Download Size"])]);
            if (pac["Installed Size"]) r.push(["Instalada ocupa", pacSize(pac["Installed Size"])]);
        }
        if (key === "flatpak" && fhSum) {
            if (fhSum.download_size) r.push(["Descarga", fmtBytes(fhSum.download_size)]);
            if (fhSum.installed_size) r.push(["Instalada ocupa", fmtBytes(fhSum.installed_size) + " (sin runtime)"]);
            if (fh?.metadata?.["flathub::verification::verified"] === "true" || fh?.metadata?.["flathub::verification::verified"] === true)
                r.push(["Verificada", "Sí · " + (fh.metadata["flathub::verification::website"] || fh.metadata["flathub::verification::login_name"] || "desarrollador")]);
        }
        if (key === "aur" && aurInfo) {
            r.push(["Votos", String(aurInfo.NumVotes) + " · popularidad " + Number(aurInfo.Popularity).toLocaleString(Qt.locale("es_ES"), "f", 2)]);
            r.push(["Mantenedor", aurInfo.Maintainer || "sin mantenedor (huérfano)"]);
            r.push(["Actualizado", fmtDate(aurInfo.LastModified)]);
            if (aurInfo.OutOfDate) r.push(["Aviso", "marcado como desactualizado el " + fmtDate(aurInfo.OutOfDate)]);
        }
        if (license) r.push(["Licencia", license]);
        if (developer) r.push(["Desarrollador", developer]);
        return r;
    }
}
