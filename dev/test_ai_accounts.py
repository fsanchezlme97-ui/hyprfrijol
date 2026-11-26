#!/usr/bin/env python3
"""Pruebas de «hf-ai account» contra un OpenCode de mentira: inicio de sesión, cancelación, cierre y que las cuentas
nunca se usen sin elegirlas. No toca tu OpenCode ni abre el navegador."""
import http.server
import json
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOG = []                          # (método, ruta, cuerpo)
STATE = {"status": ["pending", "complete"], "url": "https://ejemplo.invalid/entrar", "connections": {}, "missing": False}
MODELS = [{"providerID": "opencode", "id": "gratis", "name": "Gratis", "limit": {"context": 100000}, "cost": [{"input": 0, "output": 0}], "time": {"released": 1}},
          {"providerID": "openai", "id": "viejo", "name": "Viejo", "limit": {"context": 100000}, "cost": [{"input": 1, "output": 1}], "time": {"released": 1}},
          {"providerID": "openai", "id": "nuevo", "name": "Nuevo", "limit": {"context": 100000}, "cost": [{"input": 1, "output": 1}], "time": {"released": 9}},
          {"providerID": "mio", "id": "propio", "name": "Propio", "limit": {"context": 100000}, "cost": [{"input": 1, "output": 1}], "time": {"released": 1}}]


