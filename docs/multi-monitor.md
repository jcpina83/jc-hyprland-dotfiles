# Multi-monitor

El soporte multi-monitor de `jc-hyprland-dotfiles` está diseñado alrededor de
**roles lógicos**, discovery dinámico, geometría lógica y estado machine-local.

El objetivo es evitar que temas, Waybar, Quickshell o scripts compartidos
dependan de conectores, seriales o modelos físicos específicos.

---

# Roles y hardware

El runtime usa roles:

```text
MAIN_OUTPUT
SECONDARY_OUTPUT
```

La asociación con conectores físicos vive en:

```text
~/.config/jc-hyprland-dotfiles/local/host.env
```

Ejemplo ilustrativo:

```ini
MAIN_OUTPUT=DP-3
SECONDARY_OUTPUT=DP-1

MAIN_WORKSPACES=1,2,3,4,5
SECONDARY_WORKSPACES=6,7,8,9,10
```

Cada host mantiene sus propios valores.

Los seriales/descriptores usados para identidad estable del hardware permanecen
en `local/monitors.lua`, fuera de Git.

---

# Fuentes de estado

Hay cuatro estados deliberadamente distintos:

```text
Observed
   ↓
Draft
   ↓
Applied Runtime
   ↓
Persistent
```

## Observed

Lo que Hyprland está utilizando ahora.

Fuentes:

```text
Quickshell.Hyprland
hyprctl -j monitors all
```

Normalizado por:

```text
MonitorService.qml
```

Incluye:

```text
output
description
make
model
serial              runtime only
width
height
refreshRate
x
y
scale
transform
focused
disabled
activeWorkspace
availableModes
```

## Draft

Lo que el usuario está editando sin modificar todavía el compositor.

Responsable:

```text
DisplayDraftStore.qml
```

## Applied Runtime

Estado enviado a Hyprland y confirmado con `Keep`.

Responsable:

```text
MonitorApplyService.qml
      ↓
jc-displayctl
```

No implica persistencia.

## Persistent

Estado que debe sobrevivir a reload/logout/reboot.

Fuente:

```text
~/.config/jc-hyprland-dotfiles/local/monitors.lua
```

Writer:

```text
jc-displaycfg
```

---

# Estado persistente

La configuración física real del host permanece fuera de Git:

```text
~/.config/jc-hyprland-dotfiles/local/
├── host.env
├── monitors.lua
├── backups/
│   └── displays/
└── wallpaper.env
```

## `host.env`

Define roles y workspace ownership.

## `monitors.lua`

Es la única fuente persistente de displays.

Ejemplo conceptual:

```lua
hl.monitor({
    output = "desc:<monitor-description>",
    mode = "3440x1440@120.00000",
    position = "328x0",
    scale = 1,
    transform = 0,
    disabled = false,
    vrr = 2,
})
```

Puede conservar propiedades estáticas adicionales:

```lua
bitdepth = 10,
cm = "srgb",
```

y reglas machine-local:

```lua
hl.workspace_rule({
    workspace = "6",
    monitor = "desc:<monitor-description>",
    persistent = true,
})
```

El writer de persistencia modifica únicamente el estado de los bloques de
monitor que posee y preserva el resto del Lua.

---

# Identidad estable del monitor

El conector (`DP-1`, `DP-3`, etc.) es útil en runtime pero puede cambiar por:

- GPU,
- cableado,
- docking,
- orden de enumeración,
- hardware distinto.

Cuando existe una descripción estable, el estado persistente puede utilizar:

```text
desc:<description>
```

Los descriptores reales del host no deben publicarse en documentación o archivos
versionados.

---

# Geometría de Hyprland

Hyprland posiciona monitores en un espacio lógico 2D.

```text
(x, y)
  │
  ▼
┌───────────────────┐
│      monitor      │
│                   │
│ logical W × H     │
└───────────────────┘
```

Para una pantalla sin rotación:

```text
logicalWidth  = physicalWidth  / scale
logicalHeight = physicalHeight / scale
```

Para transform 90°/270°, los ejes lógicos se intercambian.

Las posiciones pueden ser negativas.

---

# Topología proyectada

