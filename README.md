# jc-hyprland-dotfiles

Dotfiles modulares de Hyprland, diseñados para ser **agnósticos a la distribución**, al hardware y al número de monitores.

## Principios

- Distro agnostic: Arch, Garuda y openSUSE mediante adaptadores.
- Hardware agnostic: los monitores/GPU/host viven fuera del repo.
- Multi-monitor aware: perfiles de barra principal y secundaria.
- Theme based: `odyssey-glass` es el primer tema.
- Update safe: una única integración pequeña con la configuración existente.
- Reversible: backup antes de modificar archivos del usuario.
- Git managed: el repo es la fuente de verdad.

## Estado

Base inicial orientada a Hyprland 0.54.x/Hyprlang. La estructura deja espacio para una futura capa Lua cuando Hyprland 0.55+ sea el objetivo.

## Estructura

```text
config/      componentes agnósticos (Hyprland, Waybar, Wofi, SwayNC, Hyprlock, Foot)
themes/      paletas y assets
profiles/    perfiles de uso (desktop, futuro laptop/minimal)
distros/     adaptadores de instalación/integración por distro
hosts/       ejemplos únicamente; datos reales se guardan fuera del repo
scripts/     instalación, backup, doctor y runtime
docs/        arquitectura y documentación
```

## Instalación segura

Primero inspecciona:

```bash
./install.sh --dry-run
```

Luego instala sólo el namespace del proyecto:

```bash
./install.sh
```

Para integrar Hyprland explícitamente:

```bash
./install.sh --apply-hyprland
```

La configuración local se crea en:

```text
~/.config/jc-hyprland-dotfiles/local/
```

Nunca se versiona dentro del repositorio.

## Tema inicial

`themes/odyssey-glass/` contiene la paleta compartida por Waybar, Wofi, Hyprlock, SwayNC y terminal.
