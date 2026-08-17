# Devlog 03: Towers

---

# Introduction

Once enemies were walking down the paths, I needed something to stop them. Towers are the core gameplay loop of any tower defense, but making them interesting is a design challenge: a game where all towers feel the same gets boring fast. The flip side is that making each tower a special case means the code becomes a mess the moment you try to add a new one.

I needed a system flexible enough to support very different towers without requiring a rewrite every time, and clean enough that future additions (like modifiers changing behavior at runtime) wouldn't break everything.

# My solution

Each tower is split into three nodes with distinct responsibilities.

**Tower** holds stats, getters, and targeting logic. It doesn't know how to shoot or what it looks like. It just knows who to shoot at:

```gdscript
func _select_target(enemies: Array) -> Node2D:
    match target_mode:
        TargetMode.MOST_HP:
            target = _get_hp_extreme(enemies, true)
        TargetMode.CLOSEST:
            target = _get_distance_extreme(enemies, true)
        # ...
    return target
```

Stats scale with level using a base + scaling resource pair, so every getter is one line:

```gdscript
func get_damage() -> float:
    return _stats.damage + _stats_scaling.damage * _level
```

**TowerVisuals** handles everything aesthetic. Right now that means rotating the cannon to face the current target:

```gdscript
func rotate_towards_target(target_position: Vector2) -> void:
    _cannon.global_rotation = (target_position - _cannon.global_position).angle()
```

Keeping this separate means swapping a tower's look, adding animations, or making a tower that doesn't rotate at all, are all changes that don't touch stats or shooting logic.

**TowerWeapon** handles the actual firing. Instead of a Timer node, it uses a float accumulator:

```gdscript
func _accumulate_attack(delta: float) -> void:
    _attack_accumulator += delta
    var interval: float = _tower.get_attack_speed_timer()
    while _attack_accumulator >= interval:
        _attack_accumulator -= interval
        shoot()
```

A Timer node caps effective attack speed at the framerate: once the wait time drops below a frame's duration, it can only fire once per frame. The accumulator has no such ceiling and always reflects the current attack speed, which matters when modifiers will be changing stats at runtime.

# Projectiles

TowerWeapon fires a `_projectile` scene. The projectile is responsible for its own movement and collision, and pulls stats from the tower via `setup()`:

```gdscript
func setup(tower: Tower) -> void:
    damage = tower.get_damage()
    _apply_spread(tower.get_spread())
    _start_lifetime(tower.get_optics())
```

Lifetime is derived from the tower's optics range, giving the bullet 50% extra travel distance beyond the tower's range so targets acquired near the edge still get hit.

The base projectile (Bullet) exposes three virtual hooks for subclasses:

```gdscript
func on_spawn() -> void: pass
func on_hit(_enemy: Node, _damage_dealt: int) -> void: pass
func on_lifetime_expired() -> void: pass
```

A projectile that explodes on impact, one that pierces through enemies, or one that slows targets on hit are all just subclasses of Bullet that override one of these hooks. The base collision and movement logic stays untouched.

The result is a system where adding a new tower type is mostly a matter of filling in different numbers in the Inspector and, if needed, writing a small Bullet subclass. The three-node split means each concern has exactly one place to live, and the hook pattern in the projectile keeps future mod behavior from needing to touch the base classes.

# The shop

Towers need to be buyable. The shop is a CanvasLayer on the right side of the screen, with a grid of slots. Each slot is a `TowerShopSlotConfig` resource with three fields: the tower scene, a base price, and a price increment. Adding a new tower to the shop is dragging a resource into an array in the Inspector, nothing more.

Each slot keeps a ghost instance of its tower scene: instantiated but never added to the scene tree. This is used to query stats for the tooltip without any side effects:

```gdscript
func _on_slot_hover(idx: int) -> void:
    var g := slot.ghost
    var text := "%s\n%s\n\nDamage: %.1f\nAtk Speed: %.2f\nOptics: %.1f" % [
        g.get_title(), g.get_description(),
        g.get_damage(), g.get_attack_speed(), g.get_optics()
    ]
    _tooltip_label.text = text
```

The ghost also updates its level at the end of each wave, so the tooltip always shows stats at the current wave's level before the player commits to a purchase.

Prices increase every time a tower of that type is bought, and persist for the rest of the run:

```gdscript
func increment_price() -> void:
    current_price += price_increment
```

When a slot is clicked, instead of placing a tower immediately, a placement mode starts. A cursor sprite follows the mouse showing the tower's icon, and a transparent circle drawn via `_draw()` shows the optics range, snapping to the nearest valid chunk:

```gdscript
func _draw() -> void:
    var color: Color = _VALID_COLOR if _placement_valid else _INVALID_COLOR
    draw_circle(local_pos, _draw_radius, color)
    draw_arc(local_pos, _draw_radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.8), 2.0)
```

The circle turns red on invalid placements (path chunks, already-built slots, ghost chunks). A left click confirms and spends the gold, a right click cancels. Both are announced via the notification system.
