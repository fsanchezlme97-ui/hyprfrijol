# Apps por defecto elegidas en Bienvenida / Ajustes: gestor de archivos (Super + E) y terminal (Super + Enter).
# Si la app elegida no está instalada no se fija nada y env.lua usa la primera instalada (Nautilus primero).
import json, shutil
FM = {"dolphin": "dolphin", "nautilus": "nautilus", "thunar": "thunar", "nemo": "nemo", "yazi": "kitty -e yazi", "pcmanfm": "pcmanfm-qt"}

def _installed(cmd):
    words = cmd.split()
    if not words:
        return False
    if words[0] in ("gtk-launch", "kitty") and len(words) > 1:   # «gtk-launch app» / «kitty -e yazi»
        return bool(shutil.which(words[0])) and (words[0] == "gtk-launch" or bool(shutil.which(words[-1])))
    return bool(shutil.which(words[0]))

def hypr_lua(s, c):
    out = []
    fm = s.get("fileManager")
    if fm:
        cmd = FM.get(fm, fm)
        if _installed(cmd):
            out.append("HF.files = " + json.dumps(cmd))
    term = s.get("terminal")
    if term:
        out.append("HF.terminal = " + json.dumps(term))
    return out
