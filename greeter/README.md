# Inicio de sesión (greetd)

El login del diseño (cortina en reposo, reloj, usuarios abajo a la izquierda, contraseña/huella/llave, menú de sesión con Hyprland y Modo juego, accesibilidad, variante clara) es **greetd + Quickshell** (`greeter/quickshell/shell.qml`, servicio `Quickshell.Services.Greetd`). Funciona igual en cualquier distro y no depende de GDM ni SDDM.

Es **autónomo**: greetd lo ejecuta como el usuario `greeter`, que no puede leer tu `$HOME` ni el repo, así que todo lo que usa está en `/etc/greetd/quickshell/` (copia de `greeter/quickshell/`: paisaje, paletas de `config/themes/palettes.json` y, si lo sincronizas, tu tema y tu fondo).

## Que el login se vea como tu escritorio

```bash
./install.sh --greeter      # instala y activa el login (ya sincroniza tu tema al final)
hf-greeter-sync             # después de cambiar de paleta, estilo o fondo: vuelve a copiarlos al login
hf-greeter-sync --dry-run   # prepara los archivos en una carpeta temporal y enseña lo que haría
hf-greeter-sync --print     # solo imprime el greeter.json que generaría
```
`hf-greeter-sync` (también `./install.sh --greeter-sync`) copia a `/etc/greetd/quickshell/` tu tema resuelto (`~/.local/state/hyprfrijol/theme.json`: colores, estilo Liquid/Material/Tonal/Aurora, tipografía, reducir movimiento), tu fondo actual (reducido a 2560 px; de un vídeo, un fotograma) y la versión del greeter de esta copia del repo. Pide la contraseña una sola vez (pkexec o sudo).
El login **no se actualiza solo**: los cambios se ven tras volver a sincronizar, la próxima vez que aparezca (al cerrar sesión o reiniciar). La primera vez que lo activas, **reinicia** para pasar de tu gestor anterior a greetd (no reinicies greetd desde tu sesión: la cerraría).

## Probarlo sin instalar nada

```bash
HF_GREETER_PREVIEW=1 qs -p greeter/quickshell                         # cortina → clic → formulario
HF_GREETER_PREVIEW=1 HF_GREETER_OPEN=1 HF_GREETER_PALETTE=claro qs -p greeter/quickshell
HF_GREETER_PREVIEW=1 HF_GREETER_OPEN=1 HF_GREETER_MENU=sesion HF_GREETER_SCENE=lago qs -p greeter/quickshell
hf-greeter-sync --print > /tmp/g.json && HF_GREETER_PREVIEW=1 HF_GREETER_CONFIG=/tmp/g.json qs -p greeter/quickshell   # con tu tema
HF_GREETER_PREVIEW=1 HF_GREETER_ESTILO=flat qs -p greeter/quickshell   # forzar estilo: flat (Material) · aurora
```
En vista previa no se inicia nada: la contraseña `error` simula un fallo y cualquier otra simula el inicio (imprime el comando). Mejor dentro de un Hyprland anidado (`dev/try.sh -k`), porque ocupa toda la pantalla (Esc vuelve a la cortina).

## Fase 1 — tuigreet (texto, muy fiable)

```bash
sudo cp greeter/config.toml /etc/greetd/config.toml
sudo systemctl disable gdm sddm lightdm 2>/dev/null
sudo systemctl enable greetd
```

## Fase 2 — login visual con Quickshell

```bash
sudo install -Dm644 greeter/hyprland-greeter.lua /etc/greetd/hyprland-greeter.lua
sudo mkdir -p /etc/greetd/quickshell
sudo cp greeter/quickshell/{shell.qml,Landscape.qml,palettes.json} /etc/greetd/quickshell/
scripts/hf-greeter-sync     # tu tema y tu fondo (o a mano: un greeter.json con "palette" y "wallpaper")
```
En `/etc/greetd/config.toml` cambia el `command` por la línea comentada de la fase 2 (`start-hyprland -- --config /etc/greetd/hyprland-greeter.lua`).

`greeter.json` admite: `theme` (lo escribe `hf-greeter-sync`; si está, manda sobre `palette`), `defaultUser` (usuario preseleccionado la primera vez), `palette` (cualquiera de `palettes.json`; `claro`/`monoclaro` → variante clara), `scene` (`amanecer`, `lago`, `bosque`, `noche`, `bruma`; si no hay fondo), `wallpaper` (ruta legible por `greeter`) y `gameCommand` (por defecto `gamescope -e -f -- steam -gamepadui -steamos3`).
La distribución de teclado está en `hyprland-greeter.lua` (`kb_layout`).

- **Sesiones**: las de `/usr/share/wayland-sessions` (la de hyprfrijol, `hyprfrijol.desktop`, va primero como «Hyprland»), más «Modo juego (Steam)» si hay `steam` (necesita `gamescope`).
- **Recuerda** el último usuario y la sesión de cada uno en `~greeter/.cache/hf-greeter.json`.
- **Avatar**: `/var/lib/AccountsService/icons/<usuario>` si existe.
- **Huella**: `fprintd` + `auth sufficient pam_fprintd.so` en `/etc/pam.d/greetd` (aparece «Huella»).
- **Llave de seguridad**: `pam_u2f` (aparece «Llave»).
- **Accesibilidad**: lector de pantalla (`orca`), teclado en pantalla (`wvkbd-mobintl`/`squeekboard`/`onboard`), alto contraste y texto grande.

> Ojo: prueba siempre en otra TTY (Ctrl+Alt+F3) antes de reiniciar, por si el greeter falla.