`DisplayLayoutEditor.qml` representa el **draft**, no solamente el estado
observado.

La geometría proyectada se calcula a partir de:

```text
draft mode
draft scale
draft transform
draft position
draft enabled
```

Esto permite detectar conflictos antes de enviar cambios al compositor.

Reglas:

```text
✓ touching edges permitido
✓ overlap bloqueado
✓ posiciones negativas permitidas
✓ monitor disabled removido de la topología proyectada
```

---

# Editor visual

El editor permite:

- drag de monitores,
- snap de bordes,
- Left,
- Right,
- Above,
- Below,
- centrado en el eje ortogonal.

El drag usa coordenadas lógicas y solo confirma la posición al finalizar el
gesto.

Un cambio de scale o transform puede crear temporalmente un conflicto de layout.
En ese estado:

```text
Safe Apply = blocked
```

hasta que la posición sea corregida.

---

# MonitorService

Ruta:

```text
config/quickshell/jc-hyprland/services/MonitorService.qml
```

Responsabilidad:

- discovery,
- estado observado,
- geometría lógica,
- modos disponibles,
- output enfocado,
- outputs deshabilitados.

La lista incluye outputs deshabilitados porque el Control Center debe poder
volver a activarlos.

---

# Modos de monitor

Los modos no se hardcodean.

El Control Center usa:

```text
hyprctl -j monitors all
      ↓
availableModes
      ↓
MonitorModeParser
      ├── resolutions
      └── refresh rates per resolution
```

Ejemplo conceptual:

```text
3440x1440@165.00
3440x1440@120.00
3440x1440@99.98
3440x1440@59.97
```

Una resolución únicamente ofrece los refresh rates que aparecen asociados a
ella.

Duplicados exactos pueden deduplicarse.

Valores distintos como:

```text
120.00
119.88
```

siguen siendo modos diferentes.

---

# Scale

Los candidatos actuales del Control Center se filtran desde:

```text
1
1.25
1.5
1.75
2
```

y solo se ofrecen cuando producen dimensiones lógicas válidas para la
resolución seleccionada.

El scale forma parte tanto del draft como del runtime/persistencia.

---

# Orientation / transform

Hyprland usa valores transform `0..7`.

El draft y la persistencia conservan ese valor explícitamente.

Los cambios de orientación actualizan inmediatamente:

```text
logicalWidth
logicalHeight
projected topology
layout validation
```

sin aplicar todavía el monitor al runtime.

---

# Enable / Disable

`enabled` existe en:

```text
Observed
Draft
Projected topology
Runtime transaction
Persistent state
```

Reglas de seguridad:

```text
✓ debe quedar al menos un monitor activo
✓ el monitor enfocado no puede deshabilitarse
✓ backend repite los guards de la UI
✓ outputs disabled siguen visibles en el Control Center
```

Para reactivar un monitor previamente deshabilitado, el backend utiliza
explícitamente:

```lua
disabled = false
```

junto con su geometría reusable.

La persistencia Lua puede conservar:

```lua
disabled = true
mode = "..."
position = "..."
scale = ...
transform = ...
```

en el mismo bloque, por lo que deshabilitar no destruye la información necesaria
para una reactivación futura.

---

# Runtime apply

`MonitorApplyService.qml` no ejecuta mutaciones raw desde la UI.

Flujo:

```text
Display UI
    ↓
DisplayDraftStore
    ↓
MonitorApplyService
    ↓
jc-displayctl
    ↓
hyprctl eval hl.monitor(...)
```

`jc-displayctl` valida contra el estado live antes de modificar el compositor.

---

# Safe Apply

Cambiar pantallas puede causar:

- pantalla negra,
- modo no útil,
- monitor fuera del alcance,
- layout inválido,
- desactivación accidental.

El flujo validado es:

```text
Safe Apply
    │
    ├── snapshot previous runtime
    ├── apply draft
    ├── create rollback transaction
    └── start systemd user watchdog
                │
                ├── Keep → cancel watchdog
                └── timeout → rollback
```

El watchdog es externo a Quickshell.

Si Quickshell muere, el rollback continúa disponible.

---

# Keep

`Keep` confirma únicamente el estado runtime.

No escribe automáticamente:

