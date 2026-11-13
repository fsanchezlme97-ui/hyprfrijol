# Inactividad (Ajustes › Energía): genera ~/.local/state/hyprfrijol/hypridle.conf y reinicia hypridle si cambia.
#   idleDim (min, 0 = nunca)       bajar el brillo
#   idleLock (min)                 bloquear
#   idleScreenOff (min)            apagar la pantalla
#   idleSuspend (min)              suspender
#   lockOnSuspend (bool, sí)       bloquear antes de suspender (Ajustes › Privacidad)
# Por defecto, los mismos tiempos que illogical-impulse: bloquear 5, pantalla 10, suspender 15.
# No devuelve líneas de Hyprland.
import json, os, pathlib, shlex, subprocess

HOME = pathlib.Path.home()
STATE = HOME / ".local/state/hyprfrijol"
DPMS_OFF = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'"
DPMS_ON = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
# Con alguien dentro por escritorio remoto (hypr-rdp, wayvnc) la pantalla no se apaga: un monitor sin señal se
# desconecta, la salida que se captura desaparece y la conexión se corta; tampoco se suspende. El bloqueo sí se hace.
REMOTE_IN = "ss -tnpH state established 2>/dev/null | grep -qE '\"(hypr-rdp|wayvnc)\"'"

def _min(s, key, default):
    try:
        return max(0, int(s.get(key, default) or 0))
    except (TypeError, ValueError):
        return default

def render(s):
    dim, lock, off, susp = (_min(s, "idleDim", 0), _min(s, "idleLock", 5),
                            _min(s, "idleScreenOff", 10), _min(s, "idleSuspend", 15))
    out = [
        "# Lo genera hf-apply desde Ajustes › Energía. No lo edites: se reescribe.",
        "general {",
        "    lock_cmd = hf-lock",
    ] + (["    before_sleep_cmd = loginctl lock-session"] if s.get("lockOnSuspend", True) is not False else []) + [
        f"    after_sleep_cmd = {DPMS_ON}",
        "    inhibit_sleep = 3",
        "}",
    ]
    def listener(mins, on, resume=None):
        out.extend(["", "listener {", f"    timeout = {mins * 60}", f"    on-timeout = {on}"]
                   + ([f"    on-resume = {resume}"] if resume else []) + ["}"])
    if dim:
        listener(dim, "brightnessctl -s set 30%", "brightnessctl -r")
    if lock:
        listener(lock, "loginctl lock-session")
    if off:
        listener(off, f"{REMOTE_IN} || {DPMS_OFF}", DPMS_ON)
    if susp:
        listener(susp, f"{REMOTE_IN} || systemctl suspend || loginctl suspend")
    return "\n".join(out) + "\n"

def hypr_lua(s, c):
    path = STATE / "hypridle.conf"
    new = render(s)
    try:
        old = path.read_text() if path.exists() else ""
    except Exception:
        old = ""
    if new != old:
        STATE.mkdir(parents=True, exist_ok=True)
        path.write_text(new)
        # Solo dentro de la sesión de hyprfrijol real (no en pruebas anidadas ni desde otra sesión)
        if os.environ.get("HF_SESSION") and not os.environ.get("HF_NESTED") and old:
            subprocess.run(["pkill", "-x", "hypridle"], check=False)
            # Por Hyprland, como autostart.lua: lanzado desde aquí se quedaba en el grupo de quien corre hf-apply (el
            # shell, una terminal) y moría con él; sin bloqueo ni apagado por inactividad hasta volver a entrar
            cmd = "hl.dsp.exec_cmd(" + json.dumps("hypridle -c " + shlex.quote(str(path)), ensure_ascii=False) + ")"
            r = subprocess.run(["hyprctl", "dispatch", cmd], capture_output=True, text=True, check=False)
            if r.stdout.strip() != "ok":
                subprocess.Popen(["setsid", "-f", "hypridle", "-c", str(path)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return []