class Fake(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, data=None):
        raw = b"" if data is None else json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def handle_any(self, method):
        n = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(n)) if n else None
        LOG.append((method, self.path, body))
        parts = self.path.strip("/").split("/")
        if self.path == "/api/model":
            return self.reply(200, {"data": MODELS})
        if STATE["missing"]:
            return self.reply(404, {"_tag": "IntegrationNotFoundError", "message": "no"})
        if parts[:2] == ["api", "integration"] and len(parts) == 3:
            methods = [{"type": "oauth", "id": {"openai": "chatgpt-token-sharing", "poe": "browser"}.get(parts[2], "device")}]
            return self.reply(200, {"data": {"id": parts[2], "name": parts[2], "methods": methods, "connections": STATE["connections"].get(parts[2], [])}})
        if parts[3:5] == ["connect", "oauth"] and method == "POST":
            return self.reply(200, {"data": {"attemptID": "con_1", "url": STATE["url"], "instructions": "Enter code: AB12-CD345", "mode": "auto"}})
        if parts[3:5] == ["connect", "oauth"] and method == "GET":
            status = STATE["status"].pop(0) if len(STATE["status"]) > 1 else STATE["status"][0]
            return self.reply(200, {"data": {"status": status, "message": "rechazado" if status == "failed" else ""}})
        if method == "DELETE":
            return self.reply(204)
        self.reply(404, {"message": "ruta desconocida"})

    def do_GET(self):
        self.handle_any("GET")

    def do_POST(self):
        self.handle_any("POST")

    def do_DELETE(self):
        self.handle_any("DELETE")


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fake)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="hf-cuentas-"))
    try:
        (tmp / ".local/state/opencode").mkdir(parents=True)
        (tmp / ".local/state/opencode/service.json").write_text(json.dumps({"url": f"http://127.0.0.1:{server.server_port}", "password": "p"}))
        tools = tmp / "bin"
        tools.mkdir()
        (tools / "opencode").write_text("#!/bin/sh\nexit 1\n")
        (tools / "xdg-open").write_text(f'#!/bin/sh\nprintf "%s\\n" "$1" >> "{tmp}/abierto"\n')
        for f in tools.iterdir():
            f.chmod(0o755)
        env = {"HOME": str(tmp), "PATH": f"{tools}:/usr/bin", "HF_ROOT": str(ROOT)}

        def run(*args):
            r = subprocess.run([sys.executable, str(ROOT / "scripts/hf-ai"), "account", *args], env=env, capture_output=True, text=True, timeout=40)
            assert r.returncode == 0, r.stderr
            return [json.loads(line) for line in r.stdout.splitlines()]

        # lista: lo conectado, el modelo más nuevo de cada cuenta y nada de credenciales
        STATE["connections"] = {"openai": [{"type": "credential", "id": "cred_1", "label": "yo", "method": "oauth"}]}
        accounts = {a["id"]: a for a in run("list")[0]["accounts"]}
        assert list(accounts) == ["openai", "github-copilot", "xai", "poe"] and "google" not in accounts
        assert accounts["openai"] == dict(accounts["openai"], connected=True, removable=True, label="yo", model="openai/nuevo", available=True), accounts["openai"]
        assert accounts["poe"]["connected"] is False and accounts["poe"]["model"] == ""

        # inicio de sesión: enlace y código, se abre el navegador y termina
        LOG.clear()
        lines = run("login", "github-copilot")
        assert [x["state"] for x in lines] == ["authorize", "done"] and lines[0]["code"] == "AB12-CD345", lines
        for _ in range(50):
            if (tmp / "abierto").exists():
                break
            time.sleep(0.1)
        assert (tmp / "abierto").read_text().strip() == STATE["url"]
        start = next(b for m, p, b in LOG if m == "POST")
        assert start == {"methodID": "device", "answer": {"deploymentType": "github.com"}}, start
        assert not [1 for m, p, b in LOG if m == "DELETE"], "lo terminado no se cancela"

        # rechazado: error y se cancela el intento
        LOG.clear()
        STATE["status"] = ["failed"]
        assert run("login", "openai")[-1] == {"state": "error", "message": "rechazado"}
        assert ("DELETE", "/api/integration/openai/connect/oauth/con_1", None) in LOG

        # un enlace que no es https no se abre
        (tmp / "abierto").unlink()
        LOG.clear()
        STATE["url"] = "file:///etc/passwd"
        assert run("login", "openai")[-1]["state"] == "error"
        time.sleep(0.5)
        assert not (tmp / "abierto").exists() and [m for m, p, b in LOG if m == "DELETE"]

        # cancelar (cerrar el proceso) cancela en OpenCode
        LOG.clear()
        STATE.update(url="https://ejemplo.invalid/entrar", status=["pending"])
        p = subprocess.Popen([sys.executable, str(ROOT / "scripts/hf-ai"), "account", "login", "xai"], env=env, stdout=subprocess.PIPE, text=True)
        assert json.loads(p.stdout.readline())["state"] == "authorize"
        time.sleep(0.3)
        p.send_signal(signal.SIGTERM)
        assert json.loads(p.stdout.readline())["state"] == "cancelled"
        p.wait(10)
        assert ("DELETE", "/api/integration/xai/connect/oauth/con_1", None) in LOG, LOG

        # cerrar sesión borra esa credencial y nunca se leen las credenciales (llevan los secretos)
        LOG.clear()
        assert run("logout", "openai")[0]["ok"] and ("DELETE", "/api/credential/cred_1", None) in LOG
        assert run("logout", "google")[0]["ok"] is False
        assert not [p for m, p, b in LOG if m == "GET" and p.startswith("/api/credential")]
        assert run("login", "google")[-1]["state"] == "error"

        # un OpenCode sin esas rutas: se dice, sin romperse
        STATE["missing"] = True
        assert "actualízalo" in run("list")[0]["error"]
        STATE["missing"] = False

        # las cuentas solo se usan si se eligen: ni «Automático», ni el respaldo, ni «el último que respondió»
        code = (
            "import importlib.machinery, importlib.util, json, sys\n"
            f"l = importlib.machinery.SourceFileLoader('ai', {str(ROOT / 'scripts/hf-ai')!r}); s = importlib.util.spec_from_loader('ai', l)\n"
            "ai = importlib.util.module_from_spec(s); sys.dont_write_bytecode = True; l.exec_module(ai)\n"
            "ai.opencode_remember('openai/nuevo')\n"
            "print(json.dumps({'auto': ai.opencode_auto(), 'solo': ai.opencode_candidates({}), 'elegido': ai.opencode_candidates({'aiModel': 'openai/nuevo'}),\n"
            "  'fijado': ai.opencode_candidates({'aiModel': 'openai/nuevo', '_pinned': True}), 'ultimo': ai.opencode_last(),\n"
            "  'sin_gratis': ai.opencode_auto([{'id': 'openai/nuevo'}])}))\n")
        r = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True, timeout=40)
        assert r.returncode == 0, r.stderr
        got = json.loads(r.stdout)
        assert got["ultimo"] == "" and not got["auto"].startswith("openai/") and not got["sin_gratis"].startswith("openai/"), got
        assert not [m for m in got["solo"] if m.startswith("openai/")] and "mio/propio" in got["solo"], got
        assert got["elegido"][0] == "openai/nuevo" and got["elegido"].count("openai/nuevo") == 1 and "openai/viejo" not in got["elegido"], got
        assert got["fijado"] == ["openai/nuevo"], got

        # lo mismo con el modelo de una cuenta puesto por defecto en la configuración de OpenCode: si conectaste
        # ChatGPT en OpenCode y lo dejaste ahí, HyprFrijol no lo usa sin avisar (gastaría tu plan)
        (tmp / ".config/opencode").mkdir(parents=True, exist_ok=True)
        (tmp / ".config/opencode/opencode.json").write_text(json.dumps({"model": "openai/nuevo"}))
        code = (
            "import importlib.machinery, importlib.util, json, sys\n"
            f"l = importlib.machinery.SourceFileLoader('ai', {str(ROOT / 'scripts/hf-ai')!r}); s = importlib.util.spec_from_loader('ai', l)\n"
            "ai = importlib.util.module_from_spec(s); sys.dont_write_bytecode = True; l.exec_module(ai)\n"
            "print(json.dumps({'configurado': ai.opencode_configured(), 'auto': ai.opencode_auto(),\n"
            "  'solo': ai.opencode_candidates({}), 'elegido': ai.opencode_candidates({'aiModel': 'openai/nuevo'})}))\n")
        r = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True, timeout=40)
        assert r.returncode == 0, r.stderr
        got = json.loads(r.stdout)
        assert got["configurado"] == "", got
        assert not got["auto"].startswith("openai/"), got
        assert not [m for m in got["solo"] if m.startswith("openai/")], got
        assert got["elegido"][0] == "openai/nuevo", got     # elegido a mano, sí se usa
    finally:
        server.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