```text
local/monitors.lua
```

Esta separación es intencional.

---

# Save Configuration

La persistencia la realiza:

```text
jc-displaycfg
```

CLI:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg status
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg preview
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg save
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg backups
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg restore-last
```

La operación es global porque `hyprctl reload` también lo es.

## Preview

`preview` genera un candidate sin mutar el archivo.

Debe mostrar únicamente diferencias reales, por ejemplo:

```diff
- mode = "3440x1440@164.99899",
+ mode = "3440x1440@120.00000",
```

sin tocar `workspace_rule(...)` ni extras no modificados.

## Save transaction

```text
save
 │
 ├── require clean configerrors
 ├── capture live monitor snapshot
 ├── build monitors.lua candidate
 ├── preserve non-monitor Lua
 ├── backup
 ├── atomic replace
 ├── hyprctl reload
 ├── wait for convergence
 ├── verify runtime == pre-save runtime
 └── success
```

En fallo:

```text
restore backup
     ↓
hyprctl reload
     ↓
return error
```

---

# Workspaces

Los roles lógicos pueden mantenerse en `host.env`:

```ini
MAIN_WORKSPACES=1,2,3,4,5
SECONDARY_WORKSPACES=6,7,8,9,10
```

La asociación persistente a un hardware concreto puede vivir en
`local/monitors.lua` mediante `hl.workspace_rule(...)`.

Cuando un output se deshabilita, Hyprland reacomoda los workspaces; al volver a
activarlo, las reglas persistentes restauran su ownership esperado.

---

# Waybar

Waybar mantiene dos instancias independientes para los roles:

```text
MAIN_OUTPUT
    └── main Waybar

SECONDARY_OUTPUT
    └── secondary Waybar
```

El comportamiento de Waybar durante Enable / Disable de monitores fue validado
sin agregar un restart artificial desde el backend de displays.

El backend de monitores no posee el lifecycle de Waybar.

---

# Wallpapers

Los wallpapers utilizan roles:

```text
main
secondary
both
```

El backend de wallpaper es independiente del de displays.

Un cambio de monitor no debe reiniciar arbitrariamente Awww/Hyprpaper.

---

# Portabilidad

```text
DO
✓ guardar roles en host.env
✓ guardar configuración física en monitors.lua
✓ mantener seriales fuera de Git
✓ descubrir modos en runtime
✓ usar geometría lógica
✓ usar wrappers/services
✓ separar Keep de Save
✓ validar Apply y Save

DON'T
✗ guardar seriales machine-local en Git
✗ meter conectores en themes
✗ hardcodear resoluciones en QML
✗ hacer que UI ejecute hyprctl directamente
✗ asumir exactamente dos monitores en la lógica base
✗ reiniciar wallpaper/Waybar desde display apply sin necesidad
```

---

# Diagnóstico

Estado observado:

```bash
hyprctl -j monitors all
```

Errores de configuración:

```bash
hyprctl configerrors
```

Control Center:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-control-center show
```

Estado de persistencia:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg status
```

Preview:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg preview
```

---

# Estado de fases

```text
Phase 1A    discovery / read-only                         ✓
Phase 1B.1  draft editing                                 ✓
Phase 1B.2  runtime mode apply                            ✓
Phase 1B.3  Safe Apply / Keep / rollback                  ✓
Phase 1B.4  scale / orientation                           ✓
Phase 1B.5  visual topology editor                        ✓
Phase 1B.6  Enable / Disable                              ✓
Phase 1C.1  Lua persistence backend                       ✓
Phase 1C.2  pre-Lua compatibility cleanup                 ✓
Phase 1C.3  Save Configuration UI orchestration           next
```

---

# Regla principal

La configuración compartida debe sobrevivir a:

```text
cambio de monitor
cambio de conector
cambio de resolución
cambio de scale
cambio de orientación
cambio de distro
cambio de tema
```

sin obligar a reescribir componentes reutilizables.

La máquina define **qué hardware tiene**.

El runtime descubre **cómo está funcionando**.

Los roles definen **qué función cumple**.

La UI presenta **qué puede cambiarse**.

El backend aplica **qué se usa temporalmente**.

La persistencia decide **qué debe conservarse**.
