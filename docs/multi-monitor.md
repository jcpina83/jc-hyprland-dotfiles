# Multi-monitor

El runtime usa roles, no conectores hardcodeados:

- `MAIN_OUTPUT`: monitor principal.
- `SECONDARY_OUTPUT`: monitor auxiliar.

Los valores se definen en `~/.config/jc-hyprland-dotfiles/local/host.env`.

Ejemplo:

```bash
MAIN_OUTPUT=DP-3
SECONDARY_OUTPUT=DP-1
```

Waybar se renderiza desde plantillas usando esos roles. Los seriales/EDID no se publican.
