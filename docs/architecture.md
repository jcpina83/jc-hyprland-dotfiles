# Arquitectura

```text
jc-hyprland-dotfiles
        |
        +-- common config ---------+
        |                          |
        +-- theme -----------------+----> ~/.config/jc-hyprland-dotfiles/repo
        |                          |
        +-- profile ---------------+
        |
        +-- distro adapter (install-time only)
        |
        +-- local host config ----------> ~/.config/jc-hyprland-dotfiles/local
```

## Separación de responsabilidades

1. `config/`: no debe contener nombres de distribución ni seriales/puertos de hardware.
2. `themes/`: sólo presentación, colores y assets.
3. `profiles/`: decide qué componentes/módulos se activan para un tipo de estación.
4. `distros/`: sólo instalación de paquetes y ajustes propios de la distribución.
5. `hosts/example/`: plantillas documentales. La configuración real vive fuera del repo.

## Compatibilidad Hyprland

La rama inicial usa Hyprlang para Hyprland 0.54.x. La configuración se divide mediante `source =` para mantener módulos pequeños y reemplazables.

## Generaciones de configuración de Hyprland

```text
config/hypr/
├── hyprlang/   # implementación activa para 0.54.x
└── lua/        # frontera reservada para 0.55+
```

El tema, los perfiles, los adaptadores de distro y la configuración local de host no dependen del lenguaje de configuración de Hyprland.
