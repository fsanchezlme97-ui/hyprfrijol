pragma Singleton
// Paquetes y tienda: detecta la distro y el gestor (paru/yay/pacman, apt, dnf, zypper, flatpak), carga el
// catálogo (config/tools/catalog.json) y decide de dónde instalar cada app. Lo usan el Centro de aplicaciones,
// la Bienvenida y Ajustes › Aplicaciones, así los tres instalan igual.
// Nunca instala nada por su cuenta: abre una terminal con el comando para que el usuario lo vea y confirme.
//
// Prioridad de fuentes según la distro (order):
//   Arch/CachyOS  repos (pacman) → AUR (paru, si no yay) → Flatpak → AppImage (Gear Lever) → script → web → descarga
//   Fedora        dnf (+ RPM Fusion / COPR) → Flatpak → …   Debian/Ubuntu  apt → Flatpak → …   openSUSE  zypper → Flatpak → …
// Un paquete «aur» que está en los repos de la distro (CachyOS trae brave-bin, zen-browser-bin…) sale como «Repos».
//
//   Pkg.tools                     catálogo con flags expandidas (star, isNew, alpha, preview, xw, term, web)
//   Pkg.sources(t) / Pkg.source(t) fuentes posibles en esta distro (por prioridad) / la elegida
//   Pkg.setSource(id, key)        el usuario elige otra fuente (se guarda en settings.json: storeSources)
//   Pkg.installedVia(t)           fuente por la que está instalada (o null)   · Pkg.updateFor(t) → { to } o null
//   Pkg.commands(items, opts)     → ["paru -S --needed …", "flatpak install …"]; items = apps del catálogo,
//                                   resultados de búsqueda ({ key, pkg }) o el formato antiguo ({ src: "Repos", pkg })
//   Pkg.uninstall(t) · Pkg.update(t) · Pkg.launch(t) · Pkg.entryOf(t)
//   Pkg.longLabels / Pkg.hue(key) / Pkg.explain  nombre claro, color y explicación de cada fuente (insignias, ficha)
//   Pkg.search("texto")           busca en repos + AUR + Flathub en segundo plano → Pkg.results / Pkg.searching
//   Pkg.runInTerminal("…", "Instalar")
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property string distro: ""          // id de /etc/os-release (cachyos, arch, fedora…)
    property string distroName: ""
    property string family: "arch"      // arch | debian | fedora | suse
    property string aur: ""             // paru | yay | ""
    property bool flatpak: false
    property bool snapper: false
    property bool gearlever: false
    property string terminal: "kitty"
    property bool probed: false
    property var installed: ({})        // paquete o id de Flatpak → true (pacman -Qq / dpkg / rpm + flatpak list)
    property var bins: ({})             // ejecutable → true (apps instaladas con script)
    property var syncDb: null           // paquetes del catálogo que están en los repos (pacman -Slq); null = sin saber
    property var updates: ({ repo: {}, aur: {}, flatpak: {} })   // nombre → versión nueva (hf-updates cached)
    property var catalog: ({ categories: [], profiles: [], tools: [] })

    // ---------- fuentes ----------
    readonly property var labels: ({ repo: "Repos", aur: "AUR", flatpak: "Flatpak", appimage: "AppImage", script: "Script", web: "Web", url: "Descarga", none: "No disponible" })
    // Nombre claro de cada fuente (insignias y ficha), su color y qué significa (tooltip y leyenda de la tienda)
    readonly property var longLabels: ({ repo: "Repos oficiales", aur: "AUR", flatpak: "Flatpak", appimage: "AppImage", script: "Instalador", web: "Web app", url: "Descarga", none: "No disponible" })
    readonly property var hues: ({ repo: "#3B9C6B", aur: "#1793D1", flatpak: "#8A63D2", appimage: "#D08A2E", script: "#7A8794", web: "#2E9FB0", url: "#7A8794" })
    readonly property var explain: ({
        repo: "Paquete oficial de " + (distroName || "tu distro") + ": revisado por la distro, se actualiza con el sistema. La opción más segura.",
        aur: "Arch User Repository: recetas de la comunidad que se compilan o empaquetan en tu equipo con " + (aur || "paru") + ". Muy completo, pero nadie las revisa: mira los votos.",
        flatpak: "Flathub: la app va en su propio entorno aislado (sandbox), con sus librerías. Igual en todas las distros; ocupa algo más.",
        appimage: "Un único archivo que se ejecuta sin instalar. Gear Lever lo integra en el menú y lo actualiza.",
        script: "El instalador oficial del proyecto (un comando de su web).",
        web: "Se abre como app web en una ventana propia del navegador.",
        url: "Descarga manual desde la web del proyecto."
    })
    function hue(key: string): color { return hues[key] ?? "#7A8794"; }
    readonly property var order: family === "arch" ? ["repo", "aur", "flatpak", "appimage", "script", "web", "url"]
                                                   : ["repo", "flatpak", "appimage", "script", "web", "url"]
    readonly property string nativeKey: ({ arch: "pacman", debian: "apt", fedora: "dnf", suse: "zypper" })[family] ?? "pacman"
    readonly property string pmName: ({ arch: "pacman", debian: "apt", fedora: "dnf", suse: "zypper" })[family] ?? "pacman"
    // Texto corto para la interfaz: «Repos → AUR (paru) → Flatpak → AppImage → Web»
    readonly property string orderText: order.filter(k => !["script", "url"].includes(k))
        .map(k => k === "repo" ? "Repos (" + pmName + ")" : k === "aur" ? "AUR" + (aur ? " (" + aur + ")" : "") : labels[k]).join(" → ")

    readonly property var tools: (catalog.tools ?? []).map(t => Object.assign({}, t, {
        star: t.flags.includes("s"), isNew: t.flags.includes("n"), alpha: t.flags.includes("a"), preview: t.flags.includes("p"),
        xw: t.flags.includes("x"), term: t.flags.includes("t"), web: t.flags.includes("w"),
        gnome: t.flags.includes("g"), kde: t.flags.includes("k")
    }))
    function tool(id: string): var { return tools.find(t => t.id === id) ?? null; }

    function names(s): var { return String(s ?? "").split(" ").filter(Boolean); }
    function inSync(pkg): bool { return syncDb === null || names(pkg).every(n => !!syncDb[n]); }

    // Fuentes posibles de una app del catálogo en esta distro, por prioridad: [{ key, label, pkg, repo? }]
    function sources(t): var {
        const p = t?.pkgs ?? {};
        const out = [];
        const add = (key, pkg, extra) => { if (pkg && !out.some(s => s.key === key)) out.push(Object.assign({ key: key, label: labels[key], pkg: pkg }, extra ?? {})); };
        if (family === "arch") {
            if (p.pacman && inSync(p.pacman)) add("repo", p.pacman);
            if (p.aur) { if (syncDb !== null && inSync(p.aur)) add("repo", p.aur); else add("aur", p.aur); }
        } else {
            const n = p[nativeKey] ?? p.pacman;     // si falta, el nombre suele coincidir con el de Arch
            if (n) add("repo", n, family === "fedora" && p.dnfRepo ? { repo: p.dnfRepo } : {});
        }
        add("flatpak", p.flatpak);
        add("appimage", p.appimage);
        add("script", p.script);
        add("web", p.web);
        add("url", p.url);
        return out.sort((a, b) => order.indexOf(a.key) - order.indexOf(b.key));
    }
    function isInst(key: string, pkg: string, t): bool {
        if (key === "repo" || key === "aur" || key === "flatpak") return names(pkg).every(n => !!installed[n]);
        if (key === "script") return !!t?.bin && !!bins[t.bin];
        return false;
    }
    function installedVia(t): var { return sources(t).find(s => isInst(s.key, s.pkg, t)) ?? null; }
    function isToolInstalled(t): bool { return installedVia(t) !== null; }
    // La elegida: la que escogió el usuario, si no por la que ya está instalada, si no la primera
    function source(t): var {
        const all = sources(t);
        const pref = (Settings.get("storeSources", {}) ?? {})[t.id];
        return all.find(s => s.key === pref) ?? all.find(s => isInst(s.key, s.pkg, t)) ?? all[0] ?? null;
    }
    function setSource(id: string, key: string): void {
        const m = Object.assign({}, Settings.get("storeSources", {}) ?? {});
        m[id] = key;
        Settings.set("storeSources", m);
    }
    function updateFor(t): var {
        const s = t?.pkgs ? installedVia(t) : (t?.installed ? t : null);
        if (!s) return null;
        const u = updates[s.key] ?? {};
        const n = names(s.pkg).find(x => u[x] !== undefined);
        return n !== undefined ? { key: s.key, pkg: n, to: u[n] } : null;
    }
    // Compatibilidad: Pkg.isInstalled("paquete1 paquete2")
    function isInstalled(pkg: string): bool { return names(pkg).every(p => !!installed[p]); }

    // ---------- comandos ----------
    readonly property var legacy: ({ "Repos": "repo", "AUR": "aur", "Flathub": "flatpak", "AppImage": "appimage", "Descarga": "url", "Código": "url", "Web app": "web", "Instalador": "script" })
    function norm(t): var {
        if (t?.pkgs) { const s = source(t); return s ? Object.assign({ name: t.name, post: t.post ?? "" }, s) : null; }
        if (t?.key) return t;
        if (t?.src) return { key: legacy[t.src] ?? "repo", pkg: t.src === "Instalador" ? t.installer : (t.url && legacy[t.src] === "url" ? t.url : t.pkg), name: t.name ?? t.pkg };
        return null;
    }
    readonly property bool canParu: syncDb !== null && !!syncDb["paru"]
    // Instalar paru (CachyOS lo trae en sus repos; en Arch se compila paru-bin desde AUR)
    function helperCmds(): var {
        return canParu ? ["sudo pacman -S --needed paru"]
            : ["sudo pacman -S --needed base-devel git", "rm -rf /tmp/hf-paru && git clone https://aur.archlinux.org/paru-bin.git /tmp/hf-paru", "(cd /tmp/hf-paru && makepkg -si)"];
    }
    function flatpakCmds(): var {
        const pm = { arch: "sudo pacman -S --needed flatpak", debian: "sudo apt install flatpak", fedora: "sudo dnf install flatpak", suse: "sudo zypper install flatpak" }[family];
        return root.flatpak ? [] : [pm, "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"];
    }
    function commands(tools, opts): var {
        opts = opts ?? {};
        const items = (tools ?? []).map(t => norm(t)).filter(Boolean);
        const by = key => items.filter(s => s.key === key).reduce((a, s) => a.concat(names(s.pkg)), []);
        const out = [];
        const repo = by("repo"), aurPk = by("aur"), fl = by("flatpak");
        if (opts.snapshot !== false && root.snapper && (repo.length || aurPk.length))
            out.push("sudo snapper -c root create -c important -d 'hyprfrijol: antes de instalar aplicaciones'");
        if (family === "arch") {
            if (aurPk.length) {
                const h = root.aur || "paru";
                if (!root.aur) out.push(...helperCmds());
                out.push(h + " -S --needed " + repo.concat(aurPk).join(" "));
            } else if (repo.length) out.push("sudo pacman -S --needed " + repo.join(" "));
        } else if (repo.length) {
            if (family === "fedora") {
                const extra = [...new Set(items.filter(s => s.key === "repo" && s.repo).map(s => s.repo))];
                extra.forEach(r => out.push(r.startsWith("copr:") ? "sudo dnf copr enable -y " + r.slice(5)
                    : "sudo dnf install -y https://mirrors.rpmfusion.org/" + (r.includes("nonfree") ? "nonfree" : "free") + "/fedora/rpmfusion-"
                      + (r.includes("nonfree") ? "nonfree" : "free") + "-release-$(rpm -E %fedora).noarch.rpm"));
            }
            out.push(({ debian: "sudo apt install ", fedora: "sudo dnf install ", suse: "sudo zypper install " })[family] + repo.join(" "));
        }
        if (fl.length) { out.push(...flatpakCmds()); out.push("flatpak install -y flathub " + fl.join(" ")); }
        items.filter(s => s.key === "appimage").forEach(s => out.push("xdg-open " + s.pkg));
        if (items.some(s => s.key === "appimage") && !root.gearlever && !installed["it.mijorus.gearlever"])
            out.push("# AppImage: descarga el archivo y ábrelo con Gear Lever (Flatpak it.mijorus.gearlever) para integrarlo en el menú");
        items.filter(s => s.key === "script").forEach(s => out.push(s.pkg));
        items.filter(s => s.key === "url").forEach(s => out.push("xdg-open " + s.pkg));
        items.filter(s => s.key === "web").forEach(s => out.push("# Web app: " + s.name + " → Ajustes › Web apps (" + s.pkg + ")"));
        // Pasos tras instalar (catalog.json «post»: activar un servicio…), solo para paquetes
        items.filter(s => s.post && ["repo", "aur", "flatpak"].includes(s.key)).forEach(s => out.push(s.post));
        return out;
    }
    function run(cmds, title): void { const c = cmds.filter(x => !x.startsWith("#")); if (c.length) runInTerminal(c.join(" && "), title); }
    function install(items, title): void { run(commands(items), title || "Instalar aplicaciones"); refreshSoon.restart(); }
    function uninstallCmd(t): string {
        const s = t?.pkgs ? installedVia(t) : t;
        if (!s) return "";
        const n = names(s.pkg).filter(x => installed[x]).join(" ");
        if (s.key === "flatpak") return "flatpak uninstall " + n;
        if (s.key === "repo" || s.key === "aur")
            return ({ arch: "sudo pacman -Rns ", debian: "sudo apt remove ", fedora: "sudo dnf remove ", suse: "sudo zypper remove " })[family] + n;
        return "";
    }
    function uninstall(t): void { const c = uninstallCmd(t); if (c) { runInTerminal(c, "Desinstalar " + (t.name ?? "")); refreshSoon.restart(); } }
    // Actualizar: Arch no admite actualizaciones parciales, así que lo de los repos actualiza todo (hf-updates run)
    function update(t): void {
        const u = updateFor(t);
        if (!u) return;
        if (u.key === "repo") Quickshell.execDetached([Paths.script("hf-updates"), "run"].concat(Settings.get("updatesSnapshot", true) !== false ? ["--snapshot"] : []));
        else if (u.key === "aur") runInTerminal((root.aur || "paru") + " -S " + u.pkg, "Actualizar " + (t.name ?? ""));
        else if (u.key === "flatpak") runInTerminal("flatpak update " + u.pkg, "Actualizar " + (t.name ?? ""));
        refreshSoon.restart();
    }
    // Entrada .desktop de una app instalada (para «Abrir»)
    function entryOf(t): var {
        DesktopEntries.applications.values.length;
        const p = t?.pkgs ?? {};
        const ids = [t?.desktop, p.flatpak, t?.key === "flatpak" ? t.pkg : ""].concat(t?.icon ?? [], names(p.pacman ?? p.aur ?? (t?.key ? t.pkg : "")).slice(0, 1), [t?.id])
            .filter(Boolean);
        for (const id of ids) { const e = DesktopEntries.byId(id); if (e) return e; }
        return t?.name ? DesktopEntries.heuristicLookup(t.name.replace(/ \(.*\)/, "")) : null;
    }
    function launch(t): void {
        const e = entryOf(t);
        if (e) e.execute();
        else if (t?.bin) runInTerminal(t.bin, t.name);
    }

    // Abre la terminal preferida con el comando; al final espera una tecla.
    function runInTerminal(cmd: string, title: string): void {
        const script = "printf '\\033[1m%s\\033[0m\\n\\n' " + JSON.stringify("HyprFrijol · " + (title || "Terminal"))
            + "; set -x; " + cmd + "; set +x; echo; read -n1 -rsp 'Listo. Pulsa una tecla para cerrar…'";
        const t = root.terminal;
        const args = t === "foot" ? ["foot", "-T", title || "HyprFrijol", "bash", "-c", script]
                   : t === "alacritty" ? ["alacritty", "-T", title || "HyprFrijol", "-e", "bash", "-c", script]
                   : t === "ghostty" ? ["ghostty", "-e", "bash", "-c", script]
                   : t === "wezterm" ? ["wezterm", "start", "--", "bash", "-c", script]
                   : t === "konsole" ? ["konsole", "-e", "bash", "-c", script]
                   : [t, "-T", title || "HyprFrijol", "bash", "-c", script];   // kitty
        Quickshell.execDetached(args);
    }

    function refresh(): void { probe.running = true; cachedUpd.running = true; }
    Timer { id: refreshSoon; interval: 20000; repeat: true; property int n: 0; onTriggered: { root.refresh(); if (++n >= 6) { n = 0; stop(); } } }

    // ---------- catálogo ----------
    FileView {
        path: Paths.root + "/config/tools/catalog.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.catalog = JSON.parse(text()); root.checkSync(); } catch (e) { console.warn("[pkg] catalog.json: " + e); } }
    }
    // Qué paquetes del catálogo están en los repos de esta distro (solo Arch: pacman -Slq, sin red)
    function checkSync(): void {
        if (!probed || family !== "arch" || !(catalog.tools ?? []).length) return;
        const all = ["paru", "yay", "flatpak"];
        catalog.tools.forEach(t => { const p = t.pkgs ?? {}; all.push(...names(p.pacman), ...names(p.aur)); });
        sync.command = ["bash", "-c", "pacman -Slq 2>/dev/null | grep -Fx -f <(printf '%s\\n' \"$@\")", "hf-sync"].concat([...new Set(all)]);
        sync.running = true;
    }
    Process {
        id: sync
        stdout: StdioCollector {
            onStreamFinished: { const m = {}; text.split("\n").filter(Boolean).forEach(n => m[n] = true); root.syncDb = m; }
        }
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", ". /etc/os-release; echo \"$ID|$PRETTY_NAME|$ID_LIKE\"; "
            + "for b in paru yay flatpak snapper gearlever claude codex gemini ollama; do command -v $b >/dev/null && echo has:$b; done; "
            + "for t in \"$TERMINAL\" kitty ghostty foot alacritty wezterm konsole; do [ -n \"$t\" ] && command -v \"$t\" >/dev/null && { echo term:$t; break; }; done; "
            + "if command -v pacman >/dev/null; then pacman -Qq; elif command -v dpkg-query >/dev/null; then dpkg-query -W -f='${Package}\\n'; "
            + "elif command -v rpm >/dev/null; then rpm -qa --qf '%{NAME}\\n'; fi | sed 's/^/pkg:/'; "
            + "command -v flatpak >/dev/null && flatpak list --app --columns=application | sed 's/^/pkg:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const f = (l[0] ?? "").split("|");
                root.distro = f[0] ?? ""; root.distroName = f[1] ?? "";
                const like = (f[0] + " " + (f[2] ?? "")).toLowerCase();
                root.family = /arch/.test(like) ? "arch" : /debian|ubuntu/.test(like) ? "debian" : /fedora|rhel/.test(like) ? "fedora" : /suse/.test(like) ? "suse" : "arch";
                const has = b => l.includes("has:" + b);
                root.aur = has("paru") ? "paru" : has("yay") ? "yay" : "";
                root.flatpak = has("flatpak"); root.snapper = has("snapper"); root.gearlever = has("gearlever");
                root.terminal = (l.find(x => x.startsWith("term:")) ?? "term:kitty").slice(5);
                const b = {};
                l.filter(x => x.startsWith("has:")).forEach(x => b[x.slice(4)] = true);
                root.bins = b;
                const inst = {};
                l.filter(x => x.startsWith("pkg:")).forEach(x => inst[x.slice(4)] = true);
                root.installed = inst;
                const first = !root.probed;
                root.probed = true;
                if (first) root.checkSync();
            }
        }
    }
    // Actualizaciones pendientes: el último resultado de hf-updates (no comprueba ni usa la red)
    Process {
        id: cachedUpd
        running: true
        command: [Paths.script("hf-updates"), "cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text || "{}");
                    const m = a => { const o = {}; (a ?? []).forEach(x => o[x.name] = x.to); return o; };
                    root.updates = { repo: m(r.pacman), aur: m(r.aur), flatpak: m(r.flatpak) };
                } catch (e) {}
            }
        }
    }

    // ---------- búsqueda en vivo (repos + AUR + Flathub) ----------
    property string query: ""           // lo último que se pidió
    property string resultsFor: ""      // para qué búsqueda son los resultados
    property var results: []            // [{ id, key, label, pkg, name, desc, version, repo, installed }]
    readonly property bool searching: srch.running || (query !== "" && query !== resultsFor)
    function search(q: string): void {
        q = q.trim();
        query = q;
        if (q.length < 2) { results = []; resultsFor = q; return; }
        if (!srch.running) startSearch();
    }
    function startSearch(): void {
        srch.ran = query;
        srch.command = ["bash", "-c", searchScript, "hf-search", query, family, aur, root.flatpak ? "1" : ""];
        srch.running = true;
    }
    readonly property string searchScript: "export LC_ALL=C; set -f; q=$1; fam=$2; aur=$3\n"
        + "case $fam in\n"
        + " arch) echo @repo; pacman -Ss -- $q 2>/dev/null | head -n 160\n"
        + "   if [ \"$aur\" = paru ]; then echo @aur; timeout 15 paru -Ss --aur --limit 40 --sortby popularity -- $q 2>/dev/null\n"
        + "   elif [ \"$aur\" = yay ]; then echo @aur; timeout 15 yay -Ss --aur --sortby popularity -- $q 2>/dev/null | head -n 80; fi ;;\n"
        + " debian) echo @apt; apt-cache search -- $q 2>/dev/null | head -n 80 ;;\n"
        + " fedora) echo @dnf; timeout 25 dnf -q search -- $q 2>/dev/null | head -n 80 ;;\n"
        + " suse) echo @zypper; timeout 25 zypper -q --no-refresh search -t package -- $q 2>/dev/null | head -n 80 ;;\n"
        + "esac\n"
        + "[ -n \"$4\" ] && { echo @flatpak; timeout 20 flatpak search --columns=application,name,description,version -- \"$q\" 2>/dev/null | head -n 40; }\n"
        + "exit 0"
    Process {
        id: srch
        property string ran: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (srch.ran === root.query) { root.results = root.parseSearch(text, srch.ran); root.resultsFor = srch.ran; }
                else Qt.callLater(root.startSearch);     // llegó otra búsqueda mientras tanto
            }
        }
    }
    function parseSearch(text: string, q: string): var {
        const out = [];
        let sec = "";
        let cur = null;
        const push = r => { if (!/-debug$/.test(r.pkg) && !out.some(o => o.key === r.key && o.pkg === r.pkg)) out.push(r); };
        for (const line of text.split("\n")) {
            if (line.startsWith("@")) { sec = line.slice(1); cur = null; continue; }
            if (!line.trim()) continue;
            if (sec === "repo" || sec === "aur") {             // «repo/nombre 1.2-1 [+12 ~0.3] [installed]» + descripción con sangría
                if (/^\s/.test(line)) { if (cur) cur.desc = line.trim(); continue; }
                const m = line.match(/^(\S+)\/(\S+)\s+(\S+)(.*)$/);
                if (!m) continue;
                const isAur = m[1] === "aur";
                cur = { key: isAur ? "aur" : "repo", pkg: m[2], name: m[2], version: m[3], repo: m[1], desc: "", installed: /\[(installed|instalado)/i.test(m[4]) || !!installed[m[2]] };
                push(cur);
            } else if (sec === "apt") {                         // «nombre - descripción»
                const m = line.match(/^(\S+) - (.*)$/);
                if (m) push({ key: "repo", pkg: m[1], name: m[1], version: "", repo: "apt", desc: m[2], installed: !!installed[m[1]] });
            } else if (sec === "dnf") {                         // «nombre.arch : descripción» (dnf4) o «nombre.arch\tdescripción» (dnf5)
                const m = line.match(/^\s*(\S+)\.(?:x86_64|noarch|aarch64|i686)(?:\s*:\s*|\s+)(.*)$/);
                if (m) push({ key: "repo", pkg: m[1], name: m[1], version: "", repo: "dnf", desc: m[2], installed: !!installed[m[1]] });
            } else if (sec === "zypper") {                      // «S | nombre | resumen | tipo»
                const c = line.split("|").map(x => x.trim());
                if (c.length >= 3 && c[1] && c[1] !== "Name" && !/^-+$/.test(c[1]))
                    push({ key: "repo", pkg: c[1], name: c[1], version: "", repo: "zypper", desc: c[2], installed: !!installed[c[1]] });
            } else if (sec === "flatpak") {                     // id \t nombre \t descripción \t versión
                let c = line.split("\t");
                if (c.length < 2) c = line.split(/\s{2,}/);
                const id = (c[0] ?? "").trim();
                if (!/^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+){2,}$/.test(id)) continue;
                push({ key: "flatpak", pkg: id, name: (c[1] ?? id).trim(), version: (c[3] ?? "").trim(), repo: "flathub", desc: (c[2] ?? "").trim(), installed: !!installed[id] });
            }
        }
        // Relevancia (nombre exacto › empieza › contiene › solo descripción) y luego prioridad de la fuente
        const ql = q.toLowerCase();
        const tier = r => {
            const n = r.name.toLowerCase(), p = r.pkg.toLowerCase().split(".").pop();
            return n === ql || p === ql ? 0 : n.startsWith(ql) || p.startsWith(ql) ? 1 : n.includes(ql) || p.includes(ql) ? 2 : 3;
        };
        return out.map((r, i) => Object.assign(r, { id: "s:" + r.key + ":" + r.pkg, label: labels[r.key], t: tier(r), i: i }))
            .sort((a, b) => a.t - b.t || order.indexOf(a.key) - order.indexOf(b.key) || a.i - b.i)
            .slice(0, 40);
    }
}
