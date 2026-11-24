# Migrar a HyprFrijol
 
 HyprFrijol se ejecuta como una sesión aparte, así que puedes probarlo sin romper tu escritorio actual.
 
 ## Desde hypr-liquid (nombre anterior)
 
 ```bash
 ./install.sh --migrate
 # o, para ver qué haría antes:
 scripts/hf-migrate --dry-run
 ```
 
 Esto:
 
 - Mueve `~/.config/hypr-liquid`, `~/.local/state/hypr-liquid`, `~/.local/share/hypr-liquid` y `~/.cache/hypr-liquid` a `…/hyprfrijol`.
 - Deja enlaces simbólicos desde los nombres antiguos.
 - Renombra la carpeta del repo si se llamaba `hypr-liquid`.
 - Crea enlaces `~/.local/bin/hl-*` que apuntan a los nuevos `hf-*`.
 - Te dice los pasos que necesitan `sudo` (entrada de sesión, greetd, logind).
 
 Las variables de entorno `HL_*` siguen valiendo.
 
 ## Desde Omarchy
 
 Omarchy y HyprFrijol comparten Hyprland y Quickshell, pero son proyectos distintos.
 
 ### Ajustes
 
 - HyprFrijol no lee `~/.config/omarchy/`. Copia los valores que quieras a `~/.config/hyprfrijol/settings.json`.
 - Los temas `colors.toml` de Omarchy se pueden importar con `hf-plugin theme`.
 - Los plugins de Omarchy se pueden añadir con `hf-plugin add`.
 
 ### Apps predeterminadas
 
 HyprFrijol prioriza apps KDE/Qt por defecto (Dolphin, Kate, Falkon, Okular…). Omarchy usa otras elecciones. Revisa:
 
 ```bash
 hf-defaults list
 ```
 
 ### Atajos
 
 Omarchy usa `Super + Espacio` para su menú y `Super + K` para buscar atajos. HyprFrijol usa `Super + Espacio` para Spotlight y `Super + /` para la chuleta. Revisa [`docs/BINDS.md`](BINDS.md).
 
 ### Plugins
 
 Los plugins de Omarchy funcionan parcialmente. Lee [`docs/PLUGINS-OMARCHY.md`](PLUGINS-OMARCHY.md) para saber qué se soporta y qué no.
 
 ## Desde otro rice de Hyprland
 
 1. Haz una copia de tu configuración actual:
    ```bash
    cp -r ~/.config/hypr ~/.config/hypr.bak
    ```
 2. Instala HyprFrijol sin tocar tus configs:
    ```bash
    git clone https://github.com/fsanchezlme97-ui/hyprfrijol ~/hyprfrijol
    cd ~/hyprfrijol
    ./install.sh --no-deps --no-system --no-session
    ```
 3. Prueba en modo anidado:
    ```bash
    hf-session --nested
    ```
 4. Si te gusta, cierra tu sesión actual y elige «Hyprland (HyprFrijol)» en el gestor de inicio.
 
 ## Desde GNOME o KDE
 
 HyprFrijol no reemplaza tu sesión de GNOME/KDE. Al instalarlo se añade una entrada de sesión adicional. Puedes seguir usando GNOME/KDE cuando quieras.
 
 Si vienes de KDE, muchas apps predeterminadas ya te resultarán familiares (Dolphin, Kate, Konsole, Okular…).
 
 ## Desde Windows o macOS
 
 HyprFrijol no intenta imitar Windows ni macOS. Es un escritorio tiling con barra propia. Antes de migrar:
 
 1. Prueba `hf-session --nested` dentro de tu sesión actual.
 2. Lee [`docs/BINDS.md`](BINDS.md) para ver los atajos principales.
 3. Configura el asistente (`Super + A`) si quieres ayuda para personalizar.
 
 ## Notas generales
 
 - HyprFrijol **nunca toca** `~/.config/hypr`, `~/.config/quickshell` ni `~/.config/matugen` de tu usuario. Tus configs anteriores siguen ahí.
 - Si algo falla, usa `hf-doctor` y revisa [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
