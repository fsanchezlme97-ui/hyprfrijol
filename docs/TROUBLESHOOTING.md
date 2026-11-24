# Solución de problemas de HyprFrijol

Si algo no funciona, empieza por estos tres comandos:

```bash
hf-doctor                 # informe de diagnóstico
hf-deps status            # qué dependencias faltan
./dev/lint.sh && ./dev/check.sh   # validar que no hay errores en el repo
```

## No arranca la sesión

### Pantalla negra tras seleccionar HyprFrijol en el gestor de inicio

1. Comprueba que Hyprland y Quickshell están instalados:
   ```bash
   Hyprland --version
   qs --version
   ```
2. Prueba el modo anidado desde otra sesión:
   ```bash
   cd ~/hyprfrijol
   ./scripts/hf-session --nested
   ```
3. Revisa los logs:
   ```bash
   cat ~/.local/state/hyprfrijol/hyprland.log
   ```

### Login roto tras habilitar el greeter

HyprFrijol deja `tuigreet` como respaldo. En la pantalla de login:

- Busca una opción para cambiar de sesión o de greeter.
- Si no puedes entrar, cambia a otra TTY (`Ctrl + Alt + F3`), haz login y ejecuta:
  ```bash
  ./install.sh --greeter-off
  ```

## El shell no aparece (sin barra ni paneles)

1. Reinicia el shell:
   ```bash
   ./scripts/hf-shell restart
   ```
2. Si sigue sin aparecer, mira errores de Quickshell:
   ```bash
   qs -p ~/hyprfrijol/config/quickshell log
   ```
3. Comprueba que `settings.json` no esté corrupto:
   ```bash
   python3 -m json.tool ~/.config/hyprfrijol/settings.json
   ```

## Las ventanas flotantes desaparecen o se minimizan solas

Desde la versión reciente se eliminó el modo "Ocultas" de `floatOrder`. Si una ventana se oculta al perder el foco, comprueba el ajuste:

```bash
hf-ai get floatOrder   # no implementado; abre Ajustes › Escritorio
```

Ajustes › Escritorio y gestos › Ventanas flotantes › Prioridad debe estar en `Encima` o `Espacio oculto`.

## El asistente no responde

1. Prueba la conexión:
   ```bash
   ./scripts/hf-ai test
   ```
2. Si usas Ollama, asegúrate de que el modelo está cargado:
   ```bash
   ollama list
   ollama run gemma4:e4b
   ```
3. Si usas OpenCode o Claude Code, comprueba que están en `PATH`.

## NVIDIA: tartamudeo o pantalla negra

- Añade al kernel: `nvidia_drm.modeset=1`.
- Usa el modo de rendimiento de HyprFrijol si tu tarjeta es dedicada.
- Revisa que el driver NVIDIA sea reciente (proprietary).

## Nouveau y avisos de `gst-plugin-scan`

Estos avisos no tienen arreglo desde HyprFrijol:

- `eglCreateSyncKHR … EGL_BAD_ATTRIBUTE` con aquamarine en gráficas antiguas.
- TRAP de nouveau al regenerar la caché de `gst-plugin-scan`.

No afectan al funcionamiento general. Si molestan mucho, usa el driver propietario de NVIDIA.

## Ajustes no se aplican

1. Ejecuta `hf-apply` manualmente:
   ```bash
   ./scripts/hf-apply
   ```
2. Si falla, comprueba `settings.json`:
   ```bash
   python3 -m json.tool ~/.config/hyprfrijol/settings.json
   ```
3. Restaura ajustes buenos:
   ```bash
   ./scripts/hf-safe restore
   ```

## Problemas después de una actualización

1. Actualiza HyprFrijol:
   ```bash
   ./scripts/hf-update
   ```
2. Si algo se rompió, vuelve a la versión anterior:
   ```bash
   ./scripts/hf-update --rollback
   ```
3. Restaura un punto de snapper si lo tienes configurado:
   ```bash
   sudo snapper rollback
   ```

## Cómo pedir ayuda

1. Ejecuta:
   ```bash
   ./scripts/hf-doctor --copy
   ```
2. Pega el resultado en el issue o mensaje, junto con:
   - Distro y versión.
   - Versión de Hyprland y Quickshell.
   - Qué has intentado.
   - Captura de pantalla si aplica.
