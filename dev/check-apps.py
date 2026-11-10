#!/usr/bin/env python3
"""dev/check-apps.py — comprueba en la web cada fuente de install/apps.json (necesita red).

  dev/check-apps.py            tabla app × fuente: ok / FALTA
  dev/check-apps.py --json     lo mismo en JSON
  dev/check-apps.py --stamp    si todo está bien, pone la fecha de hoy en «verified»

Fuentes: archlinux.org (repos oficiales) y AUR RPC · mdapi de Fedora 44 · madison de Debian forky ·
Launchpad (Ubuntu 26.04, amd64) · listado de download.opensuse.org (Tumbleweed) · Flathub API · índice OCI del remoto ArtCraft ·
releases de GitHub (AppImage / .flatpak) · repositorios del fabricante (Google, Microsoft).
"""
import datetime, json, pathlib, re, sys, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAT = ROOT / "install/apps.json"
UA = {"User-Agent": "hyprfrijol-catalog-check/1.0 (+https://github.com/fsanchezlme97-ui/hyprfrijol)"}
_cache = {}


def get(url, as_json=True, method="GET"):
    if (url, method) in _cache:
        return _cache[(url, method)]
    req = urllib.request.Request(url, headers=UA, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            data = r.read() if method == "GET" else b""
            out = (json.loads(data) if as_json else data.decode("utf-8", "replace")) if method == "GET" else r.status
    except urllib.error.HTTPError as e:
        out = None if method == "GET" else e.code
    except Exception:
        out = None if method == "GET" else 0
    _cache[(url, method)] = out
    return out


def arch_ok(name):
    if name.startswith("aur:"):
        r = get("https://aur.archlinux.org/rpc/v5/info?arg[]=" + urllib.parse.quote(name[4:]))
        return bool(r and r.get("resultcount"))
    r = get("https://archlinux.org/packages/search/json/?name=" + urllib.parse.quote(name))
    return bool(r and r.get("results"))


def fedora_ok(name):
    r = get("https://mdapi.fedoraproject.org/f44/pkg/" + urllib.parse.quote(name))
    return bool(r and r.get("basename"))


def debian_ok(name):
    r = get("https://api.ftp-master.debian.org/madison?f=json&s=forky&package=" + urllib.parse.quote(name))
    try:
        return bool(r and r[0].get(name))
    except Exception:
        return False


def ubuntu_ok(name):
    """Launchpad: binario publicado en Ubuntu 26.04 (resolute) para amd64."""
    r = get("https://api.launchpad.net/1.0/ubuntu/+archive/primary?ws.op=getPublishedBinaries&exact_match=true&status=Published"
            "&ws.size=1&distro_arch_series=https://api.launchpad.net/1.0/ubuntu/resolute/amd64&binary_name=" + urllib.parse.quote(name))
    return bool(r and r.get("total_size"))


_suse = None
def suse_ok(name):
    """Listado de download.opensuse.org (Tumbleweed oss, x86_64 + noarch). python3-x = python313-x / python314-x."""
    global _suse
    if _suse is None:
        _suse = set()
        for arch in ("x86_64", "noarch"):
            for f in (get(f"https://download.opensuse.org/tumbleweed/repo/oss/{arch}/?jsontable") or {}).get("data", []):
                m = re.match(r"(.+)-[^-]+-[^-]+\.(x86_64|noarch)\.rpm$", f.get("name", ""))
                if m: _suse.add(m.group(1))
    if name in _suse:
        return True
    return name.startswith("python3-") and any(re.fullmatch(r"python3\d+-" + re.escape(name[8:]), n) for n in _suse)


def flatpak_ok(app_id, remote):
    if remote == "artcraft-oci":
        idx = get("https://getartcraft.com/index/static?label:org.flatpak.ref:exists=1&architecture=amd64")
        return f"app/{app_id}/x86_64/stable" in json.dumps(idx or {})
    return get("https://flathub.org/api/v2/appstream/" + app_id) is not None


def github_ok(spec):
    rels = get(f"https://api.github.com/repos/{spec['repo']}/releases?per_page=20") or []
    rx = re.compile(spec["asset"])
    for r in rels:
        if r.get("prerelease") and not spec.get("pre"):
            continue
        if any(rx.search(a["name"]) for a in r.get("assets", [])):
            return r["tag_name"]
    return False


def url_ok(u):
    return get(u, method="HEAD") in (200, 301, 302)


def check():
    cat = json.loads(CAT.read_text())
    rows = []
    for a in cat["apps"]:
        s = a.get("src", {})
        res = {}
        for fam in ("arch", "fedora", "debian", "ubuntu", "suse"):
            v = s.get(fam)
            if not v or v == "-":
                continue
            ok = True
            for n in v.split():
                if fam == "arch": good = arch_ok(n)
                elif fam == "fedora": good = fedora_ok(n)
                elif fam == "debian": good = debian_ok(n)
                elif fam == "ubuntu": good = ubuntu_ok(n)
                else: good = suse_ok(n)
                ok = ok and good
                if not good: res.setdefault("missing", []).append(f"{fam}:{n}")
            res[fam] = ok
        if s.get("flatpak"):
            res["flatpak"] = flatpak_ok(s["flatpak"], s.get("flatpakRemote", "flathub"))
            if not res["flatpak"]: res.setdefault("missing", []).append("flatpak:" + s["flatpak"])
        for k in ("appimage", "flatpakBundle"):
            if s.get(k):
                tag = github_ok(s[k])
                res[k] = tag or False
                if not tag: res.setdefault("missing", []).append(k)
        if s.get("build"):
            res["build"] = url_ok(s["build"]["repo"].removesuffix(".git"))
        if s.get("vendor"):
            res["vendor"] = all(url_ok(u) for cmd in sum(cat["vendors"][s["vendor"]]["setup"].values(), [])
                                for u in re.findall(r"https://[^\s'\\]+", cmd) if "/keys/" in u or "signing_key" in u)
        rows.append((a["id"], res))
    return cat, rows


def main():
    cat, rows = check()
    bad = [r for r in rows if r[1].get("missing") or False in r[1].values()]
    if "--json" in sys.argv:
        print(json.dumps({k: v for k, v in rows}, ensure_ascii=False, indent=1))
    else:
        for i, r in rows:
            print(f"{i:13} " + "  ".join(f"{k}={'ok' if v is True else v if v else 'FALTA'}" for k, v in r.items() if k != "missing")
                  + (f"   ✗ {' '.join(r['missing'])}" if r.get("missing") else ""))
        print(f"\n{len(rows) - len(bad)}/{len(rows)} apps con todas sus fuentes comprobadas")
    if "--stamp" in sys.argv and not bad:
        txt = CAT.read_text()
        CAT.write_text(re.sub(r'"verified": "[^"]*"', f'"verified": "{datetime.date.today().isoformat()}"', txt, count=1))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
