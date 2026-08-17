# Devlog 02: Enemies

---

# Introduction

Once I got the map generation working, I needed to populate my maps with enemies. This topic may seem trivial, but there are multiple related challenges, divided into two types: Wave management and enemy pathfinding.

For starters, I had to compute how many enemies of each type appear and distribute them across spawn points around the map. The priority is coherence in enemy composition, so they don't appear as a random army.

Once the army is built, enemies that appear need to know where to go. This is, in essence, a pathfinding problem without a precalculated graph. The map size and number of enemies can reach extremely high numbers, so efficiency is critical here.

# Wave management

## Building an army

The first step in building an army is planning and hiring soldiers. I implemented a token-based system which grants the wave manager an increasing amount of tokens based on the current wave, with a small exponential bias:

```gdscript
func _compute_tokens(wave_number: int) -> int:
	return int(1 + (10 * wave_number * pow(1.01, wave_number)))
```

Using tokens, the wave manager can recruit enemies to fight in the current wave, which will be spawned in groups to avoid a random clutter of enemies.

![Enemies spawning in groups](https://i.imgur.com/WWK8560.gif)
*Enemies spawning in groups*

Some enemies have restrictions on how early in the game they can appear, so that information is also factored in, alongside how many of them can be grouped together for deployment:

```gdscript
var tokens: int = _compute_tokens(wave_number)
var available_types: Array = _get_unlocked_types(wave_number)
var max_group: int = int(10 + float(wave_number) / 4.0)
```

After gathering all relevant information, the wave manager proceeds to spend tokens to build enemy groups of the same category, cycling through available types:

```gdscript
var chosen: Enemy.EnemyType = affordable[randi() % affordable.size()]
var cost: int = TOKEN_COST[chosen]

# Group size is proportional to remaining budget, capped to avoid one type dominating
var actual_size: int = mini(int(remaining / cost), max_group)

var group: Array[Enemy.EnemyType] = []
for i in range(actual_size):
    group.append(chosen)
groups.append(group)
remaining -= cost * actual_size

# Remove this type so the next iteration picks a different one
available_types.erase(chosen)
```

Finally, the group list is shuffled to make the order feel more natural to the player, otherwise groups would cycle on a regular basis:

```gdscript
# Shuffle group order so the sequence varies between waves
groups.shuffle()

var enemy_list: Array[Enemy.EnemyType] = []
for group in groups:
    for type in group:
        enemy_list.append(type)
```

## Deploying troops

With the enemies ready, we have to place them around the map. First, we determine how many spawn points will be used:

```gdscript
var points_to_use: int = clampi(
	enemy_list.size() / 3,
	1,
	_spawn_data.size()
)
```

Next, we prioritize spawns that are farther away:

```gdscript
# Sort spawn points by weight descending (farthest first)
var sorted_spawns: Array = _spawn_data.duplicate()
sorted_spawns.sort_custom(func(a, b): return a["weight"] > b["weight"])
var active_spawns: Array = sorted_spawns.slice(0, points_to_use)
```

Finally, the time between enemy spawns, also called "spawn interval", is calculated. It shortens as the wave number increases, but it is at least fast enough to deliver 0.5% of the total enemy count each second:

```gdscript
func _compute_spawn_interval(wave_number: int, total_enemies: int, active_spawns: int) -> float:
	var speed_mult: float = _compute_speed_mult(wave_number)
	var scaled_interval: float = default_spawn_interval / speed_mult

	# Minimum interval: 0.5% of total enemies per second means
	# 1 tick per (active_spawns / (total * 0.005)) seconds
	var min_interval: float = float(active_spawns) / (float(total_enemies) * 0.005)
	min_interval = maxf(min_interval, 0.05)

	return minf(scaled_interval, min_interval)
```

# Enemy pathfinding

When enemies spawn, they need to know what path to follow in order to reach the player's base. In order to achieve this, I designed the system to store the direction from which each chunk was generated, a vector pointing to its parent chunk, which can be found in constant time since it is stored as a dictionary. This lookup is instant (constant time, or O(1)), no matter how many chunks exist, because the system doesn't need to search through a list; it just performs a direct hash table lookup using the chunk coordinates as the key:

```gdscript
var chunk_parent_dirs: Dictionary[Vector2i, Constants.Directions] = {}
```

Whenever an enemy spawns or reaches their current chunk goal, they request the map director where to go next:

```gdscript
func _request_next_target() -> void:
	var current_chunk: Vector2i = map_director.world_to_chunk(position)
	var next_pos: Vector2 = map_director.get_next_position(current_chunk)

	if next_pos == Vector2.ZERO:
		# get_next_position returns ZERO when at origin = base reached
		_on_reached_base()
		return

	_target = next_pos
```

Once the request is sent, the map director will access WorldData, a custom class holding information about the current state of chunks and retrieves the parent chunk given a pair of coordinates in O(1):

```gdscript
func get_parent_dir(c: Vector2i) -> int:
	# Real chunk: ORIGIN has no parent
	if chunks.get(c, ChunkState.NULL) == ChunkState.ORIGIN:
		return -1
	# Real PATH chunk: direction stored at registration
	if chunk_parent_dirs.has(c):
		return chunk_parent_dirs[c]
	# Ghost chunk: entry_dir points FROM the parent, so that IS the direction toward parent
	if ghost_chunks.has(c):
		return ghost_chunks[c]
	return -1
```

Since the origin chunk has its own state (ChunkState.ORIGIN), we can easily detect when the player base has been reached, in which case we would send a damage signal and remove the enemy:

```gdscript
func _on_reached_base() -> void:
	_active = false
	reached_base.emit(damage)
	queue_free()
```
